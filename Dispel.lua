-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Assistant de dispel (Paladin, Prêtre, Druide, Chaman, Mage)
local VP = VuhPlus
local D = VP:NewModule("Dispel")

-- Sorts de dispel WotLK 3.3.5 (ID -> nom localisé automatiquement, client FR ou EN)
local DATA = {
	PALADIN = {
		{ id = 4987,  types = { Magic = true, Poison = true, Disease = true } }, -- Épuration
		{ id = 1152,  types = { Poison = true, Disease = true } },              -- Purification
	},
	PRIEST = {
		{ id = 527,   types = { Magic = true } },                               -- Dissipation de la magie
		{ id = 552,   types = { Disease = true } },                             -- Abolir maladie
		{ id = 528,   types = { Disease = true } },                             -- Guérison des maladies
	},
	DRUID = {
		{ id = 2782,  types = { Curse = true } },                               -- Délivrance de la malédiction
		{ id = 2893,  types = { Poison = true } },                              -- Abolir le poison
		{ id = 8946,  types = { Poison = true } },                              -- Guérison du poison
	},
	SHAMAN = {
		{ id = 51886, types = { Poison = true, Disease = true, Curse = true } }, -- Purifier l'esprit (talent)
		{ id = 526,   types = { Poison = true, Disease = true } },              -- Guérison des toxines
	},
	MAGE = {
		{ id = 475,   types = { Curse = true } },                               -- Délivrance de la malédiction
	},
}

-- Affaiblissements dangereux à dissiper (contrecoup)
local DANGER_IDS = { 30108 }  -- Affliction instable (silence + dégâts au dissipateur)

-- Toujours ignorés (comme Decursive) : inutiles ou à NE PAS retirer
local IGNORE_ALWAYS = { 28169, 2096, 15822, 24360, 29232 } -- Injection mutante, Vision télépathique, Sommeil sans rêve (x2), Dévoré par la peur
-- Ignorés en combat seulement (gênants mais pas urgents)
local IGNORE_COMBAT = { 30129, 60814 }

