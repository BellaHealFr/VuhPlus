-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Panneaux : raid principal, tanks principaux, « Mes tanks », familiers,
-- cible / cible de la cible / focalisation, barre GCD, bouton minicarte, cadres Blizzard
local VP = VuhPlus
local P = VP:NewModule("Panels")
P.anchors = {}
P.headers = {}

local CLASS_ORDER = "WARRIOR,DEATHKNIGHT,PALADIN,DRUID,PRIEST,SHAMAN,ROGUE,HUNTER,MAGE,WARLOCK"
local GCD_REF = { WARRIOR = 6673, PALADIN = 635, HUNTER = 1978, ROGUE = 1752, PRIEST = 585, DEATHKNIGHT = 47541,
	SHAMAN = 403, MAGE = 133, WARLOCK = 686, DRUID = 5176 }

local function posOf(key)
	if key == "main" then return VP.db.pos end
	return VP.db.panels[key].pos
end

local function savePos(key, a)
	-- position réelle à l'écran (coin haut-gauche de l'ancre), et non GetPoint() : après un
	-- déplacement, le point renvoyé n'est pas toujours relatif à l'écran entier
	local x, y = a:GetLeft(), a:GetTop()
	if not x or not y then return end
	local p = { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = x, y = y }
	if key == "main" then VP.db.pos = p else VP.db.panels[key].pos = p end
	VP:Unplace(a)
end

function P:MakeAnchor(key, label)
	local a = CreateFrame("Frame", "VuhPlusAnchor_" .. key, UIParent)
	a:SetWidth(10); a:SetHeight(10)
	a:SetMovable(true)
	a:SetClampedToScreen(true)
	a.handle = VP.Theme:Handle(a, label,
		function() if not InCombatLockdown() then a:StartMoving() end end,
		function() a:StopMovingOrSizing(); savePos(key, a) end)
	self.anchors[key] = a
	return a
end

-- Les nouveaux cadres prennent tout de suite la bonne taille, même créés en combat :
-- le code sécurisé de l'en-tête lit la taille dans ses attributs « vp-w » / « vp-h ».
local SIZE_SNIPPET = [[
	local h = self:GetParent()
	local w, ht = h:GetAttribute("vp-w"), h:GetAttribute("vp-h")
	if w and ht then
		self:SetWidth(w)
		self:SetHeight(ht)
	end
]]
-- Taille d'un cadre de familier (réglable en % d'un cadre de joueur)
function P:PetSize()
	local db = VP.db
	local pt = db.pets or {}
	local w = math.floor(db.width * (pt.width or 100) / 100 + 0.5)
	local h = math.max(12, math.floor(VP.Frames:FrameHeight() * (pt.height or 60) / 100 + 0.5))
	return w, h
end

function P:SizeHeader(h)
	local db = VP.db
	local w, ht = db.width, VP.Frames:FrameHeight()
	if h.vpKind == "pets" then w, ht = self:PetSize() end
	if h:GetAttribute("vp-w") ~= w then h:SetAttribute("vp-w", w) end
	if h:GetAttribute("vp-h") ~= ht then h:SetAttribute("vp-h", ht) end
	if h:GetAttribute("initialConfigFunction") ~= SIZE_SNIPPET then h:SetAttribute("initialConfigFunction", SIZE_SNIPPET) end
end

local function header(key, anchor, template)
	local h = CreateFrame("Frame", "VuhPlusHeader_" .. key, anchor, template)
	h.vpKind = key
	h:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
	h:SetAttribute("template", "VuhPlusUnitTemplate")
	h:SetAttribute("templateType", "Button")
	h:SetAttribute("point", "TOP")
	h:SetAttribute("columnAnchorPoint", "LEFT")
	h:SetAttribute("toggleForVehicle", true)
	P:SizeHeader(h)
	VP.Clicks:RegisterTarget(h)
	P.headers[key] = h
	return h
end

-- « Mes tanks » : liste de noms choisie par le joueur
function P:ToggleMyTank(name)
	name = name or (UnitExists("target") and UnitIsPlayer("target") and UnitName("target"))
	if not name then VP:Print("Ciblez un joueur ou tapez /vp tank Nom.") return end
	local list = VP.db.myTanks
	for i, n in ipairs(list) do
		if n == name then
			table.remove(list, i)
			VP:Print(name .. " retiré de « Mes tanks ».")
			self:ApplyMyTanks()
			return
		end
	end
	table.insert(list, name)
	VP:Print(name .. " ajouté à « Mes tanks »." .. (InCombatLockdown() and " (affiché à la fin du combat)" or ""))
	self:ApplyMyTanks()
end

function P:ApplyMyTanks()
	VP:RunOOC("mytanks", function()
		local h = P.headers.mytanks
		local list = table.concat(VP.db.myTanks, ",")
		h:SetAttribute("nameList", list)
		if list == "" then h:Hide() else h:Show() end
	end)
end

