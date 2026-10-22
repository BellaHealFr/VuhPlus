-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Contenu de la fenêtre de configuration (/vp)
-- Une fonction = une page qui contient tout ce qui la concerne (touche, affichage, son, fenêtre).
-- Les pages « Fenêtres à l'écran » et « Sons et alertes » sont des vues d'ensemble : chaque ligne
-- est le même réglage que sur la page de la fonction, avec un lien vers elle.
local VP = VuhPlus
local O = VP:NewModule("Options")
local UI = VP.UI

local function layout() VP.Frames:Refresh(); VP.Panels:ApplyLayout() end
local function db() return VP.db end
local I = "Interface\\Icons\\"

-- Mode test (5 / 10 / 25 / 40 joueurs), réutilisé sur plusieurs onglets
local function testButtons(p)
	local PV = VP.Preview
	p:Chips("Mode test : afficher un faux groupe pour voir le résultat", {
		{ 0, "Arrêt (réel)" }, { 5, "5 joueurs" }, { 10, "10 joueurs" }, { 25, "25 joueurs" }, { 40, "40 joueurs" },
	}, function() return PV.shown and PV.size or 0 end, function(v)
		if v == 0 then PV:Hide() else PV:Show(v); PV.fromUI = true end
		if UI.footRefresh then UI.footRefresh() end
	end, 5)
end

local CLASS_FR = { PALADIN = "Paladin", PRIEST = "Prêtre", DRUID = "Druide", SHAMAN = "Chaman", MAGE = "Mage" }

-- =====================================================================================
-- DÉMARRER
-- =====================================================================================

