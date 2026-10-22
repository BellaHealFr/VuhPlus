-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- Scénario 2 : tri par rôle (blocs Tanks / Soigneurs / DPS) avec un druide tank qui change de forme
local me = SIM_UNIT({ name = "Bella", class = "PRIEST", talents = { 10, 51, 0 } })
W.spellbook["Soins inférieurs"] = true
BOOT(me, nil)
local ours = SIM_UNIT({ name = "Ourson", class = "DRUID", ptype = 1, talents = { 0, 55, 16 } })
local mage = SIM_UNIT({ name = "Givre", class = "MAGE" })
local rogue = SIM_UNIT({ name = "Lame", class = "ROGUE" })
SIM_SETRAID({ me, ours, mage, rogue })
BUFF(ours, 9634)   -- Forme d'ours redoutable
VuhPlusDB.sortMode = "ROLE"
SIM_FIRE("RAID_ROSTER_UPDATE")

-- inspection discrète (deux lectures identiques sont nécessaires)
for _ = 1, 12 do
	SIM_RUN(2.05)
	if W.inspect then W.inspectDone = W.inspect; SIM_FIRE("INSPECT_TALENT_READY") end
end
local R, P = VuhPlus.Roles, VuhPlus.Panels
CHECK("druide inspecté : arbre Combat farouche retenu", R.trees[ours.guid] == 2, R.trees[ours.guid])
SIM_RUN(6)
local function block() -- 1 = Tanks, 2 = Soigneurs, 3 = DPS
	for i = 1, 3 do if inList(P.groups[i]:GetAttribute("nameList"), "Ourson") then return i end end
end
CHECK("en forme d'ours : bloc Tanks", block() == 1, block())

-- 1. hors combat, forme de félin 40 s (déplacement entre deux packs) : plus long que les 30 s du seuil
ours.ptype = 3; UNBUFF(ours, 9634); BUFF(ours, 768)
SIM_FIRE("UNIT_AURA", "raid2"); SIM_FIRE("UNIT_DISPLAYPOWER", "raid2")
SIM_RUN(40)
LOG("  (félin hors combat 40 s : rôle lu = " .. tostring(R:GetRole("raid2")) .. ", bloc " .. tostring(block()) .. ")")
CHECK("félin 40 s hors combat : reste dans le bloc Tanks", block() == 1, block())
ours.ptype = 1; UNBUFF(ours, 768); BUFF(ours, 9634); SIM_RUN(6)

-- 2. en combat, félin 10 s puis retour en ours
SIM_COMBAT(true)
ours.ptype = 3; UNBUFF(ours, 9634); BUFF(ours, 768); SIM_FIRE("UNIT_AURA", "raid2")
SIM_RUN(10)
ours.ptype = 1; UNBUFF(ours, 768); BUFF(ours, 9634); SIM_FIRE("UNIT_AURA", "raid2")
SIM_RUN(5)
SIM_COMBAT(false); SIM_RUN(6)
CHECK("félin 10 s en combat : reste tank", R:GetRole("raid2") == "TANK" and block() == 1, block())

-- 3. en combat, félin plus de 30 s : il joue vraiment DPS
SIM_COMBAT(true)
ours.ptype = 3; UNBUFF(ours, 9634); BUFF(ours, 768); SIM_FIRE("UNIT_AURA", "raid2")
SIM_RUN(35)
CHECK("félin 35 s en combat : rôle DPS", R:GetRole("raid2") == "DAMAGER", R:GetRole("raid2"))
SIM_COMBAT(false); SIM_RUN(6)
CHECK("après le combat : bloc DPS", block() == 3, block())

-- 4. il repasse ours pour tanker le combat suivant : rôle tank retrouvé au bout de 30 s de combat en ours
SIM_COMBAT(true)
ours.ptype = 1; UNBUFF(ours, 768); BUFF(ours, 9634); SIM_FIRE("UNIT_AURA", "raid2")
SIM_RUN(32)
SIM_COMBAT(false); SIM_RUN(6)
CHECK("retour en ours 32 s en combat : bloc Tanks", block() == 1, block())

-- 5. changement de spé : la nouvelle forme compte tout de suite
ours.ptype = 3; UNBUFF(ours, 9634); BUFF(ours, 768)
SIM_FIRE("UNIT_SPELLCAST_SUCCEEDED", "raid2", "Activation de la spécialisation secondaire")
CHECK("changement de spé : rôle relu immédiatement (DPS en félin)", R:GetRole("raid2") == "DAMAGER", R:GetRole("raid2"))
FINISH("Scénario 2 : druide tank et tri par rôle")
