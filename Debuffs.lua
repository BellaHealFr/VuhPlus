-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Affaiblissements de boss (liste intégrée WotLK) + liste personnelle
local VP = VuhPlus
local B = VP:NewModule("Debuffs")

-- Les ID servent seulement à retrouver le nom dans la langue du client.
-- La détection se fait par nom : toutes les difficultés (10/25/HM) sont couvertes.
-- Priorité : 1 (anecdotique) à 10 (vital). Le cadre affiche le débuff de plus haute priorité ;
-- à partir de 8 (« critique »), la grande icône clignote. Sans priorité = 5.
local BOSS_IDS = {
	-- Naxxramas
	28169, 28622, 27808, 27819, 28084, 28059, 29213, 28522,
	-- Malygos / Sartharion
	56272, 57491,
	-- Ulduar
	63018, 63024, 61903, 61888, 64290, 62283, 63830, 62188, 62038, 64126, 63138, 63802, 62661, 63355, 64771,
	62717, 62166, 62130, 63276, 64125, 63042, 64412,
	-- Épreuve du croisé
	66013, 66197, 66237, 65950, 66001, 66334, 66869, 66823, 67475, 66406, 67574,
	-- Onyxia
	18392,
	-- Citadelle de la Couronne de glace
	69062, 69065, 69146, 71289, 72293, 72410, 72385, 69279, 69240, 72219, 69674, 70911, 70672, 70447,
	72451, 72999, 70867, 70877, 71340, 71264, 70923, 70751, 70126, 69766, 70106, 70128, 69762, 70157,
	70337, 70541, 72754, 68980, 69409, 73912, 71224, 69508, 70215,
	71237, 71204, 69291, 69774, 70633,
	-- Sanctum rubis
	74562, 74792, 74367, 74505,
}

-- Priorités différentes de 5 (ID => priorité)
local PRIO = {
	-- vitaux : le joueur meurt ou fait mourir le raid si on ne réagit pas
	[69065] = 10,  -- Empalé (Gargamoelle)
	[71289] = 10,  -- Domination mentale (Dame Murmemort)
	[69279] = 9,   -- Spores gazeuses (Pulentraille)
	[69674] = 9,   -- Infection mutante (Trognepus)
	[70911] = 9,   -- Peste libérée (Putricide)
	[70672] = 9,   -- Ballonnement gazeux (Putricide)
	[70447] = 9,   -- Adhésif d'ooze volatil (Putricide)
	[70877] = 9,   -- Soif de sang frénétique (Reine de sang)
	[70923] = 10,  -- Frénésie incontrôlable (Reine de sang)
	[70126] = 9,   -- Guide de givre (Sindragosa)
	[70157] = 10,  -- Tombeau de glace (Sindragosa)
	[70337] = 9,   -- Peste nécrotique (Roi-liche)
	[73912] = 9,   -- Peste nécrotique (Roi-liche)
	[72754] = 10,  -- Profanation (Roi-liche)
	[68980] = 10,  -- Moisson d'âme (Roi-liche)
	[69409] = 9,   -- Faucheur d'âme (Roi-liche)
	[74562] = 9,   -- Combustion ardente (Halion)
	[74792] = 9,   -- Consommation d'âme (Halion)
	[62166] = 9,   -- Poigne de pierre (Kologarn)
	[64125] = 9,   -- Étreinte (Yogg-Saron)
	[63042] = 10,  -- Domination mentale (Yogg-Saron)
	[66237] = 9,   -- Incinérer la chair (Jaraxxus)
	[66869] = 8,   -- Bile brûlante (Jormungar)
	[66823] = 8,   -- Toxine paralysante (Jormungar)
	-- secondaires : utiles à voir mais rarement urgents
	[69291] = 2,   -- Inoculé (Pulentraille)
	[72219] = 3,   -- Gonflement gastrique (Pulentraille)
	[70867] = 3,   -- Essence de la Reine de sang
	[71204] = 3,   -- Toucher d'insignifiance (Dame Murmemort)
}

B.boss = {}   -- nom => priorité

