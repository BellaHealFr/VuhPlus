-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Couleurs personnalisables (inspiré de la page Couleurs de VuhDo)
local VP = VuhPlus
local CO = VP:NewModule("Colors")

-- Valeurs par défaut { r, g, b } ; les options booléennes bg / text indiquent où la couleur s'applique
CO.DEFAULTS = {
	debuff = {
		Poison  = { 0.0, 0.6, 0.0, bg = true, text = true },
		Disease = { 0.6, 0.4, 0.0, bg = true, text = true },
		Curse   = { 0.6, 0.0, 1.0, bg = true, text = true },
		Magic   = { 0.2, 0.6, 1.0, bg = true, text = true },
		Custom  = { 0.9, 0.45, 0.1, bg = true, text = true },   -- débuffs de boss / liste perso
	},
	dead     = { 0.35, 0.12, 0.12 },
	charmed  = { 1.0, 0.25, 0.8 },
	offline  = { 0.30, 0.30, 0.32 },
	gcd      = { 0.2, 0.85, 0.55 },
	bossTarget = { 1, 0.1, 0.6 },
	arrow = { 1, 0.85, 0.1 },               -- flèche de direction           -- bordure « ciblé par le boss »
	incoming = { 0.3, 1.0, 0.45 },
	absorb   = { 0.85, 0.95, 1.0 },        -- barre des boucliers
	spike    = { 1.0, 0.1, 0.1 },          -- dégâts brutaux
	assign   = { 0.3, 0.8, 1.0 },          -- mes cibles assignées
	cast     = { 1.0, 0.85, 0.2 },         -- joueur que je suis en train de soigner
	urgent   = { 1.0, 0.15, 0.15 },
	notUrgent= { 1.0, 0.55, 0.1 },
	good     = { 0.15, 0.85, 0.2 },
	fair     = { 1.0, 0.85, 0.1 },
	low      = { 0.9, 0.15, 0.15 },
	solid    = { 0.2, 0.78, 0.35 },
	power = {
		[0] = { 0.25, 0.52, 1 },   -- mana
		[1] = { 0.95, 0.22, 0.22 },-- rage
		[3] = { 1, 0.9, 0.3 },     -- énergie
		[6] = { 0, 0.82, 1 },      -- puissance runique
		[2] = { 1, 0.55, 0.25 },   -- focus (familiers)
	},
	hotWarn  = { 1.0, 0.25, 0.25 },        -- HoT qui expire
	-- charges restantes (Bouclier de terre, Prière de guérison) : rouge à 1, jaune à 2, vert à 3 et plus
	charge   = { [1] = { 1, 0.2, 0.2 }, [2] = { 1, 0.85, 0.1 }, [3] = { 0.3, 1, 0.4 }, [4] = { 0.3, 1, 0.4 } },
	pet      = { 0.3, 0.75, 0.3 },
	class    = {},   -- vide = couleurs Blizzard
	raid = {
		{ 1, 0.9, 0.1, bg = true, text = true }, { 1, 0.5, 0.1, bg = true, text = true },
		{ 0.8, 0.3, 1, bg = true, text = true }, { 0.2, 0.9, 0.2, bg = true, text = true },
		{ 0.75, 0.8, 0.9, bg = true, text = true }, { 0.2, 0.6, 1, bg = true, text = true },
		{ 1, 0.2, 0.2, bg = true, text = true }, { 1, 1, 1, bg = true, text = true },
	},
}

VP.defaults.colors = CO.DEFAULTS

CO.CLASS_LIST = {
	{ "WARRIOR", "Guerriers" }, { "WARLOCK", "Démonistes" }, { "ROGUE", "Voleurs" }, { "SHAMAN", "Chamans" },
	{ "HUNTER", "Chasseurs" }, { "DRUID", "Druides" }, { "PALADIN", "Paladins" }, { "PRIEST", "Prêtres" },
	{ "MAGE", "Mages" }, { "DEATHKNIGHT", "Chevaliers de la mort" },
}

function CO:Get(path, sub)
	local c = VP.db.colors[path]
	if sub ~= nil then c = c and c[sub] end
	return c
end

-- Couleur de classe (personnalisée ou Blizzard)
function CO:Class(class)
	local c = class and VP.db.colors.class[class]
	if c then return c[1], c[2], c[3] end
	local b = class and RAID_CLASS_COLORS[class]
	if b then return b.r, b.g, b.b end
	return 0.5, 0.5, 0.5
end

function CO:SetClass(class, r, g, b)
	VP.db.colors.class[class] = { r, g, b }
end

function CO:Debuff(dtype)
	local c = VP.db.colors.debuff[dtype] or VP.db.colors.debuff.Custom
	return c
end

-- Remise à zéro de toutes les couleurs
function CO:Reset()
	-- remise à zéro SUR PLACE : l'onglet Couleurs garde un lien vers cette table
	local c = VP.db.colors
	wipe(c)
	for k, v in pairs(self.DEFAULTS) do c[k] = VP.deepCopy(v) end
	VP:RefreshAll()
end
