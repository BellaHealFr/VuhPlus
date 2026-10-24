-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Détection du rôle par les talents (tank / soigneur / DPS)
-- En 3.3.5, le jeu ne connaît le rôle que dans l'outil Recherche de donjon.
-- Ici : votre propre rôle vient de vos talents, celui des autres d'une inspection discrète
-- (hors combat, à portée, une personne toutes les 2 secondes).
local VP = VuhPlus
local R = VP:NewModule("Roles")

-- Rôle par arbre de talents (1, 2, 3)
local TREES = {
	WARRIOR = { "DAMAGER", "DAMAGER", "TANK" },
	PALADIN = { "HEALER", "TANK", "DAMAGER" },
	PRIEST = { "HEALER", "HEALER", "DAMAGER" },
	DRUID = { "DAMAGER", "FERAL", "HEALER" },
	SHAMAN = { "DAMAGER", "DAMAGER", "HEALER" },
	DEATHKNIGHT = { "DK", "DK", "DK" },
}
-- Classes toujours DPS : pas besoin d'inspecter
local ALWAYS_DPS = { MAGE = true, WARLOCK = true, HUNTER = true, ROGUE = true }

local BEAR_IDS = { 5487, 9634 }       -- Forme d'ours, Forme d'ours redoutable
local CAT_FORM = 768                  -- Forme de félin (druide farouche DPS)
local FROST_PRESENCE = 48263          -- Présence de givre (chevalier de la mort tank)
local DPS_PRESENCE_IDS = { 48266, 48265 }   -- Présence de sang, Présence impie
local RIGHTEOUS_FURY = 25780          -- Fureur vertueuse (paladin tank)
local SHADOWFORM, MOONKIN, TREE_OF_LIFE = 15473, 24858, 33891   -- prêtre Ombre, druide Équilibre, druide Restauration
local catName, dpsPresenceNames, rfName = nil, {}, nil
local shadowName, moonkinName, treeName
local auraRole = {}                   -- GUID -> rôle retenu d'après la forme / la présence
local auraCand = {}                   -- GUID -> { role, since } : autre forme vue en combat, pas encore retenue
local AURA_HOLD = 30                  -- secondes d'affilée en combat dans l'autre forme avant de changer de rôle

