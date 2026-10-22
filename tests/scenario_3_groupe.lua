-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- Scénario 3 : fonctions de groupe et données reçues d'autres joueurs
local me = SIM_UNIT({ name = "Bella", class = "PRIEST", talents = { 10, 51, 0 } })
W.spellbook["Soins inférieurs"] = true
BOOT(me, nil)
local tank = SIM_UNIT({ name = "Tankor", class = "WARRIOR" })
local mage = SIM_UNIT({ name = "Givre", class = "MAGE" })
SIM_SETPARTY({ tank, mage })
W.leader = tank   -- je ne suis PAS le chef du groupe
SIM_FIRE("PARTY_MEMBERS_CHANGED")
SIM_RUN(1)

-- 1. Rapport de mort annoncé au groupe : seul le chef doit l'envoyer
VuhPlusDB.alerts.deathReport = "GROUP"
local n0 = #CHAT
SIM_FIRE("COMBAT_LOG_EVENT_UNFILTERED", W.now, "SPELL_DAMAGE", "0xF1", "Saurfang", 0x848, mage.guid, "Givre", 0x514, 72410, "Coup", 1, 45000)
SIM_FIRE("COMBAT_LOG_EVENT_UNFILTERED", W.now, "UNIT_DIED", nil, nil, 0, mage.guid, "Givre", 0x514)
SIM_RUN(3)
local sent = #CHAT - n0
CHECK("mort en groupe de 5, je ne suis pas chef : rien envoyé au groupe", sent == 0, sent .. " message(s) envoyé(s)")
local printed = false
for _, p in ipairs(PRINTS) do if p:find("Givre est mort") then printed = true end end
CHECK("le rapport reste dans mon chat", printed)
W.leader = me
SIM_FIRE("COMBAT_LOG_EVENT_UNFILTERED", W.now, "UNIT_DIED", nil, nil, 0, tank.guid, "Tankor", 0x514)
SIM_RUN(3)
CHECK("je suis chef : la mort est annoncée au groupe", #CHAT - n0 == 1 and CHAT[#CHAT].ch == "PARTY", #CHAT - n0)

-- 2. Appel (ready check) : relais d'un autre joueur VuhPlus
W.leader = tank
SIM_FIRE("READY_CHECK", "Tankor", 30)
SIM_FIRE("CHAT_MSG_ADDON", "VuhPlusRC", "B:Givre=0,Tankor=1", "PARTY", "Tankor")
local F = VuhPlus.Frames
CHECK("appel : réponse relayée « pas prêt » de Givre", F.readyStatus[mage.guid] == "notready", F.readyStatus[mage.guid])
CHECK("appel : réponse relayée « prêt » de Tankor", F.readyStatus[tank.guid] == "ready", F.readyStatus[tank.guid])
SIM_FIRE("CHAT_MSG_ADDON", "VuhPlusRC", "B:Inconnu=1,|cff00ff00Pirate=1", "PARTY", "Tankor")
CHECK("appel : noms hors du groupe ignorés", #ERRORS == 0, ERRORS[1])
SIM_FIRE("READY_CHECK_FINISHED")
SIM_RUN(8)
CHECK("appel : icônes retirées après le délai", not F.readyActive)

-- 3. Recharges partagées reçues d'un autre joueur VuhPlus
SIM_FIRE("CHAT_MSG_ADDON", "VuhPlusCD", "S:47788=95,33206=0,99999=5,abc", "PARTY", "Givre")
local CD = VuhPlus.Cooldowns
CHECK("recharges reçues : Esprit gardien dans 95 s", CD.ready[mage.guid] and math.abs(CD.ready[mage.guid][47788] - (W.now + 95)) < 0.01)
CHECK("recharges reçues : identifiant inconnu ignoré", CD.ready[mage.guid][99999] == nil)

-- 4. Import de profil : texte piégé jamais exécuté, valeurs bornées
local SH = VuhPlus.Share
local ok1 = SH:Import('VUHPLUS1:{"width"=#99999;"hpHeight"="x";"locked"=T;"inconnu"=#1;}', "Test")
local p = VuhPlusDB.profiles.Test
CHECK("import : largeur bornée à 300", ok1 and p.width == 300, p and p.width)
CHECK("import : valeur du mauvais type retirée", p and p.hpHeight == nil)
CHECK("import : clé inconnue retirée", p and p.inconnu == nil)
local ok2 = SH:Import('VUHPLUS1:{"width"=os.exit();}', "Piege")
CHECK("import : code Lua refusé (jamais exécuté)", not ok2)
local data = SH:Deserialize(SH:Serialize({ a = { 1, 2, "x|y\n\"z\"" }, b = true, c = -1.5e3 }))
CHECK("export puis import : données identiques", data and data.a[3] == "x|y\n\"z\"" and data.b == true and data.c == -1500)

-- 5. Macros : vérification
local M = VuhPlus.Macros
local issues = M:Check("/cast [@vp,ded] Soins rapides\n/script print(1)")
local found = {}
for _, r in ipairs(issues) do found[#found + 1] = r[2] end
local all = table.concat(found, " | ")
CHECK("macro : faute de frappe « ded » signalée", all:find("ded", 1, true) ~= nil, all)
CHECK("macro : /script signalé", all:find("exécute du code", 1, true) ~= nil, all)
CHECK("macro : conversion du survol en @vp", M:Convert("/cast [@mouseover] Soins rapides") == "/cast [@vp] Soins rapides")

FINISH("Scénario 3 : groupe, appel, recharges, import, macros")
