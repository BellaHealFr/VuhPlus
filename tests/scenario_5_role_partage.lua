-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- Scénario 5 : rôle partagé entre joueurs VuhPlus (5.9.0)
local me = SIM_UNIT({ name = "Bella", class = "PRIEST", talents = { 10, 51, 0 } })
W.spellbook["Soins inférieurs"] = true
BOOT(me, nil)
local pal = SIM_UNIT({ name = "Lumen", class = "PALADIN", talents = { 5, 51, 15 } })
pal.inRange = false   -- trop loin pour être inspecté (28 m)
local sham = SIM_UNIT({ name = "Remous", class = "SHAMAN", talents = { 0, 15, 56 } })
SIM_SETRAID({ me, pal, sham })
SIM_FIRE("RAID_ROSTER_UPDATE")
local R = VuhPlus.Roles

-- 1. j'envoie ma spé au groupe peu après l'arrivée dans le raid
local n0 = #ADDONMSG
SIM_RUN(8)
local mine
for i = n0 + 1, #ADDONMSG do if ADDONMSG[i].prefix == "VuhPlusRole" then mine = ADDONMSG[i] end end
CHECK("ma spé est envoyée au raid (« T:2 », Sacré)", mine and mine.msg == "T:2" and mine.ch == "RAID", mine and mine.msg)

-- 2. un paladin VuhPlus hors de portée d'inspection envoie sa spé : rôle connu tout de suite
CHECK("paladin hors de portée : rôle inconnu sans partage", R:GetRole("raid2") == nil, R:GetRole("raid2"))
SIM_FIRE("CHAT_MSG_ADDON", "VuhPlusRole", "T:2", "RAID", "Lumen")
CHECK("paladin : rôle TANK reçu (arbre Protection)", R:GetRole("raid2") == "TANK", R:GetRole("raid2"))

-- 3. un joueur partagé n'est plus inspecté ; les autres le sont toujours
local inspected = {}
for _ = 1, 10 do
	SIM_RUN(2.05)
	if W.inspect then inspected[W.inspect.name] = true; W.inspectDone = W.inspect; SIM_FIRE("INSPECT_TALENT_READY") end
end
CHECK("joueur VuhPlus partagé : jamais inspecté", not inspected.Lumen)
CHECK("joueur sans VuhPlus : toujours inspecté", inspected.Remous == true)
CHECK("chaman inspecté : soigneur", R:GetRole("raid3") == "HEALER", R:GetRole("raid3"))

-- 4. changement de spé du paladin : nouveau message, rôle suivi aussitôt
SIM_FIRE("CHAT_MSG_ADDON", "VuhPlusRole", "T:1", "RAID", "Lumen")
CHECK("paladin passe Sacré : rôle SOIGNEUR immédiat", R:GetRole("raid2") == "HEALER", R:GetRole("raid2"))

-- 5. messages invalides ou d'inconnus ignorés
SIM_FIRE("CHAT_MSG_ADDON", "VuhPlusRole", "T:9", "RAID", "Lumen")
SIM_FIRE("CHAT_MSG_ADDON", "VuhPlusRole", "T:1;os.exit()", "RAID", "Lumen")
SIM_FIRE("CHAT_MSG_ADDON", "VuhPlusRole", "T:3", "RAID", "Inconnu")
CHECK("messages invalides ou hors du groupe ignorés", R:GetRole("raid2") == "HEALER" and #ERRORS == 0, ERRORS[1])

-- 6. partage coupé : rien n'est envoyé ni lu
VuhPlusDB.roleShare = false
local n1 = #ADDONMSG
R:QueueShare(0); SIM_RUN(1)
local sent = 0
for i = n1 + 1, #ADDONMSG do if ADDONMSG[i].prefix == "VuhPlusRole" then sent = sent + 1 end end
CHECK("partage coupé : aucun message envoyé", sent == 0, sent)
SIM_FIRE("CHAT_MSG_ADDON", "VuhPlusRole", "T:2", "RAID", "Lumen")
CHECK("partage coupé : message reçu ignoré", R:GetRole("raid2") == "HEALER", R:GetRole("raid2"))

-- 7. mon propre changement de spé part tout de suite
VuhPlusDB.roleShare = true
me.talents = { 51, 10, 0 }
local n2 = #ADDONMSG
SIM_FIRE("PLAYER_TALENT_UPDATE"); SIM_RUN(4)
local last
for i = n2 + 1, #ADDONMSG do if ADDONMSG[i].prefix == "VuhPlusRole" then last = ADDONMSG[i].msg end end
CHECK("ma nouvelle spé (Discipline) est envoyée", last == "T:1", last)
FINISH("Scénario 5 : rôle partagé entre joueurs VuhPlus")
