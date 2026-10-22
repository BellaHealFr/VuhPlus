-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Recharges du raid : qui a quoi de PRÊT (externes, gros sorts de soin, mana, Héroïsme)
-- + résurrections en combat (Renaissance, Réanimation d'un allié) et pierres d'âme posées.
-- Inspiré des « Raid tools » de Cell (battle res) et des suivis de recharges des guides WotLK.
--  * vos sorts : recharge exacte lue dans le jeu (talents et glyphes compris) ;
--  * les autres : recharge de base WotLK, à partir du moment où le sort est vu dans le journal de combat ;
--  * sorts de base d'une classe : supposés prêts tant qu'on ne les a pas vus lancés ;
--    sorts de talent : affichés seulement après la première utilisation vue (on ne connaît pas les talents des autres).
local VP = VuhPlus
local CD = VP:NewModule("Cooldowns")

-- id : n'importe quel rang (le nom localisé sert à reconnaître le sort) ; cd : recharge de base (s)
-- base : sort de base de la classe ; br : résurrection en combat ; faction : Héroïsme / Furie sanguinaire
CD.SPELLS = {
	{ id = 20484, class = "DRUID", cd = 600, base = true, br = true },         -- Renaissance
	{ id = 61999, class = "DEATHKNIGHT", cd = 600, base = true, br = true },   -- Réanimation d'un allié
	{ id = 33206, class = "PRIEST", cd = 180 },                                 -- Suppression de la douleur
	{ id = 47788, class = "PRIEST", cd = 180 },                                 -- Esprit gardien
	{ id = 6940,  class = "PALADIN", cd = 120, base = true },                   -- Main de sacrifice
	{ id = 1022,  class = "PALADIN", cd = 300, base = true },                   -- Main de protection
	{ id = 64205, class = "PALADIN", cd = 120 },                                -- Sacrifice divin
	{ id = 31821, class = "PALADIN", cd = 120 },                                -- Maîtrise des auras
	{ id = 633,   class = "PALADIN", cd = 1200, base = true },                  -- Imposition des mains
	{ id = 64843, class = "PRIEST", cd = 480, base = true },                    -- Hymne divin
	{ id = 64901, class = "PRIEST", cd = 360, base = true },                    -- Hymne d'espoir
	{ id = 16190, class = "SHAMAN", cd = 300 },                                 -- Totem de vague de mana
	{ id = 29166, class = "DRUID", cd = 180, base = true },                     -- Innervation
	{ id = 740,   class = "DRUID", cd = 480, base = true },                     -- Tranquillité
	{ id = 32182, class = "SHAMAN", cd = 300, base = true, faction = "Alliance" }, -- Héroïsme
	{ id = 2825,  class = "SHAMAN", cd = 300, base = true, faction = "Horde" },    -- Furie sanguinaire
	{ id = 10060, class = "PRIEST", cd = 120 },                                 -- Infusion de puissance (talent)
	{ id = 51052, class = "DEATHKNIGHT", cd = 120 },                            -- Zone anti-magie (talent)
	{ id = 19752, class = "PALADIN", cd = 600, base = true },                   -- Intervention divine
}
local byId = {}
for _, e in ipairs(CD.SPELLS) do byId[e.id] = e end
local SOULSTONE_ID = 20707   -- Résurrection de pierre d'âme (buff)

local band = bit and bit.band
local GROUP_MASK = 0x00000007   -- COMBATLOG_OBJECT_AFFILIATION_MINE | PARTY | RAID

CD.byName = {}     -- nom localisé -> entrée
CD.ready = {}      -- GUID -> { [id] = heure où le sort sera de nouveau prêt }
CD.seen = {}       -- GUID -> { [id] = true } : sort vu lancé (sorts de talent)
CD.synced = {}     -- GUID -> heure du dernier état reçu d'un autre joueur VuhPlus
CD.has = {}        -- GUID -> { [id] = true } : sorts qu'il possède VRAIMENT (d'après son propre addon)
local soulName

