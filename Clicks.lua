-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Clic-soin : souris (5 boutons x 4 modificateurs), touches au survol, molette,
-- actions hostiles, clic intelligent (résurrection hors combat), bijoux avec les soins, clics par spé
local VP = VuhPlus
local C = VP:NewModule("Clicks")

C.MOUSE = { "1", "2", "3", "4", "5" }
-- Ordre des préfixes imposé par le jeu : alt- puis ctrl- puis shift-
C.MODS = { "", "alt-", "ctrl-", "shift-", "alt-ctrl-", "alt-shift-", "ctrl-shift-", "alt-ctrl-shift-" }
C.MOUSE_LABEL = { ["1"] = "Clic gauche", ["2"] = "Clic droit", ["3"] = "Clic milieu", ["4"] = "Bouton 4", ["5"] = "Bouton 5" }
C.MOD_LABEL = { [""] = "", ["alt-"] = "Alt + ", ["ctrl-"] = "Ctrl + ", ["shift-"] = "Maj + ",
	["alt-ctrl-"] = "Alt + Ctrl + ", ["alt-shift-"] = "Alt + Maj + ", ["ctrl-shift-"] = "Ctrl + Maj + ", ["alt-ctrl-shift-"] = "Alt + Ctrl + Maj + " }
C.MOD_NAME = { [""] = "Aucune", ["alt-"] = "Alt", ["ctrl-"] = "Ctrl", ["shift-"] = "Maj",
	["alt-ctrl-"] = "Alt + Ctrl", ["alt-shift-"] = "Alt + Maj", ["ctrl-shift-"] = "Ctrl + Maj", ["alt-ctrl-shift-"] = "Alt + Ctrl + Maj" }
-- Molette (lancée sur le cadre survolé)
C.WHEEL = { "wheelup", "wheeldown" }
C.WHEEL_LABEL = { wheelup = "Molette vers le haut", wheeldown = "Molette vers le bas" }
C.WHEEL_KEY = { wheelup = "MOUSEWHEELUP", wheeldown = "MOUSEWHEELDOWN" }
C.SHORT_MOUSE = { ["1"] = "G", ["2"] = "D", ["3"] = "Mil", ["4"] = "B4", ["5"] = "B5" }
C.SHORT_MOD = { [""] = "", ["alt-"] = "A+", ["ctrl-"] = "C+", ["shift-"] = "M+",
	["alt-ctrl-"] = "AC+", ["alt-shift-"] = "AM+", ["ctrl-shift-"] = "CM+", ["alt-ctrl-shift-"] = "ACM+" }
C.NUM_KEYS = 14
C.NUM_HOSTILE = 3

-- Clics par défaut (ID de sort => nom localisé)
local DEFAULT_BINDS = {
	PALADIN = { ["1"] = "target", ["ctrl-1"] = "menu", ["2"] = 19750, ["shift-2"] = 635, ["ctrl-2"] = 20473, ["alt-2"] = 53563, ["alt-1"] = 53601, ["3"] = "DISPEL1", ["shift-3"] = "DISPEL2", ["4"] = 633, ["5"] = 1022 },
	PRIEST  = { ["1"] = "target", ["ctrl-1"] = "menu", ["2"] = 2061, ["shift-2"] = 2060, ["ctrl-2"] = 139, ["alt-2"] = 17, ["alt-1"] = 33076, ["3"] = "DISPEL1", ["shift-3"] = "DISPEL2", ["4"] = 47788, ["5"] = 33206 },
	DRUID   = { ["1"] = "target", ["ctrl-1"] = "menu", ["2"] = 774, ["shift-2"] = 8936, ["ctrl-2"] = 33763, ["alt-2"] = 50464, ["alt-1"] = 18562, ["3"] = "DISPEL1", ["shift-3"] = "DISPEL2", ["4"] = 48438, ["5"] = 20484 },
	SHAMAN  = { ["1"] = "target", ["ctrl-1"] = "menu", ["2"] = 8004, ["shift-2"] = 331, ["ctrl-2"] = 1064, ["alt-2"] = 61295, ["alt-1"] = 974, ["3"] = "DISPEL1", ["shift-3"] = "DISPEL2" },
	MAGE    = { ["1"] = "target", ["ctrl-1"] = "menu", ["2"] = 54646, ["3"] = "DISPEL1" },
}
local REZ = { PALADIN = 7328, PRIEST = 2006, SHAMAN = 2008, DRUID = 50769 }  -- druide : Ranimer (pas Renaissance, la rez de combat)