-- « Projecteur » (comme le Spotlight de Cell) : cadres en plus pour des joueurs choisis
-- (/vp spot) et, en option, vos cibles assignées (onglet Assignations)
function P:SpotlightNames()
	local out, seen = {}, {}
	local function add(n)
		if n and n ~= "" and not seen[string.lower(n)] then seen[string.lower(n)] = true; out[#out + 1] = n end
	end
	for _, n in ipairs(VP.db.spotlight) do add(n) end
	if VP.db.spotAssign and VP.Assign then
		for _, n in ipairs(VP.Assign:MyTargets()) do add(n) end
	end
	return out
end

function P:ToggleSpotlight(name)
	name = name or (UnitExists("target") and UnitIsPlayer("target") and UnitName("target"))
	if not name then VP:Print("Ciblez un joueur ou tapez /vp spot Nom.") return end
	local list = VP.db.spotlight
	for i, n in ipairs(list) do
		if n == name then
			table.remove(list, i)
			VP:Print(name .. " retiré du Projecteur.")
			self:ApplySpotlight()
			return
		end
	end
	table.insert(list, name)
	if not VP.db.panels.spotlight.enabled then
		VP.db.panels.spotlight.enabled = true
		self:ApplyLayout()
	end
	VP:Print(name .. " ajouté au Projecteur." .. (InCombatLockdown() and " (affiché à la fin du combat)" or ""))
	self:ApplySpotlight()
end

function P:ApplySpotlight()
	VP:RunOOC("spotlight", function()
		local h = P.headers.spotlight
		if not h then return end
		local list = table.concat(P:SpotlightNames(), ",")
		h:SetAttribute("nameList", list ~= "" and list or "VuhPlusPersonne")
		if list == "" or not VP.db.panels.spotlight.enabled then h:Hide() else h:Show() end
	end)
end

-- Disposition du raid principal ---------------------------------------------------
-- Tri par groupe : 8 en-têtes (un par groupe) avec titre « Groupe N », comme VuhDo.
-- Tri par classe / nom : un seul en-tête en colonnes.
local TITLE_H = 14

-- Échelle effective : automatique selon la taille du raid si demandé
function P:EffScale()
	local d = VP.db
	if d.autoScale then
		local n = GetNumRaidMembers()
		if n > 25 then return d.scale40 elseif n > 10 then return d.scale25 end
	end
	return d.scale
end

function P:UseGroups()
	-- le tri par rôle réutilise les en-têtes de groupe (1 bloc par rôle, ou 1 morceau de ligne en grille)
	return VP.db.sortMode == "GROUP" or VP.db.sortMode == "ROLE" or VP.db.sortMode == "ROLEGRID"
end

-- Tri par rôle ----------------------------------------------------------------------
-- 3 blocs (Tanks / Soigneurs / DPS) dans l'ordre choisi. Chaque bloc est un en-tête sécurisé
-- filtré par une liste de noms, reconstruite hors combat quand le groupe ou un rôle change.
P.ROLE_NAMES = { TANK = "Tanks", HEALER = "Soigneurs", DAMAGER = "DPS" }
P.roleLists = { {}, {}, {} }

function P:UseRoles() return VP.db.sortMode == "ROLE" end
-- Grille par rôle : même encombrement que le tri par groupe (2 colonnes à 10, 5 colonnes à 25),
-- mais remplie ligne par ligne dans l'ordre des rôles : les tanks en haut, puis les soigneurs, puis les DPS.
function P:UseGrid() return VP.db.sortMode == "ROLEGRID" end

function P:RoleOrder()
	local o = VP.db.roleOrder
	local ok = type(o) == "table" and #o == 3
	if ok then
		local seen = {}
		for _, r in ipairs(o) do
			if not P.ROLE_NAMES[r] or seen[r] then ok = false end
			seen[r] = true
		end
	end
	if not ok then
		o = { "TANK", "HEALER", "DAMAGER" }
		VP.db.roleOrder = o
	end
	return o
end

-- Rôle d'un joueur pour le placement (même logique que l'icône : forcé, talents,
-- Recherche de donjon, tank principal du raid ; inconnu = DPS)
function P:UnitRole(u, raidIndex)
	local r = VP.Roles and VP.Roles:GetRole(u)
	if r then return r end
	local t, h, dd = UnitGroupRolesAssigned(u)
	if t then return "TANK" elseif h then return "HEALER" elseif dd then return "DAMAGER" end
	if type(raidIndex) == "number" then
		local rr = select(10, GetRaidRosterInfo(raidIndex))
		if rr == "MAINTANK" then return "TANK" end
	end
	return "DAMAGER"
end

