-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Noyau : configuration, profils, événements, file hors-combat, commandes
VuhPlus = {}
local VP = VuhPlus
VP.version = "5.9.0"

BINDING_HEADER_VUHPLUS = "VuhPlus"
_G["BINDING_NAME_CLICK VuhPlusTrinketButton:LeftButton"] = "Utiliser les bijoux"
_G["BINDING_NAME_CLICK VuhPlusSmartBuff:LeftButton"] = "Buff intelligent (premier buff manquant)"

-- Réglages d'affichage (copiés dans les profils)
VP.defaults = {
	locked = false,
	hideEmpty = false,       -- cacher les fenêtres d'information vides (liste de dispel vide, état du raid en solo) ;
	                         -- le verrouillage ne fait que bloquer les positions
	pos = { point = "CENTER", relPoint = "CENTER", x = -350, y = 50 },
	scale = 1,
	width = 80,
	hpHeight = 32,           -- hauteur de la barre de vie
	manaHeight = 4,          -- hauteur de la barre de mana
	xGap = 2, yGap = 2,      -- écart entre les barres (horizontal / vertical)
	padX = 5, padY = 5,      -- marge intérieure du panneau
	perColumn = 5,           -- joueurs par colonne (tri par classe / nom, familiers)
	groupTitles = true,      -- titres « Groupe 1 »
	groupOrient = "H",       -- H : groupes côte à côte, V : groupes empilés
	groupCompact = true,     -- masquer les groupes vides et resserrer
	panelBg = true, panelBgAlpha = 0.55,
	sortMode = "GROUP",      -- GROUP / CLASS / NAME / ROLE (blocs par rôle) / ROLEGRID (grille remplie par rôle)
	roleOrder = { "TANK", "HEALER", "DAMAGER" },  -- tri par rôle : ordre des blocs
	accent = "vert",         -- couleur d'accent du thème
	barStyle = "FLAT",       -- FLAT / DARK / CLASSIC
	gloss = true,            -- reflet sur les barres
	healthText = "DEFICIT",  -- DEFICIT / PERCENT / CURRENT / NONE
	fontSize = 11,
	nameLength = 0,          -- 0 = auto
	classNames = false,      -- nom en couleur de classe
	lowMana = true, lowManaPct = 20,
	showSolo = true,
	showFrames = true,       -- cadres de soin (raid, tanks, cible, familiers) ; false : seules les fenêtres d'information restent
	showMana = true,
	showDeficit = true,
	healthColor = "CLASS",   -- CLASS / GRADIENT / GREEN
	rangeFade = true, rangeAlpha = 0.35,
	hoverHighlight = true,   -- surbrillance du cadre survolé (comme Cell, Danders Frames, VuhDo)
	showDrinking = true,     -- « Boit 45% » : joueur en train de boire, avec sa mana (comme Cell, Grid2)
	smoothBars = false,      -- barres de vie animées (comme VuhDo 3.202, Danders Frames) : un peu plus de processeur
	showHots = true, showStacks = true,
	hotTimer = true,         -- temps restant écrit sur les icônes
	hotWarnSecs = 3,         -- alerte d'expiration (secondes)
	hotWarnFlash = true,     -- l'icône clignote quand elle expire
	hotTextOutline = true,   -- contour du texte des icônes (sinon ombre)
	hotSpiral = true,        -- spirale de durée sur les icônes
	hotSize = 14,
	chargeOnly = true,       -- Bouclier de terre / Prière de guérison : charges au lieu du temps
	remindSize = 18,
	hotGap = 1,              -- espace entre les icônes de HoTs
	hotMode = "ICON",        -- ICON : icônes du sort ; SQUARE : carrés de couleur
	hotFixed = false,        -- emplacements à position fixe (sinon resserrés)
	font = "ARIALN",
	iconPos = {
		hots = "R", hotGrow = "AUTO",
		boss = "C", dispel = "L", role = "TL", raid = "TE", missing = "B", remind = "T", overheal = "L",
		defensive = "LE", healred = "RE", soul = "BL", arrow = "C", guide = "C",
		leader = "TL",       -- couronne chef / assistant (à côté du rôle)
		others = "BL", othersGrow = "RIGHT",
	},
	bossSize = 18,
	dispelSize = 14,
	roleInspect = true,      -- rôle des autres via inspection des talents
	roleShare = true,        -- partager sa spé avec les autres joueurs VuhPlus (et lire la leur)
	roleShowDps = true,      -- afficher aussi l'icône DPS
	showAggro = true,
	showRaidIcon = true,
	raidIconSize = 16,
	raidIconAlpha = 1,
	raidIconShow = { true, true, true, true, true, true, true, true }, -- étoile ... crâne
	raidIconColor = "NONE",
	overhealText = true, overhealSize = 11,   -- texte de surplus de soin
	indicators = true,       -- indicateurs de soigneur ci-dessous
	indDefensive = true,     -- gros défensif actif (Mur protecteur, Écorce, Suppression de la douleur...)
	indHealRed = true,       -- soins réduits (Frappe mortelle, Aura nécrotique...)
	indSoul = true,          -- pierre d'âme
	indBossTarget = true,    -- ciblé par le boss
	indSize = 16,
	arrows = true,           -- petite flèche sur les cadres hors de portée de soin
	arrowSize = 16,
	guideArrow = true,       -- grande flèche par-dessus le cadre survolé hors de portée (comme VuhDo)
	guideScale = 100,        -- taille de la grande flèche, en % de la hauteur de la barre de vie
	guideTarget = true,      -- ... ou quand votre cible amie est hors de portée
	guidePos = { point = "CENTER", relPoint = "CENTER", x = 0, y = 120 },
	autoScale = false, scale25 = 1, scale40 = 0.85,  -- échelle automatique selon la taille du raid
	avoidOverlap = true,     -- placement individuel : décale une icône si sa place est déjà prise
	iconLayout = "FREE",     -- FREE : chaque icône à sa place (individuel) ; AUTO : alignement automatique
	-- décalage X / Y (en % de la taille du cadre) et taille (0 = taille par défaut) de chaque icône
	iconOff = {
		raid = { x = 0, y = 0, size = 0 }, overheal = { x = 0, y = 0, size = 0 },
		role = { x = 0, y = 0, size = 0 }, dispel = { x = 0, y = 0, size = 0 }, boss = { x = 0, y = 0, size = 0 },
		remind = { x = 0, y = 0, size = 0 }, defensive = { x = 0, y = 0, size = 0 }, healred = { x = 0, y = 0, size = 0 },
		soul = { x = 0, y = 0, size = 0 }, missing = { x = 0, y = 0, size = 0 }, arrow = { x = 0, y = 0, size = 0 },
		guide = { x = 0, y = 0, size = 0 },
		others = { x = 0, y = 0, size = 0 },
		leader = { x = 0, y = 0, size = 0 },
	},  -- NONE / BORDER (bordure de la couleur du symbole) / NAME (nom coloré)
	showRole = true,
	showLeader = true,       -- couronne du chef / de l'assistant (comme Cell, Danders Frames)
	showAssist = true,       -- ... et icône des assistants du raid
	showStatus = true,       -- AFK, contrôlé, feinte de mort
	showReadyCheck = true,
	readyHold = 5,           -- secondes d'affichage des réponses une fois que tout le monde a répondu
	showIncoming = true,     -- soins entrants (LibHealComm-4.0)
	incomingWindow = 4,      -- ne compter que les soins qui arrivent dans les N secondes (0 = tous, HoTs entiers compris)
	incomingMine = true,     -- compter aussi VOS soins (sinon seulement ceux des autres soigneurs)
	showAbsorb = true,       -- barre des boucliers (Mot de pouvoir : Bouclier, Égide divine, Bouclier sacré...)
	absorbHeight = 3,        -- hauteur de cette barre (px)
	hotBars = "TANKS",       -- barres de durée des HoTs en haut du cadre : OFF / TANKS (tanks seulement) / ALL
	hotBarHeight = 2,        -- hauteur de chaque barre (px)
	barTexture = "",         -- texture SharedMedia des barres ("" = selon le style)
	spike = {                -- alerte de dégâts brutaux (bordure rouge qui s'éteint)
		enabled = true,
		pct = 30,            -- % de la vie max perdus...
		window = 1.5,        -- ... en moins de N secondes
		skipTanks = false,   -- ignorer les tanks (ils prennent de gros coups en permanence)
		sound = false,
	},
	cooldowns = {            -- recharges du raid + résurrections en combat
		enabled = true,
		groupOnly = true,    -- seulement en groupe / raid
		br = true,           -- ligne « Rez combat / pierres d'âme »
		spells = {},         -- [id] = false : sort masqué
		scale = 1,
		sync = true,         -- partager ses vraies recharges avec les autres joueurs VuhPlus du groupe
		pos = { point = "CENTER", relPoint = "CENTER", x = 420, y = -40 },
	},
	spotAssign = true,       -- panneau « Projecteur » : inclure mes cibles assignées
	deadTimer = true,        -- « Mort 1:23 » : temps depuis la mort (aide à choisir la rez combat)
	rezStatus = true,        -- « Rez... » / « Rez en attente » sur les morts déjà en cours de résurrection
	castHighlight = true,    -- bordure sur le joueur que je suis en train de soigner
	emergency = true, emergencyPct = 50, emergencyCount = 3,
	tooltip = true, tooltipInCombat = false, tooltipBinds = true,
	castOnDown = false,
	hideBlizzParty = false,
	gcdBar = true,
	minimap = true, minimapAngle = 210,
	panels = {
		tanks = { enabled = true,  pos = { point = "CENTER", relPoint = "CENTER", x = -550, y = 50 } },
		mytanks = { enabled = true, pos = { point = "CENTER", relPoint = "CENTER", x = -550, y = -100 } },
		pets = { enabled = false, pos = { point = "CENTER", relPoint = "CENTER", x = -350, y = -200 } },
		target = { enabled = true, pos = { point = "CENTER", relPoint = "CENTER", x = -150, y = 150 },
			boss = true,          -- cadre « Cible du boss » (boss1target) : le joueur que le boss frappe
			focusTarget = false,  -- cadre « Cible de la focalisation » (focustarget) : boss mis en focalisation
		},
		spotlight = { enabled = false, pos = { point = "CENTER", relPoint = "CENTER", x = -550, y = -250 } },
	},
	alerts = {
		aggro = true,            -- alerte quand VOUS prenez l'aggro
		tankLow = true, tankPct = 30, -- alerte quand un tank passe sous ce seuil
		sound = true,
		quiet = false,           -- mode silencieux : plus aucune alerte sonore ni bandeau (aggro, tank, débuffs, dispel, bijoux)
		status = true,           -- barre « état du raid »
		statusPos = { point = "CENTER", relPoint = "CENTER", x = -350, y = 120 },
		deathReport = "SELF",    -- OFF / SELF (chat perso) / GROUP (groupe ou raid)
		tools = false,           -- barre d'outils de raid (toujours affichée)
		toolsAsk = "ASK",        -- chef / assistant du raid : ASK proposer, AUTO afficher, NEVER rien
		toolsPos = { point = "TOP", relPoint = "TOP", x = 0, y = -60 },
	},
	pets = {                     -- familiers (chasseur, démoniste, chevalier de la mort, élémentaire d'eau...)
		enabled = true,          -- soigner les familiers (tout couper si non)
		mode = "ATTACH",         -- ATTACH : sous le groupe / bloc de leur maître ; SIDE : à côté des joueurs ; PANEL : panneau séparé déplaçable
		combatOnly = false,      -- seulement en combat
		dimFull = false,         -- familier en pleine vie : discret (transparent) ; se confond avec « hors de portée »
		dimAlpha = 0.45,
		height = 60,             -- hauteur en % d'un cadre de joueur
		width = 100,             -- largeur en %
		ownerName = true,        -- « Félin (Bob) »
		ownerColor = true,       -- barre de la couleur de classe du maître
		dispel = true,           -- alertes de dispel aussi sur les familiers
		overheal = false,        -- texte de surplus de soin « +3.2k » sur les familiers
		-- classes dont on CACHE les familiers : ils n'ont que des invocations de quelques secondes
		-- (tréants du druide, loups esprits du chaman, ombrefiel du prêtre) qui bousculeraient les cadres
		hideClasses = { DRUID = true, SHAMAN = true, PRIEST = true },
	},
	announce = {                 -- annonces de vos gros sorts (Héroïsme, Totem de vague de mana...)
		enabled = true,
		channel = "AUTO",        -- AUTO (raid / groupe / champ de bataille), SAY, YELL, SELF (mon chat seulement)
		warning = false,         -- alerte de raid pour les gros sorts si je suis chef / assistant
		soloSelf = true,         -- seul : l'afficher dans mon chat
		spells = {},             -- [clé] = false pour ne pas annoncer un sort
		countdown = "NONE",      -- décompte dans le chat : FULL (30/20/10/5/3/2/1 s + fin), LIGHT (10/5 s + fin), END (fin seulement), NONE
		-- mode discret (5.8.5) : les joueurs trouvaient les annonces envahissantes
		scope = "BIG",           -- sorts annoncés au groupe : BIG (sorts de raid seulement), ALL (tous), NONE (aucun)
		cdReadySelf = true,      -- « de nouveau disponible » : dans mon chat seulement
		instanceOnly = true,     -- rien au groupe hors donjon / raid / champ de bataille
		othersBigOnly = true,    -- barres des autres soigneurs : seulement leurs sorts de raid
		bars = true,             -- barres de temps à l'écran
		cdAnnounce = true,       -- annoncer le temps avant de pouvoir relancer (ex. Renaissance) puis « de nouveau disponible »
		cdBars = true,           -- barres de recharge de vos gros sorts
		othersBars = true,       -- barres aussi pour les gros sorts des autres joueurs du groupe
		barsPos = { point = "CENTER", relPoint = "CENTER", x = 250, y = 120 },
	},
	consum = {                   -- vérification des consommables
		enabled = true,
		flask = true,            -- flacon ou 2 élixirs
		food = true,             -- buff « Bien nourri »
		onReady = true,          -- vérifier automatiquement à chaque appel
		announce = "SELF",       -- SELF : dans mon chat ; GROUP : annoncé au raid (si c'est moi qui lance l'appel)
		selfAlert = true,        -- bandeau si c'est MOI qui n'ai pas mon flacon / ma nourriture
	},
	clicks = {
		smartRes = true,
		autoTrinket = false,
		blizz = false,           -- clic-soin aussi sur les cadres Blizzard
	},
	dispel = {
		classes = { PALADIN = true, PRIEST = true, DRUID = true, SHAMAN = true, MAGE = true },
		highlight = true, sound = true, showHint = true, warnDanger = true, ignoreList = true,
		style = "BAR",           -- BAR : barre de vie de la couleur du débuff ; TINT : teinte légère
		pulse = true,            -- bordure qui clignote
		soundName = "TellMessage",
		types = {},              -- types désactivés : [type] = false
		order = { "Magic", "Curse", "Disease", "Poison" },
		classFilter = true,      -- ignorer les affaiblissements sans effet sur la classe
		checkAbolish = true,     -- ne pas dissiper si votre Abolir est déjà dessus
		rangeCheck = true,       -- portée de VOTRE sort de dispel
		alertOutOfRange = false, -- son même si le joueur est hors de portée
		blacklistTime = 5,       -- secondes d'oubli après « hors de vue »
		failAlert = true,        -- message si dispel résisté / impossible
		liveList = true,         -- liste en direct des joueurs à dissiper
		liveListRows = 5,
		liveListPos = { point = "CENTER", relPoint = "CENTER", x = 250, y = -40 },
		mini = "AUTO",           -- petits cadres cliquables (comme Decursive) : AUTO = quand les cadres de soin sont cachés, ON, OFF
		miniSize = 18,
		miniPos = { point = "CENTER", relPoint = "CENTER", x = 250, y = -200 },
		userIgnore = {}, userIgnoreCombat = {}, skipNames = {}, priorityNames = {},
	},
	debuffs = {
		boss = true,           -- liste intégrée Naxx / Ulduar / ToC / ICC / RS
		custom = true,         -- votre liste personnelle
		sound = "CRIT",        -- son : OFF jamais / CRIT seulement les débuffs critiques / ALL tous
		highlight = false,     -- colorer le cadre et le nom (ressemble à une alerte de dispel : désactivé par défaut)
		minPrio = 1,           -- n'afficher que les débuffs de cette priorité ou plus (8 = critiques seulement)
		showOthers = false,    -- afficher aussi les autres affaiblissements
		critGlow = true,       -- bordure clignotante pour les débuffs critiques (priorité 8 et plus)
		customPrio = 7,        -- priorité donnée aux sorts ajoutés à « ma liste »
	},
	buffs = {
		track = {},            -- buffs suivis (rempli selon la classe)
		charges = {},          -- seuil « griser à N charges »
		enabled = true,
		showPanel = true,
		scale = 1,
		showMissing = true,    -- point jaune sur les cadres
		grayFrames = true,     -- cadre gris quand un buff de soigneur manque (vous / vos tanks)
		selfCharges = true,    -- nombre de charges du Bouclier d'eau sur votre cadre
		rebuffMinutes = 3,
		pos = { point = "CENTER", relPoint = "CENTER", x = 250, y = 150 },
	},
	aoe = {
		enabled = true,
		pct = 80,
		count = 3,
	},
	trinket = {
		enabled = true,
		slot13 = true, slot14 = true,
		mode = "BOTH",
		playerPct = 35,
		raidPct = 50, raidCount = 3,
		onlyInCombat = true,
		sound = true,
		showButton = true,
		scale = 1,
		alertText = true,
		pos = { point = "CENTER", relPoint = "CENTER", x = 0, y = -180 },
	},
}

-- Données hors profil
local PERSIST = { binds = true, keys = true, hostile = true, myTanks = true, customDebuffs = true, profiles = true,
	roleOverride = true, macros = true,
	uiShowAll = true, uiScale = true,   -- préférences de la fenêtre de configuration (pas des réglages de profil)
	autoProfile = true,   -- changement automatique de profil (spé / taille du groupe)
	assign = true,        -- assignations de soin
	diag = true,          -- diagnostic (/vp diag) : activé sur un personnage, il doit suivre sur les autres
	chars = true,         -- réglages de chaque personnage (voir « Réglages par personnage »)
	spotlight = true }    -- noms du panneau « Projecteur »   -- macros : bibliothèque commune à tous les profils
-- clés communes qui ne sont PAS des tables (toutes les autres en sont)
local PERSIST_TYPE = { uiShowAll = "boolean", uiScale = "number" }

local function copyDefaults(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			copyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local r = {}
	for k, v in pairs(t) do r[k] = deepCopy(v) end
	return r
end
VP.deepCopy = deepCopy

function VP:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99VuhPlus|r : " .. tostring(msg))
end

-- Infobulle cachée UNIQUE (montant des boucliers, enchantement d'arme) : deux infobulles du même nom
-- se volaient les lignes « VuhPlusScanTipTextLeftN » et chacune lisait le texte de l'autre
function VP:ScanTip()
	local t = self.scanTip
	if not t then
		t = CreateFrame("GameTooltip", "VuhPlusScanTip", nil, "GameTooltipTemplate")
		self.scanTip = t
	end
	t:SetOwner(WorldFrame, "ANCHOR_NONE")
	t:ClearLines()
	return t
end

-- Modules ------------------------------------------------------------------
local order = {}
function VP:NewModule(name)
	local m = {}
	self[name] = m
	table.insert(order, m)
	return m
end

-- Événements ---------------------------------------------------------------
local ef = CreateFrame("Frame")
local handlers = {}
function VP:On(event, func)
	if not handlers[event] then
		handlers[event] = {}
		ef:RegisterEvent(event)
	end
	table.insert(handlers[event], func)
end
-- chaque module est isolé : une erreur dans l'un (signalée normalement) n'empêche pas les autres
-- modules de recevoir le même événement (ex. journal de combat : dispel, recharges, annonces...)
ef:SetScript("OnEvent", function(self, event, ...)
	local list = handlers[event]
	if list then
		for i = 1, #list do
			local ok, err = pcall(list[i], event, ...)
			if not ok then geterrorhandler()(err) end   -- relu à chaque fois (BugSack peut le remplacer)
		end
	end
end)

-- File d'attente hors combat
local queue = {}
function VP:RunOOC(key, func)
	if InCombatLockdown() then
		queue[key] = func
		return false
	end
	func()
	return true
end
VP:On("PLAYER_REGEN_ENABLED", function()
	-- une erreur dans une tâche ne doit pas bloquer les suivantes
	for k, f in pairs(queue) do
		queue[k] = nil
		local ok, err = pcall(f)
		if not ok then geterrorhandler()(err) end
	end
end)

-- Les positions sont enregistrées par l'addon (VuhPlusDB, commun au compte). Sans ceci, le client
-- les mémorise AUSSI dans layout-local.txt (par personnage) dès qu'un cadre nommé est déplacé à la
-- souris, puis replace le cadre à cette ancienne position à la connexion.
function VP:Unplace(f)
	if not f or not f.SetUserPlaced or not f:IsMovable() then return end
	if InCombatLockdown() and f:IsProtected() then return end
	f:SetUserPlaced(false)
end

-- Canal de discussion du groupe : BATTLEGROUND en champ de bataille (RAID y donne une erreur)
function VP:GroupChannel()
	local _, itype = IsInInstance()
	if itype == "pvp" and (GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0) then return "BATTLEGROUND" end
	if GetNumRaidMembers() > 0 then return "RAID" end
	if GetNumPartyMembers() > 0 then return "PARTY" end
	return nil
end

-- Spécialisation active (double spé)
function VP:Spec()
	return (GetActiveTalentGroup and GetActiveTalentGroup()) or 1
end

-- Profils ------------------------------------------------------------------
function VP:SaveProfile(name)
	if not name or name == "" then return end
	local p = {}
	for k, v in pairs(self.db) do
		if not PERSIST[k] then p[k] = deepCopy(v) end
	end
	self.db.profiles[name] = p
	self:Print("Profil « " .. name .. " » enregistré.")
end

local migrate   -- défini plus bas (conversion des anciens réglages)

-- Listes à garder cohérentes après fusion avec les valeurs par défaut :
-- l'ordre de dispel doit contenir chaque type une seule fois
local function fixLists(db)
	local d = db.dispel
	if d and d.order then
		local seen, out = {}, {}
		for _, t in ipairs(d.order) do
			if not seen[t] and (t == "Magic" or t == "Curse" or t == "Disease" or t == "Poison") then
				seen[t] = true; out[#out + 1] = t
			end
		end
		for _, t in ipairs({ "Magic", "Curse", "Disease", "Poison" }) do
			if not seen[t] then out[#out + 1] = t end
		end
		d.order = out
	end
end
VP.fixLists = fixLists
function VP:LoadProfile(name)
	local p = self.db.profiles[name]
	if not p then self:Print("Profil introuvable : " .. tostring(name)) return end
	if InCombatLockdown() then self:Print("Impossible en combat.") return end
	for k in pairs(self.defaults) do self.db[k] = nil end
	self.db.posV2 = nil   -- un vieux profil sans ce repère doit être converti
	for k, v in pairs(p) do self.db[k] = deepCopy(v) end
	migrate(self.db)
	copyDefaults(self.defaults, self.db)
	fixLists(self.db)
	self:RefreshAll()
	if self.UI and self.UI.InvalidatePages then self.UI:InvalidatePages() end
	self:Print("Profil « " .. name .. " » chargé.")
end

-- Réglages par personnage --------------------------------------------------------
-- Le fichier de sauvegarde est commun au compte. Les réglages « vivants » restent à la racine
-- (rien ne change pour le reste du code) ; chaque personnage en garde sa propre copie dans
-- « chars », rangée à la déconnexion et remise en place à la connexion. Un personnage encore
-- inconnu démarre avec les réglages du dernier personnage joué. Les clics, touches, macros et
-- profils (PERSIST) restent communs : ils sont déjà rangés par classe et par spé.
local function charKey()
	return (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
end

local function storeChar()
	local db = VP.db
	if not db or not VP.charKey then return end
	local s = {}
	for k, v in pairs(db) do
		if not PERSIST[k] then s[k] = deepCopy(v) end
	end
	db.chars[VP.charKey] = { settings = s, class = VP.class, autoLast = db.autoProfile and db.autoProfile.last }
end

local function restoreChar()
	local db = VP.db
	VP.charKey = charKey()
	local saved = db.chars[VP.charKey]
	if type(saved) ~= "table" or type(saved.settings) ~= "table" then
		VP.charNew = true
		return
	end
	local old = {}
	for k in pairs(db) do
		if not PERSIST[k] then old[#old + 1] = k end
	end
	for _, k in ipairs(old) do db[k] = nil end
	for k, v in pairs(saved.settings) do
		if not PERSIST[k] then db[k] = deepCopy(v) end
	end
	migrate(db)
	copyDefaults(VP.defaults, db)
	fixLists(db)
	if type(db.autoProfile) == "table" then db.autoProfile.last = saved.autoLast end
end

-- Autres personnages connus : { clé, ... } triées
function VP:CharList()
	local t = {}
	for k, v in pairs(self.db.chars) do
		if k ~= self.charKey and type(v) == "table" and type(v.settings) == "table" then t[#t + 1] = k end
	end
	table.sort(t)
	return t
end

-- Copie ici les réglages d'un autre personnage
function VP:CopyFromChar(key)
	local c = key and self.db.chars[key]
	if type(c) ~= "table" or type(c.settings) ~= "table" then self:Print("Personnage introuvable : " .. tostring(key)) return end
	if InCombatLockdown() then self:Print("Impossible en combat.") return end
	local old = {}
	for k in pairs(self.db) do
		if not PERSIST[k] then old[#old + 1] = k end
	end
	for _, k in ipairs(old) do self.db[k] = nil end
	for k, v in pairs(c.settings) do
		if not PERSIST[k] then self.db[k] = deepCopy(v) end
	end
	migrate(self.db)
	copyDefaults(self.defaults, self.db)
	fixLists(self.db)
	self:RefreshAll()
	if self.UI and self.UI.InvalidatePages then self.UI:InvalidatePages() end
	self:Print("Réglages de « " .. key .. " » copiés sur ce personnage.")
end

function VP:DeleteProfile(name)
	if self.db.profiles[name] then
		self.db.profiles[name] = nil
		self:Print("Profil « " .. name .. " » supprimé.")
	end
end

function VP:ProfileList()
	local t = {}
	for k in pairs(self.db.profiles) do table.insert(t, k) end
	table.sort(t)
	return t
end

function VP:RefreshAll()
	for _, m in ipairs(order) do
		if m.Refresh then
			local ok, err = pcall(m.Refresh, m)
			if not ok then geterrorhandler()(err) end
		end
	end
end

-- conversion des anciens réglages (v1 à v3.3) ; sert aussi pour les vieux profils
function migrate(old)
	if old.height and not old.hpHeight then
		old.hpHeight = math.max(14, old.height - 7)
		old.manaHeight = 4
		old.height = nil
	end
	if old.spacing and not old.xGap then
		old.xGap, old.yGap = old.spacing, old.spacing
		old.spacing = nil
	end
	-- positions v3.2 -> v3.3 : libérer les coins pour les emplacements de HoTs
	if old.iconPos and not old.posV2 then
		local ip = old.iconPos
		if ip.dispel == "BR" then ip.dispel = "L" end
		if ip.missing == "TR" then ip.missing = "B" end
		if ip.raid == "T" or ip.raid == "OT" then ip.raid = "TE" end
		if ip.others == "L" then ip.others = "BL" end
		if ip.hotGrow == "LEFT" then ip.hotGrow = "AUTO" end
	end
	old.posV2 = true
	-- 5.1 : l'ancien interrupteur « panneau Familiers » devient le mode « panneau séparé »
	if old.panels and old.panels.pets and old.panels.pets.enabled and not old.petsV1 then
		old.pets = old.pets or {}
		old.pets.mode = "PANEL"
	end
	old.petsV1 = true
	-- 5.5 : le son des débuffs de boss n'est plus « oui / non » : par défaut, seulement les critiques
	-- (un son à chaque débuff, même non dissipable, perturbait les soigneurs qui découvrent l'addon)
	if old.debuffs and type(old.debuffs.sound) == "boolean" then
		old.debuffs.sound = old.debuffs.sound and "CRIT" or "OFF"
	end
	-- 5.2 : « discret en pleine vie » se confondait avec « hors de portée » : désactivé une fois
	if old.pets and not old.petsV2 then old.pets.dimFull = false end
	old.petsV2 = true
	-- 5.8 : « 4 charges et + » était gris clair (un Bouclier de terre neuf semblait éteint) : vert comme à 3 charges.
	-- Seulement si la couleur est restée celle d'origine (une couleur choisie par le joueur est gardée).
	local ch = type(old.colors) == "table" and type(old.colors.charge) == "table" and old.colors.charge[4]
	if type(ch) == "table" and ch[1] == 0.75 and ch[2] == 0.75 and ch[3] == 0.8 then
		ch[1], ch[2], ch[3] = 0.3, 1, 0.4
	end
end

VP:On("ADDON_LOADED", function(_, name)
	if name ~= "VuhPlus" then return end
	VuhPlusDB = VuhPlusDB or {}
	migrate(VuhPlusDB)
	copyDefaults(VP.defaults, VuhPlusDB)
	fixLists(VuhPlusDB)
	for k in pairs(PERSIST) do
		local want = PERSIST_TYPE[k] or "table"
		if type(VuhPlusDB[k]) ~= want then
			-- préférences simples (nombre, oui / non) : valeur abîmée effacée, la valeur par défaut s'applique
			-- (avant 5.8.1 elles étaient changées en table : SetScale({}) plantait à l'ouverture de /vp)
			VuhPlusDB[k] = (want == "table") and {} or nil
		end
	end
	VP.db = VuhPlusDB
end)

VP:On("PLAYER_LOGIN", function()
	local _, class = UnitClass("player")
	VP.class = class
	VP.loadTime = GetTime()
	-- réglages de CE personnage, avant le démarrage des modules
	local okc, errc = pcall(restoreChar)
	if not okc then geterrorhandler()(errc) end
	-- un module en erreur au démarrage ne doit pas empêcher les suivants de démarrer
	for _, m in ipairs(order) do
		if m.OnLogin then
			local ok, err = pcall(m.OnLogin, m)
			if not ok then geterrorhandler()(err) end
		end
	end
	VP:Print("v" .. VP.version .. " chargé. Tapez |cffffff00/vp|r pour les options, |cffffff00/vp help|r pour l'aide.")
	if VP.charNew then
		VP:Print("Nouveau personnage : il démarre avec vos réglages actuels, puis garde les siens (/vp > Profils).")
	end
end)

VP:On("PLAYER_LOGOUT", storeChar)

-- Commandes ----------------------------------------------------------------
SLASH_VUHPLUS1 = "/vp"
SLASH_VUHPLUS2 = "/vuhplus"
SlashCmdList["VUHPLUS"] = function(msg)
	msg = msg or ""
	local cmd, rest = string.match(msg, "^(%S*)%s*(.-)$")
	cmd = string.lower(cmd or "")
	if cmd == "lock" then
		VP.db.locked = true; VP:RefreshAll(); VP:Print("Cadres verrouillés.")
	elseif cmd == "unlock" then
		VP.db.locked = false; VP:RefreshAll(); VP:Print("Cadres déverrouillés : glissez les barres vertes pour déplacer.")
	elseif cmd == "test" then
		VP.Trinkets:TestAlert()
	elseif cmd == "preview" or cmd == "apercu" or cmd == "aperçu" then
		VP.Preview:Toggle()
	elseif cmd == "reset" then
		if InCombatLockdown() then VP:Print("Impossible en combat.") return end
		VP.db.pos = deepCopy(VP.defaults.pos)
		VP.db.trinket.pos = deepCopy(VP.defaults.trinket.pos)
		VP.db.buffs.pos = deepCopy(VP.defaults.buffs.pos)
		for k, v in pairs(VP.defaults.panels) do VP.db.panels[k].pos = deepCopy(v.pos) end
		VP.db.alerts.statusPos = deepCopy(VP.defaults.alerts.statusPos)
		VP.db.alerts.toolsPos = deepCopy(VP.defaults.alerts.toolsPos)
		VP.db.dispel.liveListPos = deepCopy(VP.defaults.dispel.liveListPos)
		VP.db.dispel.miniPos = deepCopy(VP.defaults.dispel.miniPos)
		VP.db.announce.barsPos = deepCopy(VP.defaults.announce.barsPos)
		VP.db.cooldowns.pos = deepCopy(VP.defaults.cooldowns.pos)
		VP:RefreshAll()
		VP:Print("Positions réinitialisées.")
	elseif cmd == "role" or cmd == "rôle" then
		local name, r = string.match(rest or "", "^(%S*)%s*(%S*)$")
		-- « /vp role heal » sur la cible : le premier mot est alors le rôle
		if name and (r == nil or r == "") and ({ heal = 1, soin = 1, healer = 1, tank = 1, dps = 1, auto = 1 })[string.lower(name)] then
			name, r = nil, name
		end
		VP.Roles:SetOverride(name, r)
	elseif cmd == "conso" then
		VP.Consumables:Report(string.lower(rest or "") == "raid")
	elseif (cmd == "outils" or cmd == "tools" or cmd == "barre") and string.lower(rest or "") == "test" then
		VP.Raid:TestTools()
	elseif cmd == "outils" or cmd == "tools" or cmd == "barre" then
		-- barre d'outils de raid : appel, pull, symboles
		local shown = VP.db.alerts.tools or (VP.Raid and VP.Raid.toolsTemp)
		VP.db.alerts.tools = not shown
		if VP.Raid then VP.Raid.toolsTemp = false end
		if VP.Raid and VP.Raid.ApplyTools then VP.Raid:ApplyTools() end
		VP:Print(VP.db.alerts.tools and "Barre d'outils de raid affichée (/vp unlock pour la déplacer)." or "Barre d'outils de raid cachée.")
	elseif cmd == "tank" then
		VP.Panels:ToggleMyTank(rest ~= "" and rest or nil)
	elseif cmd == "spot" or cmd == "projecteur" then
		VP.Panels:ToggleSpotlight(rest ~= "" and rest or nil)
	elseif cmd == "dispel" then
		-- ce que CE personnage peut dissiper (d'après les sorts de son grimoire, donc sa classe et sa spé)
		local D = VP.Dispel
		D:Refresh()
		local t = D:TypesText()
		if t then
			VP:Print("Alertes de dispel pour : |cffffffff" .. t .. "|r")
			for i, sl in ipairs(D.slots) do VP:Print("  Dispel " .. i .. " = |cffffffff" .. sl.name .. "|r") end
		else
			VP:Print("Aucune alerte de dispel : ce personnage ne connaît aucun sort pour dissiper un allié "
				.. "(ou sa classe / tous ses types sont désactivés : /vp > Dispel).")
		end
	elseif cmd == "perf" then
		-- mémoire (toujours) et processeur (si le profilage est activé : /console scriptProfile 1 puis /reload)
		UpdateAddOnMemoryUsage()
		VP:Print(string.format("Mémoire : %.0f Ko", GetAddOnMemoryUsage("VuhPlus")))
		if GetCVar("scriptProfile") == "1" then
			UpdateAddOnCPUUsage()
			local ms = GetAddOnCPUUsage("VuhPlus")
			VP:Print(string.format("Processeur : %.0f ms depuis le chargement (%.2f ms par seconde de jeu)", ms, ms / math.max(1, GetTime() - (VP.loadTime or 0))))
		else
			VP:Print("Processeur : tapez /console scriptProfile 1 puis /reload pour le mesurer (à désactiver ensuite : ça ralentit le jeu).")
		end
	elseif cmd == "silence" or cmd == "alertes" or cmd == "quiet" then
		-- mode silencieux : un DPS garde les fenêtres d'information sans les alertes pensées pour un soigneur
		VP.db.alerts.quiet = not VP.db.alerts.quiet
		if VP.UI and VP.UI.InvalidatePages then VP.UI:InvalidatePages() end
		VP:Print(VP.db.alerts.quiet and "Mode silencieux : plus aucune alerte sonore ni bandeau." or "Alertes réactivées.")
	elseif cmd == "diag" then
		VP.Diag:Toggle()
	elseif cmd == "cadres" or cmd == "frames" then
		-- cadres de soin : un DPS peut les couper et garder les fenêtres d'information
		VP.db.showFrames = VP.db.showFrames == false
		VP:RefreshAll()
		if VP.UI and VP.UI.InvalidatePages then VP.UI:InvalidatePages() end
		VP:Print((VP.db.showFrames and "Cadres de soin affichés." or "Cadres de soin cachés : les fenêtres d'information restent.")
			.. (InCombatLockdown() and " (appliqué à la fin du combat)" or ""))
	elseif cmd == "cd" or cmd == "recharges" then
		VP.db.cooldowns.enabled = not VP.db.cooldowns.enabled
		VP.Cooldowns:Refresh()
		VP:Print(VP.db.cooldowns.enabled and "Recharges du raid affichées." or "Recharges du raid cachées.")
	elseif cmd == "profil" or cmd == "profile" then
		local sub, name = string.match(rest, "^(%S*)%s*(.-)$")
		sub = string.lower(sub or "")
		if sub == "save" or sub == "sauver" then VP:SaveProfile(name)
		elseif sub == "load" or sub == "charger" then VP:LoadProfile(name)
		elseif sub == "delete" or sub == "suppr" then VP:DeleteProfile(name)
		else VP:Print("Profils : " .. (table.concat(VP:ProfileList(), ", ") ~= "" and table.concat(VP:ProfileList(), ", ") or "aucun")) end
	elseif cmd == "help" or cmd == "aide" then
		VP:Print("/vp : options")
		VP:Print("/vp lock | unlock : verrouiller / déplacer les cadres")
		VP:Print("/vp reset : positions par défaut")
		VP:Print("/vp outils : afficher / cacher la barre d'outils de raid (appel, pull, symboles)")
		VP:Print("/vp outils test : tester la barre d'outils 60 s (rien n'est envoyé au groupe)")
		VP:Print("/vp role [nom] heal|tank|dps|auto : forcer le rôle d'un joueur (ou de votre cible)")
		VP:Print("/vp conso : vérifier flacons et nourriture (/vp conso raid : l'annoncer au raid)")
		VP:Print("/vp tank [nom] : ajoute/retire votre cible (ou le nom) de « Mes tanks »")
		VP:Print("/vp spot [nom] : ajoute/retire votre cible (ou le nom) du panneau « Projecteur »")
		VP:Print("/vp cadres : afficher / cacher les cadres de soin (les fenêtres d'information restent)")
		VP:Print("/vp silence : couper / remettre toutes les alertes sonores et les bandeaux")
		VP:Print("/vp cd : afficher / cacher les recharges du raid")
		VP:Print("/vp perf : mémoire et processeur utilisés par VuhPlus")
		VP:Print("/vp dispel : ce que votre personnage peut dissiper (selon ses sorts)")
		VP:Print("/vp profil save|load|suppr <nom> : gérer les profils")
		VP:Print("/vp test : tester l'alerte bijoux")
		VP:Print("/vp apercu : afficher / masquer un faux raid pour régler l'apparence")
	else
		VP.Options:Open()
	end
end