-- Ensemble de clics de la spé active ------------------------------------------
local function defaultsFor(class)
	local t = {}
	for k, v in pairs(DEFAULT_BINDS[class] or { ["1"] = "target", ["ctrl-1"] = "menu" }) do
		if type(v) == "number" then t[k] = GetSpellInfo(v) or "" else t[k] = v end
	end
	return t
end

function C:Binds(spec)
	local db = VP.db
	local class = VP.class
	local cb = db.binds[class]
	-- Migration de l'ancien format (un seul jeu par classe)
	if type(cb) == "table" and (cb["1"] ~= nil or cb["2"] ~= nil) then
		cb = { [1] = cb, [2] = VP.deepCopy(cb) }
		db.binds[class] = cb
	end
	if type(cb) ~= "table" then
		cb = { [1] = defaultsFor(class), [2] = defaultsFor(class) }
		db.binds[class] = cb
	end
	spec = spec or VP:Spec()
	cb[spec] = cb[spec] or defaultsFor(class)
	return cb[spec]
end

local function listFor(root, n)
	local db = VP.db
	db[root][VP.class] = db[root][VP.class] or {}
	local s = VP:Spec()
	local t = db[root][VP.class][s]
	if not t then
		t = {}
		db[root][VP.class][s] = t
	end
	for i = 1, n do t[i] = t[i] or {} end
	return t
end
function C:Keys() return listFor("keys", self.NUM_KEYS) end
-- Sur un allié contrôlé par l'ennemi : sorts proposés par défaut (comme Decursive)
local HOSTILE_DEFAULTS = {
	SHAMAN = { 51514, 370 },     -- Maléfice, Purge
	MAGE = { 118 },              -- Métamorphose
	DRUID = { 33786, 2637 },     -- Cyclone, Hibernation
	PRIEST = { 527, 10955 },     -- Dissipation de la magie, Entraves des morts-vivants
	PALADIN = { 20066 },         -- Repentir
	WARLOCK = { 5782 },          -- Peur
	HUNTER = { 19801 },          -- Tir tranquillisant
}
function C:Hostile()
	local t = listFor("hostile", self.NUM_HOSTILE)
	if not t.vpInit then
		t.vpInit = true
		for i, id in ipairs(HOSTILE_DEFAULTS[VP.class] or {}) do
			local n = GetSpellInfo(id)
			if t[i] and (not t[i].action or t[i].action == "") and n then t[i].action = n end
		end
	end
	return t
end

function C:CopySpec(from, to)
	local db = VP.db
	self:Binds(from); self:Binds(to)
	db.binds[VP.class][to] = VP.deepCopy(db.binds[VP.class][from])
	for _, root in ipairs({ "keys", "hostile" }) do
		db[root][VP.class] = db[root][VP.class] or {}
		db[root][VP.class][to] = VP.deepCopy(db[root][VP.class][from] or {})
	end
	self:Apply()
	VP:Print("Clics de la spé " .. from .. " copiés vers la spé " .. to .. ".")
end

-- Traduction d'une action en attributs sécurisés --------------------------------
function C:Resolve(val)
	if val == "target" then return "target" end
	if val == "menu" then return "menu" end
	if val == "focus" then return "focus" end
	if val == "assist" then return "assist" end
	if val == "DISPEL1" or val == "DISPEL2" then
		local s = VP.Dispel.slots[tonumber(string.sub(val, -1))]
		if s then return "spell", "spell", s.name end
		return nil
	end
	if type(val) == "string" and val ~= "" then
		-- macro de la bibliothèque : « M:Nom »
		local mname = string.match(val, "^[Mm]:%s*(.+)$")
		if mname then
			local m = VP.Macros and VP.Macros:Find(mname)
			if m and m.body and m.body ~= "" then return "macro", "macrotext", m.body end
			return nil
		end
		if string.sub(val, 1, 1) == "/" then return "macro", "macrotext", val end
		local item = string.match(val, "^[Oo]bjet:%s*(.+)$") or string.match(val, "^[Ii]tem:%s*(.+)$")
		if item then return "item", "item", item end
		return "spell", "spell", val
	end
	return nil
end

