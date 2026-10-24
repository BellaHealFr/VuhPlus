-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- Scénario 1 : démarrage complet, raid de 10, minute de jeu, fenêtre de configuration et mode test
local me = SIM_UNIT({ name = "Bella", class = "PRIEST", talents = { 10, 51, 0 } })
for _, n in ipairs({ "Dissipation de la magie", "Soins rapides", "Soins supérieurs", "Rénovation", "Mot de pouvoir : Bouclier",
	"Soins inférieurs", "Résurrection", "Prière de guérison", "Abolir maladie" }) do W.spellbook[n] = true end
BOOT(me, nil)
CHECK("chargement des 27 fichiers et démarrage sans erreur", #ERRORS == 0, ERRORS[1])
CHECK("message de bienvenue affiché", PRINTS[1] and PRINTS[1]:find("chargé") ~= nil, PRINTS[1])
CHECK("version 5.9.1", VuhPlus.version == "5.9.1", VuhPlus.version)

local classes = { "WARRIOR", "DRUID", "PALADIN", "SHAMAN", "MAGE", "ROGUE", "HUNTER", "WARLOCK", "DEATHKNIGHT" }
local raid = { me }
for i, c in ipairs(classes) do raid[#raid + 1] = SIM_UNIT({ name = "Joueur" .. i, class = c, subgroup = math.floor(i / 5) + 1 }) end
SIM_SETRAID(raid)
SIM_FIRE("RAID_ROSTER_UPDATE")
-- un cadre par membre (comme les en-têtes sécurisés)
for i = 1, #raid do
	local b = CreateFrame("Button", nil, VuhPlus.Panels.groups[1], "VuhPlusUnitTemplate")
	b:SetAttribute("unit", "raid" .. i)
end
CHECK("cadres créés pour le raid", #VuhPlus.Frames.buttons >= 10, #VuhPlus.Frames.buttons)
-- débuff magique sur un joueur : alerte de dispel
table.insert(raid[5].debuffs, { name = "Peur", dtype = "Magic", dur = 8, exp = W.now + 8, icon = "X" })
SIM_FIRE("UNIT_AURA", "raid5")
SIM_RUN(60, 0.05)
CHECK("une minute de jeu sans erreur", #ERRORS == 0, ERRORS[1])
local dt = VuhPlus.Dispel:Scan("raid5")
CHECK("Dispel : débuff magique reconnu pour un prêtre", dt == "Magic", dt)
local tracked = VuhPlus.Dispel.afflicted[raid[5].guid]
CHECK("liste « À dissiper » : le joueur y figure", tracked ~= nil)
CHECK("son d'alerte de dispel joué", #SOUNDS > 0, #SOUNDS)

-- combat de 30 s puis sortie
SIM_COMBAT(true); SIM_RUN(30, 0.05); SIM_COMBAT(false); SIM_RUN(2)
CHECK("combat de 30 s sans erreur", #ERRORS == 0, ERRORS[1])

-- fenêtre de configuration : toutes les pages, recherche
VuhPlus.UI:Open()
VuhPlus.UI:BuildAllPages()
for _, t in ipairs(VuhPlus.UI.tabs) do VuhPlus.UI:Select(t) end
local res = VuhPlus.UI:Search("bouclier")
CHECK("les " .. #VuhPlus.UI.tabs .. " pages de la configuration se construisent", #ERRORS == 0, ERRORS[1])
CHECK("recherche « bouclier » : des résultats", res and #res > 0, res and #res)
local res2 = VuhPlus.UI:Search("decurse")
CHECK("recherche par synonyme « decurse » : page Dispel", res2 and res2[1] and res2[1].tab.id == "dispel")
VuhPlus.UI.window:Hide()

-- mode test 40 joueurs
VuhPlus.Preview:Show(40); SIM_RUN(3); VuhPlus.Preview:Hide()
CHECK("mode test 40 joueurs sans erreur", #ERRORS == 0, ERRORS[1])

-- commandes
for _, c in ipairs({ "help", "dispel", "perf", "cd", "cd", "silence", "silence", "conso", "outils", "outils", "lock", "unlock", "reset" }) do
	SlashCmdList.VUHPLUS(c)
end
CHECK("commandes /vp sans erreur", #ERRORS == 0, ERRORS[1])

-- déconnexion : réglages du personnage rangés
SIM_FIRE("PLAYER_LOGOUT")
CHECK("réglages par personnage enregistrés", VuhPlusDB.chars["Bella - Royaume"] ~= nil)
FINISH("Scénario 1 : démarrage, raid de 10, configuration, mode test")