-- Filtre par classe : affaiblissement sans effet sur ces classes (comme Decursive)
local CLASS_FILTER = {
	[1714]  = { WARRIOR = true, ROGUE = true, DEATHKNIGHT = true, HUNTER = true },          -- Malédiction des langages (vitesse d'incantation)
	[702]   = { MAGE = true, PRIEST = true, WARLOCK = true },                                -- Malédiction de faiblesse (puissance d'attaque)
	[15487] = { WARRIOR = true, ROGUE = true, DEATHKNIGHT = true },                          -- Silence
	[8988]  = { WARRIOR = true, ROGUE = true, DEATHKNIGHT = true },                          -- Silence (variante)
	[25046] = { WARRIOR = true, ROGUE = true, DEATHKNIGHT = true },                          -- Torrent arcanique
}

-- Abolir : si votre Abolir est déjà sur la cible, inutile de dissiper ce type (option)
local ABOLISH = { Poison = 2893, Disease = 552 }

D.slots = {}        -- [1], [2] = { name = "Épuration", types = {...} }
D.canDispel = {}    -- type -> numéro de slot
D.danger = {}
D.ignoreAlways = {}
D.ignoreCombat = {}
D.classFilter = {}  -- nom -> { CLASSE = true }
D.abolish = {}      -- type -> nom du sort Abolir
D.blacklist = {}    -- nom du joueur -> heure de fin (hors de vue / échec)
D.afflicted = {}    -- GUID -> infos pour la liste en direct
D.recent = {}       -- derniers affaiblissements dissipables vus (pour les ignorer en 1 clic)

local function buildNameSet(ids, set)
	for _, id in ipairs(ids) do
		local n = GetSpellInfo(id)
		if n then set[n] = true end
	end
end

function D:Refresh()
	wipe(self.slots)
	wipe(self.canDispel)
	local class = VP.class
	if not VP.db.dispel.classes[class] then return end
	local list = DATA[class]
	if not list then return end
	local types = VP.db.dispel.types
	for _, e in ipairs(list) do
		local name = GetSpellInfo(e.id)
		-- GetSpellInfo("nom") ne renvoie quelque chose que si le sort est dans le grimoire
		if name and GetSpellInfo(name) and #self.slots < 2 then
			local adds = false
			for t in pairs(e.types) do
				if not self.canDispel[t] then adds = true end
			end
			if adds then
				table.insert(self.slots, { name = name, types = e.types })
				for t in pairs(e.types) do
					if not self.canDispel[t] then self.canDispel[t] = #self.slots end
				end
			end
		end
	end
	-- types désactivés par le joueur (partage du travail avec les autres soigneurs)
	for t in pairs(self.canDispel) do
		if types[t] == false then self.canDispel[t] = nil end
	end
end

-- Sons proposés pour l'alerte de dispel
D.SOUNDS = {
	{ "TellMessage", "Message privé (doux)" },
	{ "RaidWarning", "Alerte de raid (fort)" },
	{ "ReadyCheck", "Appel (ready check)" },
	{ "MapPing", "Ping de la carte" },
	{ "igPlayerInvite", "Invitation" },
}
D.TYPES = { "Magic", "Curse", "Disease", "Poison" }
D.TYPE_FR = { Magic = "Magie", Curse = "Malédiction", Disease = "Maladie", Poison = "Poison" }

-- Types que votre classe peut retirer, en texte
function D:TypesText()
	local t = {}
	for _, ty in ipairs(self:Order()) do
		if self.canDispel[ty] then t[#t + 1] = self.TYPE_FR[ty] .. " (Dispel " .. self.canDispel[ty] .. ")" end
	end
	return #t > 0 and table.concat(t, ", ") or nil
end

-- Ordre de priorité des types (le premier est traité en premier)
function D:Order()
	return VP.db.dispel.order
end

function D:MoveType(ty, dir)
	local o = VP.db.dispel.order
	for i, t in ipairs(o) do
		if t == ty then
			local j = i + dir
			if j >= 1 and j <= #o then o[i], o[j] = o[j], o[i] end
			return
		end
	end
end

function D:Enabled()
	return next(self.canDispel) ~= nil
end

local function listHas(list, name)
	for _, n in ipairs(list) do if n == name then return true end end
	return false
end

-- Faut-il ignorer cet affaiblissement sur cette unité ?
function D:IsIgnored(name, unit)
	local db = VP.db.dispel
	if db.ignoreList then
		if self.ignoreAlways[name] or listHas(db.userIgnore, name) then return true end
		if (self.ignoreCombat[name] or listHas(db.userIgnoreCombat, name)) and UnitAffectingCombat("player") then return true end
	end
	if db.classFilter then
		local f = self.classFilter[name]
		if f then
			local _, class = UnitClass(unit)
			if class and f[class] then return true end
		end
	end
	return false
end

-- Hors de portée de VOTRE sort de dispel ?
function D:InRange(unit, slot)
	local s = self.slots[slot or 1]
	if not s then return true end
	if UnitIsUnit(unit, "player") then return true end
	local r = IsSpellInRange(s.name, unit)
	return r ~= 0  -- 1 = à portée, nil = inconnu (on considère à portée)
end

function D:IsBlacklisted(unit)
	local name = UnitName(unit)
	local t = name and self.blacklist[name]
	return t and t > GetTime()
end

local function noteRecent(name, icon, dtype)
	for _, r in ipairs(D.recent) do if r.name == name then return end end
	table.insert(D.recent, 1, { name = name, icon = icon, dtype = dtype })
	if #D.recent > 8 then table.remove(D.recent) end
end

-- Renvoie : type, icône, nom, dangereux, slot, cumuls, durée, expiration
-- buf : affaiblissements déjà lus (VP.Debuffs:ReadHarmful) ; lus ici sinon
local tmpBuf = {}
function D:Scan(unit, buf)
	if not next(self.canDispel) then return nil end
	local db = VP.db.dispel
	local name0 = UnitName(unit)
	if name0 and listHas(db.skipNames, name0) then return nil end
	buf = buf or VP.Debuffs:ReadHarmful(unit, tmpBuf)
	local order = db.order
	-- meilleur affaiblissement (selon l'ordre des types) et éventuel « dangereux », sans créer de tables
	local bT, bI, bN, bC, bD, bE, bP
	local zT, zI, zN, zC, zD, zE
	for k = 1, buf.n do
		local e = buf[k]
		local name, icon, count, dtype, duration, expires = e.name, e.icon, e.count, e.dtype, e.dur, e.exp
		if dtype and self.canDispel[dtype] and not self:IsIgnored(name, unit) then
			local abolished = db.checkAbolish and self.abolish[dtype] and UnitBuff(unit, self.abolish[dtype])
			if not abolished then
				noteRecent(name, icon, dtype)
				if self.danger[name] then
					if not zT then zT, zI, zN, zC, zD, zE = dtype, icon, name, count, duration, expires end
				else
					local p = 0
					for r = 1, #order do if order[r] == dtype then p = 10 - r break end end
					if not bP or p > bP then bT, bI, bN, bC, bD, bE, bP = dtype, icon, name, count, duration, expires, p end
				end
			end
		end
	end
	if bT then return bT, bI, bN, false, self.canDispel[bT], bC, bD, bE end
	if zT then return zT, zI, zN, db.warnDanger, self.canDispel[zT], zC, zD, zE end
	return nil
end

-- Enregistre un joueur affligé (liste en direct)
function D:Track(unit, dtype, icon, name, slot, exp, inRange, blacklisted)
	local g = UnitGUID(unit)
	if not g then return end
	local a = self.afflicted[g] or {}
	a.unit, a.dtype, a.icon, a.debuff, a.slot, a.exp = unit, dtype, icon, name, slot, exp
	a.inRange, a.blacklisted, a.seen = inRange, blacklisted, GetTime()
	a.player = UnitName(unit)
	local _, class = UnitClass(unit)
	a.class = class
	a.priority = listHas(VP.db.dispel.priorityNames, a.player)
	self.afflicted[g] = a
end

function D:Untrack(unit)
	local g = UnitGUID(unit)
	if g then self.afflicted[g] = nil end
end

local lastSound = 0
function D:Alert(danger)
	if not VP.db.dispel.sound or VP.db.alerts.quiet then return end
	local now = GetTime()
	if now - lastSound > 2 then
		lastSound = now
		PlaySound(danger and "RaidWarning" or (VP.db.dispel.soundName or "TellMessage"))
	end
end

-- Échecs : hors de vue (liste noire temporaire), résisté
local lastTarget
function D:OnLogin()
	buildNameSet(DANGER_IDS, self.danger)
	buildNameSet(IGNORE_ALWAYS, self.ignoreAlways)
	buildNameSet(IGNORE_COMBAT, self.ignoreCombat)
	for id, classes in pairs(CLASS_FILTER) do
		local n = GetSpellInfo(id)
		if n then self.classFilter[n] = classes end
	end
	for ty, id in pairs(ABOLISH) do self.abolish[ty] = GetSpellInfo(id) end
	self:Refresh()
	local function changed()
		D:Refresh()
		VP.Clicks:Apply()
	end
	VP:On("SPELLS_CHANGED", changed)
	VP:On("LEARNED_SPELL_IN_TAB", changed)
	VP:On("PLAYER_TALENT_UPDATE", changed)
	VP:On("ACTIVE_TALENT_GROUP_CHANGED", changed)

	-- cible de votre dernier sort de dispel (avec l'heure : une erreur n'est prise en compte que
	-- juste après CE sort, jamais pour un autre sort lancé plus tard sur quelqu'un d'autre)
	local lastSent = 0
	VP:On("UNIT_SPELLCAST_SENT", function(_, unit, spell, _, target)
		if unit ~= "player" then return end
		lastTarget = nil
		for _, sl in ipairs(D.slots) do
			if sl.name == spell then lastTarget, lastSent = target, GetTime(); return end
		end
	end)
	local function clearTarget(_, unit) if unit == "player" then lastTarget = nil end end
	VP:On("UNIT_SPELLCAST_SUCCEEDED", clearTarget)
	VP:On("UNIT_SPELLCAST_INTERRUPTED", clearTarget)
	-- « Hors de la ligne de vue » : on ignore ce joueur quelques secondes
	VP:On("UI_ERROR_MESSAGE", function(_, msg)
		if lastTarget and GetTime() - lastSent < 1.5 and msg and msg == SPELL_FAILED_LINE_OF_SIGHT then
			D.blacklist[lastTarget] = GetTime() + (VP.db.dispel.blacklistTime or 5)
			if VP.db.dispel.failAlert then VP:Print("|cffff6666Dispel impossible sur " .. lastTarget .. " (" .. msg .. ") : ignoré quelques secondes.|r") end
			lastTarget = nil
		end
	end)
	-- Dispel résisté
	VP:On("COMBAT_LOG_EVENT_UNFILTERED", function(_, _, event, srcGUID, _, _, _, dstName, _, _, _, _, _, extraName)
		if event == "SPELL_DISPEL_FAILED" and srcGUID == UnitGUID("player") and VP.db.dispel.failAlert then
			VP:Print("|cffff6666Dispel résisté sur " .. tostring(dstName) .. " (" .. tostring(extraName) .. ").|r")
			if not VP.db.alerts.quiet then PlaySound("igQuestFailed") end
		end
	end)

	-- Cadres de soin cachés (/vp cadres : DPS, mage qui décurse) : ce sont les cadres qui lisent les
	-- affaiblissements ; sans eux, la liste « À dissiper » restait vide et aucun son ne sonnait.
	-- On lit alors le groupe ici, 3 fois par seconde (comme Decursive, qui ne dépend d'aucun cadre).
	local bgBuf, bgUnits, bgAlerted = {}, {}, {}
	local function bgScan()
		if VP.db.showFrames ~= false or not next(D.canDispel) then
			if next(bgAlerted) then wipe(bgAlerted) end
			return
		end
		local db = VP.db.dispel
		wipe(bgUnits)
		local n = GetNumRaidMembers()
		if n > 0 then
			for i = 1, n do bgUnits[#bgUnits + 1] = "raid" .. i end
		else
			bgUnits[1] = "player"
			for i = 1, GetNumPartyMembers() do bgUnits[#bgUnits + 1] = "party" .. i end
		end
		for _, u in ipairs(bgUnits) do
			local g = UnitGUID(u)
			if g and UnitIsConnected(u) and not UnitIsDeadOrGhost(u) and UnitIsFriend("player", u) then
				local dtype, dicon, dname, danger, slot, _, _, dexp = D:Scan(u, VP.Debuffs:ReadHarmful(u, bgBuf))
				if dtype then
					local far = db.rangeCheck and not D:InRange(u, slot)
					local blocked = D:IsBlacklisted(u)
					-- son : à la première apparition, ou quand le joueur revient à portée (comme sur les cadres)
					if not bgAlerted[g] and not blocked and (not far or db.alertOutOfRange) then
						D:Alert(danger)
						bgAlerted[g] = true
					end
					D:Track(u, dtype, dicon, dname, slot, dexp, not far, blocked)
				else
					bgAlerted[g] = nil
					D:Untrack(u)
				end
			end
		end
	end
	local bgAcc = 0
	local bg = CreateFrame("Frame")
	bg:SetScript("OnUpdate", function(_, e)
		bgAcc = bgAcc + e
		if bgAcc < 0.3 then return end
		bgAcc = 0
		bgScan()
	end)
end