function P:BuildRoleLists()
	local order = self:RoleOrder()
	local slot = {}
	for k, role in ipairs(order) do slot[role] = k; wipe(self.roleLists[k]) end
	local function add(u, name, raidIndex)
		if not name or not UnitExists(u) then return end
		local k = slot[self:UnitRole(u, raidIndex)] or 3
		local l = self.roleLists[k]
		l[#l + 1] = name
	end
	local n = GetNumRaidMembers()
	if n > 0 then
		for i = 1, n do
			local name = GetRaidRosterInfo(i)
			add("raid" .. i, name, i)
		end
	else
		-- (UnitName(...)) entre parenthèses : UnitName renvoie aussi le royaume, qui serait pris pour un numéro de raid
		if GetNumPartyMembers() > 0 or VP.db.showSolo then add("player", (UnitName("player"))) end
		for i = 1, GetNumPartyMembers() do add("party" .. i, (UnitName("party" .. i))) end
	end
end

-- Configure les en-têtes de groupe selon le mode (rôle ou groupe) - hors combat uniquement
-- n'écrit un attribut que s'il change (chaque écriture relance le placement de l'en-tête)
local function setA(f, k, v)
	if f:GetAttribute(k) ~= v then f:SetAttribute(k, v) end
end
-- L'en-tête sécurisé ne détache pas ses cadres quand son sens de remplissage change : on le fait
-- nous-mêmes juste avant, le changement d'attribut les replace aussitôt.
local function clearChildren(h)
	for i = 1, select("#", h:GetChildren()) do
		local c = select(i, h:GetChildren())
		c:ClearAllPoints()
	end
end

-- Grille par rôle. L'ordre exact des joueurs n'est pas réglable sur un en-tête sécurisé de la 3.3.5 :
-- chaque ligne est donc découpée en morceaux d'un seul rôle, un en-tête par morceau (8 au plus).
function P:ApplyGridHeaders()
	local d = VP.db
	self:BuildRoleLists()
	local seq, roleOf = {}, {}
	for k = 1, 3 do
		table.sort(self.roleLists[k])
		for _, name in ipairs(self.roleLists[k]) do
			seq[#seq + 1] = name
			roleOf[#seq] = k
		end
	end
	local total = #seq
	-- « joueurs par colonne » donne la hauteur de la grille : 5 = 2 colonnes à 10 joueurs, 5 colonnes à 25
	local cols = math.max(1, math.ceil(total / math.max(1, d.perColumn)))
	local segs
	repeat
		segs = {}
		local cur
		for i = 1, total do
			local col = (i - 1) % cols
			if not cur or col == 0 or roleOf[i] ~= cur.role then
				cur = { role = roleOf[i], row = math.floor((i - 1) / cols), col = col, names = {} }
				segs[#segs + 1] = cur
			end
			cur.names[#cur.names + 1] = seq[i]
		end
		-- trop de morceaux pour les 8 en-têtes (grille très haute) : on élargit la grille
		if #segs > 8 then cols = cols + 1 end
	until #segs <= 8
	local fh = VP.Frames:FrameHeight()
	for i = 1, 8 do
		local g, s = self.groups[i], segs[i]
		if s then
			if g:GetAttribute("point") ~= "LEFT" then clearChildren(g) end
			-- d'abord la liste, ensuite on retire le filtre de groupe : jamais d'instant sans filtre
			setA(g, "nameList", table.concat(s.names, ","))
			setA(g, "groupFilter", nil)
			setA(g, "sortMethod", "NAME")
			setA(g, "showParty", true)
			setA(g, "showPlayer", true)
			setA(g, "showSolo", d.showSolo)
			setA(g, "unitsPerColumn", nil)
			setA(g, "maxColumns", nil)
			setA(g, "xOffset", d.xGap)
			setA(g, "point", "LEFT")
			g:ClearAllPoints()
			g:SetPoint("TOPLEFT", self.anchors.main, "TOPLEFT", d.padX + s.col * (d.width + d.xGap), -(d.padY + s.row * (fh + d.yGap)))
			g:Show()
		else
			setA(g, "nameList", "VuhPlusPersonne")
			setA(g, "groupFilter", nil)
			g:Hide()
		end
		self.titles[i]:Hide()
	end
	self.gridRows = total > 0 and math.ceil(total / cols) or 0
end

function P:ApplyRoleHeaders()
	local d = VP.db
	if self:UseGrid() then return end   -- la grille est configurée et placée par LayoutGroups
	local roles = self:UseRoles()
	if roles then self:BuildRoleLists() end
	local order = self:RoleOrder()
	for i = 1, 8 do
		local g = self.groups[i]
		-- on quitte la grille par rôle : retour au remplissage en colonne
		if g:GetAttribute("point") ~= "TOP" then
			clearChildren(g)
			g:SetAttribute("xOffset", nil)
			g:SetAttribute("point", "TOP")
		end
		if roles then
			if i <= 3 then
				local list = table.concat(self.roleLists[i], ",")
				-- d'abord la liste, ensuite on retire le filtre de groupe : jamais d'instant sans filtre
				-- (l'en-tête montrerait tout le raid et créerait des dizaines de cadres pour rien)
				-- bloc vide : un nom impossible
				setA(g, "nameList", list ~= "" and list or "VuhPlusPersonne")
				setA(g, "groupFilter", nil)
				setA(g, "sortMethod", "NAME")
				setA(g, "showParty", true)
				setA(g, "showPlayer", true)
				setA(g, "showSolo", d.showSolo)
				setA(g, "unitsPerColumn", d.perColumn)
				setA(g, "maxColumns", math.ceil(40 / math.max(1, d.perColumn)))
				setA(g, "columnAnchorPoint", "LEFT")
				self.titles[i]:SetText(self.ROLE_NAMES[order[i]] or "")
			end
		else
			setA(g, "groupFilter", tostring(i))
			setA(g, "nameList", nil)
			setA(g, "sortMethod", "INDEX")
			setA(g, "showParty", i == 1)
			setA(g, "showPlayer", i == 1)
			setA(g, "showSolo", i == 1 and d.showSolo)
			setA(g, "unitsPerColumn", nil)
			setA(g, "maxColumns", nil)
			self.titles[i]:SetText("Groupe " .. i)
		end
	end
end

-- Un rôle a changé (inspection, /vp role...) : on refait les blocs hors combat
function P:RolesChanged()
	if not self:UseRoles() and not self:UseGrid() then return end
	VP:RunOOC("roles", function() P:ApplyRoleHeaders(); P:LayoutGroups() end)
end

function P:ApplySort()
	local h = self.headers.main
	if VP.db.sortMode == "CLASS" then
		h:SetAttribute("groupBy", "CLASS")
		h:SetAttribute("groupingOrder", CLASS_ORDER)
		h:SetAttribute("sortMethod", "NAME")
	else
		h:SetAttribute("groupBy", nil)
		h:SetAttribute("groupingOrder", nil)
		h:SetAttribute("sortMethod", "NAME")
	end
end

-- Nombre de membres par groupe
function P:GroupCounts()
	local c = { 0, 0, 0, 0, 0, 0, 0, 0 }
	if self:UseRoles() then
		for k = 1, 3 do c[k] = #self.roleLists[k] end
		return c
	end
	local n = GetNumRaidMembers()
	if n > 0 then
		for i = 1, n do
			local _, _, sub = GetRaidRosterInfo(i)
			if sub and c[sub] then c[sub] = c[sub] + 1 end
		end
	else
		local party = GetNumPartyMembers()
		if party > 0 or VP.db.showSolo then c[1] = party + 1 end
	end
	return c
end

-- Familiers ----------------------------------------------------------------------
-- Mode « sous le maître » : un en-tête de familiers par groupe (ou par bloc de rôle), placé juste
-- sous les cadres de ce groupe ; en tri classe / nom, un seul sous le raid. Mode « panneau » : le
-- panneau Familiers séparé. Tout est sécurisé : un familier invoqué en combat apparaît aussitôt.
function P:PetsOn()
	local pt = VP.db.pets
	return pt and pt.enabled
end

-- Familiers cachés selon la classe du maître (invocations de quelques secondes : tréants...)
function P:PetClassHidden(class)
	local hc = VP.db.pets.hideClasses
	return hc and class and hc[class] or false
end
function P:PetFiltered()
	local hc = VP.db.pets.hideClasses
	if hc then for _, v in pairs(hc) do if v then return true end end end
	return false
end
-- Maîtres dont on affiche les familiers : liste de noms (filtre sécurisé « nameList » des en-têtes).
-- group = numéro de groupe (nil = tout le raid) ; names = liste imposée (tri par rôle)
function P:PetOwners(group, names)
	local allow
	if names then allow = {}; for _, n in ipairs(names) do allow[n] = true end end
	local out = {}
	local function add(name, class, sub)
		if name and not self:PetClassHidden(class) and (not group or sub == group) and (not allow or allow[name]) then
			out[#out + 1] = name
		end
	end
	local n = GetNumRaidMembers()
	if n > 0 then
		for i = 1, n do
			local name, _, sub, _, _, class = GetRaidRosterInfo(i)
			add(name, class, sub)
		end
	else
		add(UnitName("player"), select(2, UnitClass("player")), 1)
		for i = 1, GetNumPartyMembers() do add(UnitName("party" .. i), select(2, UnitClass("party" .. i)), 1) end
	end
	local list = table.concat(out, ",")
	return list ~= "" and list or "VuhPlusPersonne"
end

-- nombre de familiers par groupe (pour réserver la place en disposition « empilée »)
function P:PetCounts()
	local c = { 0, 0, 0, 0, 0, 0, 0, 0 }
	if not self:PetsOn() or VP.db.pets.mode ~= "ATTACH" then return c end
	local n = GetNumRaidMembers()
	if self:UseRoles() then
		-- par bloc de rôle : on compte les familiers des maîtres de chaque liste
		local where = {}
		for k = 1, 3 do for _, name in ipairs(self.roleLists[k]) do where[name] = k end end
		if n > 0 then
			for i = 1, n do
				local name = GetRaidRosterInfo(i)
				local k = name and where[name]
				if k and UnitExists("raidpet" .. i) and not self:PetClassHidden(select(6, GetRaidRosterInfo(i))) then c[k] = c[k] + 1 end
			end
		else
			local k = where[UnitName("player") or ""]
			if k and UnitExists("pet") and not self:PetClassHidden(select(2, UnitClass("player"))) then c[k] = c[k] + 1 end
			for i = 1, GetNumPartyMembers() do
				local k2 = where[UnitName("party" .. i) or ""]
				if k2 and UnitExists("partypet" .. i) and not self:PetClassHidden(select(2, UnitClass("party" .. i))) then c[k2] = c[k2] + 1 end
			end
		end
		return c
	end
	if n > 0 then
		for i = 1, n do
			local _, _, sub, _, _, class = GetRaidRosterInfo(i)
			if sub and c[sub] and UnitExists("raidpet" .. i) and not self:PetClassHidden(class) then c[sub] = c[sub] + 1 end
		end
	else
		if UnitExists("pet") and not self:PetClassHidden(select(2, UnitClass("player"))) then c[1] = c[1] + 1 end
		for i = 1, GetNumPartyMembers() do
			if UnitExists("partypet" .. i) and not self:PetClassHidden(select(2, UnitClass("party" .. i))) then c[1] = c[1] + 1 end
		end
	end
	return c
end

-- visibilité sécurisée d'un en-tête de familiers : caché, toujours, ou seulement en combat
local function petVisibility(h, on)
	local pt = VP.db.pets
	local state = (not on) and "hide" or (pt.combatOnly and "[combat] show; hide" or "show")
	if h.vpVis ~= state then
		h.vpVis = state
		RegisterStateDriver(h, "visibility", state)
	end
end

-- Configure tous les en-têtes de familiers (hors combat uniquement)
function P:ApplyPets()
	local d = VP.db
	local pt = d.pets
	local on = pt.enabled
	local attach = on and pt.mode == "ATTACH"
	local roles, groups = self:UseRoles(), self:UseGroups()
	-- grille par rôle : pas de colonne par groupe, les familiers vont sous la grille entière
	local grid = self:UseGrid()
	if grid then groups = false end
	local preview = VP.Preview and VP.Preview.shown
	local filtered = self:PetFiltered()
	-- panneau séparé (déplaçable) ou à côté des joueurs (suit le panneau principal)
	local side = on and pt.mode == "SIDE"
	local panelOn = on and (pt.mode == "PANEL" or side)
	d.panels.pets.enabled = panelOn
	local pa, hp = self.anchors.pets, self.headers.pets
	if panelOn and d.showFrames ~= false then pa:Show() else pa:Hide() end
	if panelOn then
		-- filtre sur la classe du maître : liste des maîtres autorisés (sinon tout le monde)
		setA(hp, "groupFilter", filtered and nil or "1,2,3,4,5,6,7,8")
		setA(hp, "nameList", filtered and self:PetOwners() or nil)
	end
	if side then
		-- à droite du dernier cadre de joueur, en haut du panneau, même échelle que le raid
		local main = self.anchors.main
		local al = main:GetLeft()
		local right
		for _, b in ipairs(VP.Frames.buttons) do
			if b:IsVisible() and VP.Frames:Kind(b) == "main" then
				local br = b:GetRight()
				if br and (not right or br > right) then right = br end
			end
		end
		local x = (right and al) and (right - al + d.xGap + 6) or (d.padX + d.width + d.xGap + 6)
		local th = (d.groupTitles and (groups or roles)) and TITLE_H or 0
		pa:SetScale(self:EffScale())
		pa:ClearAllPoints()
		pa:SetPoint("TOPLEFT", main, "TOPLEFT", x, -(d.padY + th))
		pa.handle:Hide()
	elseif panelOn then
		-- panneau séparé : sa position enregistrée (au cas où il était collé au raid juste avant)
		local pos = posOf("pets")
		pa:SetScale(d.scale)
		pa:ClearAllPoints()
		pa:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
		if d.locked then pa.handle:Hide() else pa.handle:Show() end
	end
	petVisibility(hp, panelOn and not (side and preview))
	local gap = d.yGap + 2
	-- un en-tête par groupe / bloc
	for i = 1, 8 do
		local pg = self.petGroups[i]
		local g = self.groups[i]
		local show = attach and groups and not preview and g:IsShown() and (not roles or i <= 3)
		if show then
			if roles then
				local list = table.concat(self.roleLists[i], ",")
				if filtered then list = self:PetOwners(nil, self.roleLists[i]) end
				setA(pg, "nameList", list ~= "" and list or "VuhPlusPersonne")   -- filtre sur les MAÎTRES
				setA(pg, "groupFilter", nil)
				setA(pg, "showParty", true); setA(pg, "showPlayer", true)
				setA(pg, "unitsPerColumn", d.perColumn)
				setA(pg, "maxColumns", math.ceil(40 / math.max(1, d.perColumn)))
			elseif filtered then
				-- « groupFilter » ne sait pas exclure une classe : liste des maîtres du groupe autorisés
				setA(pg, "groupFilter", nil)
				setA(pg, "nameList", self:PetOwners(i))
				setA(pg, "showParty", i == 1); setA(pg, "showPlayer", i == 1)
				setA(pg, "unitsPerColumn", nil)
				setA(pg, "maxColumns", nil)
			else
				setA(pg, "groupFilter", tostring(i))
				setA(pg, "nameList", nil)
				setA(pg, "showParty", i == 1); setA(pg, "showPlayer", i == 1)
				setA(pg, "unitsPerColumn", nil)
				setA(pg, "maxColumns", nil)
			end
			setA(pg, "showSolo", (i == 1 or roles) and d.showSolo)
			pg:ClearAllPoints()
			pg:SetPoint("TOPLEFT", g, "BOTTOMLEFT", 0, -gap)
		end
		petVisibility(pg, show)
	end
	-- tri par classe / nom : un seul en-tête sous le raid
	local pm = self.petMain
	local showMain = attach and not groups and not preview
	if showMain then
		setA(pm, "groupFilter", filtered and nil or "1,2,3,4,5,6,7,8")
		setA(pm, "nameList", filtered and self:PetOwners() or nil)
		setA(pm, "unitsPerColumn", d.perColumn)
		setA(pm, "maxColumns", math.ceil(40 / math.max(1, d.perColumn)))
		setA(pm, "showSolo", d.showSolo)
		pm:ClearAllPoints()
		if grid then
			pm:SetPoint("TOPLEFT", self.anchors.main, "TOPLEFT", d.padX,
				-(d.padY + (self.gridRows or 0) * (VP.Frames:FrameHeight() + d.yGap) + 4))
		else
			pm:SetPoint("TOPLEFT", self.headers.main, "BOTTOMLEFT", 0, -gap - 4)
		end
	end
	petVisibility(pm, showMain)
	for _, h in ipairs(self.allPetHeaders) do
		self:SizeHeader(h)
		setA(h, "yOffset", -d.yGap)
		setA(h, "columnSpacing", d.xGap)
	end
end

-- Position (x, y) du coin haut-gauche du k-ième groupe affiché (k commence à 0)
function P:GroupOrigin(k)
	local d = VP.db
	local fh = VP.Frames:FrameHeight()
	local th = d.groupTitles and TITLE_H or 0
	if d.groupOrient == "V" then
		return d.padX, -(d.padY + th + k * (th + 5 * (fh + d.yGap) + d.yGap * 2))
	end
	return d.padX + k * (d.width + d.xGap), -(d.padY + th)
end

function P:LayoutGroups()
	VP:RunOOC("groups", function()
		local d = VP.db
		if P:UseGrid() and not (VP.Preview and VP.Preview.shown) then
			P:ApplyGridHeaders()
			P.anchors.main:SetScale(P:EffScale())
			P.headers.main:Hide()
			P:ApplyPets()
			return
		end
		local counts = P:GroupCounts()
		local useGroups = P:UseGroups() and not (VP.Preview and VP.Preview.shown)
		-- Les en-têtes de groupe restent TOUJOURS affichés quand on trie par groupe : un groupe vide
		-- ne dessine rien, mais s'il se remplit en combat (joueur déplacé, remplaçant invité),
		-- ses cadres apparaissent tout de suite. En mode compact, les groupes vides sont rangés
		-- après les groupes remplis.
		if P:UseRoles() and not (VP.Preview and VP.Preview.shown) then
			-- listes à jour même si cette mise en page passe avant la reconstruction des blocs
			P:ApplyRoleHeaders()   -- blocs et familiers suivent les mêmes listes
			counts = P:GroupCounts()
			-- blocs Tanks / Soigneurs / DPS : chaque bloc a autant de colonnes que nécessaire
			local fh = VP.Frames:FrameHeight()
			local th = d.groupTitles and TITLE_H or 0
			local per = math.max(1, d.perColumn)
			local x, y = d.padX, -(d.padY + th)
			local pets = P:PetCounts()
			local _, ph = P:PetSize()
			for i = 1, 8 do
				local g = P.groups[i]
				local cnt = i <= 3 and counts[i] or 0
				if i <= 3 and (cnt > 0 or not d.groupCompact) then
					g:ClearAllPoints()
					g:SetPoint("TOPLEFT", P.anchors.main, "TOPLEFT", x, y)
					g:Show()
					local cols = math.max(1, math.ceil(cnt / per))
					local rows = math.max(1, math.min(cnt, per))
					if d.groupOrient == "V" then
						local prow = math.min(pets[i], per)
						y = y - rows * (fh + d.yGap) - th - d.yGap * 2 - (prow > 0 and (prow * (ph + d.yGap) + d.yGap + 2) or 0)
					else
						x = x + cols * (d.width + d.xGap) + d.xGap * 2
					end
				elseif i <= 3 then
					-- bloc vide : affiché (rien à dessiner) pour accueillir un joueur
					g:ClearAllPoints()
					g:SetPoint("TOPLEFT", P.anchors.main, "TOPLEFT", x, y)
					g:Show()
				else
					g:Hide()
				end
				local t = P.titles[i]
				if d.groupTitles and i <= 3 and cnt > 0 then t:Show() else t:Hide() end
			end
			P.anchors.main:SetScale(P:EffScale())
			P.headers.main:Hide()
			P:ApplyPets()
			return
		end
		local k = 0
		-- disposition empilée : chaque groupe laisse la place de ses familiers en dessous
		local pets = P:PetCounts()
		local _, ph = P:PetSize()
		local extra = 0
		local function placeGroup(i)
			local g = P.groups[i]
			local x, y = P:GroupOrigin(k)
			if d.groupOrient == "V" then y = y - extra end
			g:ClearAllPoints()
			g:SetPoint("TOPLEFT", P.anchors.main, "TOPLEFT", x, y)
			g:Show()
			k = k + 1
			if pets[i] > 0 then extra = extra + pets[i] * (ph + d.yGap) + d.yGap + 2 end
		end
		if useGroups then
			for i = 1, 8 do
				if counts[i] > 0 or not d.groupCompact then placeGroup(i) end
			end
			if d.groupCompact then
				for i = 1, 8 do if counts[i] == 0 then placeGroup(i) end end
			end
		else
			for i = 1, 8 do P.groups[i]:Hide() end
		end
		for i = 1, 8 do
			local t = P.titles[i]
			if useGroups and d.groupTitles and counts[i] > 0 then t:Show() else t:Hide() end
		end
		P.anchors.main:SetScale(P:EffScale())
		local m = P.headers.main
		m:ClearAllPoints()
		m:SetPoint("TOPLEFT", P.anchors.main, "TOPLEFT", d.padX, -d.padY)
		if useGroups or (VP.Preview and VP.Preview.shown) then m:Hide() else m:Show() end
		P:ApplyPets()
	end)
end

function P:ApplyPositions()
	-- les ancres portent des cadres sécurisés : interdit de les déplacer en combat
	VP:RunOOC("positions", function()
		for key, a in pairs(P.anchors) do
			local p = posOf(key)
			a:ClearAllPoints()
			a:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
			VP:Unplace(a)
		end
	end)
end

function P:ApplyLayout()
	VP:RunOOC("layout", function()
		local db = VP.db
		local fh = VP.Frames:FrameHeight()
		local petSide = db.pets.enabled and db.pets.mode == "SIDE"
		-- cadres de soin coupés (un DPS qui ne garde que les fenêtres d'information) : toutes les ancres cachées
		local framesOn = db.showFrames ~= false
		for key, a in pairs(P.anchors) do
			a:SetScale((key == "main" or (key == "pets" and petSide)) and P:EffScale() or db.scale)
			if db.locked or (key == "pets" and petSide) then a.handle:Hide() else a.handle:Show() end
			if key == "main" then
				if framesOn then a:Show() else a:Hide() end
			else
				if framesOn and db.panels[key].enabled then a:Show() else a:Hide() end
			end
		end
		local function gaps(h)
			h:SetAttribute("yOffset", -db.yGap)
			h:SetAttribute("columnSpacing", db.xGap)
		end
		for key, h in pairs(P.headers) do
			gaps(h)
			P:SizeHeader(h)
			if key == "main" or key == "pets" then
				h:SetAttribute("unitsPerColumn", db.perColumn)
				-- assez de colonnes pour 40 joueurs, quel que soit le nombre de joueurs par colonne
				h:SetAttribute("maxColumns", math.ceil(40 / math.max(1, db.perColumn)))
			end
		end
		for i = 1, 8 do
			gaps(P.groups[i])
			P:SizeHeader(P.groups[i])
			if not P:UseRoles() and not P:UseGrid() then P.groups[i]:SetAttribute("showSolo", i == 1 and db.showSolo) end
			local t = P.titles[i]
			t:ClearAllPoints()
			t:SetPoint("BOTTOMLEFT", P.groups[i], "TOPLEFT", 0, 2)
			t:SetWidth(db.width)
		end
		P.headers.main:SetAttribute("showSolo", db.showSolo)
		P:ApplySort()
		P:ApplyRoleHeaders()
		-- les cadres en option désactivés ne prennent pas de place
		local row = 0
		for _, b in ipairs(P.targetButtons) do
			local on = not b.vpOpt or db.panels.target[b.vpOpt]
			if b.vpOpt and on ~= b.vpWatched then
				b.vpWatched = on
				if on then RegisterUnitWatch(b) else UnregisterUnitWatch(b); b:Hide() end
			end
			if on then
				b:ClearAllPoints()
				b:SetPoint("TOPLEFT", P.anchors.target, "TOPLEFT", 0, -row * (fh + db.yGap))
				row = row + 1
			end
		end
		for _, b in ipairs(VP.Frames.buttons) do
			VP.Frames:SizeButton(b)   -- familiers : leur propre taille
		end
		P.gcd:SetWidth(db.width)
		local gc = db.colors.gcd
		P.gcd:SetStatusBarColor(gc[1], gc[2], gc[3])
	end)
	self:LayoutGroups()
	if VP.Preview then VP.Preview:Refresh() end
end

-- Fond du panneau : entoure tous les cadres visibles (avec la marge X/Y)
function P:UpdateBackground()
	local d = VP.db
	local bg = self.bg
	if not d.panelBg then bg:Hide() return end
	local list
	if VP.Preview and VP.Preview.shown then list = VP.Preview.buttons else list = VP.Frames.buttons end
	local l, r, t, b
	for _, f in ipairs(list) do
		local kind = not f.vpPreview and VP.Frames:Kind(f)
		if f:IsVisible() and (f.vpPreview or kind == "main" or (kind == "pets" and (d.pets.mode == "ATTACH" or d.pets.mode == "SIDE"))) then
			local fl, fr, ft, fb = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
			if fl then
				l = l and math.min(l, fl) or fl
				r = r and math.max(r, fr) or fr
				t = t and math.max(t, ft) or ft
				b = b and math.min(b, fb) or fb
			end
		end
	end
	if not l then bg:Hide() return end
	local th = (d.groupTitles and not self:UseGrid() and (self:UseGroups() or (VP.Preview and VP.Preview.shown))) and TITLE_H or 0
	bg:ClearAllPoints()
	bg:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l - d.padX, t + d.padY + th)
	bg:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", r + d.padX, b - d.padY)
	bg:SetBackdropColor(0.04, 0.04, 0.05, d.panelBgAlpha)
	bg:Show()
end

function P:Refresh()
	self:ApplyPositions()
	self:ApplyLayout()
	self:ApplyMyTanks()
	self:ApplySpotlight()
	self:ApplyBlizzard()
	self:UpdateMinimap()
end

-- Masquer les cadres de groupe Blizzard
-- Hors combat, Blizzard réaffiche ses cadres à chaque changement du groupe (PartyMemberFrame_UpdateMember
-- appelle Show) : le pilote d'état seul ne suffisait pas. On les recache juste après (jamais en combat).
local function wantBlizzHidden() return VP.db and VP.db.hideBlizzParty and VP.db.showFrames ~= false end
if PartyMemberFrame_UpdateMember then
	hooksecurefunc("PartyMemberFrame_UpdateMember", function(self)
		if wantBlizzHidden() and not InCombatLockdown() and self and self:IsShown() then self:Hide() end
	end)
end
function P:ApplyBlizzard()
	VP:RunOOC("blizz", function()
		for i = 1, 4 do
			local f = _G["PartyMemberFrame" .. i]
			if f then
				-- cadres de soin coupés : on rend les cadres de groupe Blizzard
				if VP.db.hideBlizzParty and VP.db.showFrames ~= false then
					RegisterStateDriver(f, "visibility", "hide")
					P.blizzHidden = true
				elseif P.blizzHidden then
					UnregisterStateDriver(f, "visibility")
					-- le pilote ne réaffiche pas le cadre : on le fait si le membre existe
					if UnitExists("party" .. i) then f:Show() end
				end
			end
		end
	end)
end

-- Bouton de la minicarte
function P:UpdateMinimap()
	local mb = self.minimap
	if not mb then return end
	if VP.db.minimap then mb:Show() else mb:Hide() end
	local a = math.rad(VP.db.minimapAngle or 210)
	mb:ClearAllPoints()
	mb:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(a), 80 * math.sin(a))
end

local function createMinimap()
	local mb = CreateFrame("Button", "VuhPlusMinimapButton", Minimap)
	mb:SetWidth(31); mb:SetHeight(31)
	mb:SetFrameStrata("MEDIUM")
	mb:SetFrameLevel(8)
	mb:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local ic = mb:CreateTexture(nil, "BACKGROUND")
	ic:SetTexture("Interface\\Icons\\Spell_Holy_FlashHeal")
	ic:SetWidth(20); ic:SetHeight(20)
	ic:SetPoint("TOPLEFT", mb, "TOPLEFT", 7, -5)
	local border = mb:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetWidth(53); border:SetHeight(53)
	border:SetPoint("TOPLEFT", mb, "TOPLEFT", 0, 0)
	mb:RegisterForClicks("AnyUp")
	mb:RegisterForDrag("LeftButton")
	mb:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			VP.db.locked = not VP.db.locked
			VP:RefreshAll()
			VP:Print(VP.db.locked and "Cadres verrouillés." or "Cadres déverrouillés.")
			if VP.UI and VP.UI.footRefresh then VP.UI.footRefresh() end
		else
			VP.Options:Open()
		end
	end)
	mb:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local s = Minimap:GetEffectiveScale()
			VP.db.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
			P:UpdateMinimap()
		end)
	end)
	mb:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	mb:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("VuhPlus " .. VP.version)
		GameTooltip:AddLine("par BellaHealFr", 0.6, 0.6, 0.65)
		GameTooltip:AddLine("Clic gauche : options", 1, 1, 1)
		GameTooltip:AddLine("Clic droit : verrouiller / déverrouiller", 1, 1, 1)
		GameTooltip:AddLine("Glisser : déplacer ce bouton", 1, 1, 1)
		GameTooltip:Show()
	end)
	mb:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return mb
end

function P:OnLogin()
	local db = VP.db

	-- Raid / groupe : en-tête unique (tri classe / nom)
	local a = self:MakeAnchor("main", "VuhPlus - Raid")
	local h = header("main", a, "SecureGroupHeaderTemplate")
	h:SetAttribute("showRaid", true)
	h:SetAttribute("showParty", true)
	h:SetAttribute("showPlayer", true)
	h:SetAttribute("showSolo", db.showSolo)
	h:SetAttribute("maxColumns", 8)
	h:SetAttribute("unitsPerColumn", db.perColumn)
	self:ApplySort()

	-- Fond du panneau (derrière les cadres)
	local bg = CreateFrame("Frame", "VuhPlusPanelBackground", a)
	bg:SetFrameStrata("BACKGROUND")
	VP.Theme:Backdrop(bg, { 0.04, 0.04, 0.05, 0.55 }, { 0, 0, 0, 0.9 })
	bg:Hide()
	self.bg = bg

	-- Tri par groupe : un en-tête par groupe + titre
	self.groups, self.titles = {}, {}
	for i = 1, 8 do
		local g = CreateFrame("Frame", "VuhPlusGroup" .. i, a, "SecureGroupHeaderTemplate")
		g.vpKind = "main"
		g:SetAttribute("template", "VuhPlusUnitTemplate")
		g:SetAttribute("templateType", "Button")
		g:SetAttribute("point", "TOP")
		g:SetAttribute("toggleForVehicle", true)
		g:SetAttribute("groupFilter", tostring(i))
		g:SetAttribute("showRaid", true)
		-- en groupe (hors raid), seul le groupe 1 affiche le groupe
		g:SetAttribute("showParty", i == 1)
		g:SetAttribute("showPlayer", i == 1)
		g:SetAttribute("showSolo", i == 1 and db.showSolo)
		g:SetAttribute("sortMethod", "INDEX")
		self:SizeHeader(g)
		VP.Clicks:RegisterTarget(g)
		self.groups[i] = g
		local t = VP.Theme:Text(a, 11, VP.Theme.C.muted)
		t:SetJustifyH("CENTER")
		t:SetText("Groupe " .. i)
		t:Hide()
		self.titles[i] = t
	end

	-- Tanks principaux du raid (désignés par le chef)
	a = self:MakeAnchor("tanks", "Tanks principaux")
	local ht = header("tanks", a, "SecureGroupHeaderTemplate")
	ht:SetAttribute("showRaid", true)
	ht:SetAttribute("groupFilter", "MAINTANK,MAINASSIST")
	ht:SetAttribute("unitsPerColumn", 10)

	-- Mes tanks (liste personnelle)
	a = self:MakeAnchor("mytanks", "Mes tanks")
	local hm = header("mytanks", a, "SecureGroupHeaderTemplate")
	hm:SetAttribute("showRaid", true)
	hm:SetAttribute("showParty", true)
	hm:SetAttribute("showPlayer", true)
	hm:SetAttribute("showSolo", true)
	hm:SetAttribute("unitsPerColumn", 10)

	-- Projecteur (joueurs choisis + cibles assignées)
	a = self:MakeAnchor("spotlight", "Projecteur")
	local hs = header("spotlight", a, "SecureGroupHeaderTemplate")
	hs:SetAttribute("showRaid", true)
	hs:SetAttribute("showParty", true)
	hs:SetAttribute("showPlayer", true)
	hs:SetAttribute("showSolo", true)
	hs:SetAttribute("unitsPerColumn", 5)
	hs:SetAttribute("maxColumns", 2)
	hs:SetAttribute("nameList", "VuhPlusPersonne")

	-- Familiers
	a = self:MakeAnchor("pets", "Familiers")
	local hp = header("pets", a, "SecureGroupPetHeaderTemplate")
	hp:SetAttribute("showRaid", true)
	hp:SetAttribute("showParty", true)
	hp:SetAttribute("showPlayer", true)
	hp:SetAttribute("showSolo", true)
	hp:SetAttribute("maxColumns", 8)
	hp:SetAttribute("unitsPerColumn", db.perColumn)
	hp:SetAttribute("filterOnPet", false)   -- la liste de noms filtre sur le MAÎTRE

	-- Familiers sous leur maître : un en-tête par groupe / bloc, plus un sous le raid (tri classe / nom)
	self.petGroups = {}
	self.allPetHeaders = { hp }
	local function petHeader(name)
		local ph = CreateFrame("Frame", name, self.anchors.main, "SecureGroupPetHeaderTemplate")
		ph.vpKind = "pets"
		ph:SetAttribute("template", "VuhPlusUnitTemplate")
		ph:SetAttribute("templateType", "Button")
		ph:SetAttribute("point", "TOP")
		ph:SetAttribute("columnAnchorPoint", "LEFT")
		ph:SetAttribute("showRaid", true)
		ph:SetAttribute("filterOnPet", false)   -- les listes de noms filtrent sur le MAÎTRE
		ph:SetAttribute("useOwnerUnit", false)
		ph:SetAttribute("sortMethod", "INDEX")
		self:SizeHeader(ph)
		VP.Clicks:RegisterTarget(ph)
		self.allPetHeaders[#self.allPetHeaders + 1] = ph
		return ph
	end
	for i = 1, 8 do self.petGroups[i] = petHeader("VuhPlusPetGroup" .. i) end
	self.petMain = petHeader("VuhPlusPetMain")
	self.petMain:SetAttribute("showParty", true)
	self.petMain:SetAttribute("showPlayer", true)

	-- Cible / cible de la cible / focalisation
	a = self:MakeAnchor("target", "Cible / Focus")
	self.targetButtons = {}
	for i, u in ipairs({ "target", "targettarget", "focus", "boss1target", "focustarget" }) do
		local b = CreateFrame("Button", "VuhPlusUnit_" .. u, a, "VuhPlusUnitTemplate")
		b.vpKind = "target"
		b:SetAttribute("unit", u)
		-- cadres en option : « Cible du boss » (le joueur que le boss frappe) et « Cible de la focalisation »
		if u == "boss1target" then b.vpOpt = "boss" elseif u == "focustarget" then b.vpOpt = "focusTarget" end
		if not b.vpOpt then RegisterUnitWatch(b) end
		table.insert(self.targetButtons, b)
	end

	-- Barre de temps de recharge global
	local gcd = CreateFrame("StatusBar", "VuhPlusGCDBar", self.anchors.main)
	gcd:SetStatusBarTexture(VP.Theme.TEX)

	gcd:SetMinMaxValues(0, 1)
	gcd:SetHeight(2)
	gcd:SetPoint("BOTTOMLEFT", self.anchors.main, "TOPLEFT", 0, 1)
	local gbg = gcd:CreateTexture(nil, "BACKGROUND")
	gbg:SetAllPoints(gcd); gbg:SetTexture(0, 0, 0, 0.6)
	gcd:Hide()
	self.gcd = gcd
	local ref = GCD_REF[VP.class] and GetSpellInfo(GCD_REF[VP.class])
	local gf = CreateFrame("Frame")
	gf:SetScript("OnUpdate", function()
		if not VP.db.gcdBar or not ref then gcd:Hide() return end
		local start, dur = GetSpellCooldown(ref)
		if start and dur and dur > 0 and dur <= 1.6 then
			gcd:SetValue((GetTime() - start) / dur)
			gcd:Show()
		else
			gcd:Hide()
		end
	end)

	self.minimap = createMinimap()

	self:ApplyPositions()
	for key, hh in pairs(self.headers) do
		if key ~= "mytanks" and key ~= "main" and key ~= "pets" and key ~= "spotlight" then hh:Show() end
	end
	local function relayout()
		VP:RunOOC("sizeAll", function() VP.Frames:SizeAll() end)
		if P:UseRoles() or P:UseGrid() then
			VP:RunOOC("roles", function() P:ApplyRoleHeaders(); P:LayoutGroups() end)
		else
			P:LayoutGroups()
		end
	end
	-- tri par rôle : on revérifie les rôles toutes les 5 s hors combat (forme d'ours, présence de givre,
	-- spé changée...) et on ne replace les blocs que si leur contenu a changé
	local roleAcc, lastSig = 0, nil
	local rf = CreateFrame("Frame")
	rf:SetScript("OnUpdate", function(_, e)
		roleAcc = roleAcc + e
		if roleAcc < 5 then return end
		roleAcc = 0
		if not (P:UseRoles() or P:UseGrid()) or InCombatLockdown() then lastSig = nil return end
		P:BuildRoleLists()
		local sig = table.concat(P.roleLists[1], ",") .. "|" .. table.concat(P.roleLists[2], ",") .. "|" .. table.concat(P.roleLists[3], ",")
		if sig ~= lastSig then
			lastSig = sig
			P:ApplyRoleHeaders()
			P:LayoutGroups()
		end
	end)
	VP:On("RAID_ROSTER_UPDATE", relayout)
	-- familier invoqué / renvoyé : on refait la place en dessous des groupes (hors combat)
	-- (regroupé : plusieurs familiers invoqués d'un coup = une seule mise en page)
	local petDirty = false
	VP:On("UNIT_PET", function()
		if P:PetsOn() and VP.db.pets.mode == "ATTACH" then petDirty = true end
	end)
	local pf, pacc, lastPetSig = CreateFrame("Frame"), 0, nil
	pf:SetScript("OnUpdate", function(_, e)
		if not petDirty then return end
		pacc = pacc + e
		if pacc < 0.3 then return end
		pacc = 0
		petDirty = false
		local sig = table.concat(P:PetCounts(), ",")
		if sig ~= lastPetSig then lastPetSig = sig; P:LayoutGroups() end
	end)
	VP:On("PARTY_MEMBERS_CHANGED", relayout)
	VP:On("PLAYER_ENTERING_WORLD", function()
		-- le client replace les cadres mémorisés après PLAYER_LOGIN : on remet nos positions
		P:ApplyPositions()
		relayout()
	end)
	local acc = 0
	local bgf = CreateFrame("Frame")
	bgf:SetScript("OnUpdate", function(_, e)
		acc = acc + e
		if acc < 0.3 then return end
		acc = 0
		P:UpdateBackground()
	end)
	self:ApplyLayout()
	self:ApplyMyTanks()
	self:ApplySpotlight()
	self:ApplyBlizzard()
	self:UpdateMinimap()
	VP.Clicks:Apply()
end