UI:AddTab("home", "Accueil", function(p)
	p:Title("Que voulez-vous faire ?", "Cliquez sur une tâche : la bonne page s'ouvre et le réglage s'illumine. "
		.. "Pour tout le reste, tapez un mot dans la recherche en haut à gauche (ex. « bouclier », « portée », « son »).")
	p:Tasks({
		{ label = "Dissiper en cliquant sur un cadre", where = "Dispel  »  Votre touche", tab = "dispel", anchor = "key", icon = I .. "Spell_Holy_DispelMagic" },
		{ label = "Choisir le sort de chaque clic", where = "Clics et touches", tab = "clicks", anchor = "mouse", icon = I .. "Spell_Holy_FlashHeal" },
		{ label = "Agrandir ou réduire les cadres", where = "Taille et disposition  »  Préréglages", tab = "dims", anchor = "presets", icon = I .. "INV_Misc_Spyglass_03" },
		{ label = "Suivre mes HoTs sur les joueurs", where = "HoTs suivis", tab = "hots", anchor = "slots", icon = I .. "Spell_Holy_Renew" },
		{ label = "Couper ou tester les sons", where = "Sons et alertes", tab = "alerts", anchor = "quiet", icon = I .. "Ability_Warrior_BattleShout" },
		{ label = "Afficher ou cacher une fenêtre", where = "Fenêtres à l'écran", tab = "panels", anchor = "windows", icon = I .. "INV_Misc_Bag_08" },
		{ label = "Voir les recharges du raid", where = "Recharges et annonces", tab = "cds", anchor = "cd", icon = I .. "Spell_Nature_Reincarnation" },
		{ label = "Être prévenu des débuffs de boss", where = "Débuffs de boss", tab = "debuffs", anchor = "options", icon = I .. "Spell_Shadow_DeathScream" },
		{ label = "Changer les couleurs et la police", where = "Style et couleurs", tab = "look", anchor = "main", icon = I .. "INV_Misc_Gem_Variety_01" },
		{ label = "Partager mes réglages", where = "Profils  »  Partager", tab = "profiles", anchor = "share", icon = I .. "INV_Misc_Note_01" },
	})

	p:Section("Premiers pas", { desc = "4 étapes, 2 minutes" })
	p:Note("1. Lancez le mode test : un faux raid apparaît pour régler l'affichage sans être en groupe.\n"
		.. "2. Déplacez les cadres où vous voulez (poignées au-dessus des panneaux), puis verrouillez-les.\n"
		.. "3. Choisissez vos sorts sur chaque clic de souris.\n"
		.. "4. Enregistrez votre réglage dans un profil, pour le retrouver ou le partager.")
	p:Buttons({
		{ "1. Mode test", function()
			local PV = VP.Preview
			if PV.shown then PV:Hide() else PV:Show(25); PV.fromUI = true end
			if UI.footRefresh then UI.footRefresh() end
		end, 130, true },
		{ "2. Déplacer les cadres", function()
			db().locked = not db().locked
			VP:RefreshAll()
			if UI.footRefresh then UI.footRefresh() end
			UI:RefreshCurrent()
		end, 160 },
		{ "3. Mes clics", function() UI:Go("clicks", "mouse") end, 120 },
		{ "4. Profils", function() UI:Go("profiles", "manage") end, 120 },
	})

	p:Section("État de l'addon")
	local function yes(ok, txt, no) return (ok and "|cff55dd77OK|r   " or "|cff888888--|r    ") .. (ok and txt or (no or txt)) end
	p:Note(nil, function()
		local d = db()
		local lines = {}
		lines[#lines + 1] = yes(VP.healComm ~= nil, "Soins entrants actifs (LibHealComm-4.0)",
			"Soins entrants inactifs : installez LibHealComm-4.0 (version 3.3.5)")
		lines[#lines + 1] = yes((VP.Clicks.activeCount or 0) > 0, (VP.Clicks.activeCount or 0) .. " action(s) de clic actives (spé " .. VP:Spec() .. ")",
			"Aucun clic configuré : page Clics et touches")
		local types = VP.Dispel and VP.Dispel:TypesText()
		lines[#lines + 1] = yes(types ~= nil, "Dispel actif : " .. (types or ""), "Aucun dispel pour votre classe")
		local tankOK, tankTxt = VP.Buffs:TankStatus()
		if tankTxt then lines[#lines + 1] = yes(tankOK, tankTxt) end
		lines[#lines + 1] = yes(not d.locked, "Cadres déverrouillés : déplacez-les avec leurs poignées", "Cadres verrouillés")
		lines[#lines + 1] = yes(VP.Theme:LSM() ~= nil, "SharedMedia détecté : textures et polices en plus (Style et couleurs)",
			"SharedMedia absent (facultatif)")
		lines[#lines + 1] = yes(VP.Rez and VP.Rez.lib ~= nil, "Résurrections des autres visibles (LibResComm-1.0)",
			"LibResComm-1.0 absente (facultatif)")
		local ap = d.autoProfile
		lines[#lines + 1] = yes(ap and ap.enabled, "Profil automatique actif" .. ((ap and ap.last) and (" : « " .. ap.last .. " »") or ""),
			"Profil automatique désactivé (page Profils)")
		return table.concat(lines, "\n")
	end)
	p:Buttons({
		{ "Ma cible est un tank", function() VP.Panels:ToggleMyTank(); VP.Buffs:Scan(); UI:RefreshCurrent() end, 170 },
		{ "Actualiser", function() VP.Buffs:Scan(); UI:RefreshCurrent() end, 110 },
	})

	p:Section("Lire les cadres en combat")
	p:Note("|cffffffffBarre de vie colorée|r (bleu, violet, brun, vert) + son doux : un débuff que VOTRE personnage peut dissiper. À vous d'agir.\n"
		.. "|cffffffffGrande icône au centre|r : débuff de boss, une information. Bordure de couleur = vous pouvez le dissiper ; "
		.. "orange = critique, soignez ce joueur ; grise = rien à faire.\n"
		.. "|cffffffffBordure rouge qui s'éteint|r : le joueur vient de prendre un gros coup.\n"
		.. "|cffffffffCadre gris|r : un de vos buffs manque (ex. Bouclier de terre).\n"
		.. "Tapez /vp dispel pour voir ce que votre personnage peut dissiper.")
	p:Buttons({
		{ "Régler le dispel", function() UI:Go("dispel", "key") end, 150 },
		{ "Régler les débuffs de boss", function() UI:Go("debuffs", "options") end, 200 },
	})
end, { icon = I .. "INV_Misc_Map_01" })

UI:AddTab("profiles", "Profils", function(p)
	p:Title("Profils", "Un profil enregistre l'apparence et les options (les clics restent rangés par classe et par spé). "
		.. "Pratique pour passer d'une config raid 25 à une config 5 joueurs.")
	p:Section("Mes profils", { key = "manage" })
	local inp = p:Input("Nom du profil")
	p:Dropdown("Ou choisissez un profil enregistré", function()
		local c = {}
		for _, n in ipairs(VP:ProfileList()) do c[#c + 1] = { n, n } end
		return c
	end, function() return inp.edit:GetText() end, function(v) inp.edit:SetText(v) end)
	p:Buttons({
		{ "Enregistrer", function() VP:SaveProfile(inp.edit:GetText()); UI:RefreshCurrent() end, 120, true },
		{ "Charger", function() VP:LoadProfile(inp.edit:GetText()); UI:RefreshCurrent() end, 120 },
		{ "Supprimer", function() VP:DeleteProfile(inp.edit:GetText()); UI:RefreshCurrent() end, 120 },
	})
	p:Note(nil, function()
		local l = VP:ProfileList()
		return "Profils enregistrés : |cffffffff" .. (#l > 0 and table.concat(l, ", ") or "(aucun)") .. "|r"
	end)

	p:Section("Partager (import / export)", { key = "share" })
	p:Note("Exporter : le profil nommé ci-dessus (ou vos réglages actuels si le nom est vide) devient un texte à copier "
		.. "et à envoyer. Importer : collez le texte reçu ; il est enregistré sous le nom ci-dessus, puis « Charger ». "
		.. "Le texte importé n'est jamais exécuté : seuls des réglages VuhPlus valides sont gardés.")
	p:Buttons({
		{ "Exporter", function()
			local txt, err = VP.Share:Export(inp.edit:GetText())
			if not txt then VP:Print("|cffff6666" .. err .. "|r") return end
			VP.Share:Window("Exporter un profil", txt)
		end, 140, true },
		{ "Importer...", function()
			VP.Share:Window("Importer un profil", "", function(text)
				local ok, res = VP.Share:Import(text, inp.edit:GetText())
				if ok then
					VP:Print("Profil importé : « " .. res .. " ». Cliquez sur « Charger » pour l'utiliser.")
					inp.edit:SetText(res)
					VP.Share.win:Hide()
					UI:RefreshCurrent()
				else
					VP:Print("|cffff6666Import impossible : " .. tostring(res) .. "|r")
				end
			end, "Importer")
		end, 140 },
	})

	p:Section("Profil automatique")
	local ap = VP.AutoProfile:DB()
	p:Toggle("Activer le profil automatique", function() return ap.enabled end,
		function(v) ap.enabled = v; ap.last = nil; VP.AutoProfile:Check() end, nil,
		"Charge tout seul un profil selon votre spé (double spé) ou la taille du groupe. Le profil de la taille du groupe "
		.. "passe avant celui de la spé. Changement appliqué hors combat. Laissez « (aucun) » pour ne rien changer.")
	local function choices()
		local c = { { "", "(aucun)" } }
		for _, n in ipairs(VP:ProfileList()) do c[#c + 1] = { n, n } end
		return c
	end
	local function pick(key, label)
		p:Dropdown(label, choices, function() return ap[key] end,
			function(v) ap[key] = v; ap.last = nil; VP.AutoProfile:Check() end, true)
	end
	pick("spec1", "Spé principale")
	pick("spec2", "Spé secondaire")
	for _, sz in ipairs(VP.AutoProfile.SIZES) do pick(sz[1], sz[2]) end

	p:Section("Réglages par personnage", { adv = true })
	p:Note("Chaque personnage garde ses propres réglages (apparence, positions, fenêtres affichées, alertes...) : "
		.. "changer une option ici ne touche pas vos autres personnages. Un nouveau personnage démarre avec les réglages "
		.. "du dernier personnage joué. Les clics, touches et macros restent rangés par classe et par spé ; "
		.. "les profils sont communs à tout le compte.")
	local others = VP:CharList()
	if #others > 0 then
		local cc = {}
		for i, k in ipairs(others) do cc[i] = { k, k } end
		local from = others[1]
		p:Dropdown("Copier les réglages de", cc, function() return from end, function(v) from = v end, true)
		p:Buttons({ { "Copier sur ce personnage", function() VP:CopyFromChar(from); UI:RefreshCurrent() end, 210 } })
	else
		p:Note("|cff999999Aucun autre personnage enregistré pour l'instant : connectez-vous une fois avec chacun.|r")
	end
end, { icon = I .. "INV_Misc_Note_01", keys = "sauvegarde export import partage personnage",
	active = function() local ap = db().autoProfile; return ap and ap.enabled end })

-- =====================================================================================
-- SOIGNER
-- =====================================================================================

local function applyNow()
	local C = VP.Clicks
	if C:Apply() then
		VP:Print("Clics appliqués : " .. (C.activeCount or 0) .. " actions actives. Survolez un cadre pour les voir dans l'infobulle.")
	else
		VP:Print("En combat : vos clics seront appliqués dès la fin du combat.")
	end
	UI:RefreshCurrent()
end

local function clicksBanner()
	local C = VP.Clicks
	if InCombatLockdown() then return "|cffffbb33En combat : les changements seront appliqués à la fin du combat.|r" end
	if not C.lastApply then return "Clics pas encore appliqués." end
	return "|cff55dd77Clics actifs|r : " .. (C.activeCount or 0) .. " actions  ·  dernière application à " .. C.lastApply
		.. "  ·  spé " .. VP:Spec()
end

UI:AddTab("clicks", "Clics et touches", function(p)
	local d = db()
	local C = VP.Clicks
	p:Title("Clics et touches", "Cliquez sur un cadre du raid avec la combinaison indiquée pour lancer le sort sur ce joueur. "
		.. "Glissez un sort depuis le grimoire (P) sur une case, ou écrivez son nom puis Entrée.")
	p:Banner(clicksBanner)
	p:Buttons({
		{ "Appliquer et vérifier", applyNow, 180, true },
		{ "Copier spé 1 > spé 2", function() C:CopySpec(1, 2); UI:RefreshCurrent() end, 170 },
		{ "Copier spé 2 > spé 1", function() C:CopySpec(2, 1); UI:RefreshCurrent() end, 170 },
	})

	-- 1. touche modificatrice, 2. boutons de la souris et molette pour cette touche
	p:Section("Touche modificatrice", { key = "mouse", desc = "choisissez, puis réglez les boutons" })
	local mods = {}
	for _, m in ipairs(C.MODS) do mods[#mods + 1] = { m, C.MOD_NAME[m] } end
	p:Chips(nil, mods, function() return O.modSel or "" end, function(v) O.modSel = v end, 4)
	p:Banner(function()
		local m = O.modSel or ""
		return "Vous réglez : |cffffffff" .. (m == "" and "les clics sans touche" or ("les clics avec " .. C.MOD_NAME[m] .. " enfoncé")) .. "|r"
	end)

	p:Section("Boutons de la souris")
	for _, btn in ipairs(C.MOUSE) do
		p:Binding(C.MOUSE_LABEL[btn], function() return C:Binds()[(O.modSel or "") .. btn] end,
			function(v) C:Binds()[(O.modSel or "") .. btn] = v; C:Apply() end)
	end
	p:Note("Mots spéciaux : |cffffffffcible|r, |cffffffffmenu|r, |cfffffffffocus|r, |cffffffffassister|r, |cffffffffdispel1|r, |cffffffffdispel2|r. "
		.. "Une ligne commençant par / est une macro ; « objet: Nom » utilise un objet ; |cffffffffM:Nom|r une macro de l'onglet Macros.")
	p:Link("Votre touche de dispel se choisit dans", "dispel", "key")

	p:Section("Molette de la souris (sur le cadre survolé)")
	for _, w in ipairs(C.WHEEL) do
		p:Binding(C.WHEEL_LABEL[w], function() return C:Binds()[(O.modSel or "") .. w] end,
			function(v) C:Binds()[(O.modSel or "") .. w] = v; C:Apply() end)
	end

	p:Section("Touches du clavier au survol", { key = "keys" })
	p:Note("Survolez un cadre et appuyez sur la touche : l'action vise ce joueur. Cliquez sur la case de gauche puis appuyez sur la touche "
		.. "(avec Maj/Ctrl/Alt si voulu) ou tournez la molette. Clic droit sur la case : effacer.")
	for i = 1, C.NUM_KEYS do
		local idx = i
		p:KeyAction(function() return C:Keys()[idx].key end, function(v) C:Keys()[idx].key = v; C:Apply() end,
			function() return C:Keys()[idx].action end, function(v) C:Keys()[idx].action = v; C:Apply() end)
	end

	p:Section("Automatismes", { adv = true })
	p:Toggle("Clic intelligent : résurrection hors combat", function() return d.clicks.smartRes end, function(v) d.clicks.smartRes = v; C:Apply() end, nil,
		"Un clic sur un joueur mort, hors combat, lance votre sort de résurrection.")
	p:Toggle("Bijoux automatiques avec les soins cliqués", function() return d.clicks.autoTrinket end, function(v) d.clicks.autoTrinket = v; C:Apply() end, nil,
		"Chaque sort de soin lancé par un clic utilise aussi vos bijoux « Utiliser : » s'ils sont prêts.")
	p:Toggle("Lancer à l'appui (au lieu du relâchement)", function() return d.castOnDown end, function(v) d.castOnDown = v; C:Apply() end)
	p:Toggle("Lister mes clics dans l'infobulle des cadres", function() return d.tooltipBinds end, function(v) d.tooltipBinds = v end)
	p:Toggle("Clic-soin aussi sur les cadres Blizzard", function() return d.clicks.blizz end, function(v) d.clicks.blizz = v; C:Apply() end, nil,
		"Vos clics fonctionnent aussi sur votre portrait, celui de la cible, de la focalisation, de votre familier et du groupe (comme l'addon Clique).")

	p:Section("Sur un allié contrôlé par l'ennemi", { adv = true })
	p:Note("Exemple : Métamorphose, Peur, Cyclone sur un joueur sous Domination.")
	local hl = { "Clic gauche", "Clic droit", "Clic milieu" }
	for i = 1, C.NUM_HOSTILE do
		local idx = i
		p:Binding(hl[i], function() return C:Hostile()[idx].action end, function(v) C:Hostile()[idx].action = v; C:Apply() end)
	end

	p:Section("Toutes vos combinaisons actives")
	p:Note(nil, function()
		local list = C:Summary()
		if #list == 0 then return "Aucune action assignée." end
		local lines = {}
		for _, e in ipairs(list) do lines[#lines + 1] = "|cffaaaaaa" .. e[1] .. "|r  >  |cffffffff" .. e[2] .. "|r" end
		return table.concat(lines, "\n")
	end)
	p:Buttons({ { "Appliquer et vérifier", applyNow, 180, true } })
end, { icon = I .. "Spell_Holy_FlashHeal", keys = "clic souris molette touche raccourci bind sort",
	active = function() return (VP.Clicks.activeCount or 0) > 0 end })

UI:AddTab("hots", "HoTs suivis", function(p)
	local d = db()
	local c = d.colors
	p:Title("HoTs suivis", "Les sorts que vous gardez sur les joueurs (Rénovation, Remous, Fleur de vie...) : 6 emplacements "
		.. "et tout leur affichage. Les sorts proposés sont ceux de votre classe : " .. (CLASS_FR[VP.class] or VP.class) .. ".")
	testButtons(p)

	p:Section("Sorts suivis (emplacements 1 à 6)", { key = "slots" })
	p:Note("Bouton « v » : liste des sorts de votre classe. Vous pouvez aussi glisser un sort du grimoire. « Les miens » : lancés par vous ; « Des autres » : lancés par un autre joueur.")
	for i = 1, VP.Frames.NUM_SLOTS do
		local idx = i
		p:HotSlot(idx, function() return VP.Frames:HotSlots()[idx] end)
	end
	p:Link("Position précise de chaque HoT :", "icons", "pos")

	p:Section("Affichage des HoTs")
	p:Toggle("Afficher mes HoTs et boucliers", function() return d.showHots end, function(v) d.showHots = v end)
	p:Dropdown("Affichage", { { "ICON", "Icônes du sort" }, { "SQUARE", "Carrés de couleur" } },
		function() return d.hotMode end, function(v) d.hotMode = v end, true)
	p:Gap(2)
	p:Toggle("Temps restant (secondes)", function() return d.hotTimer end, function(v) d.hotTimer = v end, true,
		"Secondes restantes écrites sur l'icône : blanc, puis jaune sous 6 s et rouge sous 3 s. Aussi sur les affaiblissements de boss.")
	p:Toggle("Spirale de durée", function() return d.hotSpiral end, function(v) d.hotSpiral = v end, true)
	p:Toggle("Charges / cumuls", function() return d.showStacks end, function(v) d.showStacks = v end, true,
		"Bouclier de terre, Prière de guérison : vert, jaune puis rouge quand il reste peu de charges.")
	p:Toggle("Sorts à charges : nombre de charges au lieu du temps", function() return d.chargeOnly ~= false end,
		function(v) d.chargeOnly = v; layout() end, true,
		"Bouclier de terre (chaman) et Prière de guérison (prêtre) : gros chiffre des charges restantes au centre de l'icône, "
		.. "couleur selon le nombre (vert, jaune, rouge) et bordure rouge à 1 charge. Pas de temps restant ni de spirale.")
	p:Slider("Taille des HoTs", 8, 48, 1, function() return d.hotSize end, function(v) d.hotSize = v; layout() end, " px", true)
	p:Slider("Espace entre les HoTs", 0, 12, 1, function() return d.hotGap end, function(v) d.hotGap = v; layout() end, " px", true)

	p:Section("Barres de durée sur les tanks")
	p:Note("Fines barres en haut du cadre : temps restant de vos 3 premiers HoTs, couleur de l'emplacement, "
		.. "rouge quand le HoT va expirer. Plus lisible que les icônes pour garder les HoTs sur un tank.")
	p:Dropdown("Afficher sur", {
		{ "OFF", "Désactivé" }, { "TANKS", "Les tanks seulement" }, { "ALL", "Tous les cadres" },
	}, function() return d.hotBars end, function(v) d.hotBars = v; VP.Frames:Refresh() end, true)
	p:Slider("Hauteur des barres", 1, 6, 1, function() return d.hotBarHeight or 2 end,
		function(v) d.hotBarHeight = v; VP.Frames:Refresh() end, " px", true)

	p:Section("Compte à rebours et alerte d'expiration", { adv = true })
	local CD = { { "OFF", "Aucun" }, { "SEC", "Secondes" }, { "TENTH", "Dixièmes (sous 10 s)" } }
	for i = 1, VP.Frames.NUM_SLOTS do
		local idx = i
		local function sl() return VP.Frames:HotSlots()[idx] end
		p:Dropdown("Compte à rebours, emplacement " .. idx, CD, function() return sl().countdown or "SEC" end, function(v) sl().countdown = v end, true)
	end
	p:Color("Alerte d'expiration", function() return c.hotWarn end, nil, true)
	p:Slider("Alerter quand il reste", 0, 10, 1, function() return d.hotWarnSecs end, function(v) d.hotWarnSecs = v end, " s", true)
	p:Toggle("Clignoter à l'expiration", function() return d.hotWarnFlash end, function(v) d.hotWarnFlash = v end, true)
	p:Toggle("Contour du texte (sinon ombre)", function() return d.hotTextOutline end, function(v) d.hotTextOutline = v; layout() end, true)

	p:Section("Couleurs des charges", { adv = true })
	p:Color("1 charge", function() return c.charge[1] end, nil, true)
	p:Color("2 charges", function() return c.charge[2] end, nil, true)
	p:Color("3 charges", function() return c.charge[3] end, nil, true)
	p:Color("4 charges et +", function() return c.charge[4] end, nil, true)
end, { icon = I .. "Spell_Holy_Renew", keys = "hot renovation remous fleur de vie bouclier charges emplacement",
	active = function() return db().showHots end })

UI:AddTab("macros", "Macros", function(p)
	p:Title("Macros de clic-soin", "Vos macros sur plusieurs lignes, utilisables sur n'importe quel clic, touche ou molette. "
		.. "Elles visent le joueur cliqué grâce aux jetons ci-dessous.")
	p:Note("|cffffffff@vp|r dans les conditions vise le joueur cliqué : |cffffffff/cast [@vp,dead] Résurrection; [@vp] Soin rapide|r\n"
		.. "|cffffffff{vp}|r hors conditions : |cffffffff/focus {vp}|r, |cffffffff/target {vp}|r.\n"
		.. "Dans une case de clic ou de touche, écrivez |cffffffffM:Nom de la macro|r, ou utilisez « Assigner à un clic... ». "
		.. "Glissez un sort du grimoire dans le texte pour l'écrire, ou une macro du jeu (Échap > Macros) pour l'importer.")
	p:MacroEditor()
end, { icon = I .. "INV_Scroll_03", keys = "macro script @vp" })

-- =====================================================================================
-- AIDES AU SOIN
-- =====================================================================================

UI:AddTab("dispel", "Dispel", function(p)
	local d = db()
	local dd = d.dispel
	local D = VP.Dispel
	local C = VP.Clicks
	local function changed() D:Refresh(); C:Apply() end
	p:Title("Dispel", "Retirez un débuff d'un simple clic sur le cadre du joueur. Tout le dispel se règle ici : "
		.. "votre touche, l'affichage sur le cadre, le son et la fenêtre « À dissiper ».")
	p:Banner(function()
		local t = D:TypesText()
		if not t then return "|cffff6666Aucun dispel actif pour votre classe (classe désactivée ou sort non appris).|r" end
		return "Vous pouvez dissiper : |cffffffff" .. t .. "|r"
	end)
	if CLASS_FR[VP.class] then
		p:Toggle("Assistant de dispel activé (" .. CLASS_FR[VP.class] .. ")", function() return dd.classes[VP.class] end,
			function(v) dd.classes[VP.class] = v; changed(); UI:RefreshCurrent() end)
	end

	p:Section("1. Votre touche pour dissiper", { key = "key" })
	p:Note("Comment ça marche : 1. le cadre prend la couleur du débuff et un son vous prévient ; "
		.. "2. vous cliquez sur le cadre avec la touche choisie ci-dessous ; 3. le débuff est retiré, le cadre redevient normal.")
	local combos = C:Combos()
	for i = 1, 2 do
		local idx = i
		local sl = D.slots[idx]
		if sl then
			p:Dropdown("Dispel " .. idx .. " : " .. sl.name, combos, function() return C:FindBind("DISPEL" .. idx) end,
				function(v) C:SetDispelKey(idx, v); UI:RefreshCurrent() end, true)
		end
	end
	if not D.slots[1] then p:Note("|cffff6666Aucun sort de dispel connu.|r") end
	p:Link("Cette touche remplace le sort qui y était. Tous vos clics :", "clicks", "mouse")

	p:Section("2. Sur le cadre")
	p:Toggle("Changer la couleur du cadre", function() return dd.highlight end, function(v) dd.highlight = v end, true)
	p:Dropdown("Style de mise en évidence", {
		{ "BAR", "Barre entière colorée" },
		{ "TINT", "Teinte légère" },
	}, function() return dd.style or "BAR" end, function(v) dd.style = v end, true)
	p:Toggle("Bordure qui clignote", function() return dd.pulse ~= false end, function(v) dd.pulse = v end, true,
		"Bordure épaisse de la couleur du débuff qui clignote tant que le joueur est à portée de dispel.")
	p:Toggle("Écrire la touche sur le cadre", function() return dd.showHint end, function(v) dd.showHint = v end, true)
	p:Toggle("Aussi sur les familiers", function() return d.pets.dispel end, function(v) d.pets.dispel = v; VP.Frames:Refresh() end, true)
	p:Slider("Taille de l'icône de dispel", 10, 48, 1, function() return d.dispelSize end, function(v) d.dispelSize = v; layout() end, " px", true)
	p:Note("Couleur de chaque type de débuff (« Fond » : la barre ; « Texte » : le nom) :")
	for _, e in ipairs({ { "Magic", "Magique" }, { "Curse", "Malédiction" }, { "Disease", "Maladie" }, { "Poison", "Poison" } }) do
		local k = e[1]
		p:Color(e[2], function() return d.colors.debuff[k] end, { bg = true, text = true })
	end

	p:Section("3. Son")
	p:Toggle("Jouer un son quand je peux dissiper", function() return dd.sound end, function(v) dd.sound = v end, true)
	p:Dropdown("Son", D.SOUNDS, function() return dd.soundName end, function(v) dd.soundName = v; PlaySound(v) end, true)
	p:Toggle("Son même hors de portée", function() return dd.alertOutOfRange end, function(v) dd.alertOutOfRange = v end, true,
		"Désactivé (comme Decursive) : le son ne sonne que lorsque le joueur est à portée.")
	p:Buttons({ { "Écouter le son", function() PlaySound(dd.soundName or "TellMessage") end, 150 } })

	p:Section("4. Fenêtre « À dissiper »")
	p:Toggle("Afficher la liste des joueurs à dissiper", function() return dd.liveList end,
		function(v) dd.liveList = v; VP.LiveList:Refresh() end, nil,
		"Triée : prioritaires, à portée, ordre des types, puis ce qui expire le plus tôt. Déplaçable une fois les cadres déverrouillés.")
	p:Slider("Nombre de lignes", 1, 10, 1, function() return dd.liveListRows end, function(v) dd.liveListRows = v end, nil, true)

	p:Section("5. Petits cadres cliquables", { key = "mini", desc = "comme Decursive" })
	p:Note("Un petit carré par joueur, coloré quand il a un débuff que vous pouvez retirer. Clic gauche : Dispel 1, "
		.. "clic droit : Dispel 2, clic milieu : cibler. Fonctionne même en combat. Idéal si vous cachez les cadres de soin (DPS, mage).")
	p:Dropdown("Afficher", {
		{ "AUTO", "Seulement quand les cadres de soin sont cachés" },
		{ "ON", "Toujours" },
		{ "OFF", "Jamais" },
	}, function() return dd.mini or "AUTO" end, function(v) dd.mini = v; VP.LiveList:ApplyCure() end, true)
	p:Slider("Taille des carrés", 12, 32, 1, function() return dd.miniSize or 18 end,
		function(v) dd.miniSize = v; VP.LiveList:ApplyCure() end, " px", true)

	p:Section("Types à dissiper et priorité", { adv = true })
	p:Note("Désactivez un type pour le laisser à un autre soigneur, et choisissez l'ordre (le type n°1 est montré en premier).")
	for _, ty in ipairs(D.TYPES) do
		local t = ty
		p:Toggle(D.TYPE_FR[t], function() return dd.types[t] ~= false end, function(v) dd.types[t] = v; changed(); UI:RefreshCurrent() end, true)
	end
	local tyChoices = {}
	for _, ty in ipairs(D.TYPES) do tyChoices[#tyChoices + 1] = { ty, D.TYPE_FR[ty] } end
	for r = 1, 4 do
		local rank = r
		p:Dropdown("Priorité " .. rank, tyChoices, function() return dd.order[rank] end, function(v)
			local o = dd.order
			for i, t in ipairs(o) do if t == v then o[i] = o[rank] end end
			o[rank] = v
			UI:RefreshCurrent()
		end, true)
	end

	p:Section("Portée, ligne de vue et échecs", { adv = true })
	p:Toggle("Portée réelle de mon sort de dispel", function() return dd.rangeCheck end, function(v) dd.rangeCheck = v end, true,
		"Le cadre d'un joueur hors de portée de votre dispel est atténué et marqué « loin ».")
	p:Toggle("Message si dispel résisté / impossible", function() return dd.failAlert end, function(v) dd.failAlert = v end, true)
	p:Toggle("Ne pas dissiper si mon Abolir est dessus", function() return dd.checkAbolish end, function(v) dd.checkAbolish = v end, true,
		"Abolir le poison / Abolir maladie retirent déjà l'affaiblissement toutes les quelques secondes.")
	p:Slider("Oublier un joueur hors de vue pendant", 0, 15, 1, function() return dd.blacklistTime end, function(v) dd.blacklistTime = v end, " s", true)

	local function addTo(list, name)
		name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if name == "" then return end
		for _, n in ipairs(list) do if n == name then return end end
		table.insert(list, name)
	end
	local function removeFrom(list, name)
		for i, n in ipairs(list) do if n == name then table.remove(list, i) return end end
	end

	p:Section("Ce qu'il ne faut pas dissiper", { adv = true })
	p:Toggle("Ignorer ce qu'il ne faut pas dissiper", function() return dd.ignoreList end, function(v) dd.ignoreList = v end, true)
	p:Toggle("Ignorer selon la classe", function() return dd.classFilter end, function(v) dd.classFilter = v end, true,
		"Ex. Malédiction des langages sur un guerrier, Silence sur un voleur : sans effet, donc pas d'alerte.")
	p:Toggle("Avertir : Affliction instable", function() return dd.warnDanger end, function(v) dd.warnDanger = v end, true,
		"Dissiper Affliction instable réduit au silence et blesse : le cadre devient violet avec « DANGER » au lieu de vous inviter à dissiper.")
	p:Note(nil, function()
		local t = {}
		for _, r in ipairs(D.recent) do t[#t + 1] = r.name end
		return "Derniers affaiblissements vus : |cffffffff" .. (#t > 0 and table.concat(t, ", ") or "(aucun)") .. "|r"
	end)
	local ign = p:Input("Nom de l'affaiblissement")
	p:Buttons({
		{ "Ignorer toujours", function() addTo(dd.userIgnore, ign.edit:GetText()); ign.edit:SetText(""); UI:RefreshCurrent() end, 140, true },
		{ "Ignorer en combat", function() addTo(dd.userIgnoreCombat, ign.edit:GetText()); ign.edit:SetText(""); UI:RefreshCurrent() end, 140 },
		{ "Retirer", function()
			removeFrom(dd.userIgnore, ign.edit:GetText()); removeFrom(dd.userIgnoreCombat, ign.edit:GetText())
			ign.edit:SetText(""); UI:RefreshCurrent()
		end, 100 },
	})
	p:Note(nil, function()
		return "Toujours ignorés : |cffffffff" .. (#dd.userIgnore > 0 and table.concat(dd.userIgnore, ", ") or "(aucun)") .. "|r\n"
			.. "Ignorés en combat : |cffffffff" .. (#dd.userIgnoreCombat > 0 and table.concat(dd.userIgnoreCombat, ", ") or "(aucun)") .. "|r"
	end)

	p:Section("Joueurs prioritaires / à ignorer", { adv = true })
	local who = p:Input("Nom du joueur")
	local function nameOrTarget()
		local n = who.edit:GetText()
		if (not n or n == "") and UnitExists("target") and UnitIsPlayer("target") then n = UnitName("target") end
		return n
	end
	p:Buttons({
		{ "Prioritaire", function() addTo(dd.priorityNames, nameOrTarget()); who.edit:SetText(""); UI:RefreshCurrent() end, 120, true },
		{ "À ignorer", function() addTo(dd.skipNames, nameOrTarget()); who.edit:SetText(""); UI:RefreshCurrent() end, 120 },
		{ "Retirer", function()
			local n = nameOrTarget(); removeFrom(dd.priorityNames, n); removeFrom(dd.skipNames, n)
			who.edit:SetText(""); UI:RefreshCurrent()
		end, 100 },
	})
	p:Note(nil, function()
		return "Vide = votre cible.  Prioritaires : |cffffffff" .. (#dd.priorityNames > 0 and table.concat(dd.priorityNames, ", ") or "(aucun)") .. "|r\n"
			.. "Ignorés : |cffffffff" .. (#dd.skipNames > 0 and table.concat(dd.skipNames, ", ") or "(aucun)") .. "|r"
	end)
	p:Link("Joueur sous contrôle mental (Maléfice, Métamorphose...) :", "clicks", nil, "Clics et touches")

	p:Section("Classes", { adv = true })
	for _, cls in ipairs({ "PALADIN", "PRIEST", "DRUID", "SHAMAN", "MAGE" }) do
		p:Toggle(CLASS_FR[cls], function() return dd.classes[cls] end, function(v) dd.classes[cls] = v; changed(); UI:RefreshCurrent() end, true)
	end
end, { icon = I .. "Spell_Holy_DispelMagic", keys = "dissiper purifier purification decurse cleanse dispell magie malediction maladie poison",
	active = function() return VP.Dispel and VP.Dispel:TypesText() ~= nil end })

UI:AddTab("debuffs", "Débuffs de boss", function(p)
	local d = db()
	local dd = d.debuffs
	p:Title("Débuffs de boss", "Grande icône au centre du cadre avec cumuls et durée. Liste intégrée : Naxxramas, Ulduar, Épreuve du croisé, "
		.. "Onyxia, Citadelle de la Couronne de glace, Sanctum rubis. Le plus prioritaire est affiché.")
	p:Section("Comment lire l'icône")
	p:Note("Ces débuffs sont une INFORMATION sur le combat : ce n'est pas forcément à vous de les retirer.\n"
		.. "|cff3399ffBordure de couleur|r (bleu magie, violet malédiction, brun maladie, vert poison) : VOUS pouvez le dissiper.\n"
		.. "|cffe6731aBordure orange|r (et clignotement) : débuff critique, ce joueur va prendre cher : soignez-le.\n"
		.. "|cff8a8a94Bordure grise|r : simple information, rien à dissiper.\n"
		.. "Trop d'icônes pour débuter ? Montez « N'afficher qu'à partir de la priorité » à 8 : seuls les critiques restent.")

	p:Section("Options", { key = "options" })
	p:Toggle("Liste intégrée des boss", function() return dd.boss end, function(v) dd.boss = v end, true)
	p:Toggle("Ma liste personnelle", function() return dd.custom end, function(v) dd.custom = v end, true)
	p:Dropdown("Son quand un joueur est touché", {
		{ "OFF", "Jamais" }, { "CRIT", "Seulement les débuffs critiques" }, { "ALL", "Tous (discret, fort si critique)" },
	}, function() return dd.sound == true and "CRIT" or (dd.sound or "OFF") end, function(v) dd.sound = v end, true)
	p:Slider("N'afficher qu'à partir de la priorité", 1, 10, 1, function() return dd.minPrio or 1 end,
		function(v) dd.minPrio = v end, nil, true)
	p:Toggle("Clignoter si critique", function() return dd.critGlow end, function(v) dd.critGlow = v end, true,
		"Les débuffs de priorité 8 et plus (Empalé, Spores gazeuses, Peste libérée, Profanation...) font clignoter la grande icône.")
	p:Toggle("Afficher les autres affaiblissements", function() return dd.showOthers end, function(v) dd.showOthers = v end, true)
	p:Toggle("Colorer aussi le cadre et le nom", function() return dd.highlight end, function(v) dd.highlight = v end, nil,
		"Désactivé par défaut : un cadre entièrement coloré ressemble à une alerte de dispel. L'icône seule suffit pour un débuff de boss.")

	p:Section("Apparence")
	p:Slider("Taille de la grande icône", 12, 64, 1, function() return d.bossSize end, function(v) d.bossSize = v; layout() end, " px", true)
	p:Color("Couleur boss / perso", function() return d.colors.debuff.Custom end, { bg = true, text = true })
	p:Link("Position de l'icône :", "icons", "pos")

	p:Section("Ma liste personnelle", { adv = true })
	p:Slider("Priorité par défaut", 1, 10, 1, function() return dd.customPrio or 7 end, function(v) dd.customPrio = v end)
	p:Note("Écrivez « Nom » (priorité par défaut) ou « Nom = 9 » pour choisir la priorité de ce sort.")
	local inp = p:Input("Nom exact")
	p:Buttons({
		{ "Ajouter", function() VP.Debuffs:AddCustom(inp.edit:GetText()); inp.edit:SetText(""); UI:RefreshCurrent() end, 120, true },
		{ "Retirer", function() VP.Debuffs:RemoveCustom(inp.edit:GetText()); inp.edit:SetText(""); UI:RefreshCurrent() end, 120 },
	})
	p:Note(nil, function() return "Suivis : |cffffffff" .. VP.Debuffs:CustomText() .. "|r" end)
end, { icon = I .. "Spell_Shadow_DeathScream", keys = "boss raid affaiblissement priorite critique",
	active = function() local dd = db().debuffs; return dd.boss or dd.custom end })

UI:AddTab("buffs", "Buffs et rappels", function(p)
	local d = db()
	local b = d.buffs
	p:Title("Buffs et rappels", "Point jaune sur les joueurs à qui il manque un de vos buffs ; cadre gris quand il vous manque "
		.. "un buff de soigneur. Raccourci « Buff intelligent » : Échap > Raccourcis > VuhPlus.")
	p:Banner(function()
		local ok, txt = VP.Buffs:TankStatus()
		if not txt then return "Seul : les rappels sur le tank attendent un groupe." end
		if ok then return txt end
		return "|cffffbb33Aucun tank reconnu : ciblez-le puis « Ma cible est un tank » (ou /vp tank).|r"
	end)
	p:Buttons({
		{ "Ma cible est un tank", function() VP.Panels:ToggleMyTank(); VP.Buffs:Scan(); UI:RefreshCurrent() end, 170, true },
		{ "Actualiser", function() VP.Buffs:Scan(); UI:RefreshCurrent() end, 110 },
	})
	p:Section("Surveillance")
	p:Toggle("Activer la surveillance", function() return b.enabled end, function(v) b.enabled = v; VP.Buffs:Refresh() end, true)
	p:Toggle("Point jaune sur les cadres", function() return b.showMissing end, function(v) b.showMissing = v end, true)
	p:Slider("Manquant s'il reste moins de", 0, 10, 1, function() return b.rebuffMinutes end, function(v) b.rebuffMinutes = v end, " min", true)

	p:Section("Fenêtre Buffs (clic = lancer le buff)")
	p:Toggle("Afficher la fenêtre Buffs", function() return b.showPanel end, function(v) b.showPanel = v; VP.Buffs:Refresh() end, true)
	p:Slider("Taille de la fenêtre", 50, 200, 5, function() return math.floor((b.scale or 1) * 100 + 0.5) end, function(v) b.scale = v / 100; VP.Buffs:Refresh() end, " %", true)

	p:Section("Rappels de soigneur (cadre gris)")
	p:Toggle("Griser le cadre quand un buff manque", function() return b.grayFrames end, function(v) b.grayFrames = v end, nil,
		"Votre propre cadre devient gris s'il vous manque un buff personnel (ex. Bouclier d'eau, Arme Viveterre, Feu intérieur, Sceau). "
		.. "Le cadre de vos tanks devient gris s'il leur manque votre buff (ex. Épines, Bouclier de terre, Guide de lumière, Mot de pouvoir : Bouclier).")
	local hasCount = false
	for _, e in ipairs(VP.Buffs.entries) do if e.count then hasCount = true end end
	if hasCount then
		p:Toggle("Charges du Bouclier d'eau sur mon cadre", function() return b.selfCharges ~= false end, function(v) b.selfCharges = v end, nil,
			"Tant que le bouclier est actif, son icône reste sur votre cadre avec le nombre de charges restantes (orange à 1 charge).")
	end
	p:Slider("Taille de l'icône de rappel", 10, 48, 1, function() return d.remindSize end, function(v) d.remindSize = v; layout() end, " px", true)
	p:Note("Tanks reconnus : tank principal du raid, rôle tank (donjon ou talents), « Mes tanks » et votre focalisation. "
		.. "Bouclier de terre, Guide de lumière, Bouclier sacré : la personne qui porte VOTRE sort est toujours surveillée.\n"
		.. "Bouclier de terre, Épines, Gardien de peur ne se cumulent pas : un tank qui a déjà celui d'un autre joueur n'est pas grisé. "
		.. "Un sort en recharge (Gardien de peur) ne grise personne tant que vous ne pouvez pas le relancer.")

	local SCOPE = { raid = "groupe, point jaune", self = "vous, cadre gris", weapon = "arme, cadre gris", tank = "tank, cadre gris" }
	p:Section("Buffs suivis (votre classe)")
	if #VP.Buffs.entries == 0 then p:Note("Aucun buff connu pour votre classe ou votre niveau.") end
	for _, e in ipairs(VP.Buffs.entries) do
		local key = e.key
		p:Toggle(e.label .. "  |cff888888(" .. (SCOPE[e.scope] or "") .. ")|r", function() return b.track[key] end,
			function(v) b.track[key] = v; VP.Buffs:Refresh() end)
		if e.charges then
			-- jusqu'à 7 : Bouclier de terre amélioré porte le sort à 8 charges ; 0 = jamais (seulement quand il tombe)
			p:Slider("   Griser le porteur à", 0, 7, 1, function() return b.charges[key] or 1 end,
				function(v) b.charges[key] = v; VP.Buffs:Scan() end, " charge(s)", true)
			p:Gap(4)
		end
	end
end, { icon = I .. "Spell_Holy_WordFortitude", keys = "buff rappel gris bouclier eau terre epines manquant",
	active = function() return db().buffs.enabled end })

UI:AddTab("trinkets", "Bijoux", function(p)
	local t = db().trinket
	local function upd() VP.Trinkets:BuildMacro(); VP.Trinkets:UpdateVisibility() end
	p:Title("Bijoux en phase critique", "Quand la condition est remplie et qu'un bijou « Utiliser : » est prêt, le bouton Bijoux s'illumine, "
		.. "une alerte s'affiche et un son retentit. Appuyez alors sur votre raccourci (Échap > Raccourcis > VuhPlus).")
	p:Buttons({ { "Tester l'alerte", function() VP.Trinkets:TestAlert() end, 150, true } })
	p:Section("Module")
	p:Toggle("Activer le module bijoux", function() return t.enabled end, function(v) t.enabled = v; upd() end, true)
	p:Toggle("Afficher le bouton Bijoux", function() return t.showButton end, function(v) t.showButton = v; upd() end, true)
	p:Toggle("Bijou du haut (13)", function() return t.slot13 end, function(v) t.slot13 = v; upd() end, true)
	p:Toggle("Bijou du bas (14)", function() return t.slot14 end, function(v) t.slot14 = v; upd() end, true)
	p:Toggle("Seulement en combat", function() return t.onlyInCombat end, function(v) t.onlyInCombat = v end, true)
	p:Toggle("Son d'alerte", function() return t.sound end, function(v) t.sound = v end, true)
	p:Toggle("Bannière d'alerte à l'écran", function() return t.alertText end, function(v) t.alertText = v end, true)
	p:Slider("Taille du bouton Bijoux", 50, 200, 5, function() return math.floor((t.scale or 1) * 100 + 0.5) end, function(v) t.scale = v / 100; VP.Trinkets:ApplyPosition() end, " %", true)
	p:Section("Déclencheur")
	p:Dropdown("Condition", {
		{ "PLAYER", "Ma vie sous le seuil" },
		{ "RAID", "Plusieurs alliés sous le seuil" },
		{ "BOTH", "Ma vie OU plusieurs alliés" },
	}, function() return t.mode end, function(v) t.mode = v end)
	p:Slider("Ma vie sous", 5, 90, 5, function() return t.playerPct end, function(v) t.playerPct = v end, " %", true)
	p:Slider("Vie des alliés sous", 10, 90, 5, function() return t.raidPct end, function(v) t.raidPct = v end, " %", true)
	p:Slider("Nombre d'alliés", 1, 15, 1, function() return t.raidCount end, function(v) t.raidCount = v end, nil, true)
	p:Link("Utiliser les bijoux à chaque soin cliqué :", "clicks", nil, "Clics et touches  »  Automatismes")
end, { icon = I .. "INV_Jewelry_Talisman_01", keys = "bijou trinket",
	active = function() return db().trinket.enabled end })

UI:AddTab("aoe", "Soin de zone", function(p)
	local a = db().aoe
	p:Title("Conseil de soin de zone", "En combat, la meilleure cible est teintée : celle qui a le plus de blessés autour d'elle. "
		.. "Cercle de soins et Croissance sauvage : blessés à 15 m de la cible ; Salve de guérison : cible blessée et blessés à 12,5 m. "
		.. "Prière de soins (sans Cercle de soins) : le groupe de raid le plus touché.")
	p:Banner(function()
		local m = VP.AoE.method
		if m == "map" then return "|cff55dd77Distances réelles|r : l'échelle de la carte est apprise, les groupes de joueurs proches sont calculés." end
		if m == "group" then return "|cffffcc33Par groupe de raid|r : échelle de la carte en cours d'apprentissage (ou carte indisponible ici)." end
		return "|cff888888Aucun sort de soin de zone connu pour ce personnage.|r"
	end)
	p:Section("Réglages")
	p:Toggle("Activer le conseil", function() return a.enabled end, function(v) a.enabled = v end)
	p:Slider("Joueurs sous", 30, 95, 5, function() return a.pct end, function(v) a.pct = v end, " %", true)
	p:Slider("Au moins", 2, 5, 1, function() return a.count end, function(v) a.count = v end, " blessés", true)
	p:Note("Comment l'addon mesure les distances : le jeu donne la position des joueurs sur la carte, mais pas sa taille. "
		.. "L'addon l'apprend tout seul en comparant avec la portée de votre soin (40 m) et les distances de duel (10 m) "
		.. "et de suivi (28 m). Il faut quelques secondes avec des joueurs à des distances variées ; c'est réappris à chaque zone. "
		.. "Dans une instance sans carte, l'ancienne méthode par groupe est utilisée.")
end, { icon = I .. "Spell_Holy_PrayerOfHealing02", keys = "zone aoe priere salve croissance cercle",
	active = function() return db().aoe.enabled end })

-- =====================================================================================
-- AFFICHAGE
-- =====================================================================================

UI:AddTab("dims", "Taille et disposition", function(p)
	local d = db()
	p:Title("Taille et disposition", "Taille des cadres et ordre du raid. Les changements s'appliquent hors combat ; "
		.. "le mode test permet de les voir tout de suite.")
	testButtons(p)
	p:Section("Préréglages", { key = "presets", desc = "un point de départ, ajustable ensuite" })
	local function preset(w, hp, mp, fs, hs, bs)
		d.width, d.hpHeight, d.manaHeight, d.fontSize, d.hotSize, d.bossSize = w, hp, mp, fs, hs, bs
		layout(); UI:RefreshCurrent()
	end
	p:Buttons({
		{ "Compact", function() preset(64, 24, 3, 10, 11, 14) end, 140 },
		{ "Normal", function() preset(80, 32, 4, 11, 14, 18) end, 140, true },
		{ "Grand", function() preset(110, 40, 6, 13, 17, 22) end, 140 },
		{ "Très grand", function() preset(140, 50, 8, 15, 20, 26) end, 140 },
	})
	p:Note("Change la largeur, les hauteurs, la taille du texte, des HoTs et de l'icône de boss en un clic.")

	p:Section("Taille des barres")
	p:Slider("Largeur", 40, 300, 2, function() return d.width end, function(v) d.width = v; layout() end, " px", true)
	p:Slider("Hauteur de la barre de vie", 12, 120, 1, function() return d.hpHeight end, function(v) d.hpHeight = v; layout() end, " px", true)
	p:Slider("Hauteur de la barre de mana", 1, 30, 1, function() return d.manaHeight end, function(v) d.manaHeight = v; layout() end, " px", true)
	p:Toggle("Afficher la barre de mana / ressource", function() return d.showMana end, function(v) d.showMana = v; layout() end, true)

	p:Section("Ordre du raid")
	p:Dropdown("Trier le raid", {
		{ "GROUP", "Par groupe (Groupe 1 à 8)" },
		{ "ROLEGRID", "Par rôle, en grille (tanks en haut, puis soigneurs, puis DPS)" },
		{ "ROLE", "Par rôle, en blocs séparés (Tanks / Soigneurs / DPS)" },
		{ "CLASS", "Par classe" }, { "NAME", "Par nom" },
	}, function() return d.sortMode end, function(v) d.sortMode = v; layout() end, true)
	p:Dropdown("Disposition des groupes", {
		{ "H", "Côte à côte (colonnes)" }, { "V", "Empilés (lignes)" },
	}, function() return d.groupOrient end, function(v) d.groupOrient = v; layout() end, true)
	local RN = { TANK = "Tanks", HEALER = "Soigneurs", DAMAGER = "DPS" }
	local PERMS = {
		{ "TANK", "HEALER", "DAMAGER" }, { "TANK", "DAMAGER", "HEALER" }, { "HEALER", "TANK", "DAMAGER" },
		{ "HEALER", "DAMAGER", "TANK" }, { "DAMAGER", "TANK", "HEALER" }, { "DAMAGER", "HEALER", "TANK" },
	}
	local permChoices = {}
	for i, pm in ipairs(PERMS) do
		permChoices[i] = { i, RN[pm[1]] .. ", puis " .. RN[pm[2]] .. ", puis " .. RN[pm[3]] }
	end
	p:Dropdown("Ordre des rôles (tris par rôle)", permChoices, function()
		local o = VP.Panels:RoleOrder()
		for i, pm in ipairs(PERMS) do
			if pm[1] == o[1] and pm[2] == o[2] and pm[3] == o[3] then return i end
		end
		return 1
	end, function(v)
		local pm = PERMS[v]
		d.roleOrder = { pm[1], pm[2], pm[3] }
		layout()
	end, true)
	p:Slider("Joueurs par colonne", 1, 10, 1, function() return d.perColumn end, function(v) d.perColumn = v; layout() end, nil, true)
	p:Toggle("Titres des blocs (« Groupe 1 », « Tanks »...)", function() return d.groupTitles end, function(v) d.groupTitles = v; layout() end, true)
	p:Toggle("Masquer les groupes vides", function() return d.groupCompact end, function(v) d.groupCompact = v; layout() end, true)
	p:Toggle("Afficher quand je suis seul", function() return d.showSolo end, function(v) d.showSolo = v; layout() end, true)
	p:Note("Par rôle, en grille : le raid garde la même forme qu'en tri par groupe mais se remplit ligne par ligne dans l'ordre choisi. "
		.. "« Joueurs par colonne » règle la hauteur (tri par classe, par nom, grille par rôle). "
		.. "Le rôle vient des talents (ou de /vp role). Un joueur qui arrive pendant un combat est placé à la fin du combat.")

	p:Section("Espacements", { adv = true, desc = "entre colonnes, lignes, marges" })
	p:Slider("Entre les colonnes", 0, 20, 1, function() return d.xGap end, function(v) d.xGap = v; layout() end, " px", true)
	p:Slider("Entre les lignes", 0, 20, 1, function() return d.yGap end, function(v) d.yGap = v; layout() end, " px", true)
	p:Slider("Marge gauche / droite", 0, 30, 1, function() return d.padX end, function(v) d.padX = v; layout() end, " px", true)
	p:Slider("Marge haut / bas", 0, 30, 1, function() return d.padY end, function(v) d.padY = v; layout() end, " px", true)

	p:Section("Échelle", { adv = true })
	p:Toggle("Réduire les cadres dans les grands raids", function() return d.autoScale end, function(v) d.autoScale = v; layout() end, nil,
		"Une taille pour les groupes et petits raids, une autre en raid 25, une autre en raid 40.")
	p:Slider("Échelle en raid 11 à 25", 50, 200, 5, function() return math.floor(d.scale25 * 100 + 0.5) end, function(v) d.scale25 = v / 100; layout() end, " %", true)
	p:Slider("Échelle en raid 26 à 40", 50, 200, 5, function() return math.floor(d.scale40 * 100 + 0.5) end, function(v) d.scale40 = v / 100; layout() end, " %", true)
	p:Slider("Échelle de tous les panneaux", 50, 300, 5, function() return math.floor(d.scale * 100 + 0.5) end, function(v) d.scale = v / 100; layout() end, " %", true)
	p:Link("La police et la taille du texte se règlent dans", "look", "text")
end, { icon = I .. "INV_Misc_Spyglass_03", keys = "dimension taille largeur hauteur ecart marge echelle tri groupe colonne" })

UI:AddTab("look", "Style et couleurs", function(p)
	local d = db()
	local c = d.colors
	p:Title("Style et couleurs", "L'allure générale des cadres. Les couleurs propres à une fonction (dispel, HoTs, soins entrants...) "
		.. "sont sur la page de cette fonction.")
	testButtons(p)
	p:Section("Couleurs principales", { key = "main" })
	p:AccentPicker("Couleur d'accent (menus, poignées, alertes)")
	p:Dropdown("Style des barres", {
		{ "FLAT", "Moderne (plat, couleur de classe)" },
		{ "DARK", "Sombre (barre grise, nom coloré)" },
		{ "CLASSIC", "Classique (texture Blizzard)" },
	}, function() return d.barStyle end, function(v) d.barStyle = v; layout() end, true)
	p:Dropdown("Couleur de la vie", {
		{ "CLASS", "Couleur de classe" },
		{ "GRADIENT", "Vert > jaune > rouge" },
		{ "GREEN", "Vert uni" },
	}, function() return d.healthColor end, function(v) d.healthColor = v end, true)
	p:Toggle("Reflet sur les barres", function() return d.gloss end, function(v) d.gloss = v; layout() end, true)
	p:Toggle("Nom en couleur de classe", function() return d.classNames end, function(v) d.classNames = v end, true)
	p:Toggle("Barres de vie animées", function() return d.smoothBars end, function(v) d.smoothBars = v end, true,
		"La vie glisse vers sa nouvelle valeur au lieu de sauter (comme VuhDo et Danders Frames). Un peu plus de travail "
		.. "pour le processeur en raid 25 / 40.")

	p:Section("Textes", { key = "text" })
	local fonts = {}
	for _, f in ipairs(VP.Theme.FONTS) do fonts[#fonts + 1] = { f[1], f[2] } end
	for _, f in ipairs(VP.Theme:LSMList("font", "LSM:")) do fonts[#fonts + 1] = f end
	p:Dropdown("Police", fonts, function() return d.font end, function(v) d.font = v; layout() end, true)
	p:Dropdown("Texte de vie", {
		{ "DEFICIT", "Vie manquante (-12.3k)" },
		{ "PERCENT", "Pourcentage (63%)" },
		{ "CURRENT", "Vie actuelle (18.2k)" },
		{ "NONE", "Aucun" },
	}, function() return d.healthText end, function(v) d.healthText = v end, true)
	p:Slider("Taille du texte", 8, 28, 1, function() return d.fontSize end, function(v) d.fontSize = v; layout() end, nil, true)
	p:Slider("Longueur max. des noms (0 = auto)", 0, 12, 1, function() return d.nameLength end, function(v) d.nameLength = v end, nil, true)
	if VP.Theme:LSM() then
		local texs = { { "", "Selon le style des barres" } }
		for _, t in ipairs(VP.Theme:LSMList("statusbar")) do texs[#texs + 1] = t end
		p:Dropdown("Texture des barres (SharedMedia)", texs, function() return d.barTexture or "" end,
			function(v) d.barTexture = v; layout() end, true)
	else
		p:Note("Installez l'addon SharedMedia (version 3.3.5) pour choisir parmi plus de textures et de polices.")
	end

	p:Section("Fond et portée")
	p:Toggle("Fond derrière le panneau", function() return d.panelBg end, function(v) d.panelBg = v end, true)
	p:Slider("Opacité du fond", 0, 100, 5, function() return math.floor(d.panelBgAlpha * 100 + 0.5) end, function(v) d.panelBgAlpha = v / 100 end, " %", true)
	p:Toggle("Estomper hors de portée", function() return d.rangeFade end, function(v) d.rangeFade = v end, true)
	p:Slider("Opacité hors de portée", 10, 100, 5, function() return math.floor(d.rangeAlpha * 100 + 0.5) end, function(v) d.rangeAlpha = v / 100 end, " %", true)

	p:Section("Couleurs : vie et ressources", { adv = true })
	p:Note("Vie : utilisées avec « Couleur de la vie » = Vert > jaune > rouge (Bonne / Passable / Faible) ou Vert uni (Unie).")
	p:Color("Bonne", function() return c.good end, nil, true)
	p:Color("Passable", function() return c.fair end, nil, true)
	p:Color("Faible", function() return c.low end, nil, true)
	p:Color("Unie", function() return c.solid end, nil, true)
	p:Color("Mana", function() return c.power[0] end, nil, true)
	p:Color("Rage", function() return c.power[1] end, nil, true)
	p:Color("Énergie", function() return c.power[3] end, nil, true)
	p:Color("Puissance runique", function() return c.power[6] end, nil, true)

	p:Section("Couleurs : états", { adv = true })
	p:Color("Mort", function() return c.dead end, nil, true)
	p:Color("Contrôlé (charme)", function() return c.charmed end, nil, true)
	p:Color("Hors-ligne", function() return c.offline end, nil, true)
	p:Color("Barre GCD", function() return c.gcd end, nil, true, function() VP.Panels:ApplyLayout() end)

	p:Section("Couleurs des classes", { adv = true })
	for _, e in ipairs(VP.Colors.CLASS_LIST) do
		local cls = e[1]
		-- tant que la couleur n'est pas modifiée, on montre celle de Blizzard sans l'enregistrer
		local tmp = {}
		p:Color(e[2], function()
			if c.class[cls] then return c.class[cls] end
			tmp[1], tmp[2], tmp[3] = VP.Colors:Class(cls)
			return tmp
		end, nil, true, function()
			if not c.class[cls] then c.class[cls] = { tmp[1], tmp[2], tmp[3] } end
		end)
	end
	p:Color("Familiers", function() return c.pet end, nil, true)
	p:Buttons({
		{ "Couleurs Blizzard", function() wipe(c.class); layout(); UI:RefreshCurrent() end, 180 },
		{ "Toutes les couleurs par défaut", function() VP.Colors:Reset(); UI:RefreshCurrent() end, 220 },
	})

	p:Section("Fenêtre de configuration")
	p:Slider("Taille de cette fenêtre", 70, 140, 5, function() return math.floor(((d.uiScale) or 1) * 100 + 0.5) end,
		function(v) d.uiScale = v / 100; UI:ApplyScale() end, " %", true)
	p:Note("Agrandissez la fenêtre si le texte est trop petit sur votre écran. N'agit pas sur les cadres de soin.")
end, { icon = I .. "INV_Misc_Gem_Variety_01", keys = "apparence couleur police texte texture accent theme opacite portee classe" })

UI:AddTab("ind", "Indicateurs", function(p)
	local d = db()
	local c = d.colors
	p:Title("Indicateurs", "Les petites informations du cadre en plus de la vie. Ici on les active ; leur position se règle dans Placement des icônes.")
	testButtons(p)
	p:Section("Sur les cadres")
	p:Toggle("Aggro (trait rouge)", function() return d.showAggro end, function(v) d.showAggro = v end, true)
	p:Toggle("Statuts (AFK, contrôlé, feinte)", function() return d.showStatus end, function(v) d.showStatus = v end, true)
	p:Toggle("« Boit 45% » (joueur en train de boire)", function() return d.showDrinking end, function(v) d.showDrinking = v end, true,
		"Hors combat, à la place du texte de vie quand le joueur est en pleine vie : il boit, avec sa mana actuelle. "
		.. "Pratique pour savoir quand lancer le pull.")
	p:Toggle("Surbrillance du cadre survolé", function() return d.hoverHighlight end, function(v) d.hoverHighlight = v end, true,
		"Le cadre sous la souris s'éclaircit : on voit tout de suite sur qui part le clic de soin.")
	p:Toggle("Rôle (tank / soigneur / DPS)", function() return d.showRole end, function(v) d.showRole = v; layout() end, true,
		"Rôle de la Recherche de donjon s'il existe, sinon déduit des talents (le vôtre tout de suite, celui des autres après une courte inspection hors combat).")
	p:Toggle("Afficher aussi l'icône DPS", function() return d.roleShowDps end, function(v) d.roleShowDps = v end, true)
	p:Toggle("Couronne du chef", function() return d.showLeader end, function(v) d.showLeader = v; layout() end, true,
		"Petite couronne sur le cadre du chef du groupe ou du raid (comme Cell). Position : page Placement des icônes, « Chef / assistant ».")
	p:Toggle("   + Icône des assistants", function() return d.showAssist end, function(v) d.showAssist = v; layout() end, true,
		"Les assistants du raid ont aussi leur icône (ceux qui peuvent lancer un appel, poser des symboles...).")
	p:Toggle("Rôle des autres via leurs talents", function() return d.roleInspect end, function(v) d.roleInspect = v end, true,
		"Inspecte discrètement un joueur toutes les 2 secondes, hors combat et à portée, pour connaître sa spécialisation.")
	p:Toggle("Partager ma spé avec les joueurs VuhPlus", function() return d.roleShare ~= false end,
		function(v) d.roleShare = v; if v then VP.Roles:QueueShare(0) end end, true,
		"Chaque joueur VuhPlus envoie l'arbre principal de ses talents au groupe : son rôle est connu tout de suite, "
		.. "sans inspection ni distance, et un changement de spé suit aussitôt. Un petit message d'addon invisible "
		.. "part quand le groupe ou vos talents changent, puis toutes les 2 minutes.")
	p:Toggle("Icônes d'appel (ready check)", function() return d.showReadyCheck end, function(v) d.showReadyCheck = v end, true)
	p:Slider("Garder les réponses de l'appel", 0, 30, 1, function() return d.readyHold or 5 end,
		function(v) d.readyHold = v end, " s", true)
	p:Toggle("Alerte mana faible (soigneurs)", function() return d.lowMana end, function(v) d.lowMana = v end, true,
		"La barre de mana devient orange clignotant sous le seuil, pour les prêtres, paladins, druides et chamans.")
	p:Slider("Seuil mana faible", 5, 50, 5, function() return d.lowManaPct end, function(v) d.lowManaPct = v end, " %", true)

	p:Section("Soins entrants", { key = "incoming" })
	p:Note(nil, function()
		return VP.healComm and "|cff33ff99LibHealComm-4.0 détectée : soins entrants actifs.|r"
			or "|cffff6666LibHealComm-4.0 absente.|r Installez l'addon LibHealComm-4.0 (version 3.3.5) pour voir les soins entrants."
	end)
	p:Toggle("Barre de soins entrants", function() return d.showIncoming end, function(v) d.showIncoming = v end, true)
	p:Color("Couleur", function() return c.incoming end, nil, true)
	p:Slider("Soins arrivant dans les", 0, 10, 1, function() return d.incomingWindow or 4 end,
		function(v) d.incomingWindow = v end, " s", true)
	p:Toggle("Compter mes propres soins", function() return d.incomingMine ~= false end, function(v) d.incomingMine = v end, true,
		"Décoché : seuls les soins des AUTRES soigneurs sont affichés, pour éviter de soigner en double.")
	p:Note("0 s = tous les soins en cours, HoTs entiers compris (la barre et le surplus « +3.2k » sont alors surestimés).")

	p:Section("Boucliers (absorption)")
	p:Note("Fine barre en bas de la vie : Mot de pouvoir : Bouclier, Égide divine, Bouclier sacré, Barrière de glace... "
		.. "Montant lu dans l'infobulle du buff.")
	p:Toggle("Barre des boucliers", function() return d.showAbsorb end, function(v) d.showAbsorb = v end, true)
	p:Color("Couleur", function() return c.absorb end, nil, true)
	p:Slider("Hauteur", 1, 8, 1, function() return d.absorbHeight or 3 end, function(v) d.absorbHeight = v end, " px", true)

	p:Section("Mode urgence")
	p:Toggle("Bordure autour des plus blessés", function() return d.emergency end, function(v) d.emergency = v end, nil,
		"Une bordure entoure les joueurs les plus blessés sous le seuil.")
	p:Slider("Vie sous", 10, 90, 5, function() return d.emergencyPct end, function(v) d.emergencyPct = v end, " %", true)
	p:Slider("Nombre de joueurs", 1, 10, 1, function() return d.emergencyCount end, function(v) d.emergencyCount = v end, nil, true)
	p:Color("Urgence (le plus blessé)", function() return c.urgent end, nil, true)
	p:Color("Pas urgent", function() return c.notUrgent end, nil, true)

	p:Section("Indicateurs de soigneur")
	p:Toggle("Activer les indicateurs", function() return d.indicators end, function(v) d.indicators = v end, true)
	p:Slider("Taille des indicateurs", 10, 48, 1, function() return d.indSize end, function(v) d.indSize = v; layout() end, " px", true)
	p:Toggle("Gros défensif actif", function() return d.indDefensive end, function(v) d.indDefensive = v end, true,
		"Mur protecteur, Dernier rempart, Instincts de survie, Écorce, Robustesse glaciale, Bouclier divin, Main de protection, "
		.. "Suppression de la douleur, Esprit gardien, Dispersion, Évasion, Bloc de glace, Renvoi de sort, Intervention, "
		.. "Zone anti-magie, Intervention divine... avec le temps restant.")
	p:Toggle("Soins réduits", function() return d.indHealRed end, function(v) d.indHealRed = v end, true,
		"Frappe mortelle, Poison douloureux, Visée, Attaques furieuses, Blessure mortelle, Aura nécrotique... : vos soins sont moins efficaces sur ce joueur.")
	p:Toggle("Pierre d'âme", function() return d.indSoul end, function(v) d.indSoul = v end, true)
	p:Toggle("Ciblé par le boss (bordure)", function() return d.indBossTarget end, function(v) d.indBossTarget = v end, true,
		"Bordure autour du joueur ciblé par un boss (boss1 à 4), par votre cible ou par votre focalisation hostile.")
	p:Color("Couleur « ciblé par le boss »", function() return c.bossTarget end, nil, true)

	p:Section("Mort et résurrection")
	p:Toggle("Temps depuis la mort (« Mort 1:23 »)", function() return d.deadTimer end, function(v) d.deadTimer = v end, true,
		"Aide à choisir à qui donner la résurrection en combat.")
	p:Toggle("Résurrection en cours / en attente", function() return d.rezStatus end, function(v) d.rezStatus = v end, true,
		"« Rez... » : quelqu'un ressuscite déjà ce joueur. « Rez en attente » : il n'a plus qu'à accepter. Évite les doubles résurrections.")
	p:Note(nil, function()
		return (VP.Rez and VP.Rez.lib) and "|cff33ff99LibResComm-1.0 détectée : les résurrections EN COURS des autres joueurs sont visibles.|r"
			or "Vos résurrections et celles réussies de tout le groupe sont visibles. Pour voir aussi celles EN COURS des autres, "
				.. "installez LibResComm-1.0 (version 3.3.5) ; les autres joueurs doivent l'avoir aussi."
	end)

	p:Section("Ma cible d'incantation")
	p:Toggle("Bordure sur le joueur que je soigne", function() return d.castHighlight end, function(v) d.castHighlight = v end, true,
		"Pendant votre incantation, le cadre visé est entouré : pratique pour ne pas soigner deux fois le même joueur.")
	p:Color("Couleur", function() return c.cast end, nil, true)

	p:Section("Flèche de direction (joueur hors de portée)")
	p:Note("La flèche indique la direction à prendre pour rejoindre le joueur. Elle disparaît dès qu'il est à portée de votre sort de soin. "
		.. "Elle utilise la carte du jeu : elle peut être absente dans certaines instances sans carte.")
	p:Toggle("Petite flèche sur le cadre", function() return d.arrows end, function(v) d.arrows = v end, true)
	p:Slider("Taille de la flèche", 8, 48, 1, function() return d.arrowSize end, function(v) d.arrowSize = v; layout() end, " px", true)
	p:Toggle("Grande flèche sur le cadre survolé", function() return d.guideArrow end, function(v) d.guideArrow = v; VP.Frames:UpdateGuide() end, true,
		"Quand vous survolez un joueur hors de portée, une grande flèche apparaît par-dessus son cadre. "
		.. "Elle disparaît dès qu'il est à portée ou quand la souris quitte le cadre.")
	p:Toggle("Grande flèche aussi pour ma cible", function() return d.guideTarget end, function(v) d.guideTarget = v end, true,
		"Si votre cible est un membre du groupe hors de portée, la grande flèche s'affiche sur le cadre de votre cible.")
	p:Slider("Taille de la grande flèche", 40, 150, 5, function() return d.guideScale or 100 end,
		function(v) d.guideScale = v; layout() end, " % de la hauteur", true)
	p:Color("Couleur de la flèche", function() return c.arrow end, nil, true)

	p:Section("Surplus de soin (« +3.2k »)")
	p:Toggle("Afficher le surplus de soin", function() return d.overhealText end, function(v) d.overhealText = v end, true,
		"Affiche « +3.2k » quand les soins en cours dépassent la vie manquante (nécessite LibHealComm-4.0).")
	p:Slider("Taille du texte", 8, 28, 1, function() return d.overhealSize end, function(v) d.overhealSize = v; layout() end, nil, true)

	p:Section("Symboles de raid (étoile, crâne...)", { adv = true })
	p:Toggle("Afficher les symboles de raid", function() return d.showRaidIcon end, function(v) d.showRaidIcon = v end, true)
	p:Toggle("Couleur du symbole sur le cadre", function() return d.raidIconColor ~= "NONE" end,
		function(v) d.raidIconColor = v and "ON" or "NONE" end, true, "« Fond » : bordure de la couleur du symbole ; « Texte » : nom de la couleur du symbole.")
	p:Slider("Taille du symbole", 8, 48, 1, function() return d.raidIconSize end, function(v) d.raidIconSize = v; layout() end, " px", true)
	p:Slider("Opacité du symbole", 20, 100, 5, function() return math.floor((d.raidIconAlpha or 1) * 100 + 0.5) end,
		function(v) d.raidIconAlpha = v / 100; layout() end, " %", true)
	p:Note("Symboles affichés et leur couleur :")
	for i, ri in ipairs(VP.Frames.RAID_ICONS) do
		local idx = i
		p:Toggle(ri[1], function() return d.raidIconShow[idx] ~= false end, function(v) d.raidIconShow[idx] = v end, true)
		p:Color(ri[1], function() return c.raid[idx] end, { bg = true, text = true }, true)
	end

	p:Section("Infobulle", { adv = true })
	p:Toggle("Infobulle au survol", function() return d.tooltip end, function(v) d.tooltip = v end, true)
	p:Toggle("Aussi en combat", function() return d.tooltipInCombat end, function(v) d.tooltipInCombat = v end, true)

	p:Link("Position de toutes ces icônes :", "icons", "pos")
end, { icon = I .. "Spell_Holy_PowerWordShield", keys = "soins entrants bouclier absorption urgence aggro role fleche surplus overheal mort rez symbole infobulle portee" })

UI:AddTab("icons", "Placement des icônes", function(p)
	local d = db()
	local ip = d.iconPos
	p:Title("Placement des icônes", "Le seul endroit pour placer une icône : choisissez-la, puis sa position sur le schéma, "
		.. "son décalage et sa taille. Ou glissez-la directement à la souris plus bas.")
	testButtons(p)

	p:Section("Mode de placement")
	p:Dropdown("Placement", {
		{ "FREE", "Individuel : chaque icône à sa place" },
		{ "AUTO", "Alignement automatique (anti-chevauchement)" },
	}, function() return d.iconLayout end, function(v) d.iconLayout = v; layout() end, true)
	p:Gap(2)
	p:Toggle("Éviter les chevauchements", function() return d.avoidOverlap ~= false end,
		function(v) d.avoidOverlap = v; layout() end, true,
		"Si la place choisie est déjà prise par une icône plus importante, l'icône se décale juste à côté, vers l'intérieur du cadre. "
		.. "Ordre de priorité : débuff de boss, dispel, HoT 1 à 6, puis les autres.")

	p:Section("Position de chaque icône", { key = "pos" })
	p:Note("Choisissez une icône, puis sa position sur le schéma. Changer de position remet le décalage X / Y de l'icône à zéro.")
	local ELEMENTS = {}
	for i = 1, VP.Frames.NUM_SLOTS do ELEMENTS[#ELEMENTS + 1] = { "slot" .. i, "HoT " .. i } end
	local OTHER = {
		{ "boss", "Débuff de boss" }, { "dispel", "Dispel" }, { "remind", "Rappel de buff" },
		{ "defensive", "Défensif" }, { "healred", "Soins réduits" }, { "soul", "Pierre d'âme" },
		{ "role", "Rôle" }, { "leader", "Chef / assistant" }, { "raid", "Symbole de raid" }, { "missing", "Buff de raid manquant" },
		{ "arrow", "Petite flèche" }, { "guide", "Grande flèche (survol)" },
		{ "others", "Autres débuffs" }, { "overheal", "Surplus de soin" },
	}
	for _, e in ipairs(OTHER) do ELEMENTS[#ELEMENTS + 1] = e end
	O.elemSel = O.elemSel or "slot1"
	-- accès uniformes : position, décalage, taille de l'élément choisi
	local function slotOf(key)
		local n = tonumber(string.match(key, "^slot(%d)$"))
		return n and VP.Frames:HotSlots()[n]
	end
	local function getPos()
		local sl = slotOf(O.elemSel)
		if sl then return sl.pos end
		return ip[O.elemSel]
	end
	local function setPos(v)
		local sl = slotOf(O.elemSel)
		-- nouvelle zone = position propre : le décalage X / Y de l'ancienne zone est remis à zéro
		if sl then
			if sl.pos ~= v then sl.offX, sl.offY = 0, 0 end
			sl.pos = v
		else
			if ip[O.elemSel] ~= v and d.iconOff[O.elemSel] then d.iconOff[O.elemSel].x, d.iconOff[O.elemSel].y = 0, 0 end
			ip[O.elemSel] = v
		end
		layout()
		UI:RefreshCurrent()
	end
	local function off()
		d.iconOff[O.elemSel] = d.iconOff[O.elemSel] or { x = 0, y = 0, size = 0 }
		return d.iconOff[O.elemSel]
	end
	local function getV(field)
		local sl = slotOf(O.elemSel)
		if sl then return (field == "x" and sl.offX) or (field == "y" and sl.offY) or sl.size or 0 end
		return off()[field] or 0
	end
	local function setV(field, v)
		local sl = slotOf(O.elemSel)
		if sl then
			if field == "x" then sl.offX = v elseif field == "y" then sl.offY = v else sl.size = v end
		else
			off()[field] = v
		end
		layout()
	end
	p:Chips(nil, ELEMENTS, function() return O.elemSel end, function(v) O.elemSel = v end, 4)
	p:PositionPicker(function()
		for _, e in ipairs(ELEMENTS) do
			if e[1] == O.elemSel then
				local sl = slotOf(O.elemSel)
				local extra = (sl and sl.spell and sl.spell ~= "") and ("  |cffffffff(" .. sl.spell .. ")|r") or ""
				return "Icône choisie : |cffffffff" .. e[2] .. "|r" .. extra
			end
		end
		return ""
	end, getPos, setPos)
	-- décalages au pixel près (enregistrés en % pour suivre les changements de taille du cadre)
	local function pxW() return d.width end
	local function pxH() return VP.Frames:FrameHeight() end
	p:Slider("Décalage X", -60, 60, 1, function() return math.floor(getV("x") * pxW() / 100 + 0.5) end,
		function(v) setV("x", v * 100 / pxW()) end, " px", true)
	p:Slider("Décalage Y", -40, 40, 1, function() return math.floor(getV("y") * pxH() / 100 + 0.5) end,
		function(v) setV("y", v * 100 / pxH()) end, " px", true)
	p:Slider("Taille de cette icône (0 = par défaut)", 0, 64, 1, function() return getV("size") end, function(v) setV("size", v) end, " px", true)
	p:Buttons({ { "Remettre à zéro (décalage et taille)", function()
		setV("x", 0); setV("y", 0); setV("size", 0); UI:RefreshCurrent()
	end, 260 } })

	-- placement précis à la souris (copie agrandie d'un cadre)
	p:Section("Placement précis à la souris", { desc = "glisser, molette, flèches" })
	local GHOST = {
		boss = { "bossSize", 18, I .. "Spell_Shadow_DeathScream" }, dispel = { "dispelSize", 14, I .. "Spell_Holy_DispelMagic" },
		remind = { "remindSize", 18, I .. "Spell_Nature_LightningShield" }, defensive = { "indSize", 16, I .. "Ability_Warrior_ShieldWall" },
		healred = { "indSize", 16, I .. "Ability_Warrior_SavageBlow" }, soul = { "indSize", 16, I .. "Spell_Shadow_SoulGem" },
		role = { nil, 11, I .. "Ability_Defend" }, raid = { "raidIconSize", 16, "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
		leader = { nil, 10, "Interface\\GroupFrame\\UI-Group-LeaderIcon" },
		missing = { nil, 5, I .. "Spell_Holy_WordFortitude" }, arrow = { "arrowSize", 16, "Interface\\Minimap\\MinimapArrow" },
		guide = { nil, 0, "Interface\\Minimap\\MinimapArrow" },
		others = { nil, 11, I .. "Spell_Shadow_ShadowWordPain" },
	}
	local NAMES = {}
	for _, e in ipairs(ELEMENTS) do NAMES[e[1]] = e[2] end
	p:HotDesigner({
		list = function()
			local t = {}
			-- les autres icônes d'abord (dessous), puis les HoTs configurés (dessus)
			for _, e in ipairs(OTHER) do if GHOST[e[1]] then t[#t + 1] = e[1] end end
			local slots = VP.Frames:HotSlots()
			for i = 1, VP.Frames.NUM_SLOTS do
				if slots[i] and slots[i].spell and slots[i].spell ~= "" then t[#t + 1] = "slot" .. i end
			end
			return t
		end,
		info = function(key)
			local sl = slotOf(key)
			if sl then
				local base = d.hotSize or 14
				local size = (sl.size and sl.size > 0) and sl.size or base
				local tex = VP.Frames:SpellIcon(sl.spell)   -- aussi hors du grimoire (Viveterre, Égide divine...)
				local n = tonumber(string.match(key, "%d"))
				return sl.pos or ip.hots, sl.offX or 0, sl.offY or 0, size, size,
					tex or "Interface\\Icons\\INV_Misc_QuestionMark", "HoT " .. n .. " (" .. sl.spell .. ")", n
			end
			local g = GHOST[key] or { nil, 12, "Interface\\Icons\\INV_Misc_QuestionMark" }  -- ex. texte de surplus de soin
			local o = d.iconOff[key] or { x = 0, y = 0, size = 0 }
			local base = (g[1] and d[g[1]]) or g[2]
			local size = (o.size and o.size > 0) and o.size or base
			if key == "guide" then size = VP.Frames:GuideSize() end
			return ip[key] or "C", o.x or 0, o.y or 0, size, size, g[3], NAMES[key] or key, nil
		end,
		selected = function() return O.elemSel end,
		select = function(key) O.elemSel = key end,
		setOff = function(key, x, y)
			local sl = slotOf(key)
			if sl then sl.offX, sl.offY = x, y
			else
				d.iconOff[key] = d.iconOff[key] or { x = 0, y = 0, size = 0 }
				d.iconOff[key].x, d.iconOff[key].y = x, y
			end
		end,
		setSize = function(key, px)
			local sl = slotOf(key)
			if sl then sl.size = px
			else
				d.iconOff[key] = d.iconOff[key] or { x = 0, y = 0, size = 0 }
				d.iconOff[key].size = px
			end
		end,
		commit = function() layout() end,
	})

	p:Section("Sens d'empilement", { adv = true })
	p:Dropdown("HoTs au même endroit", {
		{ "AUTO", "Automatique (vers l'intérieur)" }, { "LEFT", "Vers la gauche" }, { "RIGHT", "Vers la droite" },
		{ "UP", "Vers le haut" }, { "DOWN", "Vers le bas" },
	}, function() return ip.hotGrow end, function(v) ip.hotGrow = v; layout() end, true)
	p:Dropdown("Autres débuffs", {
		{ "LEFT", "Vers la gauche" }, { "RIGHT", "Vers la droite" }, { "UP", "Vers le haut" }, { "DOWN", "Vers le bas" },
	}, function() return ip.othersGrow end, function(v) ip.othersGrow = v; layout() end, true)
	p:Toggle("HoTs : positions fixes (place réservée même vide)", function() return d.hotFixed end, function(v) d.hotFixed = v; layout() end)
end, { icon = I .. "Ability_Hunter_SniperShot", keys = "icone position decalage placement schema souris" })

UI:AddTab("panels", "Fenêtres à l'écran", function(p)
	local d = db()
	p:Title("Fenêtres à l'écran", "Toutes les fenêtres en un coup d'œil. Chaque ligne est le même réglage que sur la page de sa fonction : "
		.. "le lien y mène. Les panneaux se déplacent avec « Déplacer les cadres », en bas.")
	p:Section("Cadres de soin", { key = "frames" })
	p:Toggle("Afficher les cadres de soin (raid, tanks, cible, familiers)", function() return d.showFrames ~= false end,
		function(v) d.showFrames = v; VP:RefreshAll() end, nil,
		"Décochez pour ne garder que les fenêtres d'information (recharges du raid, état du raid, barre d'outils...) : "
		.. "utile pour un DPS ou un tank. Commande : /vp cadres. En combat, le changement s'applique à la fin du combat.")
	local function pan(key) return function() return d.panels[key].enabled end, function(v) d.panels[key].enabled = v; layout() end end
	local g, s = pan("tanks"); p:Toggle("Tanks principaux du raid", g, s, true)
	g, s = pan("mytanks"); p:Toggle("Mes tanks (liste perso)", g, s, true)
	g, s = pan("target"); p:Toggle("Cible / cible de cible / focus", g, s, true)
	p:Toggle("   + Cible du boss", function() return d.panels.target.boss end,
		function(v) d.panels.target.boss = v; layout() end, true,
		"Cadre cliquable du joueur que le boss frappe (boss1target) : quand les tanks alternent, on soigne le bon sans le chercher.")
	p:Toggle("   + Cible de la focalisation", function() return d.panels.target.focusTarget end,
		function(v) d.panels.target.focusTarget = v; layout() end, true,
		"Mettez le boss en focalisation : ce cadre montre toujours le joueur qu'il frappe, pour tous les boss.")
	p:Link("Familiers :", "pets")

	p:Section("Fenêtres d'information", { key = "windows" })
	p:Note("Verrouiller les cadres bloque seulement leur position : les fenêtres cochées restent affichées.")
	p:Toggle("Cacher les fenêtres vides (cadres verrouillés)", function() return d.hideEmpty end,
		function(v) d.hideEmpty = v; VP:RefreshAll() end, nil,
		"Cadres verrouillés, la liste « À dissiper » se cache quand personne n'est à dissiper, et l'état du raid "
		.. "quand vous êtes seul. Les recharges du raid suivent leur réglage « Seulement en groupe » (page Recharges et annonces).")
	p:Toggle("Buffs (clic = lancer)", function() return d.buffs.showPanel end,
		function(v) d.buffs.showPanel = v; VP.Buffs:Refresh() end, nil, nil, { "buffs" })
	p:Toggle("Liste « À dissiper »", function() return d.dispel.liveList end,
		function(v) d.dispel.liveList = v; VP.LiveList:Refresh() end, nil, nil, { "dispel" })
	p:Toggle("État du raid (morts, déco, loin, mana des soigneurs)", function() return d.alerts.status end,
		function(v) d.alerts.status = v; VP.Raid:Refresh() end, nil, nil, { "lead", "status", "Outils de chef" })
	p:Toggle("Recharges du raid et rez combat", function() return d.cooldowns.enabled end,
		function(v) d.cooldowns.enabled = v; VP.Cooldowns:Refresh() end, nil, nil, { "cds", "cd", "Recharges" })
	p:Toggle("Temps des gros sorts (barres à l'écran)", function() return d.announce.bars end,
		function(v) d.announce.bars = v; VP.Announce:Refresh() end, nil, nil, { "cds", "announce", "Annonces" })
	p:Toggle("Barre d'outils de raid (toujours affichée)", function() return d.alerts.tools end,
		function(v) d.alerts.tools = v; VP.Raid:ApplyTools() end, nil, nil, { "lead", "tools", "Outils de chef" })
	p:Toggle("Bouton Bijoux", function() return d.trinket.enabled and d.trinket.showButton end,
		function(v) d.trinket.showButton = v; if v then d.trinket.enabled = true end; VP.Trinkets:UpdateVisibility() end, nil, nil, { "trinkets" })
	p:Toggle("Projecteur (joueurs choisis)", function() return d.panels.spotlight.enabled end,
		function(v) d.panels.spotlight.enabled = v; layout(); VP.Panels:ApplySpotlight() end, nil, nil, { "lead", "spot", "Outils de chef" })

	p:Section("Divers", { adv = true })
	p:Toggle("Masquer les cadres de groupe Blizzard", function() return d.hideBlizzParty end, function(v)
		d.hideBlizzParty = v; VP.Panels:ApplyBlizzard()
		if not v then VP:Print("Tapez /reload pour réafficher complètement les cadres Blizzard.") end
	end, true)
	p:Toggle("Barre de recharge globale (GCD)", function() return d.gcdBar end, function(v) d.gcdBar = v end, true)
	p:Toggle("Bouton de la minicarte", function() return d.minimap end, function(v) d.minimap = v; VP.Panels:UpdateMinimap() end, true)
end, { icon = I .. "INV_Misc_Bag_08", keys = "panneau fenetre afficher cacher tank cible focus projecteur minicarte blizzard" })

UI:AddTab("pets", "Familiers", function(p)
	local pt = db().pets
	local function petLayout() VP.Panels:ApplyLayout(); VP.Frames:Refresh() end
	p:Title("Familiers", "Cadres des familiers de chasseur, démoniste, chevalier de la mort, élémentaire d'eau... "
		.. "Les clics, touches, HoTs, débuffs et la flèche de direction fonctionnent aussi sur eux.")
	p:Section("Affichage")
	p:Toggle("Soigner les familiers", function() return pt.enabled end, function(v) pt.enabled = v; petLayout() end, nil,
		"Décochez si vous ne voulez pas soigner les familiers : leurs cadres disparaissent complètement.")
	p:Dropdown("Où les afficher", {
		{ "ATTACH", "Sous le groupe de leur maître" },
		{ "SIDE", "À côté des joueurs (à droite du raid)" },
		{ "PANEL", "Dans un panneau séparé (déplaçable)" },
	}, function() return pt.mode end, function(v) pt.mode = v; petLayout() end, true)
	p:Gap(2)
	p:Toggle("Seulement en combat", function() return pt.combatOnly end, function(v) pt.combatOnly = v; petLayout() end, true)
	p:Toggle("Discrets en pleine vie", function() return pt.dimFull end, function(v) pt.dimFull = v; VP.Frames:Refresh() end, true,
		"Un familier en pleine vie est transparent ; il ressort dès qu'il perd des points de vie. Attention : il ressemble alors à un familier hors de portée.")
	p:Slider("Transparence en pleine vie", 10, 100, 5, function() return math.floor((pt.dimAlpha or 0.45) * 100 + 0.5) end,
		function(v) pt.dimAlpha = v / 100; VP.Frames:Refresh() end, " %", true)
	p:Slider("Hauteur des familiers", 30, 100, 5, function() return pt.height end, function(v) pt.height = v; petLayout() end, " %", true)
	p:Slider("Largeur des familiers", 40, 100, 5, function() return pt.width end, function(v) pt.width = v; petLayout() end, " %", true)
	p:Toggle("Nom du maître : « Félin (Bob) »", function() return pt.ownerName end, function(v) pt.ownerName = v; VP.Frames:Refresh() end, true)
	p:Toggle("Couleur de classe du maître", function() return pt.ownerColor end, function(v) pt.ownerColor = v; VP.Frames:Refresh() end, true)
	p:Toggle("Alertes de dispel sur les familiers", function() return pt.dispel end, function(v) pt.dispel = v; VP.Frames:Refresh() end, true)
	p:Toggle("Surplus de soin « +3.2k » sur les familiers", function() return pt.overheal end, function(v) pt.overheal = v; VP.Frames:Refresh() end, true)

	p:Section("Familiers temporaires à ignorer", { adv = true })
	p:Note("Ces classes n'ont que des invocations de quelques secondes qui feraient bouger les cadres en plein combat. "
		.. "Un familier ignoré n'a pas de cadre (changement pris en compte hors combat).")
	pt.hideClasses = pt.hideClasses or {}
	for _, e in ipairs({ { "DRUID", "Tréants du druide (Force de la nature)" }, { "SHAMAN", "Loups esprits / élémentaires du chaman" },
		{ "PRIEST", "Ombrefiel du prêtre" }, { "MAGE", "Élémentaire d'eau du mage" }, { "DEATHKNIGHT", "Goule / gargouille du chevalier de la mort" } }) do
		p:Toggle(e[2], function() return pt.hideClasses[e[1]] end, function(v) pt.hideClasses[e[1]] = v and true or false; petLayout() end, true)
	end
end, { icon = I .. "Ability_Hunter_Pet_Assist", keys = "familier pet invocation",
	active = function() return db().pets.enabled end })

-- =====================================================================================
-- RAID
-- =====================================================================================

UI:AddTab("cds", "Recharges et annonces", function(p)
	local d = db()
	local cd = d.cooldowns
	local an = d.announce
	p:Title("Recharges et annonces", "Qui a quoi de prêt dans le raid, et l'annonce de vos gros sorts.")
	p:Section("Recharges du raid et rez combat", { key = "cd" })
	p:Note("Panneau « qui a quoi de prêt » : Suppression de la douleur, Esprit gardien, Main de sacrifice, Maîtrise des auras, "
		.. "Hymnes, Totem de vague de mana, Innervation, Héroïsme... et une ligne « Rez combat ». Vos sorts : recharge exacte. "
		.. "Les autres : recharge de base, comptée dès que le sort est vu lancé. /vp cd pour afficher / cacher.")
	p:Toggle("Afficher le panneau", function() return cd.enabled end, function(v) cd.enabled = v; VP.Cooldowns:Refresh() end, true)
	p:Toggle("Seulement en groupe", function() return cd.groupOnly end, function(v) cd.groupOnly = v; VP.Cooldowns:Refresh() end, true)
	p:Toggle("Ligne « Rez combat »", function() return cd.br end, function(v) cd.br = v; VP.Cooldowns:Refresh() end, true)
	p:Slider("Taille du panneau", 50, 200, 5, function() return math.floor((cd.scale or 1) * 100 + 0.5) end,
		function(v) cd.scale = v / 100; VP.Cooldowns:Refresh() end, " %", true)
	p:Toggle("Partager mes vraies recharges avec les joueurs VuhPlus", function() return cd.sync ~= false end,
		function(v) cd.sync = v; if v then VP.Cooldowns:QueueSend(0) end end, nil,
		"Chaque joueur VuhPlus envoie la recharge exacte de ses sorts (talents et glyphes compris) et la liste de ceux qu'il possède. "
		.. "Pour eux, le panneau n'estime plus : il sait. Le titre du panneau indique combien de joueurs sont « exacts ». "
		.. "Un petit message d'addon invisible part au groupe quand vous lancez un sort suivi et toutes les 2 minutes.")
	p:Note(nil, function()
		local n = VP.Cooldowns:SyncedCount()
		return n > 0 and ("|cff55dd77" .. n .. " joueur(s) VuhPlus partagent leurs recharges avec vous.|r")
			or "Aucun autre joueur VuhPlus ne partage ses recharges pour l'instant (recharges des autres : estimées)."
	end)

	p:Section("Sorts suivis dans le panneau", { adv = true })
	for _, e in ipairs(VP.Cooldowns.SPELLS) do
		if e.name and (not e.faction or e.faction == UnitFactionGroup("player")) then
			local id = e.id
			p:Toggle(e.name, function() return cd.spells[id] ~= false end,
				function(v) if v then cd.spells[id] = nil else cd.spells[id] = false end; VP.Cooldowns:Refresh() end, true)
		end
	end

	p:Section("Annonces de mes sorts", { key = "announce" })
	p:Note("Annonce vos gros sorts quand ils sont lancés (ex. « >> Héroïsme (40 s) << »). Mode discret par défaut : "
		.. "une ligne au groupe pour les sorts de raid, les autres seulement dans votre chat, rien hors instance.")
	p:Toggle("Annoncer mes sorts", function() return an.enabled end, function(v) an.enabled = v end, true)
	p:Dropdown("Canal", {
		{ "AUTO", "Automatique (raid / groupe / BG)" }, { "SAY", "Dire (/s)" }, { "YELL", "Crier (/cri)" },
		{ "SELF", "Mon chat uniquement" },
	}, function() return an.channel end, function(v) an.channel = v end, true)
	p:Dropdown("Compte à rebours dans le chat", {
		{ "NONE", "Aucun (juste l'annonce de départ) - conseillé" },
		{ "LIGHT", "Léger : 10 et 5 s puis « terminé »" },
		{ "FULL", "Complet : 30, 20, 10, 5, 3, 2, 1 s puis « terminé »" },
		{ "END", "Seulement « terminé »" },
	}, function() return an.countdown or "NONE" end, function(v) an.countdown = v end, true)
	p:Dropdown("Sorts annoncés au groupe", {
		{ "BIG", "Sorts de raid seulement (Héroïsme, Renaissance, hymnes...)" },
		{ "ALL", "Tous mes sorts suivis" },
		{ "NONE", "Aucun (rien dans le chat du groupe)" },
	}, function() return an.scope or "BIG" end, function(v) an.scope = v end)
	p:Note("Sorts de raid : Héroïsme / Furie sanguinaire, Renaissance, Totem de vague de mana, hymnes, Maîtrise des auras, "
		.. "Sacrifice divin. Au plus un message au groupe toutes les 3 secondes.")
	p:Toggle("Seulement en instance", function() return an.instanceOnly ~= false end, function(v) an.instanceOnly = v end, true,
		"Rien dans le chat du groupe dans le monde extérieur (donjon, raid et champ de bataille seulement).")
	p:Toggle("Sinon, afficher dans mon chat", function() return an.soloSelf end, function(v) an.soloSelf = v end, true,
		"Une annonce qui ne part pas au groupe s'affiche quand même dans votre propre chat.")
	p:Toggle("Alerte de raid pour les gros sorts", function() return an.warning end, function(v) an.warning = v end, true,
		"Si vous êtes chef ou assistant : Héroïsme, Totem de vague de mana, hymnes... en alerte de raid (au milieu de l'écran).")
	p:Toggle("Annoncer mes temps de recharge", function() return an.cdAnnounce end, function(v) an.cdAnnounce = v end, true,
		"Ex. « >> Renaissance sur Bob << - de nouveau utilisable dans 20 min », puis « de nouveau disponible » dès qu'elle est prête.")
	p:Toggle("« De nouveau disponible » dans mon chat seulement", function() return an.cdReadySelf ~= false end,
		function(v) an.cdReadySelf = v end, true)

	p:Section("Barres de temps à l'écran")
	p:Toggle("Barres de temps de mes sorts", function() return an.bars end, function(v) an.bars = v; VP.Announce:Refresh() end, true,
		"Une barre par sort en cours avec le temps restant. Déplaçable avec « Déplacer les cadres ».")
	p:Toggle("Barres de recharge", function() return an.cdBars end, function(v) an.cdBars = v; VP.Announce:Layout() end, true)
	p:Toggle("Barres aussi pour les autres soigneurs", function() return an.othersBars end, function(v) an.othersBars = v end, nil,
		"Héroïsme, Esprit gardien, Suppression de la douleur, Main de sacrifice... lancés par les autres joueurs du groupe "
		.. "(seulement à l'écran, rien n'est envoyé dans le chat).")
	p:Toggle("   Seulement leurs sorts de raid", function() return an.othersBigOnly end, function(v) an.othersBigOnly = v end, true,
		"Héroïsme, Renaissance, hymnes, Maîtrise des auras... : pas de barre pour chaque Innervation ou Main des autres.")

	p:Section("Sorts annoncés", { adv = true })
	local AN = VP.Announce
	if AN and #AN:List() > 0 then
		for _, e in ipairs(AN:List()) do
			local key = e.key
			p:Toggle(AN:Name(e), function() return an.spells[key] ~= false end, function(v) an.spells[key] = v end, true)
		end
	else
		p:Note("|cff999999Aucun sort à annoncer pour votre classe.|r")
	end
end, { icon = I .. "Spell_Nature_Reincarnation", keys = "recharge cooldown cd rez combat annonce heroisme innervation barre",
	active = function() local d = db(); return d.cooldowns.enabled or d.announce.enabled end })

UI:AddTab("lead", "Outils de chef", function(p)
	local d = db()
	local a = d.alerts
	p:Title("Outils de chef", "Pour le chef de raid ou le chef des soigneurs : barre d'outils, consommables, état du raid, "
		.. "assignations de soin, Projecteur et Mes tanks.")

	p:Section("Barre d'outils de raid", { key = "tools" })
	p:Dropdown("Quand je deviens chef ou assistant du raid", {
		{ "ASK", "Me proposer la barre (Oui / Non)" },
		{ "AUTO", "L'afficher automatiquement" },
		{ "NEVER", "Ne rien faire" },
	}, function() return a.toolsAsk or "ASK" end, function(v) a.toolsAsk = v end)
	p:Toggle("Toujours afficher la barre d'outils", function() return a.tools end, function(v) a.tools = v; VP.Raid:ApplyTools() end, nil,
		"Appel (ready check), compte à rebours de pull (5 ou 10 s), les 8 symboles à poser sur votre cible (reclic ou clic droit : retirer) "
		.. "et le bouton x pour retirer le symbole de la cible (Maj+clic : ceux de tout le groupe).")
	p:Buttons({ { "Tester la barre (60 s)", function() VP.Raid:TestTools() end, 180 },
		{ "Tester la proposition", function() VP.Raid:ShowLeadPrompt() end, 170 } })

	p:Section("Consommables : flacons / élixirs et nourriture", { key = "conso" })
	local c = d.consum
	p:Note("Vérifie que chaque joueur a un flacon (ou deux élixirs) et le buff « Bien nourri ». "
		.. "Résultat dans le chat : bouton « Conso » de la barre d'outils, commande /vp conso, ou automatiquement à chaque appel.")
	p:Toggle("Vérifier les flacons / élixirs", function() return c.flask end, function(v) c.flask = v end, true)
	p:Toggle("Vérifier la nourriture", function() return c.food end, function(v) c.food = v end, true)
	p:Toggle("Vérifier à chaque appel (ready check)", function() return c.enabled and c.onReady end,
		function(v) c.onReady = v; c.enabled = true end, true)
	p:Toggle("Bandeau si c'est MOI qui n'ai rien", function() return c.selfAlert end, function(v) c.selfAlert = v end, true,
		"Un bandeau orange s'affiche si vous n'avez pas votre flacon ou votre nourriture.")
	p:Dropdown("Résultat de l'appel automatique", {
		{ "SELF", "Dans mon chat uniquement" },
		{ "GROUP", "Annoncé au raid (si je lance l'appel)" },
	}, function() return c.announce end, function(v) c.announce = v end, true)
	p:Buttons({ { "Vérifier maintenant", function() VP.Consumables:Report(false) end, 160 },
		{ "Annoncer au raid", function() VP.Consumables:Report(true) end, 160 } })

	p:Section("État du raid", { key = "status" })
	p:Toggle("Barre « Morts / Déco / Loin / Mana des soigneurs »", function() return a.status end, function(v) a.status = v; VP.Raid:Refresh() end, nil,
		"Résumé au-dessus du raid. La mana moyenne des soigneurs utilise le rôle détecté (donjon ou talents).")
	p:Dropdown("Rapport de mort", {
		{ "OFF", "Désactivé" }, { "SELF", "Dans mon chat uniquement" }, { "GROUP", "Annoncé au groupe / raid" },
	}, function() return a.deathReport end, function(v) a.deathReport = v end, true)
	p:Note("Le rapport de mort indique le dernier coup reçu : « Arthos est mort : Souffle de givre (12 450) de Sindragosa ».")

	p:Section("Assignations de soin", { key = "assign" })
	p:Note("Une ligne par soigneur : « Bella = Tankor, Arthos ». Vos cibles ont une bordure de couleur "
		.. "et peuvent remplir le Projecteur. Séparateurs acceptés : virgule, point-virgule ou « / ».")
	p:TextArea(function() return VP.Assign:Text() end, function(v) VP.Assign:SetText(v) end, 150)
	p:Buttons({
		{ "Modèle du groupe", function()
			VP.Assign:SetText(VP.Assign:Template()); UI:RefreshCurrent()
		end, 150, true },
		{ "Annoncer au raid", function() VP.Assign:Announce() end, 150 },
		{ "Tout effacer", function() VP.Assign:SetText(""); UI:RefreshCurrent() end, 120 },
	})
	p:Note(nil, function()
		local t = VP.Assign:MyTargets()
		return "Mes cibles : |cffffffff" .. (#t > 0 and table.concat(t, ", ") or "(aucune)") .. "|r"
	end)
	p:Color("Couleur de la bordure", function() return d.colors.assign end, nil, true)

	p:Section("Projecteur", { key = "spot" })
	p:Note("Panneau de cadres en plus pour des joueurs choisis (jusqu'à 10) : /vp spot sur votre cible, ou /vp spot Nom.")
	p:Toggle("Afficher le Projecteur", function() return d.panels.spotlight.enabled end,
		function(v) d.panels.spotlight.enabled = v; layout(); VP.Panels:ApplySpotlight() end, true)
	p:Toggle("Inclure mes cibles assignées", function() return d.spotAssign end,
		function(v) d.spotAssign = v; VP.Panels:ApplySpotlight() end, true)
	p:Note(nil, function() return "Joueurs : |cffffffff" .. (#d.spotlight > 0 and table.concat(d.spotlight, ", ") or "(aucun)") .. "|r" end)
	p:Buttons({
		{ "Ajouter / retirer ma cible", function() VP.Panels:ToggleSpotlight(); UI:RefreshCurrent() end, 200, true },
		{ "Vider la liste", function() wipe(d.spotlight); VP.Panels:ApplySpotlight(); UI:RefreshCurrent() end, 140 },
	})

	p:Section("Mes tanks")
	p:Note(nil, function() return "Liste : |cffffffff" .. (#d.myTanks > 0 and table.concat(d.myTanks, ", ") or "(vide)") .. "|r" end)
	p:Buttons({
		{ "Ajouter / retirer ma cible", function() VP.Panels:ToggleMyTank(); UI:RefreshCurrent() end, 200, true },
		{ "Vider la liste", function() wipe(d.myTanks); VP.Panels:ApplyMyTanks(); UI:RefreshCurrent() end, 140 },
	})
end, { icon = I .. "Ability_Hunter_MarkedForDeath", keys = "chef lead appel pull symbole conso flacon nourriture assignation projecteur tank mort" })

-- =====================================================================================
-- ALERTES (vue d'ensemble)
-- =====================================================================================

UI:AddTab("alerts", "Sons et alertes", function(p)
	local d = db()
	local a = d.alerts
	p:Title("Sons et alertes", "Tout ce qui vous prévient pendant le combat. Les alertes propres à une fonction (dispel, bijoux...) "
		.. "sont aussi ici, avec un lien vers leur page : c'est le même réglage.")

	p:Section("Mode silencieux", { key = "quiet" })
	p:Toggle("Couper toutes les alertes", function() return a.quiet end, function(v) a.quiet = v end, nil,
		"Plus aucun son d'alerte ni bandeau : aggro, tank en danger, débuffs de boss, dispel, dégâts brutaux, bijoux. "
		.. "Les réglages ci-dessous sont conservés. Commande : /vp silence.")
	p:Toggle("Son des alertes (aggro, tank en danger)", function() return a.sound end, function(v) a.sound = v end)

	p:Section("Alertes de combat")
	p:Toggle("Je prends l'aggro", function() return a.aggro end, function(v) a.aggro = v end, nil,
		"Bandeau « Vous avez l'aggro ! » et son : utile pour un soigneur ou un DPS qui attire les monstres. "
		.. "Jamais en spé tank (détectée par les talents, la Présence de givre ou la forme d'ours ; /vp role pour la forcer).")
	p:Toggle("Un autre tank est en danger", function() return a.tankLow end, function(v) a.tankLow = v end, nil,
		"Bandeau quand un AUTRE tank passe sous le seuil (jamais sur vous-même).")
	p:Slider("Tank sous", 5, 80, 5, function() return a.tankPct end, function(v) a.tankPct = v end, " %", true)
	p:Buttons({ { "Tester le bandeau", function() VP.Raid:Flash("Exemple : Thrallinor en danger : 24 %", 1, 0.6, 0.1) end, 170 } })

	p:Section("Dégâts brutaux")
	local sp = d.spike
	p:Toggle("Bordure rouge sur un joueur qui prend un gros coup", function() return sp.enabled end, function(v) sp.enabled = v end, nil,
		"La bordure s'éteint peu à peu : on repère le joueur avant que sa barre soit basse.")
	p:Toggle("Ignorer les tanks", function() return sp.skipTanks end, function(v) sp.skipTanks = v end, true,
		"Les tanks prennent de gros coups en permanence : la bordure clignoterait sans arrêt.")
	p:Toggle("Son", function() return sp.sound end, function(v) sp.sound = v end, true)
	p:Slider("Vie perdue", 10, 80, 5, function() return sp.pct end, function(v) sp.pct = v end, " %", true)
	p:Slider("En moins de", 0.5, 3, 0.5, function() return sp.window end, function(v) sp.window = v end, " s", true)
	p:Color("Couleur", function() return d.colors.spike end, nil, true)

	p:Section("Les autres alertes", { desc = "le lien ouvre la page de la fonction" })
	p:Toggle("Son quand je peux dissiper", function() return d.dispel.sound end, function(v) d.dispel.sound = v end,
		nil, nil, { "dispel" })
	p:Toggle("Son des débuffs de boss critiques", function() local s = d.debuffs.sound; return s == true or (s and s ~= "OFF") end,
		function(v) d.debuffs.sound = v and "CRIT" or "OFF" end, nil, nil, { "debuffs", "options" })
	p:Toggle("Mana faible des soigneurs", function() return d.lowMana end, function(v) d.lowMana = v end, nil, nil, { "ind" })
	p:Toggle("Bijoux prêts en phase critique (son)", function() return d.trinket.sound end, function(v) d.trinket.sound = v end,
		nil, nil, { "trinkets" })
	p:Toggle("Bandeau si j'ai oublié flacon ou nourriture", function() return d.consum.selfAlert end, function(v) d.consum.selfAlert = v end,
		nil, nil, { "lead", "conso", "Outils de chef" })
end, { icon = I .. "Ability_Warrior_BattleShout", keys = "son alerte bandeau silence aggro tank danger degats",
	active = function() return not db().alerts.quiet end })

-- Ouverture -------------------------------------------------------------------------------
function O:Open(tab)
	if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then InterfaceOptionsFrame:Hide() end
	UI:Open(tab)
end

function O:OnLogin()
	-- Entrée dans Échap > Interface > AddOns qui ouvre la fenêtre moderne
	local p = CreateFrame("Frame", nil, UIParent)
	p.name = "VuhPlus"
	local t = VP.Theme:Text(p, 16, nil, nil, nil, true)
	t:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -16)
	t:SetText("VuhPlus " .. VP.version)
	local b = UI:Button(p, "Ouvrir la configuration", 220, function() O:Open() end, true)
	b:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -48)
	InterfaceOptions_AddCategory(p)
end