-- Preuves de spé par le journal de combat (comme les détecteurs de soigneurs de la 3.3.5) : ces sorts sont des
-- talents PROFONDS d'un seul arbre. Un guerrier qui lance Dévastation est forcément Protection, même jamais inspecté,
-- même si l'inspection a échoué : c'est la seule façon sûre de reconnaître un guerrier tank (sa Posture défensive
-- n'est pas une aura lisible sur les autres joueurs, et UnitDefense ne marche que pour soi-même).
local PROOF_IDS = {
	WARRIOR = { [20243] = "TANK", [46968] = "TANK", [50720] = "TANK",      -- Dévastation, Onde de choc, Vigilance
		[12294] = "DAMAGER", [23881] = "DAMAGER", [46924] = "DAMAGER" },                     -- Frappe mortelle, Sanguinaire, Tempête de lames
	PALADIN = { [31935] = "TANK", [53595] = "TANK",                                         -- Bouclier du vengeur, Marteau du vertueux
		[20473] = "HEALER", [53563] = "HEALER",                                              -- Horion sacré, Guide de lumière
		[35395] = "DAMAGER", [53385] = "DAMAGER" },                                          -- Frappe du croisé, Tempête divine
	PRIEST  = { [47540] = "HEALER", [47788] = "HEALER", [34861] = "HEALER", [33206] = "HEALER", -- Pénitence, Esprit gardien, Cercle de soins, Suppression de la douleur
		[15407] = "DAMAGER", [34914] = "DAMAGER", [47585] = "DAMAGER" },                     -- Fouet mental, Toucher vampirique, Dispersion
	SHAMAN  = { [61295] = "HEALER", [974] = "HEALER",                                       -- Remous, Bouclier de terre
		[51490] = "DAMAGER", [30706] = "DAMAGER", [17364] = "DAMAGER", [60103] = "DAMAGER", [51533] = "DAMAGER" }, -- Orage, Totem de courroux, Frappe-tempête, Fouet de lave, Esprit farouche
	DRUID   = { [48438] = "HEALER",                                                     -- Croissance sauvage
		[48505] = "DAMAGER", [50516] = "DAMAGER" },                                          -- Météores, Typhon
}
local proofByName = {}   -- nom localisé -> { CLASSE = rôle }
R.proof = {}             -- GUID -> rôle prouvé par un sort (effacé au changement de spé)
local classByGUID = {}

R.trees = {}   -- GUID -> arbre principal (1-3)
R.when = {}    -- GUID -> moment de la dernière inspection réussie
R.cand = {}    -- GUID -> arbre lu une fois, en attente de confirmation par une 2e inspection
R.failed = {}  -- GUID -> moment d'une inspection sans résultat (bas niveau, égalité) : on attend 60 s
R.dirty = {}   -- GUID -> vient de changer de spé (double spé) : à réinspecter en priorité
local REFRESH = 120   -- on revérifie chaque joueur toutes les 2 minutes (talents refaits chez le maître)
-- Sorts « Activation de la spécialisation principale / secondaire » : lancés par tout joueur qui change de spé
local SPEC_SWITCH_IDS = { 63645, 63644 }
local specSwitchNames = {}
local bearNames, frostName = {}, nil

-- Qui a été inspecté EN DERNIER, par n'importe qui (fenêtre d'inspection, autre addon...) :
-- l'événement INSPECT_TALENT_READY ne dit pas de qui viennent les talents, on le note ici.
local lastInspectGUID
hooksecurefunc("NotifyInspect", function(unit)
	lastInspectGUID = unit and UnitGUID(unit)
end)

local function primaryTree(inspect)
	local group = GetActiveTalentGroup and GetActiveTalentGroup(inspect) or 1
	local best, bestPts, total, second = nil, 0, 0, 0
	local tab1
	for i = 1, 3 do
		local name, _, pts = GetTalentTabInfo(i, inspect, false, group)
		if i == 1 then tab1 = name end
		pts = pts or 0
		total = total + pts
		if pts > bestPts then best, second, bestPts = i, bestPts, pts
		elseif pts > second then second = pts end
	end
	-- données incomplètes (pas encore chargées) ou égalité : on ne conclut rien
	if total < 10 or bestPts == second then return nil, tab1 end
	return best, tab1
