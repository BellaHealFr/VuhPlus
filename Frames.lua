-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Boutons de membres : éléments visuels modernes et mise à jour
local VP = VuhPlus
local F = VP:NewModule("Frames")
local T = VP.Theme
F.buttons = {}
F.readyStatus = {}

-- Durée « 1:23 » (temps depuis la mort)
local function clock(sec)
	sec = math.floor(sec)
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-- Unité de familier -> unité de son maître
local PET_OWNER_OF = { pet = "player" }
for i = 1, 4 do PET_OWNER_OF["partypet" .. i] = "party" .. i end
for i = 1, 40 do PET_OWNER_OF["raidpet" .. i] = "raid" .. i end

local BLIZZ_TEX = "Interface\\TargetingFrame\\UI-StatusBar"

-- Soins sur la durée / boucliers lancés par VOUS
-- Emplacements de HoTs par défaut (6 max) : ID du sort, les miens, ceux des autres, couleur (mode carrés)
local DEFAULT_SLOTS = {
	-- Prêtre : Âme affaiblie (débuff : Mot de pouvoir : Bouclier impossible) et Grâce ; Esprit gardien et
	-- Suppression de la douleur sont déjà montrés par l'indicateur « gros défensif »
	PRIEST  = { { 139, true, false }, { 33076, true, false }, { 17, true, true }, { 6788, true, true }, { 47753, true, false }, { 47517, true, false } },
	DRUID   = { { 774, true, false }, { 8936, true, false }, { 33763, true, false }, { 48438, true, false }, { 29166, true, true }, { 48504, true, false } },
	SHAMAN  = { { 61295, true, false }, { 974, true, true }, { 51945, true, false }, { 16237, true, true } },
	-- Paladin : le soin sur la durée d'Éclair lumineux (cible du Bouclier saint) et Longanimité (débuff) ;
	-- Main de sacrifice / de protection sont déjà montrées par l'indicateur « gros défensif »
	PALADIN = { { 53563, true, false }, { 53601, true, false }, { 66922, true, false }, { 25771, true, true } },
}
-- Position par défaut de chaque emplacement (1 à 6)
local DEFAULT_POS = { "TR", "BR", "R", "T", "B", "BL" }  -- 6 places distinctes : aucun chevauchement

-- Sorts proposés dans la liste de chaque emplacement, selon la classe
-- (vérifiés sur la base WotLK : Soin chaîné = bonus 4 pièces T10 chaman, Soin béni = bonus 2 pièces T10 prêtre,
--  Rénovation du Puits de lumière, HoT du Glyphe de prière de soins, Gaine de lumière = talent Vindicte)
F.CLASS_SPELLS = {
	SHAMAN  = { 61295, 974, 51945, 70809, 52127, 16237, 29203, 324, 2825, 32182 },
	DRUID   = { 774, 8936, 33763, 48438, 48504, 467, 2893, 29166, 1126 },
	PRIEST  = { 139, 17, 6788, 33076, 47753, 47517, 7001, 56161, 70772, 47788, 33206, 14893, 10060, 6346 },
	PALADIN = { 53563, 53601, 66922, 54203, 25771, 6940, 1022, 1038, 1044, 31842, 20217, 19740 },
}

-- Icône d'un sort suivi, d'après son NOM. GetSpellInfo("nom") ne répond que pour les sorts du grimoire :
-- Viveterre, Égide divine, Graine de vie, Âme affaiblie, Rénovation du Puits de lumière... restaient sans
-- icône dans les options et en « ? » dans l'aperçu. On retrouve l'icône par l'ID (connu pour tout sort),
-- puis par les auras vues en jeu.
local iconByName = {}
function F:SpellIcon(name)
	if not name or name == "" then return nil end
	local _, _, ic = GetSpellInfo(name)
	if ic then return ic end
	if not self.iconsBuilt then
		self.iconsBuilt = true
		local function add(id)
			local n, _, i = GetSpellInfo(id)
			if n and i and not iconByName[n] then iconByName[n] = i end
		end
		for _, list in pairs(F.CLASS_SPELLS) do for _, id in ipairs(list) do add(id) end end
		for _, list in pairs(DEFAULT_SLOTS) do for _, e in ipairs(list) do add(e[1]) end end
	end
	return iconByName[name]
end
local function learnIcon(name, ic) if ic and not iconByName[name] then iconByName[name] = ic end end

local SLOT_COLORS = {
	{ 0.2, 0.9, 0.3 }, { 0.3, 0.6, 1 }, { 1, 0.85, 0.2 }, { 0.8, 0.4, 1 }, { 1, 0.5, 0.2 }, { 0.2, 0.9, 0.9 },
}
F.NUM_SLOTS = 6

-- Positions possibles d'une icône : point de l'icône, point de la barre, décalage x, y, dehors ?
F.POS = {
	TL = { "TOPLEFT", "TOPLEFT", 2, -2 },     T = { "TOP", "TOP", 0, -2 },        TR = { "TOPRIGHT", "TOPRIGHT", -2, -2 },
	L  = { "LEFT", "LEFT", 2, 0 },            C = { "CENTER", "CENTER", 0, 0 },   R  = { "RIGHT", "RIGHT", -2, 0 },
	BL = { "BOTTOMLEFT", "BOTTOMLEFT", 2, 2 }, B = { "BOTTOM", "BOTTOM", 0, 2 },  BR = { "BOTTOMRIGHT", "BOTTOMRIGHT", -2, 2 },
	OL = { "RIGHT", "LEFT", -3, 0, true },    OR = { "LEFT", "RIGHT", 3, 0, true },
	OT = { "BOTTOM", "TOP", 0, 3, true },     OB = { "TOP", "BOTTOM", 0, -3, true },
	TE = { "CENTER", "TOP", 0, 0, true },     RE = { "CENTER", "RIGHT", 0, 0, true },  LE = { "CENTER", "LEFT", 0, 0, true },
}
F.POS_LIST = {
	{ "TL", "Haut gauche" }, { "T", "Haut centre" }, { "TR", "Haut droite" },
	{ "L", "Milieu gauche" }, { "C", "Centre" }, { "R", "Milieu droite" },
	{ "BL", "Bas gauche" }, { "B", "Bas centre" }, { "BR", "Bas droite" },
	{ "OL", "Dehors, à gauche" }, { "OR", "Dehors, à droite" }, { "OT", "Dehors, au-dessus" }, { "OB", "Dehors, en dessous" },
	{ "TE", "À cheval sur le bord haut" }, { "LE", "À cheval sur le bord gauche" }, { "RE", "À cheval sur le bord droit" },
}

-- Gros défensifs (comme les indicateurs « Défensifs / Externes » de Cell)
local DEFENSIVE_IDS = { 871, 12975, 55694, 61336, 22812, 22842, 48792, 48707, 55233, 51271, 642, 498, 1022, 6940, 64205, 31821,
	33206, 47788, 47585, 26669, 31224, 45438, 19263, 30823, 66233, 70940,
	-- ajoutés d'après la liste Wrath de Cell (2026) : Renvoi de sort, Intervention, Zone anti-magie, Intervention divine
	23920, 3411, 51052, 19752 }
-- Boisson (« Boit 45% » sur le cadre)
local DRINK_IDS = { 430, 43182, 57073 }
local drinkNames = {}
-- Soins réduits (Frappe mortelle, Poison douloureux, Aura nécrotique...)
local HEALRED_IDS = { 12294, 13218, 19434, 46910, 28467, 55593, 30213, 43461, 69674 }
local SOULSTONE_ID = 20707
local defNames, healRedNames, soulName = {}, {}, nil

-- Boucliers : Mot de pouvoir : Bouclier, Égide divine, Bouclier sacré (l'effet déclenché), Barrière de glace,
-- Bouclier de mana, Gardiens de feu / de givre / de l'ombre, Protection des anciens rois (Val'anyr)
local SHIELD_IDS = { 17, 47753, 58597, 11426, 1463, 543, 6143, 6229, 64413 }
-- le buff posé par le paladin et l'effet qui absorbe portent le même nom : seul l'effet (58597) compte
local SACRED_PROC = 58597
local shieldNames, sacredName = {}, nil

-- Le client 3.3.5 ne donne pas le montant d'un bouclier : on le lit dans l'infobulle du buff
-- (« Absorbe 2230 points de dégâts »), avec l'infobulle cachée commune (VP:ScanTip).
local function tipAmount(u, index)
	local tip = VP:ScanTip()
	tip:SetUnitBuff(u, index)
	for l = 2, tip:NumLines() do
		local fs = _G["VuhPlusScanTipTextLeft" .. l]
		local t = fs and fs:GetText()
		local n = t and string.match(t, "(%d+)")
		if n then return tonumber(n) or 0 end
	end
	return 0
end

-- Total des boucliers d'un cadre (indices relevés par UpdateAuras), relu au plus 2 fois par seconde
-- (lecture d'infobulle : l'appel le plus coûteux de l'addon ; un bouclier posé ou retiré est relu tout de suite)
function F:ShieldAmount(b, u)
	local now = GetTime()
	if b.absorbT and now - b.absorbT < 0.5 then return b.absorbV end
	b.absorbT = now
	local total = 0
	for k = 1, b.shieldN do
		local idx = b.shieldIdx[k]
		local name = UnitAura(u, idx, "HELPFUL")
		-- l'indice peut avoir glissé depuis la dernière lecture des buffs : on vérifie le nom
		if name and shieldNames[name] then total = total + tipAmount(u, idx) end
	end
	b.absorbV = total
	return total
end

-- Symboles de raid (1 à 8) : nom et couleur
F.RAID_ICONS = {
	{ "Étoile", 1, 0.9, 0.1 }, { "Cercle", 1, 0.5, 0.1 }, { "Losange", 0.8, 0.3, 1 }, { "Triangle", 0.2, 0.9, 0.2 },
	{ "Lune", 0.75, 0.8, 0.9 }, { "Carré", 0.2, 0.6, 1 }, { "Croix", 1, 0.2, 0.2 }, { "Crâne", 1, 1, 1 },
}

-- Emplacements de HoTs de la classe (créés au premier appel)
function F:HotSlots()
	local db = VP.db
	db.hotSlots = db.hotSlots or {}
	local list = db.hotSlots[VP.class]
	if not list then
		list = {}
		local def = DEFAULT_SLOTS[VP.class] or {}
		for i = 1, F.NUM_SLOTS do
			local e = def[i]
			local c = SLOT_COLORS[i]
			list[i] = {
				spell = e and GetSpellInfo(e[1]) or "",
				-- (« e and e[2] or true » donnait toujours true, même pour un emplacement « pas les miens »)
				own = (e == nil) or (e[2] ~= false),
				others = (e ~= nil) and (e[3] == true),
				color = { c[1], c[2], c[3] },
				pos = DEFAULT_POS[i],
				offX = 0, offY = 0, size = 0,
			}
		end
		db.hotSlots[VP.class] = list
	end
	if F.slotsChecked == list then return list end
	F.slotsChecked = list
	for i = 1, F.NUM_SLOTS do
		local sl = list[i]
		if not sl then
			-- sauvegarde incomplète (ancienne version) : on recrée l'emplacement vide
			local c = SLOT_COLORS[i]
			sl = { spell = "", own = true, others = false, color = { c[1], c[2], c[3] },
				pos = DEFAULT_POS[i], offX = 0, offY = 0, size = 0, fix433 = true }
			list[i] = sl
		end
		if sl then
			if not sl.pos then sl.pos = DEFAULT_POS[i] end
			if sl.offX == nil then sl.offX = 0 end
			-- correctif 4.3.3 : les anciennes versions ajoutaient un décalage caché de -22 %
			-- aux HoTs 4 à 6 (placés au même endroit que 1 à 3) ; on l'efface une seule fois
			if i > 3 and not sl.fix433 then
				if sl.offX == -22 then
					sl.offX = 0
					if sl.pos == ({ "TR", "BR", "R" })[i - 3] then sl.pos = DEFAULT_POS[i] end
				end
				sl.fix433 = true
			end
			if sl.offY == nil then sl.offY = 0 end
			if sl.size == nil then sl.size = 0 end
		end
	end
	return list
end

-- Place un élément (icône ou groupe) à la position choisie
local function place(f, b, key, dx, dy, offKey)
	local p = F.POS[key] or F.POS.C
	dx, dy = dx or 0, dy or 0
	-- décalage X / Y en % de la taille du cadre (comme VuhDo)
	local off = offKey and VP.db.iconOff and VP.db.iconOff[offKey]
	if off then
		dx = dx + (VP.db.width or 80) * (off.x or 0) / 100
		dy = dy + VP.Frames:FrameHeight() * (off.y or 0) / 100
	end
	f:ClearAllPoints()
	f:SetPoint(p[1], p[5] and b or b.hp, p[2], p[3] + dx, p[4] + dy)
end

-- Décalage du i-ième élément d'un groupe selon la direction
local function growOffset(i, size, gap, dir)
	local step = (i - 1) * (size + gap)
	if dir == "LEFT" then return -step, 0
	elseif dir == "UP" then return 0, step
	elseif dir == "DOWN" then return 0, -step end
	return step, 0
end
F.place, F.growOffset = place, growOffset

local CHARGE_IDS = { 974, 33076 } -- Bouclier de terre, Prière de guérison
local chargeNames = {}
local lightwellName   -- Rénovation du Puits de lumière (lu à la connexion)
-- Sort à charges ? (aperçu : seuls ces sorts montrent un compteur de charges)
function F:IsChargeSpell(name) return name and chargeNames[name] or false end
local HEALER_CLASS = { PRIEST = true, PALADIN = true, DRUID = true, SHAMAN = true }
-- classes dont le rôle peut changer avec une aura (forme, présence, Fureur vertueuse, Forme d'ombre)
local HYBRID = { PRIEST = true, PALADIN = true, DRUID = true, DEATHKNIGHT = true }


local LFG_TEX = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local READY_TEX = {
	ready = "Interface\\RaidFrame\\ReadyCheck-Ready",
	notready = "Interface\\RaidFrame\\ReadyCheck-NotReady",
	afk = "Interface\\RaidFrame\\ReadyCheck-NotReady",   -- pas de réponse à la fin de l'appel
	waiting = "Interface\\RaidFrame\\ReadyCheck-Waiting",
}

local function shortNum(v)
	if v >= 10000 then return string.format("%.0fk", v / 1000) end
	if v >= 1000 then return string.format("%.1fk", v / 1000) end
	return tostring(math.floor(v))
end

local function border(parent, size, level)
	local f = CreateFrame("Frame", nil, parent)
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", -1, 1)
	f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 1, -1)
	f:SetBackdrop({ edgeFile = T.TEX, edgeSize = size })
	f:SetFrameLevel(level)
	f:Hide()
	return f
end

-- Petite icône encadrée d'un liseré noir
local function iconFrame(parent, size, level)
	local f = CreateFrame("Frame", nil, parent)
	f:SetWidth(size); f:SetHeight(size)
	f:SetFrameLevel(level)
	T:Backdrop(f, { 0, 0, 0, 1 }, { 0, 0, 0, 1 })
	f.tex = f:CreateTexture(nil, "ARTWORK")
	f.tex:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	f.tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
	f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.count = T:Text(f, 10, nil, "OUTLINE")
	f.count:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -1)
	f:EnableMouse(false)
	f:Hide()
	return f
end

-- Ajoute spirale de durée + texte du temps restant à une icône
local function addTimer(f)
	f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
	f.cd:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	f.cd:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
	f.cd:SetReverse(true)
	local top = CreateFrame("Frame", nil, f)
	top:SetAllPoints(f)
	top:SetFrameLevel(f.cd:GetFrameLevel() + 2)
	f.count:Hide()
	f.count = T:Text(top, 9, nil, "OUTLINE")
	f.count:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -1)
	f.timer = T:Text(top, 9, nil, "OUTLINE")
	f.timer:SetPoint("TOP", f, "TOP", 1, 1)
end

-- Temps restant lisible : 1m, 45, 9, 2.4
local function fmtLeft(left)
	if left >= 60 then return math.floor(left / 60 + 0.5) .. "m" end
	if left >= 10 then return tostring(math.floor(left)) end
	if left >= 3 then return tostring(math.floor(left)) end
	return string.format("%.1f", left)
end
F.fmtLeft = fmtLeft