-- Photo du groupe, prise UNE fois par rafraîchissement : chaque sort parcourt cette liste au lieu
-- d'interroger le jeu pour chaque joueur (15 sorts x 25 joueurs sinon). Tables réutilisées.
local RAID_U, PARTY_U = {}, {}
for i = 1, 40 do RAID_U[i] = "raid" .. i end
for i = 1, 4 do PARTY_U[i] = "party" .. i end
local roster, rosterN = {}, 0
local function addUnit(u)
	if not UnitExists(u) or not UnitIsConnected(u) then return end
	rosterN = rosterN + 1
	local r = roster[rosterN]
	if not r then r = {}; roster[rosterN] = r end
	local _, class = UnitClass(u)
	r.unit, r.guid, r.name, r.class = u, UnitGUID(u), UnitName(u), class
	r.dead = UnitIsDeadOrGhost(u) and true or false
	r.me = UnitIsUnit(u, "player") and true or false
end
function CD:Snapshot()
	rosterN = 0
	local n = GetNumRaidMembers()
	if n > 0 then
		for i = 1, n do addUnit(RAID_U[i]) end
	else
		addUnit("player")
		for i = 1, GetNumPartyMembers() do addUnit(PARTY_U[i]) end
	end
end

local function fmt(sec)
	sec = math.ceil(sec)
	if sec >= 60 then return string.format("%d:%02d", math.floor(sec / 60), sec % 60) end
	return sec .. " s"
end

-- code couleur par classe, gardé en mémoire (le panneau se redessine 2 à 10 fois par seconde)
local hexCache, hexKey = {}, {}
local function classHex(class)
	local r, g, b = VP.Colors:Class(class)
	local k = class or "?"
	local key = r * 1e6 + g * 1e3 + b   -- couleur changée dans les options : code recalculé
	if hexKey[k] ~= key then
		hexKey[k] = key
		hexCache[k] = string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
	end
	return hexCache[k]
end

-- Le sort est-il suivi (option) et de la bonne faction ?
function CD:Wanted(e)
	if VP.db.cooldowns.spells[e.id] == false then return false end
	if e.faction and e.faction ~= UnitFactionGroup("player") then return false end
	return e.name ~= nil
end

-- Propriétaires d'un sort dans le groupe (d'après la photo) : liste { name, class, left, dead }
-- left = 0 : prêt. Prêts d'abord, puis par temps restant.
local ownersBuf, poolBuf = {}, {}
local function byReady(a, b)
	if (a.left > 0) ~= (b.left > 0) then return a.left == 0 end
	return a.left < b.left
end
function CD:Owners(e)
	local out, pool = ownersBuf[e.id], poolBuf[e.id]
	if not out then out, pool = {}, {}; ownersBuf[e.id], poolBuf[e.id] = out, pool end
	for i = #out, 1, -1 do out[i] = nil end
	local now, n = GetTime(), 0
	for k = 1, rosterN do
		local r = roster[k]
		if r.class == e.class then
			local has
			local left = 0
			if r.me then
				-- vous : le grimoire et la vraie recharge (talents, glyphes)
				has = GetSpellInfo(e.name) ~= nil
				if has then
					local start, dur = GetSpellCooldown(e.name)
					left = (start and start > 0 and dur and dur > 1.5) and (start + dur - now) or 0
				end
			else
				local g = r.guid
				if g and self.synced[g] then
					-- joueur VuhPlus : sa propre liste fait foi (talents connus, sorts pas encore appris)
					has = self.has[g] and self.has[g][e.id] or false
				else
					has = e.base or (g and self.seen[g] and self.seen[g][e.id]) or false
				end
				local rd = g and self.ready[g] and self.ready[g][e.id]
				left = (rd and rd > now) and (rd - now) or 0
			end
			if has then
				n = n + 1
				local o = pool[n]
				if not o then o = {}; pool[n] = o end
				o.name, o.class, o.left, o.dead = r.name, r.class, left, r.dead
				out[n] = o
			end
		end
	end
	if n > 1 then table.sort(out, byReady) end
	return out
