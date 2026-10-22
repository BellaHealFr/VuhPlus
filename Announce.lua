-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Annonces et compte à rebours de vos gros sorts (Héroïsme, Totem de vague de mana...)
-- * vos sorts : annoncés dans le bon canal (raid / groupe / champ de bataille) avec un compte à
--   rebours visible par tous (« Héroïsme : 10 s », « Héroïsme terminé ») ;
-- * barres de temps à l'écran pour vos sorts ET ceux des autres soigneurs du groupe.
local VP = VuhPlus
local AN = VP:NewModule("Announce")

-- dur = durée de l'effet (s) ; target = sort lancé sur un joueur ; big = gros sort (alerte de raid
-- possible) ; channel = sort canalisé (s'arrête si vous bougez)
AN.SPELLS = {
	SHAMAN = {
		{ id = 16190, key = "manatide", cd = true, dur = 12, big = true },               -- Totem de vague de mana
		{ id = 32182, key = "heroism", cd = true, dur = 40, big = true },                -- Héroïsme
		{ id = 2825, key = "bloodlust", cd = true, dur = 40, big = true },               -- Furie sanguinaire
	},
	DRUID = {
		{ id = 29166, key = "innervate", cd = true, dur = 10, target = true },           -- Innervation
		{ id = 20484, key = "rebirth", cd = true, target = true, big = true },           -- Renaissance
		{ id = 740, key = "tranquility", dur = 8, channel = true },           -- Tranquillité
	},
	PRIEST = {
		{ id = 64901, key = "hymnhope", cd = true, dur = 8, big = true, channel = true },   -- Hymne d'espoir
		{ id = 64843, key = "divinehymn", cd = true, dur = 8, big = true, channel = true }, -- Hymne divin
		{ id = 33206, key = "painsup", cd = true, dur = 8, target = true },              -- Suppression de la douleur
		{ id = 47788, key = "guardian", cd = true, dur = 10, target = true },            -- Esprit gardien
		{ id = 10060, key = "pi", dur = 15, target = true },                  -- Infusion de puissance
	},
	PALADIN = {
		{ id = 31821, key = "auramastery", cd = true, dur = 6, big = true },             -- Maîtrise des auras
		{ id = 64205, key = "divsac", cd = true, dur = 10, big = true },                 -- Sacrifice divin
		{ id = 6940, key = "hsac", dur = 12, target = true },                 -- Main de sacrifice
		{ id = 1022, key = "hprot", dur = 10, target = true },                -- Main de protection
		{ id = 633, key = "loh", cd = true, target = true },                             -- Imposition des mains
	},
}

local mine = {}      -- nom localisé -> entrée (vos sorts, annoncés)
local any = {}       -- nom localisé -> entrée (tous les sorts suivis, barres à l'écran)
local last = {}      -- anti-doublon
AN.active = {}       -- comptes à rebours en cours

function AN:List() return self.SPELLS[VP.class] or {} end
function AN:Name(e) return (GetSpellInfo(e.id)) or ("Sort " .. e.id) end

-- Canal : réglage choisi, ou automatique (raid / groupe / champ de bataille)
function AN:Channel(e, tick)
	local c = VP.db.announce
	if c.channel == "SELF" then return nil end
	if c.channel == "SAY" or c.channel == "YELL" then return c.channel end
	local ch = VP:GroupChannel()
	-- alerte de raid : seulement pour l'annonce de départ (le décompte reste dans le chat du raid)
	if ch == "RAID" and e.big and c.warning and not tick and (IsRaidLeader() or IsRaidOfficer()) then ch = "RAID_WARNING" end
	return ch
end

-- « 20 min », « 4 min 30 s », « 45 s »
local function fmtCD(sec)
	sec = math.floor(sec + 0.5)
	if sec >= 120 then return math.floor(sec / 60 + 0.5) .. " min" end   -- « 20 min » (pas « 19 min 58 s »)
	if sec >= 60 then
		local m, r = math.floor(sec / 60), sec % 60
		return r >= 5 and (m .. " min " .. r .. " s") or (m .. " min")
	end
	return sec .. " s"
end
AN.fmtCD = fmtCD

-- temps de recharge réel du sort (talents / glyphes compris) ; nil pendant le temps global
local function realCD(e)
	local start, dur = GetSpellCooldown(AN:Name(e))
	if start and dur and dur > 2 and start > 0 then return start + dur, dur end
end

local function label(a)
	return AN:Name(a.e) .. (a.e.target and a.target and a.target ~= "" and (" sur " .. a.target) or "")
end

-- Envoi d'une annonce, en mode discret (5.8.5 : les joueurs trouvaient les annonces envahissantes) :
--   * jamais de message privé ;
--   * au groupe : seulement les sorts choisis (sorts de raid par défaut), en instance, et au plus
--     un message toutes les 3 s (le reste va dans mon chat) ;
--   * « de nouveau disponible » : dans mon chat seulement (réglable).
-- kind : "start" (départ), "tick" (décompte), "end" (terminé), "cdready" (de nouveau disponible)
local lastGroup, GROUP_GAP = 0, 3
function AN:Say(a, text, tick, kind)
	local c = VP.db.announce
	kind = kind or (tick and "tick" or "start")
	local ch = self:Channel(a.e, tick)
	if ch then
		local scope = c.scope or "BIG"
		local ok = not (scope == "NONE" or (scope == "BIG" and not a.e.big))
		if c.instanceOnly ~= false and not IsInInstance() then ok = false end
		if kind == "cdready" and c.cdReadySelf ~= false then ok = false end
		local now = GetTime()
		if ok and now - lastGroup >= GROUP_GAP then
			lastGroup = now
			SendChatMessage(text, ch)
			return
		end
	end
	-- sinon dans mon chat : départ et « de nouveau disponible » seulement (les barres montrent déjà le décompte)
	if (kind == "start" or kind == "cdready") and (c.channel == "SELF" or c.soloSelf) then VP:Print(text) end
end

-- moments du décompte annoncés dans le chat, selon le style choisi
local TICKS = {
	FULL = { 30, 20, 10, 5, 3, 2, 1 },
	LIGHT = { 10, 5 },
	END = {},
}

-- les options sont relues à chaque message : couper une annonce en cours l'arrête aussi
local function wanted(e)
	local c = VP.db.announce
	return c.enabled and c.spells[e.key] ~= false
end

-- Nouveau sort lancé (par vous ou un membre du groupe)
function AN:Start(e, target, srcName, isMine)
	local c = VP.db.announce
	local now = GetTime()
	local key = e.key .. (srcName or "")
	if last[key] and now - last[key] < 2 then return end
	-- effet déjà en cours pour ce lanceur : c'est un « tic » du même sort (hymnes, Tranquillité,
	-- soin déclenché d'Esprit gardien...), pas un nouveau lancement
	for _, o in ipairs(self.active) do
		if o.kind ~= "cd" and o.e == e and o.src == srcName and o.ends and o.ends - now > 1 then return end
	end
	last[key] = now
	local a = { e = e, target = target, src = srcName, mine = isMine, start = now,
		ends = e.dur and (now + e.dur) or nil, ticked = {} }
	if isMine then
		local readyAt, dur
		if e.cd and (c.cdAnnounce or c.cdBars) then
			readyAt, dur = realCD(e)
			if readyAt then
				self:StartCD(e, readyAt, dur)
			else
				-- le temps de recharge n'est lisible qu'après le temps global : on relit dans 1,6 s
				self.cdCheck = self.cdCheck or {}
				self.cdCheck[e] = { at = now + 1.6, a = a }
			end
		end
		if wanted(e) then
			a.announce = true
			if e.cd and c.cdAnnounce and not readyAt then
				-- annonce envoyée avec le temps de recharge, en un seul message (dans 1,6 s max)
				a.pendingStart = true
			else
				self:Say(a, self:StartText(a, readyAt and (readyAt - now)))
			end
		end
	end
	if a.ends then
		-- remplace un décompte identique déjà en cours (même sort, même lanceur)
		for i = #self.active, 1, -1 do
			local o = self.active[i]
			if o.kind ~= "cd" and o.e == e and o.src == srcName then self:Stop(i, true) end
		end
		-- barres des autres soigneurs : seulement leurs sorts de raid par défaut (moins de distraction à l'écran)
		if isMine or (c.othersBars and (not c.othersBigOnly or e.big)) then
			self.active[#self.active + 1] = a
			self:Layout()
		end
	end
end

-- « >> Renaissance sur Bob << - de nouveau utilisable dans 20 min »
function AN:StartText(a, cdLeft)
	local c = VP.db.announce
	return ">> " .. label(a) .. (a.e.dur and (" (" .. a.e.dur .. " s)") or "") .. " <<"
		.. ((cdLeft and c.cdAnnounce) and (" - de nouveau utilisable dans " .. fmtCD(cdLeft)) or "")
end

-- Temps de recharge d'un de vos sorts : barre à l'écran et annonce quand il redevient utilisable
function AN:StartCD(e, readyAt, dur)
	for i = #self.active, 1, -1 do
		local o = self.active[i]
		if o.kind == "cd" and o.e == e then self:Stop(i, true) end
	end
	if not VP.db.announce.cdBars and not VP.db.announce.cdAnnounce then return end
	self.active[#self.active + 1] = { e = e, kind = "cd", mine = true, start = GetTime(), ends = readyAt, total = dur,
		announce = true, ticked = {} }
	self:Layout()
end

-- Fin d'un décompte (temps écoulé, canalisation interrompue, effet retiré)
function AN:Stop(i, silent)
	local a = table.remove(self.active, i)
	if not a then return end
	if not silent and a.announce and wanted(a.e) then
		if a.kind == "cd" then
			if VP.db.announce.cdAnnounce then self:Say(a, ">> " .. AN:Name(a.e) .. " de nouveau disponible <<", true, "cdready") end
		elseif VP.db.announce.countdown ~= "NONE" then
			self:Say(a, label(a) .. " terminé", true, "end")
		end
	end
	if a.bar then a.bar:Hide(); a.bar.used = false; a.bar = nil end
	self:Layout()
end

function AN:Tick()
	local c = VP.db.announce
	local now = GetTime()
	local ticks = TICKS[c.countdown or "LIGHT"]
	-- recharges à relire après le temps global
	if self.cdCheck then
		for e, chk in pairs(self.cdCheck) do
			if now >= chk.at then
				self.cdCheck[e] = nil
				local readyAt, dur = realCD(e)
				if readyAt then self:StartCD(e, readyAt, dur) end
				local a = chk.a
				if a.pendingStart then
					a.pendingStart = nil
					if wanted(e) then self:Say(a, self:StartText(a, readyAt and (readyAt - now))) end
				end
			end
		end
		if not next(self.cdCheck) then self.cdCheck = nil end
	end
	for i = #self.active, 1, -1 do
		local a = self.active[i]
		local left = a.ends - now
		if left <= 0 then
			self:Stop(i)
		else
			if a.announce and ticks and a.kind ~= "cd" and not a.pendingStart and wanted(a.e) then
				local s = math.ceil(left)
				for _, t in ipairs(ticks) do
					-- on n'annonce que les paliers plus courts que le sort (pas « 30 s » pour 12 s)
					if s == t and t < (a.e.dur or 0) and not a.ticked[t] then
						a.ticked[t] = true
						self:Say(a, label(a) .. " : " .. t .. " s", true)
					end
				end
			end
			if a.bar then
				a.bar.sb:SetValue(left / (a.total or a.e.dur or 1))
				a.bar.right:SetText(left >= 60 and fmtCD(left) or (left < 10 and string.format("%.1f", left) or tostring(math.floor(left))))
			end
		end
	end
end

-- Barres à l'écran ---------------------------------------------------------------
local pool = {}
local function getBar()
	for _, b in ipairs(pool) do if not b.used then b.used = true; return b end end
	local T = VP.Theme
	local f = CreateFrame("Frame", nil, AN.frame)
	f:SetWidth(200); f:SetHeight(20)
	T:Backdrop(f, { 0, 0, 0, 0.6 }, { 0, 0, 0, 1 })
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetWidth(18); f.icon:SetHeight(18)
	f.icon:SetPoint("LEFT", f, "LEFT", 1, 0)
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.sb = CreateFrame("StatusBar", nil, f)
	f.sb:SetStatusBarTexture(T.TEX)
	f.sb:SetMinMaxValues(0, 1)
	f.sb:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 2, 0)
	f.sb:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
	f.left = T:Text(f.sb, 11, nil, "OUTLINE")
	f.left:SetPoint("LEFT", f.sb, "LEFT", 4, 0)
	f.left:SetWidth(140); f.left:SetJustifyH("LEFT")
	f.right = T:Text(f.sb, 11, nil, "OUTLINE")
	f.right:SetPoint("RIGHT", f.sb, "RIGHT", -4, 0)
	f.used = true
	pool[#pool + 1] = f
	return f
end

function AN:Layout()
	local f = self.frame
	if not f then return end
	local y = 0
	for _, a in ipairs(self.active) do
		if a.kind == "cd" and not VP.db.announce.cdBars then
			if a.bar then a.bar:Hide(); a.bar.used = false; a.bar = nil end
		elseif not a.bar then
			local b = getBar()
			a.bar = b
			local _, _, icon = GetSpellInfo(a.e.id)
			b.icon:SetTexture(icon)
			local _, class = UnitClass(a.src or "")
			if a.kind == "cd" then
				b.sb:SetStatusBarColor(0.45, 0.45, 0.5)   -- recharge : barre grise
			elseif class then
				b.sb:SetStatusBarColor(VP.Colors:Class(class))
			else
				local r, g, bl = VP.Theme:Accent()
				b.sb:SetStatusBarColor(r, g, bl)
			end
			local who = a.mine and "" or ((a.src or "?") .. " : ")
			if a.kind == "cd" then
				b.left:SetText("Recharge : " .. AN:Name(a.e))
			else
				b.left:SetText(who .. AN:Name(a.e) .. (a.e.target and a.target and a.target ~= "" and (" > " .. a.target) or ""))
			end
		end
		if a.bar then
			a.bar:ClearAllPoints()
			a.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y)
			a.bar:Show()
			y = y - 22
		end
	end
	if not VP.db.announce.bars then
		for _, a in ipairs(self.active) do if a.bar then a.bar:Hide() end end
	end
	-- barres désactivées : rien à l'écran, pas même la poignée quand les cadres sont déverrouillés
	if VP.db.announce.bars and (y < 0 or not VP.db.locked) then f:Show() else f:Hide() end
end

function AN:ApplyPosition()
	local f = self.frame
	local p = VP.db.announce.barsPos
	f:ClearAllPoints()
	f:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
	VP:Unplace(f)
	f:SetScale(VP.db.scale or 1)
	if VP.db.locked then f.handle:Hide() else f.handle:Show() end
	self:Layout()
end

function AN:Refresh() if self.frame then self:ApplyPosition() end end

function AN:OnLogin()
	-- 4.8.1 : décompte « léger » par défaut (10 et 5 s puis « terminé »), une seule fois
	-- (repère gardé à la racine des réglages : un chargement de profil ne le remet pas à zéro)
	local c = VP.db.announce
	if not VP.db.announceLightV1 and not c.lightV1 then c.countdown = "LIGHT" end
	VP.db.announceLightV1 = true
	-- 5.8.5 : mode discret appliqué une fois à tous (les joueurs trouvaient les annonces envahissantes) ;
	-- chacun peut revenir en arrière dans /vp > Recharges et annonces
	if not VP.db.announceQuietV1 then
		c.countdown, c.scope, c.cdReadySelf = "NONE", "BIG", true
		c.instanceOnly, c.othersBigOnly, c.warning = true, true, false
		VP.db.announceQuietV1 = true
	end
	for _, e in ipairs(self:List()) do
		local n = GetSpellInfo(e.id)
		if n then mine[n] = e end
	end
	for _, list in pairs(self.SPELLS) do
		for _, e in ipairs(list) do
			local n = GetSpellInfo(e.id)
			if n then any[n] = e end
		end
	end
	local T = VP.Theme
	local f = CreateFrame("Frame", "VuhPlusCooldownBars", UIParent)
	f:SetWidth(200); f:SetHeight(20)
	f:SetMovable(true); f:SetClampedToScreen(true)
	f.handle = T:Handle(f, "Temps des gros sorts",
		function() f:StartMoving() end,
		function()
			f:StopMovingOrSizing()
			local point, _, relPoint, x, y = f:GetPoint()
			VP.db.announce.barsPos = { point = point, relPoint = relPoint, x = x, y = y }
			VP:Unplace(f)
		end)
	self.frame = f
	self:ApplyPosition()

	local band = bit and bit.band
	local me = UnitGUID("player")
	VP:On("COMBAT_LOG_EVENT_UNFILTERED", function(_, _, event, srcGUID, srcName, srcFlags, _, dstName, _, _, spellName)
		if event == "SPELL_CAST_SUCCESS" then
			local isMine = srcGUID == me
			local e = isMine and mine[spellName] or any[spellName]
			if not e then return end
			-- les autres : seulement les membres de votre groupe / raid
			if not isMine and not (band and band(srcFlags or 0, 0x7) > 0) then return end
			AN:Start(e, dstName, srcName, isMine)
		elseif event == "SPELL_AURA_REMOVED" then
			-- effet sur une cible retiré avant la fin (annulé, dissipé...) : fin du décompte
			for i = #AN.active, 1, -1 do
				local a = AN.active[i]
				-- même cible ET même lanceur (deux druides peuvent innerver la même personne)
				if a.kind ~= "cd" and a.e.target and a.target == dstName and a.src == srcName and AN:Name(a.e) == spellName then AN:Stop(i) end
			end
		end
	end)
	-- temps de recharge modifié (glyphe, remise à zéro...) : on relit le vrai temps
	VP:On("SPELL_UPDATE_COOLDOWN", function()
		local now = GetTime()
		for i = #AN.active, 1, -1 do
			local a = AN.active[i]
			if a.kind == "cd" then
				local readyAt, dur = realCD(a.e)
				if not readyAt then
					if a.ends - now > 2 then AN:Stop(i) end   -- recharge remise à zéro : disponible
				elseif math.abs(readyAt - a.ends) > 1 then
					a.ends, a.total = readyAt, dur
				end
			end
		end
	end)
	-- après /reload : barres des recharges déjà en cours (sans annonce)
	for _, e in ipairs(self:List()) do
		if e.cd then
			local readyAt, dur = realCD(e)
			if readyAt and readyAt - GetTime() > 2 then self:StartCD(e, readyAt, dur) end
		end
	end
	-- canalisation interrompue (Tranquillité, hymnes) : fin du décompte
	VP:On("UNIT_SPELLCAST_CHANNEL_STOP", function(_, unit, spell)
		if unit ~= "player" then return end
		for i = #AN.active, 1, -1 do
			local a = AN.active[i]
			if a.mine and a.kind ~= "cd" and a.e.channel and AN:Name(a.e) == spell and a.ends - GetTime() > 0.5 then AN:Stop(i) end
		end
	end)
	local acc = 0
	local drv = CreateFrame("Frame")
	drv:SetScript("OnUpdate", function(_, el)
		if #AN.active == 0 and not AN.cdCheck then return end
		acc = acc + el
		if acc < 0.1 then return end
		acc = 0
		AN:Tick()
	end)
end
