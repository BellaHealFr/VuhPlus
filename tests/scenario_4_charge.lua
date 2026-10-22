-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- Scénario 4 : charge d'un raid 25 en combat (2 minutes, 30 images par seconde, événements en rafale)
local me = SIM_UNIT({ name = "Bella", class = "PRIEST", talents = { 10, 51, 0 } })
for _, n in ipairs({ "Dissipation de la magie", "Soins inférieurs", "Rénovation", "Mot de pouvoir : Bouclier" }) do W.spellbook[n] = true end
BOOT(me, nil)
local classes = { "WARRIOR", "DRUID", "PALADIN", "SHAMAN", "MAGE", "ROGUE", "HUNTER", "WARLOCK", "DEATHKNIGHT", "PRIEST" }
local raid = { me }
for i = 1, 24 do raid[#raid + 1] = SIM_UNIT({ name = "J" .. i, class = classes[i % 10 + 1], subgroup = math.floor(i / 5) + 1 }) end
SIM_SETRAID(raid)
SIM_FIRE("RAID_ROSTER_UPDATE")
for i = 1, #raid do
	local b = CreateFrame("Button", nil, VuhPlus.Panels.groups[1], "VuhPlusUnitTemplate")
	b:SetAttribute("unit", "raid" .. i)
	-- deux HoTs à moi, un défensif et un débuff de soins réduits sur chacun
	BUFF(raid[i], 139, { caster = "player", dur = 15, exp = W.now + 15, icon = "R" })
	BUFF(raid[i], 17, { caster = "player", dur = 30, exp = W.now + 30, icon = "B" })
	BUFF(raid[i], 871, { dur = 12, exp = W.now + 12, icon = "D", name = "Mur protecteur" })
end
SIM_RUN(2)
SIM_COMBAT(true)
collectgarbage("collect")
collectgarbage("stop")
local mem0, t0 = collectgarbage("count"), os.clock()
for s = 1, 120 do
	-- chaque seconde : vie et auras de tout le raid changent plusieurs fois
	for k = 1, 3 do
		for i = 1, #raid do
			raid[i].hp = 8000 + ((s * 7 + i * 13 + k) % 12000)
			SIM_FIRE("UNIT_HEALTH", "raid" .. i)
			SIM_FIRE("UNIT_AURA", "raid" .. i)
		end
		SIM_RUN(1 / 3, 1 / 30)
	end
end
local cpu, mem = os.clock() - t0, collectgarbage("count") - mem0
collectgarbage("restart")
SIM_COMBAT(false)
LOG(string.format("  2 min de combat en raid 25 : %.2f s de processeur (faux client compris), %.0f Ko alloués", cpu, mem))
CHECK("aucune erreur pendant la charge", #ERRORS == 0, ERRORS[1])
FINISH("Scénario 4 : charge raid 25")