-- Met à jour les minuteurs (appelé 10 fois par seconde)
function F:UpdateTimers(b)
	local d = VP.db
	local now = GetTime()
	if not b.timed then
		b.timed = {}
		for _, h in ipairs(b.hots) do b.timed[#b.timed + 1] = h end
		b.timed[#b.timed + 1] = b.bossFrame
		b.timed[#b.timed + 1] = b.dIcon
		b.timed[#b.timed + 1] = b.defIcon
		b.timed[#b.timed + 1] = b.healRed
	end
	local warn = d.hotWarnSecs or 3
	local wc = d.colors.hotWarn
	if b.nHotBars and b.nHotBars > 0 then
		local w = b.hp:GetWidth()
		for k = 1, b.nHotBars do
			local hb = b.hotBars[k]
			if hb.exp then
				local left = hb.exp - now
				if left > 0 then
					hb:SetWidth(math.max(1, w * math.min(1, left / hb.dur)))
					if left < warn then hb:SetVertexColor(wc[1], wc[2], wc[3], 1) end
				else
					hb:Hide()
				end
			end
		end
	end
	for _, f in ipairs(b.timed) do
		if f:IsShown() and f.exp and f.exp > 0 and d.hotTimer and f.countdown ~= "OFF" then
			local left = f.exp - now
			-- clé d'affichage : on ne réécrit le texte que s'il change (moins d'allocations)
			local tenth = (f.countdown == "TENTH" and left < 10) or left < 3
			local key = left <= 0 and -1 or (tenth and math.floor(left * 10) or math.floor(left))
			if key ~= f.tKey then
				f.tKey = key
				if left <= 0 then f.timer:SetText("")
				elseif tenth then f.timer:SetText(string.format("%.1f", left))
				else f.timer:SetText(fmtLeft(left)) end
				local state = (left < warn) and 2 or ((left < warn * 2) and 1 or 0)
				if state ~= f.tState then
					f.tState = state
					if state == 2 then f.timer:SetTextColor(wc[1], wc[2], wc[3])
					elseif state == 1 then f.timer:SetTextColor(1, 0.85, 0.2)
					else f.timer:SetTextColor(1, 1, 1) end
				end
			end
			if left > 0 and left < warn and d.hotWarnFlash and f.isHot then
				f:SetAlpha(0.45 + 0.55 * math.abs(math.sin(now * 6)))
				f.flashing = true
			elseif f.flashing then
				f.flashing = nil
				f:SetAlpha(1)
			end
		elseif f.timer and f.tKey ~= "off" then
			f.tKey = "off"
			f.timer:SetText("")
			if f.flashing then f.flashing = nil; f:SetAlpha(1) end
		end
	end
end

-- Hauteur totale d'un cadre = barre de vie + barre de mana + bordures
function F:FrameHeight()
	local d = VP.db
	return d.hpHeight + 2 + (d.showMana and (d.manaHeight + 1) or 0)
end

-- Dégâts brutaux (module Spikes)
function F:Spike(b)
	local c = VP.db.colors.spike or { 1, 0.1, 0.1 }
	local f = b.spikeBorder
	f:SetBackdropBorderColor(c[1], c[2], c[3], 1)
	f.untilT = GetTime() + 1.5
	f:SetAlpha(1)
	f:Show()
end

function F:Kind(b)
	local p = b:GetParent()
	return (p and p.vpKind) or b.vpKind or "main"
end

-- Création ------------------------------------------------------------------------
function VuhPlus_InitButton(b)
	F:SetupButton(b)
end

function F:SetupButton(b, preview)
	if b.vpInit then return end
	b.vpInit = true
	b.vpPreview = preview

	T:Backdrop(b, { 0.04, 0.04, 0.05, 0.92 }, { 0, 0, 0, 1 })

	local hp = CreateFrame("StatusBar", nil, b)
	hp:SetMinMaxValues(0, 1)
	hp.bg = hp:CreateTexture(nil, "BACKGROUND")
	hp.bg:SetAllPoints(hp)
	b.hp = hp
	b.gloss = T:Gloss(hp)

	-- soins entrants
	local inc = hp:CreateTexture(nil, "ARTWORK")
	inc:SetTexture(T.TEX)
	inc:SetVertexColor(0.3, 1, 0.45, 0.45)
	inc:SetPoint("TOPLEFT", hp:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
	inc:SetPoint("BOTTOMLEFT", hp:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
	inc:SetWidth(1)
	inc:Hide()
	b.inc = inc

	-- boucliers : fine barre au bas de la barre de vie (visible même en pleine vie, comme VuhDo)
	local ab = hp:CreateTexture(nil, "OVERLAY")
	ab:SetTexture(T.TEX)
	ab:SetPoint("BOTTOMLEFT", hp, "BOTTOMLEFT", 0, 0)
	ab:SetHeight(3)
	ab:SetWidth(1)
	ab:Hide()
	b.absorb = ab

	-- teinte : soin de zone / dispel
	local tint = hp:CreateTexture(nil, "OVERLAY")
	tint:SetAllPoints(hp)
	tint:SetTexture(T.TEX)
	tint:Hide()
	b.tint = tint

	-- surbrillance du cadre survolé (on voit tout de suite sur qui part le clic)
	local hov = hp:CreateTexture(nil, "OVERLAY")
	hov:SetAllPoints(hp)
	hov:SetTexture(T.TEX)
	hov:SetVertexColor(1, 1, 1, 0.12)
	hov:Hide()
	b.hoverTex = hov

	local mp = CreateFrame("StatusBar", nil, b)
	mp:SetStatusBarTexture(T.TEX)
	mp:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 1, 1)
	mp:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	mp:SetHeight(4)
	mp.bg = mp:CreateTexture(nil, "BACKGROUND")
	mp.bg:SetAllPoints(mp)
	mp.bg:SetTexture(T.TEX)
	mp.bg:SetVertexColor(0, 0, 0, 0.6)
	b.mp = mp

	local ov = CreateFrame("Frame", nil, b)
	ov:SetAllPoints(b)
	ov:SetFrameLevel(hp:GetFrameLevel() + 3)
	b.ov = ov
	local lvl = ov:GetFrameLevel()

	local role = ov:CreateTexture(nil, "OVERLAY")
	role:SetWidth(11); role:SetHeight(11)
	role:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
	role:Hide()
	b.role = role

	-- couronne du chef / icône d'assistant (placée par le gestionnaire de placement)
	local leader = ov:CreateTexture(nil, "OVERLAY")
	leader:SetWidth(10); leader:SetHeight(10)
	leader:SetPoint("TOPLEFT", b, "TOPLEFT", 14, -3)
	leader:Hide()
	b.leader = leader

	b.name = T:Text(ov, 11)
	b.name:SetJustifyH("LEFT")
	b.name:SetHeight(13)
	-- surplus de soin (soins entrants au-delà de la vie manquante)
	b.overheal = T:Text(ov, 11, { 0.4, 1, 0.5 }, "OUTLINE")
	b.info = T:Text(ov, 10)
	b.info:SetPoint("BOTTOMLEFT", hp, "BOTTOMLEFT", 3, 2)
	b.info:SetJustifyH("LEFT")

	-- dispel : icône + clic à utiliser
	b.dIcon = iconFrame(ov, 14, lvl + 2)
	addTimer(b.dIcon)
	b.dIcon:SetPoint("BOTTOMRIGHT", hp, "BOTTOMRIGHT", -2, 2)
	b.dHint = T:Text(ov, 10, { 1, 0.9, 0.3 }, "OUTLINE")
	b.dHint:SetPoint("RIGHT", b.dIcon, "LEFT", -2, 0)

	-- affaiblissement de boss
	local bf = iconFrame(ov, 18, lvl + 3)
	bf:SetPoint("CENTER", hp, "CENTER", 0, -1)
	bf:SetBackdropBorderColor(1, 0.25, 0.25, 1)
	addTimer(bf)
	-- débuff critique (priorité 8 et plus) : l'icône clignote
	bf:SetScript("OnUpdate", function(self)
		if self.pulse then self:SetAlpha(0.45 + 0.55 * math.abs(math.sin(GetTime() * 5))) end
	end)
	b.bossFrame = bf

	b.others = {}
	for i = 1, 3 do
		local o = iconFrame(ov, 11, lvl + 2)
		if i == 1 then o:SetPoint("LEFT", b, "LEFT", 3, -1) else o:SetPoint("LEFT", b.others[i - 1], "RIGHT", 1, 0) end
		b.others[i] = o
	end

	b.hots = {}
	for i = 1, F.NUM_SLOTS do
		local h = iconFrame(ov, 14, lvl + 2)
		addTimer(h)
		h.isHot = true
		b.hots[i] = h
	end

	local aggro = T:Tex(ov, "OVERLAY", 1, 0.15, 0.15, 1)
	aggro:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	aggro:SetPoint("TOPRIGHT", b, "TOPRIGHT", -1, -1)
	aggro:SetHeight(2)
	aggro:Hide()
	b.aggro = aggro

	local ri = ov:CreateTexture(nil, "OVERLAY")
	ri:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	ri:SetWidth(12); ri:SetHeight(12)
	ri:SetPoint("TOP", b, "TOP", 0, 5)
	ri:Hide()
	b.raidIcon = ri

	-- flèche de direction vers un joueur hors de portée de soin
	local arrow = ov:CreateTexture(nil, "OVERLAY")
	arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
	arrow:SetWidth(16); arrow:SetHeight(16)
	arrow:Hide()
	b.arrow = arrow

	-- défensif actif, soins réduits, pierre d'âme
	b.defIcon = iconFrame(ov, 16, lvl + 3)
	addTimer(b.defIcon)
	b.defIcon:SetBackdropBorderColor(0.3, 0.8, 1, 1)
	b.healRed = iconFrame(ov, 16, lvl + 3)
	addTimer(b.healRed)
	b.healRed:SetBackdropBorderColor(1, 0.2, 0.2, 1)
	b.soulIcon = iconFrame(ov, 16, lvl + 3)
	b.soulIcon:SetBackdropBorderColor(0.7, 0.3, 1, 1)

	-- rappel de soigneur (buff manquant sur vous / votre tank)
	b.remIcon = iconFrame(ov, 16, lvl + 4)
	b.remIcon:SetBackdropBorderColor(1, 0.8, 0.1, 1)

	local mb = T:Tex(ov, "OVERLAY", 1, 0.85, 0.1, 1)
	mb:SetWidth(5); mb:SetHeight(5)
	mb:SetPoint("TOPRIGHT", b, "TOPRIGHT", -3, -3)
	mb:Hide()
	b.missBuff = mb

	local rc = ov:CreateTexture(nil, "OVERLAY")
	rc:SetWidth(18); rc:SetHeight(18)
	rc:SetPoint("CENTER", b, "CENTER")
	rc:Hide()
	b.ready = rc

	b.emergBorder = border(b, 2, lvl + 4)
	b.emergBorder:SetBackdropBorderColor(1, 0.55, 0.1, 1)
	b.dispelBorder = border(b, 3, lvl + 5)
	-- clignotement de la bordure (ne tourne que quand la bordure est visible)
	b.dispelBorder:SetScript("OnUpdate", function(self)
		if self.pulse then self:SetAlpha(0.35 + 0.65 * math.abs(math.sin(GetTime() * 4))) end
	end)
	b.markBorder = border(b, 2, lvl + 3)
	-- mes cibles assignées (onglet Assignations)
	b.assignBorder = border(b, 1, lvl + 2)
	-- joueur que je suis en train de soigner (incantation en cours)
	b.castBorder = border(b, 2, lvl + 6)
	-- dégâts brutaux : bordure rouge épaisse qui s'éteint en 1,5 s
	b.spikeBorder = border(b, 3, lvl + 7)
	b.spikeBorder:SetScript("OnUpdate", function(self)
		local left = (self.untilT or 0) - GetTime()
		if left <= 0 then self:Hide() return end
		self:SetAlpha(math.min(1, left / 1.5 * 1.3))
	end)
	-- barres de durée des HoTs (en haut de la barre de vie, tanks par défaut)
	b.hotBars = {}
	for i = 1, 3 do
		local hb = hp:CreateTexture(nil, "OVERLAY")
		hb:SetTexture(T.TEX)
		hb:SetHeight(2); hb:SetWidth(1)
		hb:Hide()
		b.hotBars[i] = hb
	end
	b.bossTargetBorder = border(b, 2, lvl + 4)
	b.targetBorder = border(b, 1, lvl + 6)
	b.targetBorder:SetBackdropBorderColor(1, 1, 1, 0.9)

	self:LayoutButton(b)
	if preview then return end

	b.menu = function(self) F:ShowMenu(self) end
	b:HookScript("OnAttributeChanged", function(self, attr, value)
		if attr == "unit" then
			self.unit = value
			-- autre joueur derrière ce cadre : ses alertes (son du dispel, du débuff de boss) repartent de zéro
			self.alerted, self.lastBoss = nil, nil
			-- nouveau joueur : sa vie s'affiche d'un coup (pas d'animation depuis la vie du précédent)
			self.hp.vpVal = nil
			F.anim[self] = nil
			F.mapDirty = true
			F:FullUpdate(self)
		end
	end)
	b:HookScript("OnShow", function(self)
		self.unit = self:GetAttribute("unit")
		F:FullUpdate(self)
	end)
	b:HookScript("OnEnter", function(self)
		self.hover = true
		local d = VP.db
		if d.hoverHighlight then self.hoverTex:Show() end
		if d.tooltip and (d.tooltipInCombat or not InCombatLockdown()) and self.unit and UnitExists(self.unit) then
			GameTooltip_SetDefaultAnchor(GameTooltip, self)
			GameTooltip:SetUnit(self.unit)
			-- débuff de boss sur ce joueur : dit clairement s'il y a quelque chose à faire
			if self.bossName then
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine("Débuff de boss : " .. self.bossName, 1, 0.75, 0.3)
				if self.bossCan then
					GameTooltip:AddLine("Vous pouvez le dissiper.", 0.4, 1, 0.5)
				else
					GameTooltip:AddLine("Information : vous ne pouvez pas le dissiper"
						.. (self.bossCrit and " (critique : soignez ce joueur)." or "."), 0.7, 0.7, 0.75)
				end
			end
			if d.tooltipBinds then
				local list = VP.Clicks:Summary()
				if #list > 0 then
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine("Clics VuhPlus", T:Accent())
					for _, e in ipairs(list) do
						GameTooltip:AddDoubleLine(e[1], e[2], 0.7, 0.7, 0.75, 1, 1, 1)
					end
				end
			end
			GameTooltip:Show()
		end
	end)
	b:HookScript("OnLeave", function(self) self.hover = nil; self.hoverTex:Hide(); GameTooltip:Hide() end)
	-- un cadre caché sous la souris (joueur parti, groupe réorganisé) ne reçoit pas toujours OnLeave
	b:HookScript("OnHide", function(self) self.hover = nil; self.hoverTex:Hide() end)

	table.insert(self.buttons, b)
	self:SizeButton(b)
	if VP.Clicks and VP.Clicks.Wrap then VP.Clicks:Wrap(b) end
	self:FullUpdate(b)
end

-- Textes d'un HoT (temps restant, charges) proportionnels à SA taille (taille individuelle possible)
function F:HotCountSize(h, isCharge)
	local sz = h:GetHeight() or 14
	if isCharge then return math.max(10, math.floor(sz * 0.8)) end
	return math.max(9, math.floor(sz * 0.5))
end
function F:HotFonts(h)
	local sz = math.floor((h:GetHeight() or 14) + 0.5)
	if h.fontSz == sz then return end
	h.fontSz = sz
	local flag = VP.db.hotTextOutline and "OUTLINE" or nil
	T:SetFont(h.timer, math.max(9, math.floor(sz * 0.5)), flag)
	local cfs = self:HotCountSize(h, h.chargeLayout)
	h.countFont = cfs
	T:SetFont(h.count, cfs, (h.chargeLayout or VP.db.hotTextOutline) and "OUTLINE" or nil)
end

-- Taille d'un cadre selon les réglages (largeur, hauteur vie + mana).
-- Les cadres sont créés par le jeu APRÈS le chargement de l'addon (à la connexion, quand le groupe
-- arrive) : sans ça ils gardaient la taille du modèle (80 x 38) jusqu'à la prochaine modification.
function F:SizeButton(b)
	local d = VP.db
	if not d then return end
	if InCombatLockdown() then
		-- en combat : l'en-tête sécurisé l'a déjà dimensionné (initialConfigFunction) ; on revérifie après
		VP:RunOOC("sizeAll", function() F:SizeAll() end)
		return
	end
	if self:Kind(b) == "pets" and VP.Panels and VP.Panels.PetSize then
		local w, h = VP.Panels:PetSize()
		b:SetWidth(w); b:SetHeight(h)
	else
		b:SetWidth(d.width)
		b:SetHeight(self:FrameHeight())
	end
end

function F:SizeAll()
	for _, b in ipairs(self.buttons) do self:SizeButton(b) end
end

-- Style dépendant des options (police, texture, ressource)
function F:LayoutButton(b)
	local d = VP.db
	if not d then return end
	local tex = d.barStyle == "CLASSIC" and BLIZZ_TEX or T.TEX
	tex = T:BarTexture(d.barTexture) or tex
	b.hp:SetStatusBarTexture(tex)
	b.hp.bg:SetTexture(tex)
	b.mp:SetStatusBarTexture(tex)
	local hbh = d.hotBarHeight or 2
	for i, hb in ipairs(b.hotBars) do
		hb:SetHeight(hbh)
		hb:ClearAllPoints()
		hb:SetPoint("TOPLEFT", b.hp, "TOPLEFT", 0, -2 - (i - 1) * (hbh + 1))
	end
	b.cR = nil   -- la couleur sera réappliquée (le changement de texture peut la remettre à zéro)
	b.hp:ClearAllPoints()
	b.hp:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	b.mp:SetHeight(d.manaHeight)
	if d.showMana then
		b.hp:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, d.manaHeight + 2)
	else
		b.hp:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
		b.mp:Hide()
	end
	if d.gloss and d.barStyle ~= "CLASSIC" then b.gloss:Show() else b.gloss:Hide() end
	local bs = d.bossSize or 18
	b.bossFrame:SetWidth(bs); b.bossFrame:SetHeight(bs)
	local ds = d.dispelSize or 14
	b.dIcon:SetWidth(ds); b.dIcon:SetHeight(ds)
	local hs = d.hotSize or 14
	local tfs = math.max(9, math.floor(hs * 0.5))
	local flag = d.hotTextOutline and "OUTLINE" or nil
	for _, h in ipairs(b.hots) do
		h:SetWidth(hs); h:SetHeight(hs)
		T:SetFont(h.timer, tfs, flag)
		T:SetFont(h.count, tfs, flag)
		h.countFont, h.chargeLayout, h.fontSz = nil, nil, nil   -- la mise en forme « charges » sera refaite
		h.count:ClearAllPoints()
		h.count:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 2, -1)
	end
	local bfs = math.max(10, math.floor((d.bossSize or 18) * 0.45))
	T:SetFont(b.bossFrame.timer, bfs, "OUTLINE")
	T:SetFont(b.bossFrame.count, bfs, "OUTLINE")
	local ip = d.iconPos
	place(b.overheal, b, ip.overheal or "L", 0, 0, "overheal")
	local oh = d.iconOff and d.iconOff.overheal
	T:SetFont(b.overheal, (oh and oh.size and oh.size > 0) and oh.size or (d.overhealSize or 11), "OUTLINE", nil, T:FontPath(d.font))
	local ris = d.raidIconSize or 16
	b.raidIcon:SetWidth(ris); b.raidIcon:SetHeight(ris)
	b.raidIcon:SetAlpha(d.raidIconAlpha or 1)
	local is = d.indSize or 16
	for _, f in ipairs({ b.defIcon, b.healRed, b.soulIcon }) do
		f:SetWidth(is); f:SetHeight(is)
		T:SetFont(f.count, math.max(9, math.floor(is * 0.5)), "OUTLINE")
		if f.timer then T:SetFont(f.timer, math.max(9, math.floor(is * 0.5)), "OUTLINE") end
	end
	local rs = d.remindSize or 18
	b.remIcon:SetWidth(rs); b.remIcon:SetHeight(rs)
	-- tailles de référence (le gestionnaire de placement peut les réduire s'il manque de place)
	local as = d.arrowSize or 16
	b.arrow:SetWidth(as); b.arrow:SetHeight(as)
	-- tailles de référence tirées des réglages (jamais de la taille actuelle, qui peut avoir été modifiée)
	local function base(f, w, h) f.baseW, f.baseH = w, h or w; f:SetWidth(w); f:SetHeight(h or w) end
	base(b.role, 11)
	base(b.leader, 10)
	base(b.raidIcon, ris)
	base(b.dIcon, ds)
	base(b.bossFrame, bs)
	base(b.remIcon, rs)
	base(b.defIcon, is); base(b.healRed, is); base(b.soulIcon, is)
	base(b.missBuff, 5)
	base(b.arrow, as)
	for _, f in ipairs(b.hots) do f.baseW, f.baseH = hs, hs; f:SetWidth(hs); f:SetHeight(hs) end
	for _, f in ipairs(b.others) do f.baseW, f.baseH = 11, 11; f:SetWidth(11); f:SetHeight(11) end
	b.arrMask = nil
	local fs = d.fontSize or 11
	local font = T:FontPath(d.font)
	T:SetFont(b.name, fs, nil, nil, font)
	T:SetFont(b.info, fs - 1, nil, nil, font)
	b.name:SetHeight(fs + 2)
end

-- Cadres de familiers (moins hauts) : nom à gauche et vie perdue à droite, sur la même ligne,
-- centrés verticalement ; sinon le texte de vie (en bas) recouvrait le nom (en haut)
function F:PetTexts(b)
	if self:Kind(b) ~= "pets" and not (b.unit and PET_OWNER_OF[b.unit]) then
		b.info:SetJustifyH("LEFT")
		return
	end
	b.info:ClearAllPoints()
	b.info:SetPoint("RIGHT", b.hp, "RIGHT", -3, 0)
	b.info:SetJustifyH("RIGHT")
	b.name:ClearAllPoints()
	b.name:SetPoint("LEFT", b.hp, "LEFT", 3, 0)
	b.name:SetPoint("RIGHT", b.info, "LEFT", -3, 0)
end

-- Gestionnaire de placement --------------------------------------------------------
-- Toutes les icônes d'une même position forment une « zone » : elles s'alignent sans se
-- chevaucher, se réduisent si la place manque, et le nom / le texte de vie se décalent.
local AXIS = {
	TL = "H", BL = "H", TR = "H", BR = "H",
	T = "HC", B = "HC", C = "HC", OT = "HC", OB = "HC", TE = "HC",
	L = "VC", R = "VC", LE = "VC", RE = "VC", OL = "VC", OR = "VC",
}
local LEFTWARD = { TR = true, BR = true }
local LEFT_SIDE = { TL = true, L = true, BL = true, LE = true, OL = true }
local zones, zoneOrder = {}, {}

local function vis(f, bit) return f:IsShown() and bit or 0 end
function F:Arrange(b, force)
	local d = VP.db
	if not d or not b.hots then return end
	local ip = d.iconPos
	-- empreinte des éléments visibles : on ne replace que si elle change
	local mask = vis(b.role, 1) + vis(b.raidIcon, 2) + vis(b.dIcon, 4) + vis(b.bossFrame, 8) + vis(b.remIcon, 16)
		+ vis(b.defIcon, 32) + vis(b.healRed, 64) + vis(b.soulIcon, 128) + vis(b.missBuff, 256) + vis(b.arrow, 262144)
		+ vis(b.leader, 524288)
	for i = 1, 3 do mask = mask + vis(b.others[i], 512 * 2 ^ (i - 1)) end
	for i = 1, F.NUM_SLOTS do mask = mask + vis(b.hots[i], 4096 * 2 ^ (i - 1)) end
	if not force and b.arrMask == mask then return end
	b.arrMask = mask
	if d.iconLayout ~= "AUTO" then return self:ArrangeFree(b) end

	for _, z in pairs(zones) do wipe(z) end
	wipe(zoneOrder)
	local function add(f, pos)
		if not pos then return end
		local z = zones[pos]
		if not z then z = {}; zones[pos] = z end
		if #z == 0 then zoneOrder[#zoneOrder + 1] = pos end
		z[#z + 1] = f
	end
	local slots = self:HotSlots()
	if b.role:IsShown() then add(b.role, ip.role) end
	if b.leader:IsShown() then add(b.leader, ip.leader or "TL") end
	if b.raidIcon:IsShown() then add(b.raidIcon, ip.raid) end
	if b.dIcon:IsShown() then add(b.dIcon, ip.dispel) end
	if b.bossFrame:IsShown() then add(b.bossFrame, ip.boss) end
	if b.remIcon:IsShown() then add(b.remIcon, ip.remind) end
	if b.defIcon:IsShown() then add(b.defIcon, ip.defensive) end
	if b.healRed:IsShown() then add(b.healRed, ip.healred) end
	if b.soulIcon:IsShown() then add(b.soulIcon, ip.soul) end
	for i = 1, F.NUM_SLOTS do
		local h = b.hots[i]
		local sl = slots[i]
		-- « positions fixes » : un emplacement configuré garde sa place même vide
		if h:IsShown() or (d.hotFixed and sl and sl.spell and sl.spell ~= "") then add(h, sl and sl.pos or ip.hots) end
	end
	if b.missBuff:IsShown() then add(b.missBuff, ip.missing) end
	if b.arrow:IsShown() then add(b.arrow, ip.arrow or "C") end
	for i = 1, 3 do if b.others[i]:IsShown() then add(b.others[i], ip.others) end end

	local W = d.width
	local barH = d.hpHeight
	local FH = self:FrameHeight()
	local gap = d.hotGap or 1
	local widths = {}
	for _, pos in ipairs(zoneOrder) do
		local list = zones[pos]
		local axis = AXIS[pos] or "HC"
		-- place disponible pour cette zone
		local cap
		if axis == "VC" then
			cap = (pos == "L" or pos == "R") and (barH - 2) or FH
		elseif pos == "OT" or pos == "OB" or pos == "TE" then
			cap = W
		elseif axis == "HC" then
			cap = W * 0.7
		else
			cap = W * 0.48
		end
		local total = 0
		for i, f in ipairs(list) do
			total = total + ((axis == "VC") and (f.baseH or f:GetHeight()) or (f.baseW or f:GetWidth()))
			if i > 1 then total = total + gap end
		end
		local scale = (total > cap and total > 0) and (cap / total) or 1
		-- les icônes dans la barre ne dépassent jamais sa hauteur
		local inside = not (F.POS[pos] and F.POS[pos][5])
		local maxSide = inside and (barH - 2) or nil
		total = 0
		for i, f in ipairs(list) do
			local w, h = (f.baseW or f:GetWidth()) * scale, (f.baseH or f:GetHeight()) * scale
			if maxSide and h > maxSide then
				local k = maxSide / h
				w, h = w * k, h * k
			end
			f:SetWidth(w); f:SetHeight(h)
			f.arrW, f.arrH = w, h
			total = total + ((axis == "VC") and h or w) + (i > 1 and gap or 0)
		end
		-- sens imposé pour les zones de HoTs (sinon automatique)
		local hasHot = false
		for _, f in ipairs(list) do if f.isHot then hasHot = true end end
		local forced = hasHot and ip.hotGrow and ip.hotGrow ~= "AUTO" and ip.hotGrow
		local p = F.POS[pos] or F.POS.C
		local rel = p[5] and b or b.hp
		local cum = 0
		for i, f in ipairs(list) do
			local w, h = f.arrW, f.arrH
			local x, y
			if forced then
				x, y = growOffset(i, (forced == "UP" or forced == "DOWN") and h or w, gap, forced)
			elseif axis == "H" then
				x, y = (LEFTWARD[pos] and -cum or cum), 0
			elseif axis == "HC" then
				x, y = -total / 2 + cum + w / 2, 0
			else
				x, y = 0, total / 2 - cum - h / 2
			end
			local off = (f == b.raidIcon) and d.iconOff and d.iconOff.raid
			if off then
				x = x + W * (off.x or 0) / 100
				y = y + FH * (off.y or 0) / 100
			end
			f:ClearAllPoints()
			f:SetPoint(p[1], rel, p[2], p[3] + x, p[4] + y)
			cum = cum + ((axis == "VC") and h or w) + gap
		end
		widths[pos] = (axis == "H") and total or 0
	end

	-- nom : entre les icônes du haut gauche et du haut droite
	b.name:ClearAllPoints()
	local lw = widths.TL and (widths.TL + 3) or 0
	local rw = widths.TR and (widths.TR + 3) or 0
	b.name:SetPoint("TOPLEFT", b, "TOPLEFT", 4 + lw, -3)
	b.name:SetPoint("TOPRIGHT", b, "TOPRIGHT", -4 - rw, -3)
	-- texte de vie : après les icônes du bas gauche
	b.info:ClearAllPoints()
	b.info:SetPoint("BOTTOMLEFT", b.hp, "BOTTOMLEFT", 3 + (widths.BL and (widths.BL + 3) or 0), 2)
	self:PetTexts(b)
	-- rappel de dispel : du côté libre de sa zone
	local dz = zones[ip.dispel]
	local edge = (dz and #dz > 0) and dz[#dz] or b.dIcon
	b.dHint:ClearAllPoints()
	if LEFT_SIDE[ip.dispel] then
		b.dHint:SetPoint("LEFT", edge, "RIGHT", 2, 0)
	elseif AXIS[ip.dispel] == "VC" or LEFTWARD[ip.dispel] then
		b.dHint:SetPoint("RIGHT", edge, "LEFT", -2, 0)
	else
		b.dHint:SetPoint("TOP", b.dIcon, "BOTTOM", 0, -1)
	end
end

-- Placement individuel : chaque icône exactement à SA position, avec SON décalage et SA taille
local FREE_KEYS = {
	{ "role", "role" }, { "leader", "leader" }, { "raidIcon", "raid" }, { "dIcon", "dispel" }, { "bossFrame", "boss" }, { "remIcon", "remind" },
	{ "defIcon", "defensive" }, { "healRed", "healred" }, { "soulIcon", "soul" }, { "missBuff", "missing" }, { "arrow", "arrow" },
}
-- point d'ancrage -> fraction (x, y) avec y vers le bas
local ANCH = {
	TOPLEFT = { 0, 0 }, TOP = { 0.5, 0 }, TOPRIGHT = { 1, 0 },
	LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 1 }, BOTTOM = { 0.5, 1 }, BOTTOMRIGHT = { 1, 1 },
}
local placed, placedN = {}, 0
local SIGN0, SIGNS = { 1 }, { 1, -1 }
local function overlaps(l, t, r, btm)
	for i = 1, placedN do
		local q = placed[i]
		if l < q[3] - 0.5 and r > q[1] + 0.5 and t < q[4] - 0.5 and btm > q[2] + 0.5 then return true end
	end
	return false
end
local function remember(l, t, r, btm)
	placedN = placedN + 1
	local q = placed[placedN]
	if not q then q = {}; placed[placedN] = q end
	q[1], q[2], q[3], q[4] = l, t, r, btm
end

-- (diagnostic) rectangles posés au dernier placement
function F:PlacedRects() return placed, placedN end

function F:ArrangeFree(b)
	local d = VP.db
	local ip = d.iconPos
	local W, FH = d.width, self:FrameHeight()
	local barH = d.hpHeight
	local avoid = d.avoidOverlap ~= false
	placedN = 0
	local function put(f, pos, off, extraX, extraY)
		local base = f.baseW or f:GetWidth()
		local size = (off and off.size and off.size > 0) and off.size or base
		local k = size / (base > 0 and base or 1)
		local w, h = size, (f.baseH or f:GetHeight()) * k
		f:SetWidth(w); f:SetHeight(h)
		local x = (off and off.x or 0) * W / 100 + (extraX or 0)
		local y = (off and off.y or 0) * FH / 100 + (extraY or 0)
		local p = F.POS[pos] or F.POS.C
		local outside = p[5]
		-- rectangle de l'icône dans le cadre (y vers le bas)
		local rl, rt, rr, rb
		if outside then rl, rt, rr, rb = 0, 0, W, FH else rl, rt, rr, rb = 1, 1, W - 1, 1 + barH end
		local ra, ia = ANCH[p[2]] or ANCH.CENTER, ANCH[p[1]] or ANCH.CENTER
		local px = rl + ra[1] * (rr - rl) + p[3] + x
		local py = rt + ra[2] * (rb - rt) - (p[4] + y)
		local l, t = px - ia[1] * w, py - ia[2] * h
		-- anti-chevauchement : si la place est prise, on décale l'icône vers l'intérieur du cadre
		if avoid and overlaps(l, t, l + w, t + h) then
			-- cherche la place libre la plus proche (d'abord vers l'intérieur, puis en hauteur)
			local dir = (l + w / 2 > W / 2) and -1 or 1
			local sx, sy = w + 1, h + 1
			local bestDx, bestDy, bestD
			for m = 0, 2 do
				for _, vs in ipairs(m == 0 and SIGN0 or SIGNS) do
					local dy = vs * m * sy
					for n = 0, 6 do
						for _, hs in ipairs(n == 0 and SIGN0 or SIGNS) do
							local dx = hs * dir * n * sx
							local dist = math.abs(dx) + math.abs(dy) * 1.5 + (hs < 0 and 0.5 or 0)
							if not bestD or dist < bestD then
								local nl, nt = l + dx, t + dy
								-- dans la barre de vie : on reste dans la barre (pas sur la barre de mana)
								local inBounds = outside or (nl >= 0 and nl + w <= W and nt >= 1 and nt + h <= 1 + barH)
								if inBounds and not overlaps(nl, nt, nl + w, nt + h) then
									bestDx, bestDy, bestD = dx, dy, dist
								end
							end
						end
					end
				end
			end
			if bestD then
				x = x + bestDx; y = y - bestDy
				l = l + bestDx; t = t + bestDy
			end
		end
		remember(l, t, l + w, t + h)
		f:ClearAllPoints()
		f:SetPoint(p[1], outside and b or b.hp, p[2], p[3] + x, p[4] + y)
	end
	-- ordre de priorité : les premiers gardent toujours leur place exacte
	local function free(key, offKey)
		local f = b[key]
		if f and f:IsShown() then put(f, ip[offKey] or "C", d.iconOff[offKey]) end
	end
	free("bossFrame", "boss")
	free("dIcon", "dispel")
	-- HoTs : chaque emplacement indépendant
	local slots = self:HotSlots()
	for i = 1, F.NUM_SLOTS do
		local h, sl = b.hots[i], slots[i]
		if h:IsShown() and sl then
			local o = h.vpOff
			if not o then o = {}; h.vpOff = o end
			o.x, o.y, o.size = sl.offX or 0, sl.offY or 0, sl.size or 0
			put(h, sl.pos or ip.hots, o)
			self:HotFonts(h)
		end
	end
	for _, e in ipairs(FREE_KEYS) do
		if e[1] ~= "bossFrame" and e[1] ~= "dIcon" then free(e[1], e[2]) end
	end
	-- autres débuffs : une petite rangée à leur position
	local oo = d.iconOff.others
	local osz = (oo and oo.size and oo.size > 0) and oo.size or 11
	for i, o in ipairs(b.others) do
		if o:IsShown() then
			o.baseW, o.baseH = osz, osz
			local dx, dy = growOffset(i, osz, 1, ip.othersGrow)
			put(o, ip.others, oo, dx, dy)
		end
	end
	-- nom et texte de vie : décalés si le rôle et / ou la couronne sont en haut à gauche
	b.name:ClearAllPoints()
	local lw = (b.role:IsShown() and ip.role == "TL") and (b.role:GetWidth() + 3) or 0
	if b.leader:IsShown() and (ip.leader or "TL") == "TL" then lw = lw + b.leader:GetWidth() + 2 end
	b.name:SetPoint("TOPLEFT", b, "TOPLEFT", 4 + lw, -3)
	b.name:SetPoint("TOPRIGHT", b, "TOPRIGHT", -4, -3)
	b.info:ClearAllPoints()
	b.info:SetPoint("BOTTOMLEFT", b.hp, "BOTTOMLEFT", 3, 2)
	self:PetTexts(b)
	b.dHint:ClearAllPoints()
	if LEFT_SIDE[ip.dispel] then b.dHint:SetPoint("LEFT", b.dIcon, "RIGHT", 2, 0)
	else b.dHint:SetPoint("RIGHT", b.dIcon, "LEFT", -2, 0) end
end

-- Menu contextuel Blizzard --------------------------------------------------------
local dropdown
function F:ShowMenu(b)
	local u = b.unit
	if not u or not UnitExists(u) then return end
	if not dropdown then
		dropdown = CreateFrame("Frame", "VuhPlusUnitDropDown", UIParent, "UIDropDownMenuTemplate")
		UIDropDownMenu_Initialize(dropdown, function(self)
			local unit = self.vpUnit
			if not unit then return end
			local which, id
			if UnitIsUnit(unit, "player") then
				which = "SELF"
			elseif UnitInRaid(unit) then
				which = "RAID_PLAYER"
				id = UnitInRaid(unit) + 1
			elseif UnitInParty(unit) then
				which = "PARTY"
			else
				which = UnitIsPlayer(unit) and "PLAYER" or "TARGET"
			end
			-- copie du menu Blizzard SANS « Définir la focalisation » : depuis un addon, cette entrée
			-- est bloquée (« action réservée à l'interface Blizzard ») et salit ensuite les menus Blizzard
			local key = "VUHPLUS_" .. which
			if UnitPopupMenus and UnitPopupMenus[which] and not UnitPopupMenus[key] then
				local t = {}
				for _, e in ipairs(UnitPopupMenus[which]) do
					if e ~= "SET_FOCUS" and e ~= "CLEAR_FOCUS" and e ~= "LARGE_FOCUS" and e ~= "MOVE_FOCUS_FRAME" then t[#t + 1] = e end
				end
				UnitPopupMenus[key] = t
			end
			UnitPopup_ShowMenu(self, UnitPopupMenus and UnitPopupMenus[key] and key or which, unit, UnitName(unit), id)
		end, "MENU")
	end
	dropdown.vpUnit = u
	dropdown.unit = u
	ToggleDropDownMenu(1, nil, dropdown, "cursor", 0, 0)
end

-- Peinture (utilisée par le jeu ET par l'aperçu) ----------------------------------
-- s = { name, class, isPlayer, friendly, hp, maxhp, status, alive, incoming, ptype, power, powerMax,
--       aggro, isTarget, raidIcon, ready, role(tex,l,r,t,b), lowMana, emergency, aoe }
local function classRGB(class)
	return VP.Colors:Class(class)
end
local function lerp(a, b, t) return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t end

-- Les appels à l'affichage ne sont faits que si la valeur change (des milliers par seconde en raid 40 sinon)
local function setMax(bar, m) if bar.vpMax ~= m then bar.vpMax = m; bar:SetMinMaxValues(0, m) end end
local function setVal(bar, v) if bar.vpVal ~= v then bar.vpVal = v; bar:SetValue(v) end end
-- Barre de vie : animée si l'option est active (glisse vers la vraie valeur en ~0,2 s), sinon immédiate.
-- Jamais animée pour un cadre caché, l'aperçu, ou la toute première valeur (nouveau joueur derrière le cadre).
F.anim = {}
local function setHP(b, v)
	local bar = b.hp
	if bar.vpVal == v then return end
	local first = bar.vpVal == nil
	bar.vpVal = v
	if VP.db.smoothBars and not first and not b.vpPreview and b:IsVisible() then
		bar.vpTarget = v
		F.anim[b] = true
	else
		F.anim[b] = nil
		bar:SetValue(v)
	end
end
-- une image d'animation pour toutes les barres en mouvement (appelé par le moteur à chaque image)
function F:StepAnim(elapsed)
	local k = math.min(1, elapsed * 12)
	for b in pairs(self.anim) do
		local bar = b.hp
		local t = bar.vpTarget or bar.vpVal or 0
		local cur = bar:GetValue()
		local diff = t - cur
		if not b:IsVisible() or math.abs(diff) <= (bar.vpMax or 1) * 0.004 then
			bar:SetValue(t)
			self.anim[b] = nil
		else
			bar:SetValue(cur + diff * k)
		end
	end
end
local function barColor(b, r, g, bl, br, bg, bb)
	if b.cR ~= r or b.cG ~= g or b.cB ~= bl or b.cbR ~= br or b.cbG ~= bg or b.cbB ~= bb then
		b.cR, b.cG, b.cB, b.cbR, b.cbG, b.cbB = r, g, bl, br, bg, bb
		b.hp:SetStatusBarColor(r, g, bl)
		b.hp.bg:SetVertexColor(br, bg, bb, 1)
	end
end

function F:PaintHealth(b, s)
	local d = VP.db
	local maxhp = (s.maxhp and s.maxhp > 0) and s.maxhp or 1
	local hp = s.hp or 0
	local pct = hp / maxhp
	setMax(b.hp, maxhp)

	-- nom
	-- nom (raccourci seulement quand il change : évite de recréer des chaînes à chaque mise à jour)
	local raw, len = s.name or "?", d.nameLength or 0
	if b.rawName ~= raw or b.rawLen ~= len then
		b.rawName, b.rawLen = raw, len
		b.name:SetText(len > 0 and T:Truncate(raw, len) or raw)
	end
	local cr, cg, cb = classRGB(s.class)
	if (d.classNames or d.barStyle == "DARK") and s.isPlayer then
		b.nbR, b.nbG, b.nbB = cr, cg, cb
	else
		b.nbR, b.nbG, b.nbB = T.C.text[1], T.C.text[2], T.C.text[3]
	end

	-- couleur de barre
	local r, g, bl
	local col = d.colors
	if not s.isPlayer and not s.friendly then
		r, g, bl = 0.85, 0.2, 0.2
	elseif not s.isPlayer and s.isPet then
		if s.ownerClass then
			-- couleur du maître, un peu adoucie pour distinguer le familier
			local cr2, cg2, cb2 = VP.Colors:Class(s.ownerClass)
			r, g, bl = cr2 * 0.75 + 0.1, cg2 * 0.75 + 0.1, cb2 * 0.75 + 0.1
		else
			r, g, bl = col.pet[1], col.pet[2], col.pet[3]
		end
	elseif not s.isPlayer then
		r, g, bl = 0.25, 0.8, 0.3
	elseif d.healthColor == "GRADIENT" then
		if pct > 0.5 then r, g, bl = lerp(col.fair, col.good, (pct - 0.5) * 2) else r, g, bl = lerp(col.low, col.fair, pct * 2) end
	elseif d.healthColor == "GREEN" then
		r, g, bl = col.solid[1], col.solid[2], col.solid[3]
	else
		r, g, bl = cr, cg, cb
	end
	if s.charmed then r, g, bl = col.charmed[1], col.charmed[2], col.charmed[3] end
	-- rappel : cadre gris tant que le buff manque
	if s.reminder then r, g, bl = 0.38, 0.38, 0.41 end
	b.pGray = s.reminder and true or nil
	if s.reminder and s.alive then
		b.remIcon.tex:SetTexture(s.reminder.icon)
		b.remIcon.count:SetText("")
		b.remIcon:SetBackdropBorderColor(1, 0.8, 0.1, 1)
		b.remIcon:Show()
		if d.classNames or d.barStyle == "DARK" then b.nbR, b.nbG, b.nbB = 0.6, 0.6, 0.62 end
	elseif s.chargeN and s.alive then
		-- buff à charges présent (Bouclier d'eau) : même icône, sans griser, avec le nombre de charges
		b.remIcon.tex:SetTexture(s.chargeIcon)
		b.remIcon.count:SetText(s.chargeN)
		if s.chargeN <= 1 then b.remIcon.count:SetTextColor(1, 0.45, 0.2) else b.remIcon.count:SetTextColor(1, 1, 1) end
		b.remIcon:SetBackdropBorderColor(0, 0, 0, 1)
		b.remIcon:Show()
	else
		b.remIcon:Hide()
	end

	if s.status == "offline" or s.status == "dead" or s.status == "ghost" then
		setHP(b, s.status == "offline" and maxhp or 0)
		b.pDown = s.status == "offline" and col.offline or col.dead
	else
		setHP(b, hp)
		b.pDown = nil
	end
	b.pR, b.pG, b.pB = r, g, bl
	self:ApplyBar(b)

	-- texte d'état / de vie
	local info
	if s.status == "offline" then info = "|cff999999Déco|r"
	elseif s.status == "dead" then
		if s.rez == "cast" then info = "|cff66ccffRez...|r"
		elseif s.rez == "pending" then info = "|cff66ccffRez en attente|r"
		elseif s.deadFor then info = "|cffff4444Mort " .. clock(s.deadFor) .. "|r"
		else info = "|cffff4444Mort|r" end
	elseif s.status == "ghost" then
		info = s.deadFor and ("|cffff4444Fantôme " .. clock(s.deadFor) .. "|r") or "|cffff4444Fantôme|r"
	elseif s.charmed and d.showStatus then info = "|cffff44ccContrôlé|r"
	elseif s.status == "feign" and d.showStatus then info = "|cffccccccFeinte|r"
	elseif s.status == "afk" and d.showStatus then info = "|cffccccccAFK|r"
	elseif s.drinking and (maxhp - hp) <= 0 then info = "|cff66ccffBoit " .. s.drinking .. "%|r"
	else
		local deficit = maxhp - hp
		local tc = pct < 0.35 and "|cffff5050" or (pct < 0.7 and "|cffffcc33" or "|cffffffff")
		if d.healthText == "DEFICIT" and deficit > 0 then info = tc .. "-" .. shortNum(deficit) .. "|r"
		elseif d.healthText == "PERCENT" and pct < 1 then info = tc .. math.floor(pct * 100 + 0.5) .. "%|r"
		elseif d.healthText == "CURRENT" then info = tc .. shortNum(hp) .. "|r"
		end
	end
	info = info or ""
	if b.lastInfo ~= info then b.lastInfo = info; b.info:SetText(info) end

	-- soins entrants
	if s.incoming and s.incoming > 0 and hp < maxhp and s.alive then
		local w = b.hp:GetWidth()
		local amount = math.min(s.incoming, maxhp - hp)
		b.inc:SetWidth(math.max(1, w * amount / maxhp))
		b.inc:SetVertexColor(col.incoming[1], col.incoming[2], col.incoming[3], 0.5)
		b.inc:Show()
	else
		b.inc:Hide()
	end
	-- boucliers (montant estimé d'après l'infobulle du buff)
	if d.showAbsorb and s.absorb and s.absorb > 0 and s.alive then
		local w = b.hp:GetWidth()
		local ac = col.absorb or { 0.85, 0.95, 1 }
		b.absorb:SetWidth(math.max(1, w * math.min(1, s.absorb / maxhp)))
		b.absorb:SetHeight(d.absorbHeight or 3)
		b.absorb:SetVertexColor(ac[1], ac[2], ac[3], 0.9)
		b.absorb:Show()
	else
		b.absorb:Hide()
	end
	local over = (s.incoming and s.alive) and (s.incoming - (maxhp - hp)) or 0
	if d.overhealText and over > 0 and not (s.isPet and d.pets and not d.pets.overheal) then
		local t = "+" .. shortNum(over)
		if b.lastOver ~= t then b.lastOver = t; b.overheal:SetText(t) end
		b.overheal:SetTextColor(col.incoming[1], col.incoming[2], col.incoming[3])
		b.overheal:Show()
	elseif b.lastOver then
		b.lastOver = nil
		b.overheal:Hide()
	end

	-- ressource
	if d.showMana and s.isPlayer and s.ptype and col.power[s.ptype] and s.powerMax and s.powerMax > 0 then
		local c = col.power[s.ptype]
		setMax(b.mp, s.powerMax)
		setVal(b.mp, s.power or 0)
		if s.lowMana then
			b.mp:SetStatusBarColor(1, 0.55, 0.1, 1)
		else
			b.mp:SetStatusBarColor(c[1], c[2], c[3], 1)
		end
		b.mp:Show()
	else
		b.mp:Hide()
	end

	if d.showAggro and s.aggro then b.aggro:Show() else b.aggro:Hide() end
	if s.isTarget then b.targetBorder:Show() else b.targetBorder:Hide() end
	if s.casting then
		local c = col.cast or { 1, 0.85, 0.2 }
		b.castBorder:SetBackdropBorderColor(c[1], c[2], c[3], 1)
		b.castBorder:Show()
	else
		b.castBorder:Hide()
	end
	if s.assigned then
		local c = col.assign or { 0.3, 0.8, 1 }
		b.assignBorder:SetBackdropBorderColor(c[1], c[2], c[3], 1)
		b.assignBorder:Show()
	else
		b.assignBorder:Hide()
	end
	if s.bossTarget then
		local c = col.bossTarget
		b.bossTargetBorder:SetBackdropBorderColor(c[1], c[2], c[3], 1)
		b.bossTargetBorder:Show()
	else
		b.bossTargetBorder:Hide()
	end

	local mark = d.showRaidIcon and s.raidIcon and d.raidIconShow[s.raidIcon] ~= false and s.raidIcon
	if mark then
		SetRaidTargetIconTexture(b.raidIcon, mark)
		b.raidIcon:Show()
	else
		b.raidIcon:Hide()
	end
	local rc = mark and d.raidIconColor ~= "NONE" and col.raid[mark]
	if rc and rc.bg then
		b.markBorder:SetBackdropBorderColor(rc[1], rc[2], rc[3], 1)
		b.markBorder:Show()
	else
		b.markBorder:Hide()
	end
	if rc and rc.text then b.nmR, b.nmG, b.nmB = rc[1], rc[2], rc[3] else b.nmR = nil end

	if s.ready and READY_TEX[s.ready] then
		b.ready:SetTexture(READY_TEX[s.ready]); b.ready:Show()
	else
		b.ready:Hide()
	end

	-- rôle (placé par le gestionnaire de placement)
	if d.showRole and s.roleTex then
		b.role:SetTexture(s.roleTex)
		b.role:SetTexCoord(s.roleL, s.roleR, s.roleT, s.roleB)
		b.role:Show()
	else
		b.role:Hide()
	end
	-- couronne chef / assistant (placée par le gestionnaire de placement)
	if s.leadTex then
		if b.leadShown ~= s.leadTex then b.leadShown = s.leadTex; b.leader:SetTexture(s.leadTex) end
		b.leader:Show()
	else
		b.leader:Hide()
	end

	-- teinte soin de zone, bordure urgence
	if not b.dispelTint and not b.bossTint and not b.dbR then
		if s.aoe then
			local ar, ag, ab = T:Accent()
			b.tint:SetVertexColor(ar, ag, ab, 0.28)
			b.tint:Show()
		else
			b.tint:Hide()
		end
	end
	if s.emergency and not b.dispelBorder:IsShown() then
		local c = (s.emergency == 1) and col.urgent or col.notUrgent
		b.emergBorder:SetBackdropBorderColor(c[1], c[2], c[3], 1)
		b.emergBorder:Show()
	else
		b.emergBorder:Hide()
	end
	self:ApplyNameColor(b)
	self:Arrange(b)
end

-- Couleur finale du nom : symbole de raid > débuff (dispel / boss) > base (classe, rappel)
function F:ApplyNameColor(b)
	local r, g, bl
	if b.nmR then r, g, bl = b.nmR, b.nmG, b.nmB
	elseif b.naR then r, g, bl = b.naR, b.naG, b.naB
	else r, g, bl = b.nbR or 1, b.nbG or 1, b.nbB or 1 end
	if r ~= b.ncR or g ~= b.ncG or bl ~= b.ncB then
		b.ncR, b.ncG, b.ncB = r, g, bl
		b.name:SetTextColor(r, g, bl)
	end
end

-- a = { dtype, dicon, danger, hint, boss = {icon,count,dur,exp}, others = {icons}, hots = {{icon,count,charge,expiring}}, missing }
-- Couleur de la barre de vie : couleur normale, ou couleur du débuff à dissiper (comme VuhDo / Decursive)
function F:ApplyBar(b)
	local d = VP.db
	local c = b.pDown
	if c then
		barColor(b, c[1], c[2], c[3], c[1], c[2], c[3])
		return
	end
	local r, g, bl = b.pR or 0.5, b.pG or 0.5, b.pB or 0.5
	if b.dbR then
		-- barre entière de la couleur du débuff ; plus sombre si le joueur est loin ou hors de vue
		local k = b.dbDim and 0.45 or 1
		r, g, bl = b.dbR * k, b.dbG * k, b.dbB * k
		barColor(b, r, g, bl, r * 0.35, g * 0.35, bl * 0.35)
	elseif d.barStyle == "DARK" and b.pGray then
		-- style sombre : la barre est déjà grise, le rappel doit rester visible (gris clair)
		barColor(b, 0.5, 0.5, 0.53, 0.22, 0.22, 0.24)
	elseif d.barStyle == "DARK" then
		barColor(b, 0.17, 0.17, 0.19, r * 0.55, g * 0.55, bl * 0.55)
	else
		barColor(b, r, g, bl, r * 0.18, g * 0.18, bl * 0.18)
	end
end

-- Icône minutée (défensif, soins réduits) : définie une seule fois, pas à chaque mise à jour des auras
local function timedIcon(f, e)
	if e then
		f.tex:SetTexture(e.icon)
		f.count:SetText((e.count and e.count > 1) and e.count or "")
		if e.exp and e.exp > 0 and e.dur and e.dur > 0 then
			if f.exp ~= e.exp then CooldownFrame_SetTimer(f.cd, e.exp - e.dur, e.dur, 1) end
			f.exp = e.exp
		else
			f.cd:Hide(); f.exp = nil
		end
		f:Show()
	else
		f:Hide(); f.exp = nil
	end
end

function F:PaintAuras(b, a)
	local d = VP.db
	local colors = d.colors
	if a.dtype and d.dispel.highlight then
		local dc = VP.Colors:Debuff(a.dtype)
		local r, g, bl = dc[1], dc[2], dc[3]
		if a.danger then r, g, bl = 0.7, 0, 1 end
		local dim = a.far or a.blocked
		local style = d.dispel.style or "BAR"
		local alpha = dim and 0.35 or 1
		b.dispelBorder:SetBackdropBorderColor(r, g, bl, alpha)
		b.dispelBorder.pulse = d.dispel.pulse ~= false and not dim
		if not b.dispelBorder.pulse then b.dispelBorder:SetAlpha(1) end
		b.dispelBorder:Show()
		-- barre entière colorée (par défaut) ou simple teinte légère
		local barOn = dc.bg and style == "BAR"
		if barOn then
			-- la teinte « soin de zone » ne doit pas rester par-dessus la barre colorée du débuff
			if not b.bossTint then b.tint:Hide() end
			if b.dbR ~= r or b.dbG ~= g or b.dbB ~= bl or b.dbDim ~= dim then
				b.dbR, b.dbG, b.dbB, b.dbDim = r, g, bl, dim
				self:ApplyBar(b)
			end
		elseif b.dbR then
			b.dbR = nil
			self:ApplyBar(b)
		end
		if dc.bg and style == "TINT" then
			b.tint:SetVertexColor(r, g, bl, dim and 0.08 or 0.3)
			b.tint:Show()
			b.dispelTint = true
		elseif b.dispelTint then
			b.dispelTint = nil
			b.tint:Hide()
		end
		if dc.text then b.naR, b.naG, b.naB = r, g, bl else b.naR = nil end
		b.dIcon.tex:SetTexture(a.dicon)
		b.dIcon:SetBackdropBorderColor(r, g, bl, 1)
		b.dIcon:SetAlpha(alpha < 1 and 0.6 or 1)
		b.dIcon.count:SetText((a.dcount and a.dcount > 1) and a.dcount or "")
		if a.dexp and a.dexp > 0 and a.ddur and a.ddur > 0 then
			if b.dIcon.exp ~= a.dexp then CooldownFrame_SetTimer(b.dIcon.cd, a.dexp - a.ddur, a.ddur, 1) end
			b.dIcon.exp = a.dexp
		else
			b.dIcon.cd:Hide()
			b.dIcon.exp = nil
		end
		b.dIcon:Show()
		if a.danger then b.dHint:SetText("|cffcc55ffDANGER|r")
		elseif a.blocked then b.dHint:SetText("|cff999999hors vue|r")
		elseif a.far then b.dHint:SetText("|cff999999loin|r")
		elseif d.dispel.showHint and a.hint then b.dHint:SetText(a.hint)
		else b.dHint:SetText("") end
	else
		b.dispelBorder:Hide()
		b.dIcon:Hide()
		b.dIcon.exp = nil
		b.dHint:SetText("")
		if b.dispelTint then b.dispelTint = nil; b.tint:Hide() end
		if b.dbR then b.dbR = nil; self:ApplyBar(b) end
		b.naR = nil
	end

	local bf = b.bossFrame
	if a.boss then
		local cc = colors.debuff.Custom
		-- la bordure de l'icône dit quoi faire :
		--   couleur du type (bleu, violet...) = VOUS pouvez le dissiper
		--   orange                            = critique : à surveiller / soigner fort
		--   gris                              = simple information, rien à dissiper
		if a.boss.can and a.boss.dtype then
			local tc = VP.Colors:Debuff(a.boss.dtype)
			bf:SetBackdropBorderColor(tc[1], tc[2], tc[3], 1)
		elseif a.boss.isCrit or a.boss.crit then
			bf:SetBackdropBorderColor(cc[1], cc[2], cc[3], 1)
		else
			bf:SetBackdropBorderColor(0.45, 0.45, 0.5, 1)
		end
		-- colorer tout le cadre et le nom ressemble à une alerte de dispel : seulement si demandé
		local hl = d.debuffs.highlight
		if not hl and b.bossTint then
			b.bossTint = nil
			if not a.dtype then b.tint:Hide() end
		end
		if hl and cc.text and not a.dtype then b.naR, b.naG, b.naB = cc[1], cc[2], cc[3] end
		if hl and cc.bg and not a.dtype and not b.tint:IsShown() then
			b.tint:SetVertexColor(cc[1], cc[2], cc[3], 0.18)
			b.tint:Show()
			b.bossTint = true
		end
		bf.pulse = a.boss.crit
		if not bf.pulse then bf:SetAlpha(1) end
		bf.tex:SetTexture(a.boss.icon)
		bf.count:SetText((a.boss.count and a.boss.count > 1) and a.boss.count or "")
		if a.boss.dur and a.boss.dur > 0 and a.boss.exp then
			if bf.exp ~= a.boss.exp then CooldownFrame_SetTimer(bf.cd, a.boss.exp - a.boss.dur, a.boss.dur, 1) end
			bf.exp = a.boss.exp
		else
			bf.cd:Hide()
			bf.exp = nil
		end
		bf:Show()
	else
		bf:Hide()
		bf.exp = nil
		if b.bossTint then b.bossTint = nil; if not a.dtype then b.tint:Hide() end end
	end
	for i = 1, 3 do
		local o = b.others[i]
		if a.others and a.others[i] then o.tex:SetTexture(a.others[i]); o.count:SetText(""); o:Show() else o:Hide() end
	end

	-- HoTs : un emplacement par sort configuré (positions fixes ou resserrées)
	local slots = self:HotSlots()
	for i = 1, F.NUM_SLOTS do
		local h = b.hots[i]
		local e = a.hots and a.hots[i]
		if e then
			if d.hotMode == "SQUARE" then
				local c = slots[i] and slots[i].color or SLOT_COLORS[i]
				h.tex:SetTexture(T.TEX)
				h.tex:SetVertexColor(c[1], c[2], c[3])
			else
				h.tex:SetTexture(e.icon)
				h.tex:SetVertexColor(1, 1, 1)
			end
			-- sort à charges (Bouclier de terre, Prière de guérison) : gros chiffre des charges au centre,
			-- sans temps restant ni spirale
			local isCharge = (e.charge and d.chargeOnly ~= false) and true or false
			if isCharge ~= h.chargeLayout then
				h.chargeLayout = isCharge
				h.count:ClearAllPoints()
				if isCharge then
					h.count:SetPoint("CENTER", h, "CENTER", 1, 0)
				else
					h.count:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 2, -1)
				end
				h.countFont = nil
			end
			local cfs = self:HotCountSize(h, isCharge)
			if h.countFont ~= cfs then
				h.countFont = cfs
				T:SetFont(h.count, cfs, (isCharge or d.hotTextOutline) and "OUTLINE" or nil)
			end
			if e.count and ((isCharge and e.count >= 1) or (d.showStacks and (e.count > 1 or (e.charge and e.count >= 1)))) then
				h.count:SetText(e.count)
				if e.charge then
					local cc = colors.charge[math.min(e.count, 4)] or colors.charge[4]
					h.count:SetTextColor(cc[1], cc[2], cc[3])
				else
					h.count:SetTextColor(1, 1, 1)
				end
			else
				h.count:SetText("")
			end
			-- durée : spirale + temps restant (pas pour les sorts à charges)
			if isCharge then
				h.cd:Hide()
				h.exp = nil
			elseif e.exp and e.exp > 0 and e.dur and e.dur > 0 then
				if d.hotSpiral then
					if h.exp ~= e.exp then CooldownFrame_SetTimer(h.cd, e.exp - e.dur, e.dur, 1) end
					h.cd:Show()
				else
					h.cd:Hide()
				end
				h.exp = e.exp
			else
				h.cd:Hide()
				h.exp = nil
			end
			h.countdown = slots[i] and slots[i].countdown or "SEC"
			if (d.showStacks or isCharge) and e.expiring then
				local wc = colors.hotWarn
				h:SetBackdropBorderColor(wc[1], wc[2], wc[3], 1)
				if d.hotMode ~= "SQUARE" then h.tex:SetVertexColor(1, 0.45, 0.45) end
			else
				h:SetBackdropBorderColor(0, 0, 0, 1)
			end
			h:Show()
		else
			h:Hide()
			h.exp = nil
		end
	end
	if a.missing then b.missBuff:Show() else b.missBuff:Hide() end
	-- barres de durée : les 3 premiers HoTs minutés (pas les sorts à charges)
	local nb = 0
	local wantBars = d.hotBars == "ALL" or (d.hotBars == "TANKS" and a.tank)
	if wantBars and a.hots then
		for i = 1, F.NUM_SLOTS do
			local e = a.hots[i]
			if e and nb < 3 and not e.charge and e.exp and e.exp > 0 and e.dur and e.dur > 0 then
				nb = nb + 1
				local hb = b.hotBars[nb]
				local c = slots[i] and slots[i].color or SLOT_COLORS[i]
				hb:SetVertexColor(c[1], c[2], c[3], 0.95)
				hb.exp, hb.dur = e.exp, e.dur
				hb:Show()
			end
		end
	end
	for k = nb + 1, 3 do local hb = b.hotBars[k]; hb.exp = nil; hb:Hide() end
	b.nHotBars = nb
	timedIcon(b.defIcon, a.def)
	timedIcon(b.healRed, a.healRed)
	if a.soul then b.soulIcon.tex:SetTexture(a.soul); b.soulIcon:Show() else b.soulIcon:Hide() end
	self:ApplyNameColor(b)
	local timed = (a.hots and next(a.hots)) or a.boss or a.dtype or a.def or a.healRed or nb > 0
	b.hasTimed = timed and true or false
	self:UpdateTimers(b)
	self:Arrange(b)
end

-- Lecture de l'état réel d'une unité -------------------------------------------------
-- unité du familier -> unité du maître (table fixe : aucune chaîne créée à chaque mise à jour)
local PET_OWNER = { pet = "player" }
for i = 1, 4 do PET_OWNER["partypet" .. i] = "party" .. i end
for i = 1, 40 do PET_OWNER["raidpet" .. i] = "raid" .. i end

local S = {}
local deadSince = {}   -- GUID -> heure à laquelle le joueur a été vu mort
function F:UpdateHealth(b)
	local u = b.unit
	if not u or not UnitExists(u) then return end
	local d = VP.db
	wipe(S)
	S.name = UnitName(u)
	S.isPlayer = UnitIsPlayer(u)
	S.isPet = not S.isPlayer and UnitPlayerControlled(u)
	-- familier : nom du maître et sa classe (« Félin (Bob) », barre couleur du chasseur)
	local pt = d.pets
	if S.isPet and pt and (pt.ownerName or pt.ownerColor) then
		local owner = PET_OWNER[u]
		if owner and UnitExists(owner) then
			local _, oc = UnitClass(owner)
			S.ownerClass = pt.ownerColor and oc or nil
			if pt.ownerName then
				local on = UnitName(owner)
				if on then S.name = (S.name or "?") .. " (" .. on .. ")" end
			end
		end
	end
	S.friendly = UnitIsFriend("player", u)
	local _, class = UnitClass(u)
	S.class = class
	S.hp, S.maxhp = UnitHealth(u), UnitHealthMax(u)
	S.alive = false
	if not UnitIsConnected(u) then
		S.status = "offline"
	elseif UnitIsDeadOrGhost(u) and not (UnitIsFeignDeath and UnitIsFeignDeath(u)) then
		S.status = UnitIsGhost(u) and "ghost" or "dead"
		if S.status == "ghost" then S.hp = 0 end
	else
		S.alive = true
		if UnitIsFeignDeath and UnitIsFeignDeath(u) then S.status = "feign"
		elseif UnitIsAFK(u) then S.status = "afk" end
		S.charmed = UnitIsCharmed(u) and S.isPlayer
	end

	local hc = VP.healComm
	if d.showIncoming and hc and S.alive then
		local guid = UnitGUID(u)
		if guid then
			-- fenêtre de temps : sans elle, un HoT de 15 s compte en entier et gonfle la barre et le surplus
			local win = d.incomingWindow or 4
			local tf = win > 0 and (GetTime() + win) or nil
			local amt
			if d.incomingMine == false then amt = hc:GetOthersHealAmount(guid, hc.ALL_HEALS, tf)
			else amt = hc:GetHealAmount(guid, hc.ALL_HEALS, tf) end
			S.incoming = (amt or 0) * (hc:GetHealModifier(guid) or 1)
		end
	end
	if d.showAbsorb and S.alive and b.shieldN and b.shieldN > 0 then S.absorb = self:ShieldAmount(b, u) end

	S.ptype = UnitPowerType(u)
	S.powerMax = UnitPowerMax(u, S.ptype)
	S.power = UnitPower(u, S.ptype)
	if d.lowMana and S.ptype == 0 and HEALER_CLASS[class] and S.alive and S.powerMax and S.powerMax > 0
		and S.power / S.powerMax * 100 <= d.lowManaPct then
		S.lowMana = true
	end
	-- en train de boire (hors combat, unités à mana) : « Boit 45% »
	if d.showDrinking and S.alive and S.ptype == 0 and S.powerMax and S.powerMax > 0 and not UnitAffectingCombat(u) then
		for n in pairs(drinkNames) do
			if UnitBuff(u, n) then S.drinking = math.floor(S.power / S.powerMax * 100 + 0.5) break end
		end
	end

	local t = d.showAggro and UnitThreatSituation(u)
	S.aggro = t and t >= 2
	S.isTarget = UnitIsUnit(u, "target") and self:Kind(b) ~= "target"
	-- mort : depuis quand, et résurrection déjà en cours / en attente ?
	local dg = UnitGUID(u)
	if S.status == "dead" or S.status == "ghost" then
		if dg then
			local since = deadSince[dg]
			if not since then since = GetTime(); deadSince[dg] = since end
			if d.deadTimer then S.deadFor = GetTime() - since end
		end
		if d.rezStatus and S.status == "dead" and VP.Rez then S.rez, S.rezBy = VP.Rez:Status(u) end
	elseif dg and deadSince[dg] then
		deadSince[dg] = nil
		if VP.Rez then VP.Rez:Clear(u) end
	end
	S.casting = d.castHighlight and F.castTarget and S.isPlayer and UnitName(u) == F.castTarget
	S.assigned = VP.Assign and S.isPlayer and VP.Assign:IsMine(UnitName(u))
	S.raidIcon = GetRaidTargetIndex(u)
	local g = UnitGUID(u)
	S.bossTarget = d.indBossTarget and g and F.bossTargets[g]
	S.ready = d.showReadyCheck and F.readyActive and g and F.readyStatus[g] or nil
	S.emergency = b.emergency
	S.reminder = S.alive and VP.Buffs and VP.Buffs:Reminder(u)
	if S.alive and not S.reminder and VP.Buffs and VP.Buffs.Charges then S.chargeIcon, S.chargeN = VP.Buffs:Charges(u) end
	S.aoe = VP.AoE and S.alive and self:Kind(b) == "main" and VP.AoE:IsHit(u)
	b.vpPct = S.maxhp > 0 and S.hp / S.maxhp or 1
	b.vpAlive = S.alive
	S.roleTex, S.roleL, S.roleR, S.roleT, S.roleB = b.roleTex, b.roleL, b.roleR, b.roleT, b.roleB
	S.leadTex = b.leadTex

	-- portée : celle de VOTRE sort de soin si possible (sinon la portée générale de 40 m)
	local far = false
	-- portée : membres du groupe et leurs familiers (flèche et transparence aussi pour les familiers)
	if not UnitIsUnit(u, "player") and (S.isPet or UnitInRaid(u) or UnitInParty(u)) and UnitIsConnected(u) then
		far = not F:InHealRange(u)
	end
	local alpha = (d.rangeFade and far) and d.rangeAlpha or 1
	-- familier en pleine vie : discret, il ressort dès qu'il est blessé
	if S.isPet and pt and pt.dimFull and S.maxhp > 0 and S.hp >= S.maxhp and self:Kind(b) == "pets" then
		alpha = math.min(alpha, pt.dimAlpha or 0.45)
	end
	if b.vpAlpha ~= alpha then b.vpAlpha = alpha; b:SetAlpha(alpha) end
	-- flèche : visible seulement tant que le joueur est hors de portée
	-- (isFar sert aussi à la grande flèche, même si la petite est désactivée)
	if far then
	b.isFar = true
	self:UpdateArrow(b)
	elseif b.isFar or b.arrow:IsShown() then
	b.isFar = nil
	if b.arrow:IsShown() then b.arrow:Hide(); self:Arrange(b) end
	end

	self:PaintHealth(b, S)
end

local A = {}
local hotList = { {}, {}, {}, {}, {}, {} }
local hotsBuf, bossBuf, defBuf, redBuf, harmBuf = {}, {}, {}, {}, { n = 0 }
function F:UpdateAuras(b)
	local u = b.unit
	if not u or not UnitExists(u) then return end
	local d = VP.db
	local friendly = UnitIsFriend("player", u)
	wipe(A)
	-- une seule lecture des affaiblissements, partagée par le dispel, les débuffs de boss et les soins réduits
	local harm = VP.Debuffs:ReadHarmful(u, harmBuf)

	local D = VP.Dispel
	local petOK = not (d.pets and not d.pets.dispel and not UnitIsPlayer(u))
	if friendly and petOK and UnitIsConnected(u) and not UnitIsDeadOrGhost(u) then
		local dtype, dicon, dname, danger, slot, dcount, ddur, dexp = D:Scan(u, harm)
		if dtype then
			A.dtype, A.dicon, A.danger, A.dname = dtype, dicon, danger, dname
			A.dcount, A.ddur, A.dexp = dcount, ddur, dexp
			A.hint = slot and VP.dispelKeys and VP.dispelKeys[slot]
			A.far = d.dispel.rangeCheck and not D:InRange(u, slot)
			A.blocked = D:IsBlacklisted(u)
			-- son : à la première apparition, ou quand il revient à portée (comme Decursive)
			local canAlert = not A.blocked and (not A.far or d.dispel.alertOutOfRange)
			if canAlert and not b.alerted then
				D:Alert(danger)
				b.alerted = true
			end
			if self:Kind(b) ~= "target" then D:Track(u, dtype, dicon, dname, slot, dexp, not A.far, A.blocked) end
		end
	end
	if not A.dtype then
		b.alerted = nil
		D:Untrack(u)
	end
	b.hadDispel = A.dtype ~= nil

	local bName, bIcon, bCount, bDur, bExp, others, bPrio, bType = VP.Debuffs:Scan(u, harm)
	if bName then
		local isCrit = bPrio and bPrio >= 8 or false
		bossBuf.icon, bossBuf.count, bossBuf.dur, bossBuf.exp = bIcon, bCount, bDur, bExp
		bossBuf.isCrit = isCrit
		bossBuf.crit = d.debuffs.critGlow and isCrit
		-- puis-je le retirer moi-même ? (son type fait partie de ce que MON personnage dissipe)
		bossBuf.dtype = bType
		bossBuf.can = (bType and D.canDispel[bType] and not D:IsIgnored(bName, u)) and true or false
		A.boss = bossBuf
		if b.lastBoss ~= bName then VP.Debuffs:Alert(isCrit) end
	end
	b.lastBoss = bName
	-- pour l'infobulle du cadre : nom du débuff de boss et « dissipable par moi ? »
	b.bossName, b.bossCan, b.bossCrit = bName, bName and bossBuf.can or nil, bName and bossBuf.isCrit or nil
	A.others = others

	-- une seule lecture des buffs : HoTs, défensif, pierre d'âme, boucliers
	local wantHots = d.showHots and friendly
	local wantInd = d.indicators and friendly
	local wantAbs = d.showAbsorb and friendly
	local oldShields = b.shieldN or 0
	b.shieldN = 0
	if wantHots or wantInd or wantAbs then
		if wantHots then wipe(hotsBuf); A.hots = hotsBuf end
		local slots = wantHots and self:HotSlots()
		local now = GetTime()
		local warn = d.hotWarnSecs or 3
		local i = 1
		while true do
			local name, _, ic, count, _, duration, expires, caster, _, _, spellId = UnitAura(u, i, "HELPFUL")
			if not name then break end
			if wantAbs and shieldNames[name] and (name ~= sacredName or spellId == SACRED_PROC) then
				b.shieldIdx = b.shieldIdx or {}
				b.shieldN = b.shieldN + 1
				b.shieldIdx[b.shieldN] = i
			end
			if wantHots then
				local mine = caster == "player" or caster == "pet" or caster == "vehicle"
				-- Rénovation du Puits de lumière : lancée par le Puits (aucune unité, lanceur nil). Impossible de
				-- savoir à quel prêtre il appartient : l'emplacement l'affiche qu'il soit réglé « les miens » ou « des autres »
				local anyOwner = caster == nil and name == lightwellName
				for si = 1, F.NUM_SLOTS do
					local sl = slots[si]
					if sl and not hotsBuf[si] and sl.spell == name and ((mine and sl.own) or (not mine and sl.others) or anyOwner) then
						learnIcon(name, ic)
						local e = hotList[si]
						e.icon, e.count, e.charge = ic, count, chargeNames[name]
						e.dur, e.exp = duration, expires
						if e.charge then
							-- sort à charges : l'alerte vient du nombre de charges, pas du temps
							e.expiring = count and count <= 1
						else
							e.expiring = expires and expires > 0 and (expires - now) < warn
						end
						hotsBuf[si] = e
						break
					end
				end
			end
			if wantInd then
				if d.indDefensive and not A.def and defNames[name] then
					defBuf.icon, defBuf.count, defBuf.dur, defBuf.exp = ic, nil, duration, expires
					A.def = defBuf
				end
				if d.indSoul and name == soulName then A.soul = ic end
			end
			i = i + 1
		end
		-- emplacements qui suivent un AFFAIBLISSEMENT (Âme affaiblie, Longanimité...) : lus dans la liste
		-- des débuffs déjà relevée ; on ne sait pas qui l'a posé, il suffit que l'emplacement soit actif
		if wantHots and harm.n > 0 then
			for si = 1, F.NUM_SLOTS do
				local sl = slots[si]
				if sl and not hotsBuf[si] and sl.spell ~= "" and (sl.own or sl.others) then
					for k = 1, harm.n do
						local h = harm[k]
						if h.name == sl.spell then
							learnIcon(h.name, h.icon)
							local e = hotList[si]
							e.icon, e.count, e.charge = h.icon, h.count, nil
							e.dur, e.exp = h.dur, h.exp
							e.expiring = h.exp and h.exp > 0 and (h.exp - now) < warn
							hotsBuf[si] = e
							break
						end
					end
				end
			end
		end
	end
	if wantInd and d.indHealRed then
		for k = 1, harm.n do
			local e = harm[k]
			if healRedNames[e.name] then
				redBuf.icon, redBuf.count, redBuf.dur, redBuf.exp = e.icon, e.count, e.dur, e.exp
				A.healRed = redBuf
				break
			end
		end
	end
	-- bouclier apparu / disparu : relire le montant tout de suite (sinon le balayage régulier
	-- le relit en moins de 0,3 s ; inutile de relire l'infobulle à chaque changement de buff du raid)
	if b.shieldN ~= oldShields then
		b.absorbT = nil
		if F.dirtyH then F.dirtyH[b] = true end
	end
	A.missing = VP.Buffs and d.buffs.enabled and d.buffs.showMissing and friendly and UnitIsPlayer(u) and VP.Buffs:IsMissingAny(u)
	if d.hotBars == "TANKS" then
		local k = self:Kind(b)
		A.tank = k == "tanks" or k == "mytanks" or (VP.Buffs and VP.Buffs:IsTank(u))
	end
	self:PaintAuras(b, A)
end

-- Chef (2) / assistant (1) de chaque joueur, par nom : relu quand le groupe ou le chef change.
-- (par nom : marche aussi pour les cadres Cible / Focus / Projecteur, quelle que soit leur unité)
F.LEADER_TEX = "Interface\\GroupFrame\\UI-Group-LeaderIcon"
F.ASSIST_TEX = "Interface\\GroupFrame\\UI-Group-AssistantIcon"
F.ranks = {}
function F:BuildRanks()
	local r = self.ranks
	wipe(r)
	local n = GetNumRaidMembers()
	if n > 0 then
		for i = 1, n do
			local name, rank = GetRaidRosterInfo(i)
			if name and rank and rank > 0 then r[(string.match(name, "^([^%-]+)")) or name] = rank end
		end
	elseif GetNumPartyMembers() > 0 then
		if IsPartyLeader() then local me = UnitName("player"); if me then r[me] = 2 end end
		for i = 1, GetNumPartyMembers() do
			local u = "party" .. i
			if UnitIsPartyLeader(u) then local nm = UnitName(u); if nm then r[nm] = 2 end end
		end
	end
end

function F:UpdateRole(b)
	local u = b.unit
	b.roleTex = nil
	-- couronne chef / assistant
	b.leadTex = nil
	local d0 = VP.db
	if d0.showLeader and u and UnitIsPlayer(u) then
		local rk = self.ranks[UnitName(u) or ""]
		if rk == 2 then b.leadTex = F.LEADER_TEX
		elseif rk == 1 and d0.showAssist then b.leadTex = F.ASSIST_TEX end
	end
	if VP.db.showRole and u and UnitExists(u) and UnitIsPlayer(u) then
		local raidIndex = string.match(u, "^raid(%d+)$")
		if raidIndex then
			local raidRole = select(10, GetRaidRosterInfo(tonumber(raidIndex)))
			if raidRole == "MAINTANK" then
				b.roleTex, b.roleL, b.roleR, b.roleT, b.roleB = "Interface\\GroupFrame\\UI-Group-MainTankIcon", 0, 1, 0, 1
			elseif raidRole == "MAINASSIST" then
				b.roleTex, b.roleL, b.roleR, b.roleT, b.roleB = "Interface\\GroupFrame\\UI-Group-MainAssistIcon", 0, 1, 0, 1
			end
		end
		if not b.roleTex then
			-- priorité : rôle forcé (/vp role), puis talents vérifiés, puis rôle de la Recherche de donjon
			-- (ce dernier peut être un ancien choix resté en mémoire : un soigneur inscrit en DPS...)
			local isTank, isHealer, isDamage
			local r = VP.Roles and VP.Roles:GetRole(u)
			if r then
				isTank, isHealer, isDamage = r == "TANK", r == "HEALER", r == "DAMAGER"
			else
				isTank, isHealer, isDamage = UnitGroupRolesAssigned(u)
			end
			if isDamage and not VP.db.roleShowDps then isDamage = false end
			if isTank then
				b.roleTex, b.roleL, b.roleR, b.roleT, b.roleB = LFG_TEX, 0, 19/64, 22/64, 41/64
			elseif isHealer then
				b.roleTex, b.roleL, b.roleR, b.roleT, b.roleB = LFG_TEX, 20/64, 39/64, 1/64, 20/64
			elseif isDamage then
				b.roleTex, b.roleL, b.roleR, b.roleT, b.roleB = LFG_TEX, 20/64, 39/64, 22/64, 41/64
			end
		end
	end
end

function F:FullUpdate(b)
	if not b.unit or not VP.db then return end
	self:UpdateRole(b)
	self:UpdateHealth(b)
	self:UpdateAuras(b)
end

-- Mode urgence : les N plus blessés sous le seuil (panneau principal)
local injured = {}
local function sortPct(a, c) return a.vpPct < c.vpPct end
function F:UpdateEmergency()
	wipe(injured)
	local d = VP.db
	for _, b in ipairs(self.buttons) do
		b.emergency = nil
		if d.emergency and b:IsVisible() and b.vpAlive and b.vpPct and self:Kind(b) == "main" and b.vpPct * 100 <= d.emergencyPct then
			table.insert(injured, b)
		end
	end
	table.sort(injured, sortPct)
	for i = 1, math.min(#injured, d.emergencyCount) do injured[i].emergency = i end
end

-- Portée de soin -------------------------------------------------------------------
local HEAL_RANGE_SPELL = { PRIEST = 2050, PALADIN = 635, SHAMAN = 331, DRUID = 5185 }
function F:InHealRange(u)
	local sp = self.rangeSpell
	if sp then
		local r = IsSpellInRange(sp, u)
		if r == 1 then return true elseif r == 0 then return false end
	end
	if UnitInRange(u) then return true end
	-- familier : le jeu répond souvent « inconnu » (nil) pour eux, ce qui les faisait passer
	-- pour hors de portée. On vérifie autrement : 28 m, puis la portée de son maître (il le suit).
	local owner = PET_OWNER_OF[u]
	if owner then
		if CheckInteractDistance(u, 4) then return true end
		if UnitIsUnit(owner, "player") then return UnitIsVisible(u) and true or false end
		return UnitInRange(owner) and true or false
	end
	return false
end

-- Flèche de direction (position sur la carte + orientation du personnage) ------------
local function rotateTex(tex, a)
	-- coins de la texture tournée (calcul direct, sans créer de fonction à chaque appel)
	local c, sn = math.cos(a) * 0.5, math.sin(a) * 0.5
	tex:SetTexCoord(0.5 - c + sn, 0.5 - sn - c, 0.5 - c - sn, 0.5 - sn + c,
		0.5 + c + sn, 0.5 + sn - c, 0.5 + c - sn, 0.5 + sn + c)
end
F.rotateTex = rotateTex

-- Angle (radians, sens anti-horaire) vers l'unité, relatif à l'orientation du joueur ; nil si inconnu
function F:Direction(u)
	local px, py = GetPlayerMapPosition("player")
	local tx, ty = GetPlayerMapPosition(u)
	if not px or not tx or (px == 0 and py == 0) or (tx == 0 and ty == 0) then
		self:FixMap()
		return nil
	end
	local dx, dy = (tx - px) * 1.5, (ty - py)   -- les cartes sont 1,5 fois plus larges que hautes
	if dx == 0 and dy == 0 then return nil end
	local theta = math.atan2(-dx, -dy)          -- 0 = nord, positif vers l'ouest
	local facing = GetPlayerFacing and GetPlayerFacing() or 0
	return theta - facing
end

local lastFix = 0
function F:FixMap()
	if WorldMapFrame and WorldMapFrame:IsShown() then return end
	if GetTime() - lastFix < 2 then return end
	lastFix = GetTime()
	SetMapToCurrentZone()
end

function F:UpdateArrow(b)
local g = self.guide
local a = not (g and g.on == b and g:IsShown()) and VP.db.arrows and b.isFar and self:Direction(b.unit)
if not a then
		if b.arrow:IsShown() then b.arrow:Hide(); self:Arrange(b) end
		return
	end
	rotateTex(b.arrow, a)
	local c = VP.db.colors.arrow or { 1, 0.85, 0.1 }
	b.arrow:SetVertexColor(c[1], c[2], c[3])
	if not b.arrow:IsShown() then b.arrow:Show(); self:Arrange(b) end
end

-- Grande flèche de guidage (comme VuhDo) : affichée PAR-DESSUS le cadre du joueur survolé
-- (ou de votre cible) quand il est hors de portée de soin ; disparaît dès qu'il est à portée.
function F:UpdateGuide()
	local g = self.guide
	if not g then return end
	local d = VP.db
	local btn
	if d.guideArrow then
		for _, b in ipairs(self.buttons) do
			if b.hover and b.isFar and b.unit and b:IsVisible() then btn = b break end
		end
		if not btn and d.guideTarget and UnitExists("target") and UnitIsFriend("player", "target") and UnitIsPlayer("target")
			and not UnitIsUnit("target", "player") and (UnitInRaid("target") or UnitInParty("target")) and not self:InHealRange("target") then
			local list = self:ButtonsFor(UnitGUID("target"))
			if list then
				for _, b in ipairs(list) do
					if b:IsVisible() and self:Kind(b) == "main" then btn = b break end
				end
				if not btn then
					for _, b in ipairs(list) do if b:IsVisible() then btn = b break end end
				end
			end
		end
	end
	local a = btn and self:Direction(btn.unit)
	if not a then
		if g:IsShown() then g:Hide(); self:ReleaseGuide() end
		return
	end
	if g.on ~= btn then
		self:ReleaseGuide()
		g.on = btn
		-- parent = écran (pas le cadre) : sinon la flèche hérite de la transparence « hors de portée »
		-- du cadre et n'est visible qu'à 35 %. Même échelle que le panneau, et toujours au-dessus.
		g:SetParent(UIParent)
		g:SetScale(btn:GetEffectiveScale() / UIParent:GetEffectiveScale())
		g:SetFrameStrata("HIGH")
		local size = self:GuideSize()
		g:SetWidth(size); g:SetHeight(size)
		place(g, btn, d.iconPos.guide or "C", 0, 0, "guide")
	end
	-- l'échelle du panneau peut changer (échelle auto 25 / 40) : on la suit
	local sc = btn:GetEffectiveScale() / UIParent:GetEffectiveScale()
	if math.abs((g:GetScale() or 1) - sc) > 0.001 then g:SetScale(sc) end
	rotateTex(g.arrow, a)
	rotateTex(g.shadow, a)
	local c = d.colors.arrow or { 1, 0.85, 0.1 }
	g.arrow:SetVertexColor(c[1], c[2], c[3])
	if not g:IsShown() then g:Show() end
	-- pas de double flèche sur le même cadre
	if btn.arrow:IsShown() then btn.arrow:Hide(); self:Arrange(btn) end
end

-- Taille de la grande flèche : taille choisie (px) ou % de la hauteur de la barre
function F:GuideSize()
	local d = VP.db
	local o = d.iconOff and d.iconOff.guide
	if o and o.size and o.size > 0 then return o.size end
	return math.min(d.width or 80, d.hpHeight or 32) * (d.guideScale or 100) / 100
end

-- La grande flèche quitte son cadre : la petite flèche de ce cadre peut revenir
function F:ReleaseGuide()
	local g = self.guide
	local old = g and g.on
	if not old then return end
	g.on = nil
	if old.isFar then self:UpdateArrow(old) end
end

function F:BuildGuide()
	local g = CreateFrame("Frame", "VuhPlusGuideArrow", UIParent)
	g:SetWidth(32); g:SetHeight(32)
	g:EnableMouse(false)
	-- ombre légère pour rester lisible sur toutes les couleurs de barre
	local sh = g:CreateTexture(nil, "BACKGROUND")
	sh:SetTexture("Interface\\Minimap\\MinimapArrow")
	sh:SetVertexColor(0, 0, 0, 0.7)
	sh:SetPoint("TOPLEFT", g, "TOPLEFT", -2, 2)
	sh:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", 2, -2)
	local a = g:CreateTexture(nil, "ARTWORK")
	a:SetTexture("Interface\\Minimap\\MinimapArrow")
	a:SetAllPoints(g)
	g.arrow, g.shadow = a, sh
	g:Hide()
	self.guide = g
end

-- Carte GUID -> boutons (reconstruite seulement quand le groupe ou un cadre change)
F.byGUID = {}
F.mapDirty = true
function F:ButtonsFor(guid)
	if self.mapDirty then
		self.mapDirty = false
		for _, l in pairs(self.byGUID) do wipe(l) end
		for _, b in ipairs(self.buttons) do
			local g = b.unit and UnitGUID(b.unit)
			if g then
				local l = self.byGUID[g]
				if not l then l = {}; self.byGUID[g] = l end
				l[#l + 1] = b
			end
		end
		-- GUID qui n'a plus de cadre (joueur parti, monstre ciblé une fois) : oublié, sinon la table
		-- gardait une liste vide par GUID vu de la soirée
		for g, l in pairs(self.byGUID) do
			if #l == 0 then self.byGUID[g] = nil end
		end
	end
	return self.byGUID[guid]
end

-- Qui est ciblé par un boss (boss1-4) ou par votre cible / focalisation hostile ?
F.bossTargets = {}
local BOSS_UNITS = { "boss1", "boss2", "boss3", "boss4", "target", "focus" }
local BOSS_TARGETS = {}   -- « boss1target »... calculés une fois (pas de chaîne créée 4 fois par seconde)
for i, u in ipairs(BOSS_UNITS) do BOSS_TARGETS[i] = u .. "target" end
function F:UpdateBossTargets()
	wipe(self.bossTargets)
	if not VP.db.indBossTarget then return end
	for i, u in ipairs(BOSS_UNITS) do
		if UnitExists(u) and UnitCanAttack("player", u) and not UnitIsPlayer(u) then
			local g = UnitGUID(BOSS_TARGETS[i])
			if g then self.bossTargets[g] = true end
		end
	end
end

function F:Refresh()
	if self.guide then
	self.guide:Hide()
	self:ReleaseGuide()   -- la taille de la flèche sera recalculée
	end
	for _, b in ipairs(self.buttons) do
		self:LayoutButton(b)
		self:FullUpdate(b)
	end
	if VP.Preview and VP.Preview.Refresh then VP.Preview:Refresh() end
end

function F:OnLogin()
	self:HotSlots()
	for _, id in ipairs(DEFENSIVE_IDS) do local n = GetSpellInfo(id); if n then defNames[n] = true end end
	for _, id in ipairs(HEALRED_IDS) do local n = GetSpellInfo(id); if n then healRedNames[n] = true end end
	for _, id in ipairs(DRINK_IDS) do local n = GetSpellInfo(id); if n then drinkNames[n] = true end end
	soulName = GetSpellInfo(SOULSTONE_ID)
	for _, id in ipairs(SHIELD_IDS) do local n = GetSpellInfo(id); if n then shieldNames[n] = true end end
	sacredName = GetSpellInfo(SACRED_PROC)
	lightwellName = GetSpellInfo(7001)
	for _, id in ipairs(CHARGE_IDS) do
		local n = GetSpellInfo(id)
		if n then chargeNames[n] = true end
	end
	if LibStub then VP.healComm = LibStub("LibHealComm-4.0", true) end
	local rs = HEAL_RANGE_SPELL[VP.class] and GetSpellInfo(HEAL_RANGE_SPELL[VP.class])
	if rs and GetSpellInfo(rs) then self.rangeSpell = rs end
	SetMapToCurrentZone()
	self:BuildGuide()
	for _, ev in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS" }) do
		VP:On(ev, function() lastFix = 0; F:FixMap() end)
	end

	-- Moteur de mise à jour optimisé pour les grands raids :
	--  * événements du jeu -> le cadre concerné est marqué « à rafraîchir » (regroupé à l'image suivante)
	--  * balayage de sécurité réparti sur plusieurs images (round-robin) au lieu de tout faire d'un coup
	--  * minuteurs seulement pour les cadres qui en affichent
	local dirtyH, dirtyA = {}, {}
	local rolePending = {}   -- cadres d'hybrides dont le rôle est à relire (regroupé 4 fois par seconde)
	F.dirtyH, F.dirtyA = dirtyH, dirtyA
	local function mark(set, unit)
		local guid = unit and UnitGUID(unit)
		if not guid then return end
		local list = F:ButtonsFor(guid)
		if list then for i = 1, #list do set[list[i]] = true end end
	end
	local healthEvents = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_MANA", "UNIT_MAXMANA", "UNIT_RAGE", "UNIT_ENERGY",
		"UNIT_RUNIC_POWER", "UNIT_DISPLAYPOWER", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_FLAGS" }
	for _, ev in ipairs(healthEvents) do VP:On(ev, function(_, unit) mark(dirtyH, unit) end) end
	VP:On("PLAYER_FLAGS_CHANGED", function(_, unit) mark(dirtyH, unit) end)
	VP:On("PARTY_MEMBER_DISABLE", function(_, unit) mark(dirtyH, unit) end)
	VP:On("PARTY_MEMBER_ENABLE", function(_, unit) mark(dirtyH, unit) end)
	VP:On("UNIT_AURA", function(_, unit)
		mark(dirtyA, unit)
		-- vos charges (Bouclier d'eau) sont affichées avec la vie : mise à jour immédiate
		if unit == "player" then mark(dirtyH, unit) end
	end)
	-- LibHealComm : la barre de soins entrants suit chaque soin lancé / retardé / arrêté immédiatement,
	-- au lieu d'attendre le balayage de sécurité (0,3 à 0,5 s de retard)
	local hc = VP.healComm
	if hc and hc.RegisterCallback then
		local function markGUID(guid)
			local list = guid and F:ButtonsFor(guid)
			if list then for i = 1, #list do dirtyH[list[i]] = true end end
		end
		-- (événement, lanceur, sort, type, fin ou « interrompu », cibles...)
		local function onHeal(_, _, _, _, _, ...)
			for i = 1, select("#", ...) do markGUID((select(i, ...))) end
		end
		for _, ev in ipairs({ "HealComm_HealStarted", "HealComm_HealUpdated", "HealComm_HealDelayed", "HealComm_HealStopped" }) do
			hc.RegisterCallback(F, ev, onHeal)
		end
		local function onGUID(_, guid) markGUID(guid) end
		hc.RegisterCallback(F, "HealComm_ModifierChanged", onGUID)
		hc.RegisterCallback(F, "HealComm_GUIDDisappeared", onGUID)
	end
	local function allDirty()
		F.mapDirty = true
		for _, b in ipairs(F.buttons) do dirtyH[b] = true; dirtyA[b] = true end
	end
	-- cible / focalisation changée : la carte GUID -> cadres change, et les cadres Cible / Focus
	-- doivent tout redessiner (HoTs, dispel...) sinon ils montrent l'ancien joueur ~1 s
	local function targetChanged()
		F.mapDirty = true
		for _, b in ipairs(F.buttons) do
			dirtyH[b] = true
			if b.vpKind == "target" then dirtyA[b] = true; b.vpRoleDirty = true end
		end
	end
	VP:On("PLAYER_TARGET_CHANGED", targetChanged)
	VP:On("PLAYER_FOCUS_CHANGED", targetChanged)
	-- le boss (ou la focalisation) change de cible : les cadres « Cible du boss » suivent aussitôt.
	-- Seuls les cadres Cible / Focus changent de joueur : inutile de redessiner tout le raid
	-- (la bordure « ciblé par le boss » suit avec le balayage régulier)
	VP:On("UNIT_TARGET", function(_, unit)
		if unit ~= "boss1" and unit ~= "focus" and unit ~= "target" then return end
		F.mapDirty = true
		for _, b in ipairs(F.buttons) do
			if b.vpKind == "target" then dirtyH[b] = true; dirtyA[b] = true; b.vpRoleDirty = true end
		end
	end)
	-- joueur que je suis en train de soigner : bordure le temps de l'incantation
	local function setCast(name)
		if F.castTarget == name then return end
		F.castTarget = name
		for _, b in ipairs(F.buttons) do dirtyH[b] = true end
	end
	VP:On("UNIT_SPELLCAST_SENT", function(_, unit, _, _, target)
		if unit == "player" then setCast(target ~= "" and target or nil) end
	end)
	for _, ev in ipairs({ "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
		"UNIT_SPELLCAST_FAILED_QUIET", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
		VP:On(ev, function(_, unit) if unit == "player" then setCast(nil) end end)
	end
	-- familier invoqué / renvoyé : son GUID change sans changer l'unité du cadre
	-- familier invoqué / renvoyé / changé (démon, goule...) : GUID changé sans changer l'unité du cadre
	VP:On("UNIT_PET", function()
		F.mapDirty = true
		for _, b in ipairs(F.buttons) do
			if F:Kind(b) == "pets" then dirtyH[b] = true; dirtyA[b] = true end
		end
	end)
	VP:On("RAID_ROSTER_UPDATE", allDirty)
	VP:On("PARTY_MEMBERS_CHANGED", allDirty)
	VP:On("PLAYER_ENTERING_WORLD", allDirty)

	local rr, rrA = 1, 1
	local tFast, tMid, accH, accA = 0, 0, 0, 0
	local driver = CreateFrame("Frame")
	driver:SetScript("OnUpdate", function(_, elapsed)
		local list = F.buttons
		local n = #list
		-- cadres de soin coupés (/vp cadres) : rien à mettre à jour, les réafficher redessine tout
		if n == 0 or VP.db.showFrames == false then return end
		if next(F.anim) then F:StepAnim(elapsed) end
		local big = GetNumRaidMembers() > 25
		-- 1. ce que le jeu a signalé
		for b in pairs(dirtyH) do
			dirtyH[b] = nil
			if b:IsVisible() then F:UpdateHealth(b) end
		end
		for b in pairs(dirtyA) do
			dirtyA[b] = nil
			if b:IsVisible() then
				-- une aura peut changer le rôle des classes hybrides : forme (druide : ours, félin, sélénien, arbre),
				-- présence (DK), Fureur vertueuse (paladin), Forme d'ombre (prêtre) ; les classes toujours DPS : non
				-- (cadres Cible / Focus : nouveau joueur derrière la même unité, rôle à relire)
				-- Hybrides : relecture regroupée (4 fois par seconde au plus par cadre) : en raid, UNIT_AURA arrive des
				-- dizaines de fois par seconde et un changement de forme n'a pas besoin d'être vu à l'image près.
				if b.vpRoleDirty then
					b.vpRoleDirty = nil
					F:UpdateRole(b)
				else
					local _, cls = UnitClass(b.unit)
					if HYBRID[cls] then rolePending[b] = true end
				end
				F:UpdateAuras(b)
			end
		end
		-- 2. balayage réparti : tous les cadres en ~0,3 s (0,5 s en raid 40) pour la portée, l'aggro...
		-- plafonné à un tour complet : après un écran de chargement (elapsed de plusieurs secondes),
		-- sans plafond, des milliers de mises à jour partaient dans la même image (gel du jeu)
		accH = math.min(accH + elapsed * n / (big and 0.5 or 0.3), n)
		while accH >= 1 do
			accH = accH - 1
			rr = rr > n and 1 or rr
			local b = list[rr]
			if b:IsVisible() then F:UpdateHealth(b) end
			rr = rr + 1
		end
		-- 3. auras : tous les cadres en ~1 s (1,5 s en raid 40) en plus des événements
		accA = math.min(accA + elapsed * n / (big and 1.5 or 1), n)
		while accA >= 1 do
			accA = accA - 1
			rrA = rrA > n and 1 or rrA
			local b = list[rrA]
			if b:IsVisible() then F:UpdateAuras(b) end
			rrA = rrA + 1
		end
		-- 4. minuteurs et flèches : 10 fois par seconde, seulement là où c'est utile
		tFast = tFast + elapsed
		if tFast >= 0.1 then
			tFast = 0
			for i = 1, n do
				local b = list[i]
				if b.hasTimed and b:IsVisible() then F:UpdateTimers(b) end
				if b.isFar and b:IsVisible() then F:UpdateArrow(b) end
			end
			F:UpdateGuide()
		end
		-- 5. urgence et cibles des boss : 4 fois par seconde
		tMid = tMid + elapsed
		if tMid >= 0.25 then
			tMid = 0
			F:UpdateEmergency()
			F:UpdateBossTargets()
			-- rôles des hybrides dont une aura a changé : redessin seulement si l'icône change
			for b in pairs(rolePending) do
				rolePending[b] = nil
				if b:IsVisible() then
					local oT, oL, oLead = b.roleTex, b.roleL, b.leadTex
					F:UpdateRole(b)
					if b.roleTex ~= oT or b.roleL ~= oL or b.leadTex ~= oLead then dirtyH[b] = true end
				end
			end
		end
	end)

	local function roles()
		F:BuildRanks()   -- chef / assistants (couronne)
		for _, b in ipairs(F.buttons) do
			if b:IsVisible() then F:UpdateRole(b); dirtyH[b] = true end
		end
	end
	-- nouveau chef (promotion, chef parti) : couronne déplacée tout de suite
	VP:On("PARTY_LEADER_CHANGED", roles)
	VP:On("RAID_ROSTER_UPDATE", roles)
	-- symbole posé / retiré : mise à jour immédiate
	VP:On("RAID_TARGET_UPDATE", function()
		for _, b in ipairs(F.buttons) do
			if b:IsVisible() then F:UpdateHealth(b) end
		end
	end)
	VP:On("PARTY_MEMBERS_CHANGED", roles)
	VP:On("PLAYER_ROLES_ASSIGNED", roles)
	-- retour à la vie (relevé, esprit libéré puis corps rejoint) ou écran de chargement : les auras des autres
	-- redeviennent lisibles, rôles relus et icônes redessinées tout de suite
	local function rolesAndPaint()
		F:BuildRanks()
		for _, b in ipairs(F.buttons) do
			if b:IsVisible() then F:UpdateRole(b); dirtyH[b] = true end
		end
	end
	VP:On("PLAYER_ALIVE", rolesAndPaint)
	VP:On("PLAYER_UNGHOST", rolesAndPaint)
	VP:On("PLAYER_ENTERING_WORLD", rolesAndPaint)
	-- Appel (ready check). Les icônes disparaissent quelques secondes après que TOUT LE MONDE a
	-- répondu (ou à la fin de l'appel). On ne dépend plus seulement de READY_CHECK_FINISHED,
	-- qui n'arrive pas toujours (certains serveurs) : on surveille les réponses nous-mêmes.
	local function refreshAll()
		for _, b in ipairs(F.buttons) do
			if b:IsVisible() then F:UpdateHealth(b) end
		end
	end
	local function eachGroupUnit(fn)
		local n = GetNumRaidMembers()
		if n > 0 then
			for i = 1, n do fn("raid" .. i) end
		else
			fn("player")
			for i = 1, GetNumPartyMembers() do fn("party" .. i) end
		end
	end
	-- Comme Grid2 (version 2026) : on ne montre que ce que le jeu nous a VRAIMENT dit, sans jamais inventer de croix.
	-- En 3.3.5, les réponses (READY_CHECK_CONFIRM, GetReadyCheckStatus) n'arrivent qu'au chef et aux assistants :
	-- un soigneur sans droits ne sait rien des autres. Avant, faute d'information, TOUT le monde finissait avec
	-- une croix. Le 1er argument de READY_CHECK_CONFIRM est un NUMÉRO (5 = raid5), pas une unité : chaque
	-- réponse était ignorée.
	-- Relais entre joueurs VuhPlus : en 3.3.5, le SERVEUR n'envoie les réponses qu'au chef et aux assistants.
	--   * chaque joueur VuhPlus annonce sa propre réponse au groupe (« R:1 » / « R:0 ») ;
	--   * un chef / assistant VuhPlus relaie ce que le serveur lui dit (« B:Nom=1,Nom=0,Nom=a »),
	--     au plus une fois par seconde : avec un seul chef ou assistant VuhPlus, tout le raid voit tout.
	-- Rien n'est exécuté à la réception : seulement des noms du groupe et des codes 1 / 0 / a.
	local RC_PREFIX = "VuhPlusRC"
	local CODE = { ready = "1", notready = "0", afk = "a" }
	local FROM_CODE = { ["1"] = "ready", ["0"] = "notready", a = "afk" }
	local initiatorGUID
	local informed   -- le serveur NOUS envoie les réponses (chef / assistant) : on relaie
	local relayed    -- un chef / assistant VuhPlus nous relaie les réponses
	local outbox, outN = {}, 0
	local function queueRelay(u, st)
		if not informed or not u or not CODE[st] then return end
		local nm = UnitName(u)
		if nm and outbox[nm] ~= CODE[st] then
			if not outbox[nm] then outN = outN + 1 end
			outbox[nm] = CODE[st]
		end
	end
	local function flushRelay()
		if outN == 0 then return end
		local ch = VP:GroupChannel()
		local parts, len = {}, 2
		local function send()
			if ch and #parts > 0 then SendAddonMessage(RC_PREFIX, "B:" .. table.concat(parts, ","), ch) end
			wipe(parts); len = 2
		end
		for nm, code in pairs(outbox) do
			local item = nm .. "=" .. code
			if len + #item + 1 > 220 then send() end   -- préfixe + message < 255 caractères
			parts[#parts + 1] = item
			len = len + #item + 1
		end
		send()
		wipe(outbox); outN = 0
	end
	-- une réponse « prêt » n'est jamais remplacée ; une réponse reçue ne redevient pas « en attente » / « sans réponse »
	local function setStatus(g, st, u)
		if not g or not st then return end
		local cur = F.readyStatus[g]
		if cur == st then return end
		if cur == "ready" then return end
		if cur == "notready" and (st == "waiting" or st == "afk") then return end
		F.readyStatus[g] = st
		queueRelay(u, st)
	end
	local function readStatus(u)
		local g = UnitGUID(u)
		-- le chef qui lance l'appel ne reçoit pas de confirmation : il est prêt par définition
		if g and g == initiatorGUID then setStatus(g, "ready", u) return end
		local st = GetReadyCheckStatus(u)
		if st then informed = true end
		setStatus(g, st, u)
	end
	-- unité d'une réponse : numéro (5 -> raid5 / party5) ou unité déjà complète selon les versions
	local function confirmUnit(id)
		if type(id) == "string" and (string.find(id, "^raid") or string.find(id, "^party") or id == "player") then return id end
		local n = tonumber(id)
		if not n then return nil end
		if GetNumRaidMembers() > 0 then return "raid" .. n end
		if n == 0 then return "player" end
		return "party" .. n
	end
	-- chef / assistant : seuls à recevoir les réponses des autres
	local function canSee()
		if GetNumRaidMembers() > 0 then return (IsRaidLeader() or IsRaidOfficer()) and true or false end
		return IsPartyLeader() and true or false
	end
	-- avec des informations sur tout le groupe : sablier pour ceux qui n'ont pas encore répondu
	local function markWaiting()
		eachGroupUnit(function(u)
			local g = UnitGUID(u)
			if g and UnitIsConnected(u) and not F.readyStatus[g] then F.readyStatus[g] = "waiting" end
		end)
	end
	-- ma propre réponse (bouton Prêt / Pas prêt) : connue même sans droits, et annoncée aux autres joueurs VuhPlus
	hooksecurefunc("ConfirmReadyCheck", function(isReady)
		if not F.readyActive then return end
		setStatus(UnitGUID("player"), isReady and "ready" or "notready", "player")
		local ch = VP:GroupChannel()
		if ch then SendAddonMessage(RC_PREFIX, "R:" .. (isReady and "1" or "0"), ch) end
		refreshAll()
	end)
	local function hold() return VP.db.readyHold or 5 end
	local readyStart, readyEnd, finishing = 0, 0, false
	-- fin de l'appel : ceux dont on SAIT qu'ils n'ont pas répondu deviennent « sans réponse »
	local function finish()
		if not F.readyActive or finishing then return end
		finishing = true
		eachGroupUnit(readStatus)   -- dernières réponses arrivées juste avant la fin
		local notReady, noAnswer, unknown = nil, nil, 0
		eachGroupUnit(function(u)
			local g = UnitGUID(u)
			if not g then return end
			local st = F.readyStatus[g]
			local nm = UnitName(u)
			if not UnitIsConnected(u) then
				F.readyStatus[g] = nil
			elseif st == "waiting" then
				setStatus(g, "afk", u)
				if nm then noAnswer = (noAnswer and (noAnswer .. ", ") or "") .. nm end
			elseif st == "notready" then
				if nm then notReady = (notReady and (notReady .. ", ") or "") .. nm end
			elseif st == nil then
				unknown = unknown + 1   -- aucune information : pas d'icône, jamais de croix
			end
		end)
		flushRelay()   -- les « sans réponse » partent tout de suite aux autres joueurs VuhPlus
		if VP.db.showReadyCheck and (informed or relayed) then
			if notReady then VP:Print("|cffff5555Pas prêts :|r " .. notReady) end
			if noAnswer then VP:Print("|cffff9933Sans réponse :|r " .. noAnswer) end
			if not notReady and not noAnswer and unknown == 0 then VP:Print("|cff55ff55Tout le monde est prêt.|r") end
		end
		F.readyHideAt = GetTime() + hold()
		refreshAll()
	end
	VP:On("READY_CHECK", function(_, initiator, duration)
		wipe(F.readyStatus)
		wipe(outbox); outN = 0
		F.readyActive, finishing = true, false
		informed, relayed = canSee(), false
		readyStart = GetTime()
		readyEnd = readyStart + (tonumber(duration) or 30)
		F.readyHideAt = readyEnd + hold() + 5   -- sécurité absolue
		-- qui a lancé l'appel (nom, éventuellement « Nom-Royaume ») : son GUID
		initiatorGUID = nil
		if initiator and initiator ~= "" then
			local short = string.match(initiator, "^([^%-]+)") or initiator
			eachGroupUnit(function(u)
				if not initiatorGUID and UnitName(u) == short then initiatorGUID = UnitGUID(u) end
			end)
		end
		-- avec les droits : tout le monde « en attente » au départ (sablier), comme l'interface Blizzard
		if informed then markWaiting() end
		eachGroupUnit(readStatus)
		refreshAll()
	end)
	-- READY_CHECK_CONFIRM : (numéro de l'unité, prêt ?) : la réponse est lue dans l'événement lui-même
	VP:On("READY_CHECK_CONFIRM", function(_, id, isReady)
		if not F.readyActive then return end
		local unit = confirmUnit(id)
		local g = unit and UnitGUID(unit)
		if g then
			if not informed then informed = true; markWaiting() end
			if isReady and isReady ~= 0 then
				setStatus(g, "ready", unit)
			else
				local st = GetReadyCheckStatus(unit)
				setStatus(g, (st == "ready") and "ready" or "notready", unit)
			end
		else
			eachGroupUnit(readStatus)
		end
		refreshAll()
	end)
	VP:On("READY_CHECK_FINISHED", function() finish() end)
	-- réponses relayées par les autres joueurs VuhPlus
	VP:On("CHAT_MSG_ADDON", function(_, prefix, msg, _, sender)
		if prefix ~= RC_PREFIX or not F.readyActive or type(msg) ~= "string" or not sender then return end
		sender = string.match(sender, "^([^%-]+)") or sender
		if sender == UnitName("player") then return end
		local own = string.match(msg, "^R:([10])$")
		if own then
			setStatus(UnitGUID(sender), FROM_CODE[own])
			refreshAll()
			return
		end
		local list = string.match(msg, "^B:(.+)$")
		if not list then return end
		-- relais d'un chef / assistant : on a maintenant des informations sur tout le groupe
		if not relayed then relayed = true; markWaiting() end
		for nm, code in string.gmatch(list, "([^,=]+)=([10a])") do
			local g = UnitGUID(nm)   -- nom d'un membre du groupe -> son GUID (sinon ignoré)
			if g then setStatus(g, FROM_CODE[code]) end
		end
		refreshAll()
	end)
	-- entrée en combat (pull juste après l'appel) : icônes retirées tout de suite, comme Grid2
	VP:On("PLAYER_REGEN_DISABLED", function()
		if not F.readyActive then return end
		F.readyActive, finishing, F.readyHideAt = nil, false, nil
		wipe(F.readyStatus)
		wipe(outbox); outN = 0
		refreshAll()
	end)
	local rcf, acc, accRelay = CreateFrame("Frame"), 0, 0
	rcf:SetScript("OnUpdate", function(_, e)
		if not F.readyActive then return end
		local now = GetTime()
		if F.readyHideAt and now > F.readyHideAt then
			F.readyHideAt = nil
			F.readyActive, finishing = nil, false
			wipe(F.readyStatus)
			wipe(outbox); outN = 0
			refreshAll()
			return
		end
		-- relais groupé : au plus un message par seconde (même pendant la fin de l'appel)
		accRelay = accRelay + e
		if accRelay >= 1 then accRelay = 0; flushRelay() end
		if finishing then return end
		acc = acc + e
		if acc < 0.5 then return end
		acc = 0
		-- tout le monde a répondu ? Seulement si on a des informations sur tout le groupe
		-- (sinon : fin de l'appel ou délai écoulé)
		local waiting = 0
		eachGroupUnit(function(u)
			readStatus(u)
			local g = UnitGUID(u)
			if g and UnitIsConnected(u) and F.readyStatus[g] == "waiting" then waiting = waiting + 1 end
		end)
		if ((informed or relayed) and waiting == 0) or now > readyEnd then
			finish()
		end
	end)
end
