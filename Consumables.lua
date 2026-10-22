-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Vérification des consommables : flacons / élixirs et nourriture (« Bien nourri »)
-- Rapport à la demande (bouton « Conso », /vp conso) et automatiquement à chaque appel (ready check).
local VP = VuhPlus
local CS = VP:NewModule("Consumables")

-- Flacons connus (WotLK + BC) : les noms sont lus dans la langue du client
local FLASK_IDS = {
	53755, 53760, 54212, 53758, 53752, 62380,                 -- Wyrm de givre, Rage sans fin, Mojo pur, Sang-de-pierre, Robustesse, Résistance
	17626, 17627, 17628, 28518, 28519, 28520, 28521, 28540, 33053, 42735, 46837, 46839, -- flacons BC
}
-- Élixirs connus (bataille et gardien, WotLK + BC)
local ELIXIR_IDS = {
	53748, 53749, 53746, 53747, 53751, 53763, 53764, 60340, 60341, 60343, 60344, 60345, 60346, 60347,
	28497, 28490, 28491, 28493, 28501, 28502, 28503, 28509, 28514, 33720, 33721, 33726, 38954, 39625, 39626, 39627, 39628,
}
local flaskNames, elixirNames = {}, {}
local FOOD_ICON = "Spell_Misc_Food"        -- icône commune à tous les buffs « Bien nourri »
local foodName                              -- nom localisé de « Bien nourri »

local function loadNames()
	for _, id in ipairs(FLASK_IDS) do local n = GetSpellInfo(id); if n then flaskNames[n] = true end end
	for _, id in ipairs(ELIXIR_IDS) do local n = GetSpellInfo(id); if n then elixirNames[n] = true end end
	foodName = GetSpellInfo(57399) -- Bien nourri (poisson)
end

-- Résultat pour une unité : flacon ?, nombre d'élixirs, nourriture ?
function CS:Scan(u)
	local flask, elix, food = false, 0, false
	local i = 1
	while true do
		local name, _, icon = UnitAura(u, i, "HELPFUL")
		if not name then break end
		if flaskNames[name] or string.find(name, "Flacon", 1, true) or string.find(name, "Flask", 1, true) then
			flask = true
		elseif elixirNames[name] or string.find(name, "lixir", 1, true) then
			elix = elix + 1
		end
		if (icon and string.find(icon, FOOD_ICON, 1, true)) or (foodName and name == foodName) then food = true end
		i = i + 1
	end
	return flask, elix, food
end

local function groupUnits(fn)
	local n = GetNumRaidMembers()
	if n > 0 then
		for i = 1, n do fn("raid" .. i) end
	else
		fn("player")
		for i = 1, GetNumPartyMembers() do fn("party" .. i) end
	end
end

-- Construit les listes des manquants. Retourne noFlask, partial, noFood, far (tables de noms)
local noFlask, partial, noFood, far = {}, {}, {}, {}
function CS:Check()
	wipe(noFlask); wipe(partial); wipe(noFood); wipe(far)
	local c = VP.db.consum
	groupUnits(function(u)
		if not UnitExists(u) or not UnitIsConnected(u) then return end
		local name = UnitName(u)
		if not name then return end
		if not UnitIsVisible(u) then far[#far + 1] = name return end
		if UnitIsDeadOrGhost(u) then return end
		local flask, elix, food = self:Scan(u)
		if c.flask and not flask then
			if elix == 0 then noFlask[#noFlask + 1] = name
			elseif elix == 1 then partial[#partial + 1] = name end
		end
		if c.food and not food then noFood[#noFood + 1] = name end
	end)
	return noFlask, partial, noFood, far
end

-- Envoie une ligne longue en plusieurs messages (le chat est limité à 255 caractères)
local function send(prefix, list, ch)
	if #list == 0 then return end
	local line = prefix
	for i, n in ipairs(list) do
		local add = (i > 1 and ", " or "") .. n
		if #line + #add > 240 then
			if ch then SendChatMessage(line, ch) else VP:Print(line) end
			line = prefix .. n
		else
			line = line .. add
		end
	end
	if ch then SendChatMessage(line, ch) else VP:Print(line) end
end

-- Rapport : toGroup = true pour l'annoncer au groupe / raid
function CS:Report(toGroup)
	local c = VP.db.consum
	if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 and toGroup then toGroup = false end
	local nf, pa, nfo, fa = self:Check()
	local ch
	if toGroup then ch = VP:GroupChannel() end
	local tag = ch and "[VuhPlus] " or ""
	if #nf == 0 and #pa == 0 and #nfo == 0 then
		local msg = tag .. "Consommables : tout le monde a son flacon et sa nourriture."
		if ch then SendChatMessage(msg, ch) else VP:Print("|cff55ff55" .. msg .. "|r") end
	else
		send(tag .. (ch and "Sans flacon ni élixir : " or "|cffff5555Sans flacon ni élixir :|r "), nf, ch)
		send(tag .. (ch and "Un seul élixir : " or "|cffffaa33Un seul élixir :|r "), pa, ch)
		send(tag .. (ch and "Sans nourriture : " or "|cffff5555Sans nourriture :|r "), nfo, ch)
	end
	if #fa > 0 and not ch then send("|cff999999Trop loin pour vérifier :|r ", fa, nil) end
	-- rappel pour vous-même
	if c.selfAlert then
		local flask, elix, food = self:Scan("player")
		local miss
		if c.flask and not flask and elix < 2 then miss = (elix == 1) and "Il vous manque un élixir" or "Pas de flacon !" end
		if c.food and not food then miss = (miss and (miss .. " + ") or "") .. "Pas de nourriture !" end
		if miss and VP.Raid and VP.Raid.Flash then VP.Raid:Flash(miss, 1, 0.6, 0.1) end
	end
end

function CS:OnLogin()
	loadNames()
	-- vérification automatique à chaque appel
	VP:On("READY_CHECK", function(_, initiator)
		local c = VP.db.consum
		if not c.enabled or not c.onReady then return end
		local mine = initiator and UnitName("player") == initiator
		local lead = VP.Raid and VP.Raid.isLead and VP.Raid.isLead()
		CS:Report(c.announce == "GROUP" and mine and lead)
	end)
end
