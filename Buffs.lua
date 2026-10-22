-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Surveillance des buffs (BuffWatch), rappels de soigneur et buff intelligent
local VP = VuhPlus
local BW = VP:NewModule("Buffs")

-- scope :
--   "raid"   : tout le groupe (point jaune sur les cadres)
--   "self"   : vous seul (votre cadre devient gris s'il manque)
--   "weapon" : enchantement d'arme temporaire (Arme Viveterre...) - votre cadre devient gris
--   "tank"   : vos tanks (leur cadre devient gris s'il manque, ou s'il reste trop peu de charges)
-- unique : un seul tank peut l'avoir (Bouclier de terre, Guide de lumière...) : gris seulement si personne ne l'a
-- anyCaster : ne se cumule pas entre joueurs (Bouclier de terre, Épines, Gardien de peur) : un tank qui porte déjà
--             celui d'un AUTRE joueur n'est pas grisé (le relancer écraserait le sien ou échouerait)
-- charges = true : réglage « griser à N charges » ; skip : affaiblissement qui empêche de relancer (Âme affaiblie)
-- count = true : buff personnel à charges (Bouclier d'eau) : le nombre de charges s'affiche sur votre cadre
local DATA = {
	PRIEST = {
		{ key = "fort", single = 1243, group = 21562, scope = "raid", on = true },
		{ key = "spirit", single = 14752, group = 27681, accept = { 54424, 57564, 57565, 57566, 57567 }, scope = "raid", on = true },
		{ key = "shadow", single = 976, group = 27683, scope = "raid", on = true },
		{ key = "innerfire", choices = { 588 }, scope = "self", on = true },
		{ key = "pws", single = 17, scope = "tank", skip = 6788, on = "DISC" },
		-- 3 min de durée et 3 min de recharge : une seule cible à la fois en pratique
		{ key = "fearward", single = 6346, scope = "tank", unique = true, anyCaster = true, on = false },
	},
	MAGE = {
		{ key = "int", single = 1459, group = 23028, accept = { 61024, 61316, 54424, 57564, 57565, 57566, 57567 }, scope = "raid", on = true },
		{ key = "armor", choices = { 30482, 6117, 7302, 168 }, scope = "self", on = true },
	},
	DRUID = {
		{ key = "motw", single = 1126, group = 21849, scope = "raid", on = true },
		{ key = "thorns", single = 467, scope = "tank", anyCaster = true, on = true },
	},
	PALADIN = {
		{ key = "kings", single = 20217, group = 25898, accept = { 69378 }, scope = "raid", on = true },  -- + Tambours des rois oubliés
		{ key = "might", single = 19740, group = 25782, scope = "raid", on = false },
		{ key = "wisdom", single = 19742, group = 25894, scope = "raid", on = false },
		{ key = "sanct", single = 20911, group = 25899, scope = "raid", on = false },
		{ key = "seal", choices = { 20166, 20165, 21084, 31801, 53736, 20375, 20164 }, scope = "self", on = true },
		{ key = "beacon", single = 53563, scope = "tank", unique = true, on = true },
		{ key = "sacred", single = 53601, scope = "tank", unique = true, on = true },
	},
	SHAMAN = {
		{ key = "wshield", choices = { 52127, 324 }, scope = "self", count = true, on = true },
		{ key = "earthliving", single = 51730, enchant = 51945, scope = "weapon", on = true },
		{ key = "eshield", single = 974, scope = "tank", unique = true, charges = true, anyCaster = true, on = true },
	},
	WARRIOR = {
		{ key = "shout", choices = { 6673, 469 }, scope = "self", on = true },
	},
	DEATHKNIGHT = {
		{ key = "horn", choices = { 57330 }, scope = "self", on = true },
	},
	WARLOCK = {
		{ key = "armor", choices = { 28176, 706, 687 }, scope = "self", on = true },
	},
	HUNTER = {
		{ key = "aspect", choices = { 61846, 13165, 34074 }, scope = "self", on = true },
	},
}

BW.entries = {}
BW.missingByGUID = {}   -- buffs de raid manquants (point jaune)
BW.remind = {}          -- GUID -> { icon, label } : cadre à griser

local function known(id)
	local n = id and GetSpellInfo(id)
	if n and GetSpellInfo(n) then return n end
	return nil
end

-- Spécialisation principale du joueur (1-3), pour les réglages par défaut
local function myTree()
	local best, pts = 1, -1
	for i = 1, 3 do
		local _, _, p = GetTalentTabInfo(i)
		if p and p > pts then best, pts = i, p end
	end
	return best
end

function BW:Build()
	wipe(self.entries)
	local list = DATA[VP.class]
	if not list then return end
	local db = VP.db.buffs
	local track = db.track
	db.charges = db.charges or {}
	for _, e in ipairs(list) do
		if track[e.key] == nil then
			if e.on == "DISC" then track[e.key] = (VP.class == "PRIEST" and myTree() == 1) else track[e.key] = e.on end
		end
		local names = {}
		local cast, label, icon, single
		if e.scope == "self" then
			for _, id in ipairs(e.choices) do
				local n, _, ic = GetSpellInfo(id)
				if n then names[n] = true end
				if not cast and known(id) then cast = n; label = n; icon = ic end
			end
		else
			local sn, _, sic = GetSpellInfo(e.single)
			local gn = e.group and GetSpellInfo(e.group)
			if sn then names[sn] = true end
			if gn then names[gn] = true end
			for _, id in ipairs(e.accept or {}) do
				local n = GetSpellInfo(id)
				if n then names[n] = true end
			end
			cast = known(e.group) or known(e.single)
			single = known(e.single)
			label = sn; icon = sic
		end
		if cast then
			if e.charges and db.charges[e.key] == nil then db.charges[e.key] = 1 end
			table.insert(self.entries, {
				key = e.key, scope = e.scope, names = names, cast = cast, single = single,
				label = label, icon = icon, missing = {}, unique = e.unique, charges = e.charges, anyCaster = e.anyCaster,
				enchant = e.enchant and GetSpellInfo(e.enchant), count = e.count,
				skip = e.skip and GetSpellInfo(e.skip),
			})
		end
	end
end

-- La personne a-t-elle ce buff (avec assez de temps restant) ? Renvoie aussi les charges.
-- seuil de « rappel » : jamais plus d'un quart de la durée du sort, sinon les buffs courts
-- (Guide de lumière 60 s, Bouclier sacré 30 s, Mot de pouvoir : Bouclier 30 s, cris 2 min...)
-- étaient toujours considérés comme manquants
local function longEnough(duration, expires, minLeft, now)
	local need = (duration and duration > 0) and math.min(minLeft, duration * 0.25) or 0
	return not duration or duration == 0 or not expires or expires == 0 or expires - now > need
end
local function findBuff(unit, names, minLeft, mineOnly)
	local now = GetTime()
	for n in pairs(names) do
		-- recherche directe par nom (rapide) : c'est le cas courant
		local name, _, _, count, _, duration, expires, caster = UnitBuff(unit, n)
		if name then
			if not mineOnly or caster == "player" then
				if longEnough(duration, expires, minLeft, now) then return true, count or 0 end
			else
				-- un buff de ce nom existe mais il n'est pas à vous : UnitBuff(unité, nom) ne renvoie que le
				-- PREMIER du nom, le vôtre peut être plus loin (deux paladins qui posent leur Guide de lumière
				-- sur le même tank, autorisé depuis la 3.2) : seulement dans ce cas, on parcourt la liste
				local i = 1
				while true do
					local nm, _, _, c2, _, d2, e2, cs2 = UnitBuff(unit, i)
					if not nm then break end
					if nm == n and cs2 == "player" and longEnough(d2, e2, minLeft, now) then return true, c2 or 0 end
					i = i + 1
				end
			end
		end
	end
	return false, 0
end

-- Enchantement d'arme temporaire (lu dans l'infobulle de l'arme, infobulle cachée commune VP:ScanTip)
local weaponCache, weaponCacheT, weaponCacheName = nil, 0, nil
local function weaponHas(name)
	if not name then return false end
	if weaponCacheName == name and GetTime() - weaponCacheT < 5 then return weaponCache end
	weaponCacheName, weaponCacheT = name, GetTime()
	weaponCache = false
	local hasMain = GetWeaponEnchantInfo()
	if not hasMain then return false end
	local tip = VP:ScanTip()
	tip:SetInventoryItem("player", 16)
	for i = 1, tip:NumLines() do
		local fs = _G["VuhPlusScanTipTextLeft" .. i]
		local t = fs and fs:GetText()
		if t and string.find(t, name, 1, true) then weaponCache = true; return true end
	end
	return false
end
BW.ResetWeaponCache = function() weaponCacheT = 0 end

local units = {}
local function groupUnits()
	wipe(units)
	local n = GetNumRaidMembers()
	if n > 0 then
		for i = 1, n do table.insert(units, "raid" .. i) end
	else
		table.insert(units, "player")
		for i = 1, GetNumPartyMembers() do table.insert(units, "party" .. i) end
	end
	return units
end

-- Qui est tank ? Tank principal du raid, rôle « tank » (donjon ou talents), « Mes tanks », ou votre focalisation
function BW:IsTank(u)
	if not UnitExists(u) or not UnitIsPlayer(u) then return false end
	local idx = string.match(u, "^raid(%d+)$")
	if idx and select(10, GetRaidRosterInfo(tonumber(idx))) == "MAINTANK" then return true end
	if UnitGroupRolesAssigned(u) then return true end
	if VP.Roles and VP.Roles:GetRole(u) == "TANK" then return true end
	local name = UnitName(u)
	for _, n in ipairs(VP.db.myTanks) do if n == name then return true end end
	if UnitExists("focus") and UnitIsUnit(u, "focus") then return true end
	return false
end

-- Pour la fenêtre de configuration : êtes-vous en groupe, suivez-vous un buff de tank, qui est reconnu tank ?
-- (sans tank reconnu, les rappels « cadre gris » sur le tank ne peuvent rien signaler)
function BW:InGroup() return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 end
function BW:TracksTankBuff()
	local db = VP.db.buffs
	if not db.enabled then return false end
	for _, e in ipairs(self.entries) do
		if e.scope == "tank" and db.track[e.key] then return true end
	end
	return false
end
function BW:TankNames()
	local t = {}
	local n = GetNumRaidMembers()
	local count = n > 0 and n or GetNumPartyMembers()
	for i = 1, count do
		local u = (n > 0 and "raid" or "party") .. i
		if UnitExists(u) and self:IsTank(u) then t[#t + 1] = UnitName(u) end
	end
	return t
end
-- Phrase d'état pour l'accueil et la page Buffs et rappels
function BW:TankStatus()
	if not self:InGroup() then return nil end
	local t = self:TankNames()
	if #t > 0 then return true, "Tank reconnu : |cffffffff" .. table.concat(t, ", ") .. "|r" end
	return false, "|cffffbb33Aucun tank reconnu|r : les rappels sur le tank (Bouclier de terre, Épines, Guide de lumière...) "
		.. "ne peuvent rien signaler. Ciblez le tank puis « Ma cible est un tank », ou tapez /vp tank."
end

local tanks = {}
local candBuf, seenBuf, statusBuf = {}, {}, {}   -- réutilisées à chaque vérification (toutes les secondes)
function BW:Scan()
	wipe(self.missingByGUID)
	wipe(self.remind)
	local db = VP.db.buffs
	if not db.enabled then return end
	local minLeft = (db.rebuffMinutes or 0) * 60
	local list = groupUnits()
	wipe(tanks)
	for _, u in ipairs(list) do
		if UnitIsConnected(u) and not UnitIsDeadOrGhost(u) and self:IsTank(u) then table.insert(tanks, u) end
	end
	local function remind(u, e, reason)
		local g = UnitGUID(u)
		if g and not self.remind[g] then self.remind[g] = { icon = e.icon, label = reason or e.label } end
	end
	local playerOK = not UnitIsDeadOrGhost("player")
	for _, e in ipairs(self.entries) do
		wipe(e.missing)
		if db.track[e.key] then
			if e.scope == "self" then
				if playerOK and not findBuff("player", e.names, minLeft) then
					table.insert(e.missing, "player")
					remind("player", e)
				end
			elseif e.scope == "weapon" then
				if playerOK and not weaponHas(e.enchant) then
					table.insert(e.missing, "player")
					remind("player", e)
				end
			elseif e.scope == "tank" then
				-- seuil par défaut : 1 charge (même valeur que celle affichée par le curseur ; 0 = seulement quand il tombe)
				local low = e.charges and (db.charges[e.key] or 1) or 0
				-- sort en recharge (Gardien de peur : 3 min) : impossible de le relancer, inutile de griser
				-- (au-delà de 1,5 s, pour ne pas compter le temps de recharge global)
				local onCD = false
				if e.single then
					local start, dur = GetSpellCooldown(e.single)
					onCD = (start and start > 0 and dur and dur > 1.5) and true or false
				end
				local anyGood = false
				wipe(statusBuf)
				local status = statusBuf
				-- sorts « uniques » (Bouclier de terre, Guide de lumière, Bouclier sacré) : la personne qui porte
				-- VOTRE sort est surveillée même si elle n'est pas reconnue comme tank (pas de tank principal,
				-- rôle inconnu...), et celle qui l'a perdu reste grisée tant que vous ne l'avez remis à personne
				local cands = tanks
				if e.unique then
					cands = candBuf
					for k = #cands, 1, -1 do cands[k] = nil end
					local seen = seenBuf
					wipe(seen)
					for _, u in ipairs(tanks) do cands[#cands + 1] = u; seen[UnitGUID(u) or u] = true end
					for _, u in ipairs(list) do
						local g = UnitGUID(u)
						if g and not seen[g] and UnitIsConnected(u) and not UnitIsDeadOrGhost(u) then
							-- vous-même n'êtes pas gardé comme « dernier porteur » : remplacer votre Bouclier de terre
							-- par le Bouclier d'eau est voulu, votre cadre ne doit pas rester gris avec son icône
							if findBuff(u, e.names, 0, true) or (g == e.holder and not UnitIsUnit(u, "player")) then
								cands[#cands + 1] = u; seen[g] = true
							end
						end
					end
				end
				for _, u in ipairs(cands) do
					local has, count = findBuff(u, e.names, minLeft, true)
					if has and e.charges and count > 0 and count <= low then
						status[u] = "low"
						anyGood = true   -- sort unique : seul le porteur est grisé, pas les autres tanks
					elseif has then
						status[u] = "ok"
						anyGood = true
					elseif e.anyCaster and findBuff(u, e.names, 0, false) then
						-- le même sort, lancé par un AUTRE joueur (autre chaman, autre druide...) : ce tank est
						-- couvert. Ne compte pas comme le vôtre : un autre tank sans rien reste à couvrir.
						status[u] = "other"
					elseif e.skip and UnitDebuff(u, e.skip) then
						status[u] = "skip"   -- ne peut pas être relancé pour l'instant
					else
						status[u] = "missing"
					end
				end
				-- dernier porteur connu (sert quand le sort tombe : charges épuisées, durée écoulée)
				if e.unique then
					for _, u in ipairs(cands) do
						if status[u] == "ok" or status[u] == "low" then e.holder = UnitGUID(u) break end
					end
				end
				for _, u in ipairs(cands) do
					local st = status[u]
					local gray = (st == "low") or (st == "missing" and not (e.unique and anyGood) and not onCD)
					if gray then
						table.insert(e.missing, u)
						remind(u, e, st == "low" and (e.label .. " : " .. ((db.charges and db.charges[e.key]) or 1) .. " charge(s)") or nil)
					end
				end
			else
				for _, u in ipairs(list) do
					if UnitExists(u) and UnitIsConnected(u) and not UnitIsDeadOrGhost(u) and not findBuff(u, e.names, minLeft) then
						table.insert(e.missing, u)
						local g = UnitGUID(u)
						if g then self.missingByGUID[g] = true end
					end
				end
			end
		end
	end
end

function BW:IsMissingAny(unit)
	local g = UnitGUID(unit)
	return g and self.missingByGUID[g] or false
end

-- Charges d'un buff personnel « à charges » (Bouclier d'eau) : icône, nombre - ou nil
local function chargesOf(e)
	for n in pairs(e.names) do
		local name, _, icon, count = UnitBuff("player", n)
		if name and count and count > 0 then return icon, count end
	end
end

-- Charges à afficher sur ce cadre (le vôtre uniquement) : icône, nombre - ou nil
function BW:Charges(unit)
	local db = VP.db.buffs
	if not db.enabled or db.selfCharges == false or not UnitIsUnit(unit, "player") then return nil end
	for _, e in ipairs(self.entries) do
		if e.count and db.track[e.key] then
			local icon, count = chargesOf(e)
			if count then return icon, count end
		end
	end
	return nil
end

-- Rappel de soigneur pour ce cadre : { icon, label } ou nil
function BW:Reminder(unit)
	if not VP.db.buffs.grayFrames then return nil end
	local g = UnitGUID(unit)
	return g and self.remind[g]
end

-- Panneau ------------------------------------------------------------------
local ROWS = 10
function BW:UpdatePanel()
	local db = VP.db.buffs
	local p = self.panel
	local shown = 0
	local firstSpell, firstUnit
	for i = 1, ROWS do
		local row = p.rows[i]
		local e = self.entries[i]
		if e and db.track[e.key] then
			shown = shown + 1
			row.icon:SetTexture(e.icon)
			local miss = #e.missing
			if miss == 0 then
				local _, n = nil, nil
				if e.count then _, n = chargesOf(e) end
				row.text:SetText(e.label .. "  |cff55dd77OK|r" .. (n and ("  |cffffffff" .. n .. "|r") or ""))
			else
				row.text:SetText(e.label .. "  |cffffbb33" .. miss .. " manquant" .. (miss > 1 and "s" or "") .. "|r")
			end
			row.wantSpell = e.cast
			row.wantUnit = e.missing[1] or "player"
			-- en solo, la version de groupe ne sert à rien : on prend le sort simple
			if (e.scope == "raid" and e.single and GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0) or e.scope == "tank" then
				row.wantSpell = e.single or e.cast
			end
			if miss > 0 and not firstSpell then firstSpell, firstUnit = row.wantSpell, row.wantUnit end
			row.vpActive = true
		else
			row.vpActive = false
		end
	end
	p.smartSpell, p.smartUnit = firstSpell, firstUnit
	VP:RunOOC("buffpanel", function()
		local show = db.enabled and db.showPanel and shown > 0
		if show then p:Show() else p:Hide() end
		p:SetHeight(28 + shown * 22)
		local y = 0
		for i = 1, ROWS do
			local row = p.rows[i]
			if row.vpActive then
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", p, "TOPLEFT", 4, -24 - y)
				y = y + 22
				row:SetAttribute("type", "spell")
				row:SetAttribute("spell", row.wantSpell)
				row:SetAttribute("unit", row.wantUnit)
				row:Show()
			else
				row:Hide()
			end
		end
		local s = BW.smart
		s:SetAttribute("type", firstSpell and "spell" or nil)
		s:SetAttribute("spell", firstSpell)
		s:SetAttribute("unit", firstUnit)
	end)
	if VP.db.locked then p.handle:Hide() else p.handle:Show() end
end

function BW:Refresh()
	self:Build()
	self:Scan()
	local p = self.panel
	if p then
		local pos = VP.db.buffs.pos
		VP:RunOOC("buffpos", function()
			p:ClearAllPoints()
			p:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
			VP:Unplace(p)
			p:SetScale(VP.db.buffs.scale or 1)
		end)
		self:UpdatePanel()
	end
end

function BW:OnLogin()
	VP.db.buffs.track = VP.db.buffs.track or {}

	local TH = VP.Theme
	local p = CreateFrame("Frame", "VuhPlusBuffPanel", UIParent)
	p:SetWidth(200); p:SetHeight(40)
	p:SetMovable(true)
	p:SetClampedToScreen(true)
	TH:Backdrop(p, TH.C.bg, TH.C.border)
	local stripe = TH:Tex(p, "ARTWORK")
	stripe:SetPoint("TOPLEFT", p, "TOPLEFT", 1, -1)
	stripe:SetPoint("TOPRIGHT", p, "TOPRIGHT", -1, -1)
	stripe:SetHeight(2)
	TH:RegisterAccent(stripe)
	local title = TH:Text(p, 12, nil, nil, nil, true)
	title:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -6)
	title:SetText("Buffs")
	local hint = TH:Text(p, 10, TH.C.muted)
	hint:SetPoint("LEFT", title, "RIGHT", 6, 0)
	hint:SetText("clic = lancer")
	p.handle = TH:Handle(p, "Buffs",
		function() if not InCombatLockdown() then p:StartMoving() end end,
		function()
			p:StopMovingOrSizing()
			local point, _, relPoint, x, y = p:GetPoint()
			VP.db.buffs.pos = { point = point, relPoint = relPoint, x = x, y = y }
			VP:Unplace(p)
		end)

	p.rows = {}
	for i = 1, ROWS do
		local r = CreateFrame("Button", "VuhPlusBuffRow" .. i, p, "SecureActionButtonTemplate")
		r:SetWidth(192); r:SetHeight(20)
		r:RegisterForClicks("AnyUp")
		local ib = CreateFrame("Frame", nil, r)
		ib:SetWidth(18); ib:SetHeight(18)
		ib:SetPoint("LEFT", r, "LEFT", 0, 0)
		TH:Backdrop(ib, { 0, 0, 0, 1 }, { 0, 0, 0, 1 })
		r.icon = ib:CreateTexture(nil, "ARTWORK")
		r.icon:SetPoint("TOPLEFT", ib, "TOPLEFT", 1, -1)
		r.icon:SetPoint("BOTTOMRIGHT", ib, "BOTTOMRIGHT", -1, 1)
		r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		r.text = TH:Text(r, 12)
		r.text:SetPoint("LEFT", ib, "RIGHT", 6, 0)
		local hl = TH:Tex(r, "BACKGROUND", 1, 1, 1, 0.06)
		hl:SetAllPoints(r)
		hl:Hide()
		r:SetScript("OnEnter", function() hl:Show() end)
		r:SetScript("OnLeave", function() hl:Hide() end)
		r:Hide()
		p.rows[i] = r
	end
	self.panel = p

	local s = CreateFrame("Button", "VuhPlusSmartBuff", UIParent, "SecureActionButtonTemplate")
	s:SetWidth(1); s:SetHeight(1)
	s:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
	s:RegisterForClicks("AnyUp")
	s:EnableMouse(false)
	self.smart = s

	self:Refresh()

	local acc = 0
	local driver = CreateFrame("Frame")
	driver:SetScript("OnUpdate", function(_, e)
		acc = acc + e
		-- toutes les secondes ; toutes les 2 secondes en raid 40 (moins de travail, même résultat)
		if acc < ((GetNumRaidMembers() > 25) and 2 or 1) then return end
		acc = 0
		BW:Scan()
		BW:UpdatePanel()
	end)
	local function rebuild() BW:Build() end
	VP:On("UNIT_INVENTORY_CHANGED", function(_, unit) if unit == "player" then BW.ResetWeaponCache() end end)
	VP:On("SPELLS_CHANGED", rebuild)
	VP:On("LEARNED_SPELL_IN_TAB", rebuild)
end