-- « Autres affaiblissements » : débuffs sans intérêt pour un soigneur, jamais affichés dans cette rangée
-- (après un Héroïsme, « Rassasié » couvrait les 25 cadres pendant 10 minutes)
local NOISE_IDS = {
	57724, 57723,   -- Rassasié, Épuisement (Furie sanguinaire / Héroïsme)
	6788,           -- Âme affaiblie (suivie à part par l'emplacement de HoT du prêtre)
	25771,          -- Longanimité (idem pour le paladin)
	11196,          -- Récemment bandé
	41425,          -- Hypothermie (après Bloc de glace)
	26013,          -- Déserteur
	8326,           -- Fantôme (liste noire de Cell)
}
B.noise = {}

function B:BuildList()
	wipe(self.boss)
	for _, id in ipairs(BOSS_IDS) do
		local n = GetSpellInfo(id)
		if n then self.boss[n] = math.max(self.boss[n] or 0, PRIO[id] or 5) end
	end
end

-- Priorité d'un affaiblissement suivi (nil = pas suivi) ; la liste perso l'emporte
function B:Priority(name)
	local db = VP.db.debuffs
	if db.custom then
		local c = VP.db.customDebuffs[name]
		if c then return type(c) == "number" and c or (db.customPrio or 7) end
	end
	if db.boss then return self.boss[name] end
	return nil
end
function B:IsTracked(name) return self:Priority(name) ~= nil end

-- Lecture unique des affaiblissements d'une unité (partagée par le dispel, les débuffs de boss
-- et les soins réduits) : un seul passage UnitAura au lieu de trois.
function B:ReadHarmful(unit, buf)
	local n, i = 0, 1
	while true do
		local name, _, icon, count, dtype, duration, expires, _, _, _, spellId = UnitAura(unit, i, "HARMFUL")
		if not name then break end
		n = n + 1
		local e = buf[n]
		if not e then e = {}; buf[n] = e end
		e.name, e.icon, e.count, e.dtype, e.dur, e.exp, e.id = name, icon, count, dtype, duration, expires, spellId
		i = i + 1
	end
	buf.n = n
	return buf
end
local tmpBuf = {}

-- Renvoie le plus important : nom, icône, cumuls, durée, expiration, autres icônes (3 max), priorité
local others = {}
function B:Scan(unit, buf)
	wipe(others)
	buf = buf or self:ReadHarmful(unit, tmpBuf)
	local db = VP.db.debuffs
	local best, bestP
	for k = 1, buf.n do
		local e = buf[k]
		local p = self:Priority(e.name)
		if p and p < (db.minPrio or 1) then p = nil end   -- sous le seuil choisi : traité comme un débuff ordinaire
		if p then
			if not bestP or p > bestP then
				if best and db.showOthers and #others < 3 then others[#others + 1] = best.icon end
				best, bestP = e, p
			elseif db.showOthers and #others < 3 then
				others[#others + 1] = e.icon
			end
		elseif db.showOthers and #others < 3 and not self.noise[e.name] then
			others[#others + 1] = e.icon
		end
	end
	if not best then return nil, nil, nil, nil, nil, others end
	return best.name, best.icon, best.count, best.dur, best.exp, others, bestP, best.dtype
end

-- « Nom » ou « Nom = 9 » (priorité 1 à 10)
local function parse(text)
	text = text and text:gsub("^%s+", ""):gsub("%s+$", "")
	if not text or text == "" then return nil end
	local name, p = string.match(text, "^(.-)%s*=%s*(%d+)$")
	if name and name ~= "" then
		return name, math.max(1, math.min(10, tonumber(p)))
	end
	return text, nil
end

function B:AddCustom(text)
	local name, p = parse(text)
	if not name then return end
	VP.db.customDebuffs[name] = p or (VP.db.debuffs.customPrio or 7)
	VP:Print("Affaiblissement suivi : " .. name .. " (priorité " .. VP.db.customDebuffs[name] .. ")")
end

function B:RemoveCustom(text)
	local name = parse(text)
	if name and VP.db.customDebuffs[name] then
		VP.db.customDebuffs[name] = nil
		VP:Print("Affaiblissement retiré : " .. name)
	end
end

function B:CustomText()
	local t = {}
	for k, v in pairs(VP.db.customDebuffs) do
		t[#t + 1] = k .. " (" .. (type(v) == "number" and v or (VP.db.debuffs.customPrio or 7)) .. ")"
	end
	table.sort(t)
	if #t == 0 then return "(vide)" end
	return table.concat(t, ", ")
end

-- Son à l'apparition d'un débuff de boss : fort pour un critique, discret pour les autres
-- (réglage : OFF jamais, CRIT seulement les critiques, ALL tous)
local lastSound = 0
function B:Alert(crit)
	local mode = VP.db.debuffs.sound
	if mode == true then mode = "CRIT" end   -- ancien réglage
	if not mode or mode == "OFF" or (mode == "CRIT" and not crit) or VP.db.alerts.quiet then return end
	if GetTime() - lastSound > 3 then
		lastSound = GetTime()
		PlaySound(crit and "RaidWarning" or "MapPing")
	end
end

function B:OnLogin()
	self:BuildList()
	for _, id in ipairs(NOISE_IDS) do
		local n = GetSpellInfo(id)
		if n then self.noise[n] = true end
	end
end