end
local myTab1   -- nom du 1er arbre de talents de MA classe (repère des réponses d'inspection fausses)

-- Peut-on inspecter ce joueur de façon fiable ? Pas s'il est mort / fantôme, hors de vue, ni si VOUS êtes
-- mort : le client renvoie alors des talents vides ou ceux d'un autre (souvent les vôtres). Deux lectures
-- fausses de suite suffisaient à changer le rôle : un guerrier ou un druide tank devenait DPS après un wipe.
local function reliable(u)
	return not UnitIsDeadOrGhost(u) and not UnitIsDeadOrGhost("player") and UnitIsVisible(u)
end

local function hasAnyBuff(unit, names)
	for n in pairs(names) do
		if UnitBuff(unit, n) then return true end
	end
	return false
end

-- Rôle d'une unité : "TANK", "HEALER", "DAMAGER" ou nil (inconnu)
function R:GetRole(unit)
	if not unit or not UnitIsPlayer(unit) then return nil end
	-- rôle forcé à la main (/vp role Nom heal|tank|dps) ; liste vide (cas courant) : pas de nom à mettre
	-- en minuscules (appelé des centaines de fois par seconde en raid)
	local ovs = VP.db.roleOverride
	if ovs and next(ovs) then
		local ov = ovs[string.lower(UnitName(unit) or "")]
		if ov then return ov end
	end
	local _, class = UnitClass(unit)
	if ALWAYS_DPS[class] then return "DAMAGER" end
	local guid = UnitGUID(unit)
	if not guid then return nil end
	-- Chevalier de la mort : les 3 arbres peuvent tanker, seule la présence compte. Pas besoin de ses talents
	-- (avant : sans inspection réussie, jamais à moins de 28 m hors combat, il n'avait AUCUNE icône)
	if class == "DEATHKNIGHT" then return self:AuraRole(unit, guid, "DK") end
	-- sort de talent profond vu dans le journal de combat : la preuve la plus sûre (passe avant l'inspection)
	local proof = self.proof[guid]
	if proof then return proof end
	local tree = self.trees[guid]
	if not tree then
		-- talents pas encore lus : seulement des indices sûrs (sinon inconnu, l'icône viendra de l'inspection
		-- ou du premier sort de talent lancé)
		if class == "PALADIN" then
			if rfName and UnitBuff(unit, rfName) then return "TANK" end          -- Fureur vertueuse
		elseif class == "DRUID" then
			if UnitPowerType(unit) == 1 or hasAnyBuff(unit, bearNames) then return "TANK" end   -- rage = forme d'ours
			if moonkinName and UnitBuff(unit, moonkinName) then return "DAMAGER" end
			if treeName and UnitBuff(unit, treeName) then return "HEALER" end
		elseif class == "PRIEST" then
			if shadowName and UnitBuff(unit, shadowName) then return "DAMAGER" end
		end
		return nil
	end
	local role = TREES[class] and TREES[class][tree] or "DAMAGER"
	if role == "FERAL" then return self:AuraRole(unit, guid, "FERAL") end
	return role
end

-- Un membre du groupe lance un sort de talent profond : son rôle est prouvé
function R:Prove(guid, spellName)
	local byClass = proofByName[spellName]
	if not byClass or not guid then return end
	local class = classByGUID[guid]
	if not class then
		class = select(2, GetPlayerInfoByGUID(guid))
		if not class then return end
		classByGUID[guid] = class
	end
	local role = byClass[class]
	if not role or self.proof[guid] == role then return end
	self.proof[guid] = role
	if VP.Frames and VP.Frames.ButtonsFor then
		local list = VP.Frames:ButtonsFor(guid)
		if list then for _, b in ipairs(list) do VP.Frames:UpdateRole(b); VP.Frames:UpdateHealth(b) end end
	end
	if VP.Panels and VP.Panels.RolesChanged and VP.Panels.groups then VP.Panels:RolesChanged() end
end

-- Rôle lu sur la forme (ours / félin) ou la présence (givre / sang, impie). Ces auras disparaissent à la mort
-- et ne sont pas lisibles quand VOUS êtes fantôme ou loin : on garde alors le dernier rôle vu (avant : un tank
-- mort ou relevé passait DPS et le restait). Forme humanoïde, aucune présence = rôle inchangé.
function R:AuraRole(unit, guid, kind)
	local seen
	if kind == "FERAL" then
		-- type de ressource (toujours lisible, même sans les auras) : rage = ours, énergie = félin ; mana = inchangé
		local pt = UnitPowerType(unit)
		if pt == 1 or hasAnyBuff(unit, bearNames) then seen = "TANK"
		elseif pt == 3 or (catName and UnitBuff(unit, catName)) then seen = "DAMAGER" end
	else
		if frostName and UnitBuff(unit, frostName) then seen = "TANK" elseif hasAnyBuff(unit, dpsPresenceNames) then seen = "DAMAGER" end
	end
	local known = auraRole[guid]
	if not known then
		if seen then auraRole[guid] = seen; return seen end
		return "DAMAGER"
	end
	-- Chevalier de la mort hors combat : il change de présence exprès (nouvelle spé, tank qui passe DPS) et n'a
	-- pas de forme de voyage, la nouvelle présence compte tout de suite. Avant : hors combat elle n'était jamais
	-- retenue, un DK passé de tank à DPS (ou l'inverse) restait à son ancienne place.
	if kind == "DK" and seen and seen ~= known and not UnitAffectingCombat(unit) then
		auraRole[guid], auraCand[guid] = seen, nil
		return seen
	end
	-- rôle déjà connu : une autre forme ne compte que tenue EN COMBAT pendant AURA_HOLD secondes d'affilée.
	-- Avant : un druide tank qui passait félin un instant (déplacement entre deux packs, Ruée...) passait DPS
	-- et changeait de bloc dans le tri par rôle.
	if seen and seen ~= known and UnitAffectingCombat(unit) then
		local c = auraCand[guid]
		if not c or c.role ~= seen then
			auraCand[guid] = { role = seen, since = GetTime() }
		elseif GetTime() - c.since >= AURA_HOLD then
			auraRole[guid], auraCand[guid] = seen, nil
			return seen
		end
	else
		auraCand[guid] = nil   -- revenu à sa forme habituelle, forme humanoïde ou hors combat : on repart de zéro
	end
	return known
end

function R:UpdatePlayer()
	local guid = UnitGUID("player")
	local tree = primaryTree(false)
	if guid and tree then
		local changed = self.trees[guid] ~= tree
		self.trees[guid] = tree; self.when[guid] = GetTime()
		if changed and VP.Frames and VP.Frames.ButtonsFor then
			local list = VP.Frames:ButtonsFor(guid)
			if list then for _, b in ipairs(list) do VP.Frames:UpdateRole(b); VP.Frames:UpdateHealth(b) end end
		end
		if changed and VP.Panels and VP.Panels.RolesChanged and VP.Panels.groups then VP.Panels:RolesChanged() end
		if changed then self:QueueShare(1) end   -- ma nouvelle spé, tout de suite aux autres
	end
end

-- Icône de rôle et blocs du tri par rôle à jour pour ce joueur
local function roleChanged(guid)
	if VP.Frames and VP.Frames.ButtonsFor then
		local list = VP.Frames:ButtonsFor(guid)
		if list then for _, b in ipairs(list) do VP.Frames:UpdateRole(b); VP.Frames:UpdateHealth(b) end end
	end
	if VP.Panels and VP.Panels.RolesChanged and VP.Panels.groups then VP.Panels:RolesChanged() end
end

-- Partage de la spé entre joueurs VuhPlus -----------------------------------------------
-- Chaque joueur VuhPlus annonce l'arbre principal de SES talents (lu sans erreur possible) par message
-- d'addon au groupe. Les autres le retiennent aussitôt : pas d'inspection, pas besoin d'être à 28 m,
-- et un changement de spé est connu dès qu'il est fait. Format : « T:2 » (arbre 1 à 3).
-- Rien n'est exécuté à la réception : seul un chiffre de 1 à 3 envoyé par un membre du groupe est lu.
local SHARE_PREFIX = "VuhPlusRole"
local SHARE_TTL = 300        -- au-delà (messages perdus, joueur qui a coupé le partage), l'inspection reprend
R.synced = {}                -- GUID -> moment du dernier arbre reçu de ce joueur
local shareAt, lastShare = nil, 0

function R:IsSynced(guid)
	local t = guid and VP.db.roleShare ~= false and self.synced[guid]
	return t and GetTime() - t < SHARE_TTL or false
end

function R:QueueShare(delay)
	local t = GetTime() + (delay or 0)
	if not shareAt or t < shareAt then shareAt = t end
end

function R:Share()
	shareAt = nil
	if VP.db.roleShare == false then return end
	local ch = VP:GroupChannel()
	local tree = primaryTree(false)
	if not ch or not tree then return end
	local now = GetTime()
	if now - lastShare < 3 then self:QueueShare(3 - (now - lastShare)) return end   -- pas de rafale
	lastShare = now
	SendAddonMessage(SHARE_PREFIX, "T:" .. tree, ch)
end

function R:OnShare(msg, sender)
	if VP.db.roleShare == false or type(msg) ~= "string" or not sender then return end
	sender = string.match(sender, "^([^%-]+)") or sender
	if sender == UnitName("player") then return end
	local tree = tonumber(string.match(msg, "^T:([123])$"))
	local g = tree and UnitGUID(sender)   -- nom d'un membre du groupe : renvoie son GUID (sinon ignoré)
	if not g then return end
	local changed = self.trees[g] ~= tree
	local now = GetTime()
	self.trees[g], self.when[g], self.synced[g] = tree, now, now
	-- ses propres talents font foi : lecture en attente, inspection ratée et preuve par sort ne servent plus
	self.cand[g], self.dirty[g], self.failed[g], self.proof[g] = nil, nil, nil, nil
	if changed then roleChanged(g) end
end

-- File d'inspection -----------------------------------------------------------
local pendingUnit, pendingGUID, pendingTime

local unitsBuf = {}
local function groupUnits()
	local t = unitsBuf
	wipe(t)
	local n = GetNumRaidMembers()
	if n > 0 then
		for i = 1, n do t[#t + 1] = "raid" .. i end
	else
		for i = 1, GetNumPartyMembers() do t[#t + 1] = "party" .. i end
	end
	return t
end

function R:Next()
	if not VP.db.roleInspect then return end
	if InCombatLockdown() or (InspectFrame and InspectFrame:IsShown()) then return end
	if pendingUnit then
		if GetTime() - pendingTime < 5 then return end
		pendingUnit, pendingGUID = nil, nil -- délai dépassé
	end
	local units = groupUnits()
	-- 1. les joueurs pas encore connus
	for _, u in ipairs(units) do
		if UnitExists(u) and UnitIsConnected(u) and not UnitIsUnit(u, "player") then
			local _, class = UnitClass(u)
			local guid = UnitGUID(u)
			-- (les joueurs VuhPlus qui partagent leur spé n'ont pas besoin d'être inspectés)
			if guid and TREES[class] and class ~= "DEATHKNIGHT" and not self:IsSynced(guid)
				and (not self.trees[guid] or self.cand[guid] or self.dirty[guid])
				and not (self.failed[guid] and GetTime() - self.failed[guid] < 60)
				and reliable(u) and CanInspect(u) and CheckInteractDistance(u, 1) then
				pendingUnit, pendingGUID, pendingTime = u, guid, GetTime()
				NotifyInspect(u)
				return
			end
		end
	end
	-- 2. tout le monde est connu : on revérifie le plus ancien (changement de spé, double spé)
	local now, oldU, oldG, oldT = GetTime(), nil, nil, nil
	for _, u in ipairs(units) do
		local guid = UnitGUID(u)
		local t = guid and self.when[guid]
		if t and now - t > REFRESH and (not oldT or t < oldT) and UnitIsConnected(u) and not self:IsSynced(guid)
			and not (self.failed[guid] and now - self.failed[guid] < 60)
			and not UnitIsUnit(u, "player") and reliable(u) and CanInspect(u) and CheckInteractDistance(u, 1) then
			oldU, oldG, oldT = u, guid, t
		end
	end
	if oldU then
		pendingUnit, pendingGUID, pendingTime = oldU, oldG, now
		NotifyInspect(oldU)
	end
end

function R:OnInspect()
	if not pendingUnit then return end
	-- les talents reçus doivent être ceux du joueur QUE NOUS avons inspecté :
	-- si quelqu'un d'autre a inspecté entre-temps, on ignore (sinon un soigneur pouvait
	-- recevoir les talents d'un DPS et s'afficher DPS)
	local mine = lastInspectGUID == pendingGUID
	if mine and UnitGUID(pendingUnit) == pendingGUID and reliable(pendingUnit) then
		local tree, tab1 = primaryTree(true)
		-- réponse qui porte les arbres de MA classe pour un joueur d'une autre classe : ce sont mes talents,
		-- pas les siens (inspection ratée côté serveur) ; ignorée sans rien changer
		local _, uclass = UnitClass(pendingUnit)
		if tree and uclass ~= VP.class and myTab1 and tab1 == myTab1 then tree = nil end
		if not tree then
			-- pas de conclusion possible : on passe aux autres joueurs pendant 60 s
			self.failed[pendingGUID] = GetTime()
		else
			self.failed[pendingGUID] = nil
			local g = pendingGUID
			self.dirty[g] = nil
			if self.trees[g] == tree then
				-- confirme ce qu'on savait déjà
				self.cand[g] = nil
				self.when[g] = GetTime()
			elseif self.cand[g] == tree then
				-- deux lectures identiques de suite : on retient ce rôle
				self.cand[g] = nil
				self.trees[g] = tree
				self.when[g] = GetTime()
				if VP.Frames then
					local list = VP.Frames:ButtonsFor(g)
					if list then for _, b in ipairs(list) do VP.Frames:UpdateRole(b); VP.Frames:UpdateHealth(b) end end
				end
				if VP.Panels and VP.Panels.RolesChanged then VP.Panels:RolesChanged() end
			else
				-- première lecture (ou différente) : à confirmer à la prochaine inspection
				self.cand[g] = tree
			end
		end
	end
	pendingUnit, pendingGUID = nil, nil
	if mine and not (InspectFrame and InspectFrame:IsShown()) then ClearInspectPlayer() end
end

-- /vp role Nom heal|tank|dps|auto
function R:SetOverride(name, role)
	VP.db.roleOverride = VP.db.roleOverride or {}
	local map = { heal = "HEALER", soin = "HEALER", healer = "HEALER", tank = "TANK", dps = "DAMAGER" }
	if not name or name == "" then
		if UnitExists("target") and UnitIsPlayer("target") then name = UnitName("target") end
	end
	if not name or name == "" then VP:Print("Usage : /vp role <nom> heal|tank|dps|auto (ou ciblez le joueur).") return end
	local word = string.lower(role or "")
	local r = map[word]
	if not r and word ~= "auto" and word ~= "" then
		VP:Print("Rôle inconnu « " .. tostring(role) .. " ». Usage : /vp role <nom> heal|tank|dps|auto")
		return
	end
	local key = string.lower(name)   -- « bob » et « Bob » : même joueur
	if r then
		VP.db.roleOverride[key] = r
		VP:Print(name .. " : rôle forcé sur " .. ({ HEALER = "soigneur", TANK = "tank", DAMAGER = "DPS" })[r] .. ".")
	else
		VP.db.roleOverride[key] = nil
		VP:Print(name .. " : rôle automatique (talents).")
	end
	if VP.Frames then for _, b in ipairs(VP.Frames.buttons) do VP.Frames:UpdateRole(b); VP.Frames:UpdateHealth(b) end end
	if VP.Panels and VP.Panels.RolesChanged then VP.Panels:RolesChanged() end
end

function R:OnLogin()
	for _, id in ipairs(BEAR_IDS) do
		local n = GetSpellInfo(id)
		if n then bearNames[n] = true end
	end
	frostName = GetSpellInfo(FROST_PRESENCE)
	myTab1 = GetTalentTabInfo(1)
	catName = GetSpellInfo(CAT_FORM)
	rfName = GetSpellInfo(RIGHTEOUS_FURY)
	shadowName, moonkinName, treeName = GetSpellInfo(SHADOWFORM), GetSpellInfo(MOONKIN), GetSpellInfo(TREE_OF_LIFE)
	for class, list in pairs(PROOF_IDS) do
		for id, role in pairs(list) do
			local n = GetSpellInfo(id)
			if n then
				proofByName[n] = proofByName[n] or {}
				proofByName[n][class] = role
			end
		end
	end
	-- journal de combat : sorts de talent lancés par un JOUEUR du groupe (filtre très tôt : coût minime)
	local band = bit and bit.band
	VP:On("COMBAT_LOG_EVENT_UNFILTERED", function(_, _, event, srcGUID, _, srcFlags, _, _, _, _, spellName)
		if event ~= "SPELL_CAST_SUCCESS" or not proofByName[spellName or ""] or not band then return end
		if band(srcFlags or 0, 0x7) == 0 or band(srcFlags or 0, 0x400) == 0 then return end
		R:Prove(srcGUID, spellName)
	end)
	-- mon propre changement de spé : ma preuve ne vaut plus, ni le rôle retenu par ma forme / ma présence
	VP:On("ACTIVE_TALENT_GROUP_CHANGED", function()
		local g = UnitGUID("player")
		if g then R.proof[g] = nil; auraRole[g] = nil; auraCand[g] = nil end
	end)
	for _, id in ipairs(DPS_PRESENCE_IDS) do
		local n = GetSpellInfo(id)
		if n then dpsPresenceNames[n] = true end
	end
	-- rôles forcés : noms en minuscules (les anciennes saisies gardaient les majuscules)
	local ov = VP.db.roleOverride
	if ov then
		local copy = {}
		for k, v in pairs(ov) do copy[string.lower(k)] = v end
		wipe(ov)
		for k, v in pairs(copy) do ov[k] = v end
	end
	self:UpdatePlayer()
	VP:On("PLAYER_TALENT_UPDATE", function() R:UpdatePlayer() end)
	VP:On("ACTIVE_TALENT_GROUP_CHANGED", function() R:UpdatePlayer() end)
	VP:On("CHARACTER_POINTS_CHANGED", function() R:UpdatePlayer() end)
	VP:On("INSPECT_TALENT_READY", function() R:OnInspect() end)
	-- un joueur du groupe change de spé : on le réinspecte tout de suite (sinon seulement au prochain tour)
	for _, id in ipairs(SPEC_SWITCH_IDS) do
		local n = GetSpellInfo(id)
		if n then specSwitchNames[n] = true end
	end
	VP:On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, spell)
		if not spell or not specSwitchNames[spell] or not unit then return end
		if UnitIsUnit(unit, "player") or not (UnitInRaid(unit) or UnitInParty(unit)) then return end
		local guid = UnitGUID(unit)
		-- nouvelle spé : la preuve par sort ne vaut plus, réinspection prioritaire
		-- (et le rôle retenu par la forme aussi : la nouvelle forme compte tout de suite)
		if guid then R.dirty[guid] = true; R.failed[guid] = nil; R.proof[guid] = nil; auraRole[guid] = nil; auraCand[guid] = nil end
	end)
	-- partage de la spé : réception, et envoi quand le groupe ou mes talents changent
	-- (délai au hasard à l'arrivée dans un groupe : pas 25 messages à la même seconde)
	VP:On("CHAT_MSG_ADDON", function(_, prefix, msg, _, sender)
		if prefix == SHARE_PREFIX then R:OnShare(msg, sender) end
	end)
	local function soon() R:QueueShare(2 + math.random() * 3) end
	VP:On("RAID_ROSTER_UPDATE", soon)
	VP:On("PARTY_MEMBERS_CHANGED", soon)
	VP:On("PLAYER_ENTERING_WORLD", function() R:QueueShare(5 + math.random() * 3) end)
	VP:On("ACTIVE_TALENT_GROUP_CHANGED", function() R:QueueShare(1) end)
	VP:On("PLAYER_TALENT_UPDATE", function() R:QueueShare(1) end)
	local acc, resend = 0, 0
	local f = CreateFrame("Frame")
	f:SetScript("OnUpdate", function(_, e)
		if shareAt and GetTime() >= shareAt then R:Share() end
		-- rappel toutes les 2 minutes (un joueur arrivé entre-temps, un message perdu)
		resend = resend + e
		if resend >= 120 then resend = 0; R:QueueShare(math.random() * 5) end
		acc = acc + e
		if acc < 2 then return end
		acc = 0
		R:Next()
	end)
end