-- Libellés et icônes pour l'affichage de l'action
function C:ToText(v)
	if v == "target" then return "cible" end
	if v == "DISPEL1" then return "dispel1" end
	if v == "DISPEL2" then return "dispel2" end
	return v or ""
end
function C:FromText(s)
	s = (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local l = string.lower(s)
	if l == "cible" or l == "target" then return "target" end
	if l == "menu" then return "menu" end
	if l == "focus" then return "focus" end
	if l == "assister" or l == "assist" then return "assist" end
	if l == "dispel1" or l == "dispel 1" then return "DISPEL1" end
	if l == "dispel2" or l == "dispel 2" then return "DISPEL2" end
	return s
end

-- Cibles des attributs : en-têtes + chaque bouton (écrits directement, sans dépendre de "useparent")
C.attrTargets = {}
C.attrs = {}          -- attributs actuellement appliqués : nom -> valeur
function C:RegisterTarget(f)
	table.insert(self.attrTargets, f)
end

-- Description lisible d'une action : icône, texte d'état, ok ?
function C:Describe(val)
	if val == nil or val == "" then return nil, "|cff666666-|r", nil end
	if val == "target" then return "Interface\\Icons\\Ability_Hunter_SniperShot", "|cff55dd77Cibler|r", true end
	if val == "menu" then return "Interface\\Icons\\INV_Misc_Note_01", "|cff55dd77Menu|r", true end
	if val == "focus" then return "Interface\\Icons\\Ability_Hunter_MarkedForDeath", "|cff55dd77Focus|r", true end
	if val == "assist" then return "Interface\\Icons\\Ability_Hunter_Pet_Assist", "|cff55dd77Assister|r", true end
	if val == "DISPEL1" or val == "DISPEL2" then
		local s = VP.Dispel.slots[tonumber(string.sub(val, -1))]
		if s then
			local _, _, icon = GetSpellInfo(s.name)
			return icon, "|cff55dd77" .. s.name .. "|r", true
		end
		return nil, "|cffff5555Aucun dispel|r", false
	end
	local mname = string.match(val, "^[Mm]:%s*(.+)$")
	if mname then
		local m = VP.Macros and VP.Macros:Find(mname)
		if m and m.body and m.body:gsub("%s", "") ~= "" then return VP.Macros:Icon(m), "|cff55dd77Macro « " .. m.name .. " »|r", true end
		if m then return VP.Macros:Icon(m), "|cffff5555Macro vide|r", false end
		return nil, "|cffff5555Macro introuvable|r", false
	end
	if string.sub(val, 1, 1) == "/" then return "Interface\\Icons\\INV_Misc_QuestionMark", "|cff55dd77Macro|r", true end
	if string.match(val, "^[Oo]bjet:") or string.match(val, "^[Ii]tem:") then return "Interface\\Icons\\INV_Misc_Bag_08", "|cff55dd77Objet|r", true end
	local name, _, icon = GetSpellInfo(val)
	if name then return icon, "|cff55dd77Sort connu|r", true end
	return nil, "|cffff5555Sort inconnu|r", false
end

-- Toutes les combinaisons souris/molette : { clé, libellé }
function C:Combos()
	local t = { { "", "(aucune)" } }
	for _, mod in ipairs(self.MODS) do
		for _, btn in ipairs(self.MOUSE) do
			t[#t + 1] = { mod .. btn, self.MOD_LABEL[mod] .. self.MOUSE_LABEL[btn] }
		end
		for _, w in ipairs(self.WHEEL) do
			t[#t + 1] = { mod .. w, self.MOD_LABEL[mod] .. self.WHEEL_LABEL[w] }
		end
	end
	return t
end

-- Combinaison qui lance une action donnée (ex. "DISPEL1")
function C:FindBind(value)
	for k, v in pairs(self:Binds()) do
		if v == value then return k end
	end
	return ""
end

-- Affecte Dispel 1 / 2 à une combinaison (et la retire de l'ancienne)
function C:SetDispelKey(slot, key)
	local binds = self:Binds()
	local value = "DISPEL" .. slot
	for k, v in pairs(binds) do
		if v == value then binds[k] = "" end
	end
	if key and key ~= "" then binds[key] = value end
	self:Apply()
end

-- Type d'action : Sort / Commande / Macro / Objet
function C:TypeLabel(val)
	local typ = self:Resolve(val)
	if typ == "spell" then
		if val == "DISPEL1" or val == "DISPEL2" then return "Dispel" end
		return "Sort"
	end
	if typ == "macro" then
		local mname = type(val) == "string" and string.match(val, "^[Mm]:%s*(.+)$")
		return mname and ("Macro « " .. mname .. " »") or "Macro"
	end
	if not typ and type(val) == "string" and string.match(val, "^[Mm]:") then return "|cffff5555Macro introuvable|r" end
	if typ == "item" then return "Objet" end
	if typ then return "Commande" end
	return ""
end

-- Liste lisible des clics actifs (infobulle des cadres, résumé)
-- libellé court d'une action : nom du sort, nom de la macro (jamais tout son texte)
local function shortWhat(clicks, v, typ, value)
	if typ == "macro" then
		return string.match(v, "^[Mm]:%s*(.+)$") or "macro"
	end
	return value or clicks:ToText(v)
end

function C:Summary()
	-- mis en cache jusqu'au prochain « Appliquer » (appelé à chaque survol de cadre)
	if self.summaryCache then return self.summaryCache end
	local out = {}
	local binds = self:Binds()
	for _, btn in ipairs(self.MOUSE) do
		for _, mod in ipairs(self.MODS) do
			local v = binds[mod .. btn]
			local typ, _, value = self:Resolve(v)
			if typ then table.insert(out, { self.MOD_LABEL[mod] .. self.MOUSE_LABEL[btn], shortWhat(self, v, typ, value) }) end
		end
	end
	for _, mod in ipairs(self.MODS) do
		for _, w in ipairs(self.WHEEL) do
			local v = binds[mod .. w]
			local typ, _, value = self:Resolve(v)
			if typ then table.insert(out, { self.MOD_LABEL[mod] .. self.WHEEL_LABEL[w], shortWhat(self, v, typ, value) }) end
		end
	end
	for _, k in ipairs(self:Keys()) do
		if k.key and k.key ~= "" and k.action and k.action ~= "" then
			local typ, _, value = self:Resolve(k.action)
			if typ then table.insert(out, { k.key, shortWhat(self, k.action, typ, value) }) end
		end
	end
	self.summaryCache = out
	return out
end

-- Écrit les attributs courants sur un cadre (hors combat)
-- Écrit les attributs de clic sur un cadre.
-- * seulement ceux qui ont changé : chaque SetAttribute sur un en-tête de groupe visible relance
--   tout son placement (gros à-coup en fin de combat en raid 25/40 sinon) ;
-- * pas de « harmbutton » (sorts sur ennemi contrôlé) sur les cadres Cible / Focus ni sur ceux de
--   Blizzard : un clic sur un monstre ciblé lançait sinon Métamorphose, Maléfice, Purge...
local function noHarm(f)
	return f.vpKind == "target" or f.vpBlizzFrame
end
-- Valeurs voulues pour ce cadre : nom -> valeur (false = à effacer). Table réutilisée.
local want = {}
local function wanted(f, old)
	wipe(want)
	local skipHarm = noHarm(f)
	-- les attributs « vp-* » ne servent qu'aux boutons (lus par le code sécurisé du bouton) :
	-- inutile de les écrire sur les en-têtes
	local isButton = f.GetObjectType and f:GetObjectType() == "Button"
	if old then
		for name in pairs(old) do
			if C.attrs[name] == nil and f:GetAttribute(name) ~= nil then want[name] = false end
		end
	end
	for name, v in pairs(C.attrs) do
		-- cadres Cible / Focus / Blizzard : aucune action « hostile », ni ses macros (vph1..3)
		if skipHarm and (string.find(name, "harmbutton", 1, true) or string.find(name, "vph", 1, true)) then v = nil end
		if not isButton and string.sub(name, 1, 3) == "vp-" then v = nil end
		if f:GetAttribute(name) ~= v then want[name] = (v == nil) and false or v end
	end
	return isButton
end
local function writeAll(f, old)
	local isButton = wanted(f, old)
	if not next(want) then return end
	-- copie locale : une écriture peut créer un nouveau cadre (placement de l'en-tête) qui réécrit SES clics
	-- avec la même table « want » ; sans copie, la boucle ci-dessous serait vidée en plein parcours
	local names, vals, n = {}, {}, 0
	for name, v in pairs(want) do n = n + 1; names[n], vals[n] = name, v end
	-- En-tête de groupe : chaque SetAttribute relance tout son placement (des centaines de fois à la
	-- connexion). Les attributs de clic ne déplacent aucun cadre : « _ignore » suspend ce placement
	-- le temps de l'écriture (le dernier SetAttribute retire la suspension, même en cas d'erreur).
	local hold = not isButton
	if hold then f:SetAttribute("_ignore", true) end
	local ok, err = pcall(function()
		for i = 1, n do
			local v = vals[i]
			if v == false then f:SetAttribute(names[i], nil) else f:SetAttribute(names[i], v) end
		end
	end)
	if hold then f:SetAttribute("_ignore", nil) end
	if not ok then geterrorhandler()(err) end
end

function C:ApplyTo(b)
	if InCombatLockdown() then return end
	writeAll(b)
	b:RegisterForClicks(VP.db.castOnDown and "AnyDown" or "AnyUp")
end

function C:Apply()
	if not VP.db or not self.handler then return end
	local binds = self:Binds()
	local keys = self:Keys()
	local hostile = self:Hostile()

	-- Rappels de dispel affichés sur les cadres
	VP.dispelKeys = {}
	for _, btn in ipairs(self.MOUSE) do
		for _, mod in ipairs(self.MODS) do
			local v = binds[mod .. btn]
			local short = self.SHORT_MOD[mod] .. self.SHORT_MOUSE[btn]
			if v == "DISPEL1" and VP.Dispel.slots[1] then VP.dispelKeys[1] = VP.dispelKeys[1] or short end
			if v == "DISPEL2" and VP.Dispel.slots[2] then VP.dispelKeys[2] = VP.dispelKeys[2] or short end
		end
	end
	for _, k in ipairs(keys) do
		if k.key and k.key ~= "" then
			if k.action == "DISPEL1" and VP.Dispel.slots[1] then VP.dispelKeys[1] = VP.dispelKeys[1] or k.key end
			if k.action == "DISPEL2" and VP.Dispel.slots[2] then VP.dispelKeys[2] = VP.dispelKeys[2] or k.key end
		end
	end

	C.summaryCache = nil
	local ok = VP:RunOOC("clicks", function()
		local db = VP.db
		local old = C.attrs
		C.attrs = {}
		local A = C.attrs
		local active = 0

		local uselines = ""
		if db.clicks.autoTrinket and VP.Trinkets.UseLines then uselines = VP.Trinkets:UseLines() end
		local autoOn = uselines ~= ""
		local hasAuto = false

		local function write(suffixKey, attrPrefix, val, macName)
			local typ, field, value = C:Resolve(val)
			if typ then
				A[attrPrefix .. "type" .. suffixKey] = typ
				if field then
					local stored = value
					-- macro à jetons : texte de secours visant le cadre survolé, utilisé là où le code
					-- sécurisé du clic n'est pas encore installé (cadres Blizzard, cadre créé en combat)
					if typ == "macro" then stored = (value:gsub("@vp", "@mouseover"):gsub("{vp}", "mouseover")) end
					A[attrPrefix .. field .. suffixKey] = stored
				end
				active = active + 1
				-- macro avec @vp / {vp} : remplacés au clic par le joueur visé
				-- @vp -> @raid5 (dans les conditions [ ]) ; {vp} -> raid5 (ex. /focus {vp})
				if typ == "macro" and macName and (string.find(value, "@vp", 1, true) or string.find(value, "{vp}", 1, true)) then
					local parts, kinds, start = {}, {}, 1
					while true do
						local i1 = string.find(value, "@vp", start, true)
						local i2 = string.find(value, "{vp}", start, true)
						local i, len, raw
						if i1 and (not i2 or i1 < i2) then i, len, raw = i1, 3, false
						elseif i2 then i, len, raw = i2, 4, true end
						if not i then parts[#parts + 1] = string.sub(value, start); break end
						parts[#parts + 1] = string.sub(value, start, i - 1)
						kinds[#kinds + 1] = raw and "" or "@"
						start = i + len
					end
					A["vp-macn-" .. macName] = #parts
					for k, part in ipairs(parts) do A["vp-mac-" .. macName .. "-" .. k] = part end
					for k, kd in ipairs(kinds) do A["vp-mact-" .. macName .. "-" .. (k + 1)] = kd end
					hasAuto = true
				end
			end
			return typ, value
		end

		-- Souris
		for _, btn in ipairs(C.MOUSE) do
			for _, mod in ipairs(C.MODS) do
				local typ, value = write(btn, mod, binds[mod .. btn], mod .. btn)
				if autoOn and typ == "spell" then
					A["vp-auto-" .. mod .. btn] = value
					hasAuto = true
				end
			end
		end

		-- Touches au survol (+ molette)
		local n = 0
		for i, k in ipairs(keys) do
			local name = "vpk" .. i
			if k.key and k.key ~= "" and k.action and k.action ~= "" then
				local typ, value = write("-" .. name, "*", k.action, name)
				if typ then
					n = n + 1
					A["vp-key" .. n] = k.key
					A["vp-keybtn" .. n] = name
					if autoOn and typ == "spell" then
						A["vp-auto-" .. name] = value
						hasAuto = true
					end
				end
			end
		end
		-- Molette avec chaque modificateur
		local wi = 0
		for _, mod in ipairs(C.MODS) do
			for _, w in ipairs(C.WHEEL) do
				wi = wi + 1
				local v = binds[mod .. w]
				local name = "vpw" .. wi
				local typ, value = write("-" .. name, "*", v, name)
				if typ then
					n = n + 1
					A["vp-key" .. n] = string.upper(mod) .. C.WHEEL_KEY[w]
					A["vp-keybtn" .. n] = name
					if autoOn and typ == "spell" then
						A["vp-auto-" .. name] = value
						hasAuto = true
					end
				end
			end
		end
		A["vp-nkeys"] = n

		-- Actions sur un allié contrôlé (hostile)
		for i = 1, C.NUM_HOSTILE do
			local a = hostile[i] and hostile[i].action
			if a and a ~= "" then
				A["*harmbutton" .. i] = "vph" .. i
				write("-vph" .. i, "*", a, "vph" .. i)
			end
		end

		-- Clic intelligent : résurrection hors combat
		local rez = REZ[VP.class] and GetSpellInfo(REZ[VP.class])
		if rez and not GetSpellInfo(rez) then rez = nil end
		if db.clicks.smartRes and rez then
			A["vp-smartres"] = true
			A["*type-vprez"] = "spell"
			A["*spell-vprez"] = rez
		end
		if hasAuto then
			A["vp-hasauto"] = true
			A["vp-uselines"] = uselines
		end

		for _, f in ipairs(C.attrTargets) do writeAll(f, old) end
		C:ApplyBlizzard(old)
		for _, b in ipairs(VP.Frames.buttons) do
			writeAll(b, old)
			b:RegisterForClicks(db.castOnDown and "AnyDown" or "AnyUp")
		end
		C.activeCount = active
		C.lastApply = date("%H:%M:%S")
	end)
	return ok
end

-- Clic-soin sur les cadres Blizzard (joueur, cible, focalisation, groupe, familier) - comme Clique
local BLIZZ = { "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame",
	"PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4" }
function C:ApplyBlizzard(old)
	local on = VP.db.clicks.blizz
	for _, n in ipairs(BLIZZ) do
		local f = _G[n]
		if f and f.SetAttribute then
			if on then
				f.vpBlizzFrame = true
				writeAll(f, old)
				f.vpClicks = true
			elseif f.vpClicks then
				for name in pairs(old or {}) do f:SetAttribute(name, nil) end
				for name in pairs(C.attrs) do f:SetAttribute(name, nil) end
				f:SetAttribute("*type1", "target")
				f:SetAttribute("*type2", "menu")
				f.vpClicks = nil
			end
		end
	end
end

-- Scripts sécurisés enveloppant chaque bouton ------------------------------
-- Ils ne lisent que les attributs du bouton lui-même (aucune dépendance externe).
local ONCLICK = [[
	local unit = self:GetAttribute("unit")
	if not unit or not SecureCmdOptionParse then return end
	if self:GetAttribute("vp-smartres") and (button == "LeftButton" or button == "RightButton" or button == "MiddleButton") then
		if SecureCmdOptionParse("[target=" .. unit .. ",help,dead,nocombat] r") == "r" then
			return "vprez"
		end
	end
	if not self:GetAttribute("vp-hasauto") then return end
	if SecureCmdOptionParse("[target=" .. unit .. ",harm] h") == "h" then
		-- allié contrôlé par l'ennemi : macro de l'action « hostile » de ce bouton
		local hn = (button == "LeftButton" and "vph1") or (button == "RightButton" and "vph2") or (button == "MiddleButton" and "vph3")
		local hp = hn and self:GetAttribute("vp-macn-" .. hn)
		if hp then
			local txt = self:GetAttribute("vp-mac-" .. hn .. "-1") or ""
			for k = 2, hp do
				txt = txt .. (self:GetAttribute("vp-mact-" .. hn .. "-" .. k) or "@") .. unit .. (self:GetAttribute("vp-mac-" .. hn .. "-" .. k) or "")
			end
			self:SetAttribute("*type-vpmac", "macro")
			self:SetAttribute("*macrotext-vpmac", txt)
			return "vpmac"
		end
		return
	end
	local name
	if button == "LeftButton" then name = "1"
	elseif button == "RightButton" then name = "2"
	elseif button == "MiddleButton" then name = "3"
	elseif button == "Button4" then name = "4"
	elseif button == "Button5" then name = "5" end
	if name then
		local mod = (SecureCmdOptionParse("[mod:alt]alt-;") or "") .. (SecureCmdOptionParse("[mod:ctrl]ctrl-;") or "")
			.. (SecureCmdOptionParse("[mod:shift]shift-;") or "")
		name = mod .. name
	else
		name = button
	end
	local np = self:GetAttribute("vp-macn-" .. name)
	if np then
		local txt = self:GetAttribute("vp-mac-" .. name .. "-1") or ""
		for k = 2, np do
			txt = txt .. (self:GetAttribute("vp-mact-" .. name .. "-" .. k) or "@") .. unit .. (self:GetAttribute("vp-mac-" .. name .. "-" .. k) or "")
		end
		self:SetAttribute("*type-vpmac", "macro")
		self:SetAttribute("*macrotext-vpmac", txt)
		return "vpmac"
	end
	local spell = self:GetAttribute("vp-auto-" .. name)
	if spell then
		self:SetAttribute("*type-vpauto", "macro")
		self:SetAttribute("*macrotext-vpauto", (self:GetAttribute("vp-uselines") or "") .. "/cast [target=" .. unit .. "] " .. spell)
		return "vpauto"
	end
]]

local ONENTER = [[
	local n = self:GetAttribute("vp-nkeys") or 0
	for i = 1, n do
		local key = self:GetAttribute("vp-key" .. i)
		local btn = self:GetAttribute("vp-keybtn" .. i)
		if key and btn then self:SetBindingClick(true, key, self, btn) end
	end
]]

local ONLEAVE = [[
	self:ClearBindings()
]]

-- Un cadre caché puis réaffiché sans que la souris ait bougé (l'en-tête de groupe replace ses cadres
-- à chaque changement dans le groupe) ne reçoit pas de nouvel OnEnter : OnHide a retiré la molette et
-- les touches de survol, on les remet si la souris est toujours dessus.
local ONSHOW = [[
	if not (self.IsUnderMouse and self:IsUnderMouse()) then return end
]] .. ONENTER

local pending = {}
function C:Wrap(b)
	if b.vpWrapped or not self.handler then return end
	if InCombatLockdown() then
		pending[b] = true
		return
	end
	b.vpWrapped = true
	self.handler:WrapScript(b, "OnClick", ONCLICK)
	self.handler:WrapScript(b, "OnEnter", ONENTER)
	self.handler:WrapScript(b, "OnLeave", ONLEAVE)
	-- un cadre qui disparaît sous la souris (cible morte, joueur parti) ne reçoit pas toujours
	-- OnLeave : sans ça, la molette et les touches de survol restaient détournées
	self.handler:WrapScript(b, "OnHide", ONLEAVE)
	self.handler:WrapScript(b, "OnShow", ONSHOW)
	self:ApplyTo(b)
end

function C:Refresh()
	self:Apply()
end

function C:OnLogin()
	self.handler = CreateFrame("Frame", "VuhPlusClickHandler", UIParent, "SecureHandlerStateTemplate")
	for _, b in ipairs(VP.Frames.buttons) do self:Wrap(b) end
	VP:On("PLAYER_REGEN_ENABLED", function()
		for b in pairs(pending) do
			pending[b] = nil
			C:Wrap(b)
		end
		C:Apply()
	end)
end