end

-- Résurrections en combat : nombre prêtes + texte ; pierres d'âme posées (d'après la photo)
local partsBuf, stonesBuf = {}, {}
function CD:BattleRes()
	local ready = 0
	wipe(partsBuf); wipe(stonesBuf)
	for _, e in ipairs(self.SPELLS) do
		if e.br and self:Wanted(e) then
			for _, o in ipairs(self:Owners(e)) do
				if o.left <= 0 and not o.dead then
					ready = ready + 1
					partsBuf[#partsBuf + 1] = classHex(o.class) .. o.name .. "|r"
				else
					partsBuf[#partsBuf + 1] = "|cff777777" .. o.name .. (o.dead and " (mort)" or (" " .. fmt(o.left))) .. "|r"
				end
			end
		end
	end
	if soulName then
		for k = 1, rosterN do
			local r = roster[k]
			if UnitBuff(r.unit, soulName) then stonesBuf[#stonesBuf + 1] = r.name end
		end
	end
	return ready, partsBuf, stonesBuf
end

-- Journal de combat : un sort suivi lancé par un membre du groupe
function CD:OnCast(srcGUID, srcFlags, spellName)
	local e = self.byName[spellName]
	if not e or not srcGUID then return end
	if band and band(srcFlags or 0, GROUP_MASK) == 0 then return end
	self.ready[srcGUID] = self.ready[srcGUID] or {}
	self.ready[srcGUID][e.id] = GetTime() + e.cd
	self.seen[srcGUID] = self.seen[srcGUID] or {}
	self.seen[srcGUID][e.id] = true
	self.dirty = true
	-- votre sort : les autres joueurs VuhPlus reçoivent la VRAIE recharge (lisible après le temps global)
	if srcGUID == UnitGUID("player") then self:QueueSend(1.6) end
end

-- Partage des recharges entre joueurs VuhPlus ------------------------------------------
-- Chacun envoie la recharge réelle de SES sorts suivis (talents et glyphes compris) par message
-- d'addon au groupe. Les autres l'affichent au lieu de la recharge de base estimée.
-- Format : « S:id=secondes,id=secondes » (0 = prêt). Rien n'est exécuté à la réception.
local PREFIX = "VuhPlusCD"
local sendAt, lastSend = nil, 0
function CD:QueueSend(delay)
	local t = GetTime() + (delay or 0)
	if not sendAt or t < sendAt then sendAt = t end
end
function CD:State()
	local parts, now = {}, GetTime()
	for _, e in ipairs(self.SPELLS) do
		if e.name and e.class == VP.class and GetSpellInfo(e.name) then
			local start, dur = GetSpellCooldown(e.name)
			local left = (start and start > 0 and dur and dur > 1.5) and math.max(0, math.floor(start + dur - now + 0.5)) or 0
			parts[#parts + 1] = e.id .. "=" .. left
		end
	end
	return table.concat(parts, ",")
end
function CD:Send()
	sendAt = nil
	if VP.db.cooldowns.sync == false then return end
	local ch = VP:GroupChannel()
	if not ch then return end
	local now = GetTime()
	if now - lastSend < 3 then self:QueueSend(3 - (now - lastSend)) return end   -- pas de rafale
	lastSend = now
	-- même une liste vide est envoyée : « je n'ai aucun de ces sorts » vaut information
	SendAddonMessage(PREFIX, "S:" .. self:State(), ch)
end
function CD:OnMessage(msg, sender)
	if VP.db.cooldowns.sync == false or not sender or sender == UnitName("player") then return end
	local body = type(msg) == "string" and string.match(msg, "^S:(.*)$")
	if not body then return end
	local g = UnitGUID(sender)   -- nom d'un membre du groupe : renvoie son GUID
	if not g then return end
	local now = GetTime()
	local has = self.has[g] or {}
	wipe(has)
	self.has[g] = has
	self.ready[g] = self.ready[g] or {}
	self.seen[g] = self.seen[g] or {}
	for id, left in string.gmatch(body, "(%d+)=(%d+)") do
		id, left = tonumber(id), tonumber(left)
		if id and left and byId[id] and left <= 3600 then
			has[id] = true
			self.seen[g][id] = true
			self.ready[g][id] = now + left
		end
	end
	self.synced[g] = now
	self.dirty = true
end
-- Joueurs VuhPlus dont on connaît les vraies recharges (pour l'affichage)
function CD:SyncedCount()
	local n = 0
	for k = 1, rosterN do
		local r = roster[k]
		if not r.me and r.guid and self.synced[r.guid] then n = n + 1 end
	end
	return n
end

-- Panneau ---------------------------------------------------------------------------------
local ROWS = 16
local lineBuf = {}
function CD:Update()
	local f = self.frame
	if not f then return end
	local db = VP.db.cooldowns
	local inGroup = GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
	if not db.enabled or (db.groupOnly and not inGroup and VP.db.locked) then f:Hide() return end
	self:Snapshot()
	local y, row = -24, 0
	local width = 180
	local function line(icon, text)
		row = row + 1
		local r = f.rows[row]
		if not r then return end
		r.icon:SetTexture(icon)
		if icon then r.icon:Show() else r.icon:Hide() end
		r.text:SetText(text)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", f, "TOPLEFT", 6, y)
		r:Show()
		y = y - 18
		width = math.max(width, r.text:GetStringWidth() + 34)
	end
	if db.br then
		local ready, parts, stones = self:BattleRes()
		local head = (ready > 0 and "|cff55ff55" or "|cffff5555") .. "Rez combat : " .. ready .. "|r"
		if #parts > 0 then head = head .. "  " .. table.concat(parts, ", ") end
		line("Interface\\Icons\\Spell_Nature_Reincarnation", head)
		if #stones > 0 then
			line("Interface\\Icons\\Spell_Shadow_SoulGem", "|cffcc88ffPierres d'âme :|r " .. table.concat(stones, ", "))
		end
	end
	for _, e in ipairs(self.SPELLS) do
		if not e.br and self:Wanted(e) then
			local own = self:Owners(e)
			if #own > 0 then
				wipe(lineBuf)
				local t = lineBuf
				for _, o in ipairs(own) do
					if o.dead then t[#t + 1] = "|cff555555" .. o.name .. "|r"
					elseif o.left <= 0 then t[#t + 1] = classHex(o.class) .. o.name .. "|r"
					else t[#t + 1] = "|cff777777" .. o.name .. " " .. fmt(o.left) .. "|r" end
				end
				line(e.icon, table.concat(t, ", "))
			end
		end
	end
	for i = row + 1, ROWS do f.rows[i]:Hide() end
	-- combien de joueurs envoient leurs vraies recharges (les autres : recharge de base estimée)
	local ns = self:SyncedCount()
	local tt = "Recharges du raid" .. (ns > 0 and ("  |cff55dd77" .. ns .. " exact" .. (ns > 1 and "s" or "") .. "|r") or "")
	if f.titleText ~= tt then f.titleText = tt; f.title:SetText(tt) end
	if row == 0 then
		f.empty:Show()
		y = y - 18
	else
		f.empty:Hide()
	end
	f:SetWidth(math.min(420, width + 8))
	f:SetHeight(-y + 6)
	f:Show()
end

function CD:ApplyPosition()
	local f = self.frame
	if not f then return end
	local db = VP.db.cooldowns
	local p = db.pos
	f:ClearAllPoints()
	f:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
	VP:Unplace(f)
	f:SetScale(db.scale or 1)
	if VP.db.locked then f.handle:Hide() else f.handle:Show() end
end

function CD:Refresh()
	if not self.frame then return end
	self:ApplyPosition()
	self:Update()
end

function CD:OnLogin()
	for _, e in ipairs(self.SPELLS) do
		local n, _, ic = GetSpellInfo(e.id)
		e.name, e.icon = n, ic
		if n then self.byName[n] = e end
	end
	soulName = GetSpellInfo(SOULSTONE_ID)

	local T = VP.Theme
	local f = CreateFrame("Frame", "VuhPlusCooldowns", UIParent)
	f:SetWidth(200); f:SetHeight(60)
	f:SetMovable(true); f:SetClampedToScreen(true)
	T:Backdrop(f, T.C.bg, T.C.border)
	local stripe = T:Tex(f, "ARTWORK")
	stripe:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	stripe:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
	stripe:SetHeight(2)
	T:RegisterAccent(stripe)
	local title = T:Text(f, 12, nil, nil, nil, true)
	title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
	title:SetText("Recharges du raid")
	f.title = title
	f.empty = T:Text(f, 11, T.C.muted)
	f.empty:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -26)
	f.empty:SetText("Aucun sort suivi dans le groupe")
	f.handle = T:Handle(f, "Recharges du raid",
		function() f:StartMoving() end,
		function()
			f:StopMovingOrSizing()
			local point, _, relPoint, x, y = f:GetPoint()
			VP.db.cooldowns.pos = { point = point, relPoint = relPoint, x = x, y = y }
			VP:Unplace(f)
		end)
	f.rows = {}
	for i = 1, ROWS do
		local r = CreateFrame("Frame", nil, f)
		r:SetWidth(400); r:SetHeight(16)
		r.icon = r:CreateTexture(nil, "ARTWORK")
		r.icon:SetWidth(14); r.icon:SetHeight(14)
		r.icon:SetPoint("LEFT", r, "LEFT", 0, 0)
		r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		r.text = T:Text(r, 11)
		r.text:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
		r.text:SetJustifyH("LEFT")
		r:Hide()
		f.rows[i] = r
	end
	self.frame = f
	self:Refresh()

	VP:On("COMBAT_LOG_EVENT_UNFILTERED", function(_, _, event, srcGUID, _, srcFlags, _, _, _, _, spellName)
		if event == "SPELL_CAST_SUCCESS" or event == "SPELL_RESURRECT" or event == "SPELL_SUMMON" then
			CD:OnCast(srcGUID, srcFlags, spellName)
		end
	end)
	-- partage : réception, et envoi quand le groupe change (délai au hasard : pas 25 messages à la fois)
	VP:On("CHAT_MSG_ADDON", function(_, prefix, msg, _, sender)
		if prefix == PREFIX then CD:OnMessage(msg, sender) end
	end)
	local function soon() CD:QueueSend(2 + math.random() * 3) end
	VP:On("RAID_ROSTER_UPDATE", soon)
	VP:On("PARTY_MEMBERS_CHANGED", soon)
	VP:On("PLAYER_ENTERING_WORLD", function() CD:QueueSend(5 + math.random() * 3) end)
	VP:On("ACTIVE_TALENT_GROUP_CHANGED", soon)
	VP:On("PLAYER_TALENT_UPDATE", soon)
	local acc, resend = 0, 0
	local drv = CreateFrame("Frame")
	drv:SetScript("OnUpdate", function(_, e)
		if sendAt and GetTime() >= sendAt then CD:Send() end
		-- rappel toutes les 2 minutes (un joueur arrivé entre-temps, un message perdu)
		resend = resend + e
		if resend >= 120 then resend = 0; CD:QueueSend(math.random() * 5) end
		acc = acc + e
		if acc < (CD.dirty and 0.1 or 0.5) then return end
		acc = 0
		CD.dirty = nil
		CD:Update()
	end)
end
