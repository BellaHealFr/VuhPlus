-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Conseil de soin de zone
-- Le client 3.3.5 donne la position de chaque joueur sur la carte, mais pas la taille de la carte en mètres.
-- L'addon APPREND cette échelle en jeu, en comparant la distance sur la carte avec des distances connues :
--   * portée de votre sort de soin (40 m) : à portée ou non ;
--   * distance de « duel » (~10 m) et de « suivre » (~28 m) : CheckInteractDistance.
-- Chaque mesure encadre l'échelle (au-dessus / en dessous) ; une fois l'encadrement assez serré, on calcule
-- les vrais groupes de joueurs proches (comme les « clusters » de VuhDo) :
--   * Cercle de soins (prêtre) et Croissance sauvage (druide) : blessés à 15 m de la cible, 5 au plus ;
--   * Salve de guérison (chaman) : cible blessée + blessés à 12,5 m (3 rebonds).
-- Sans échelle fiable (début de soirée, instance sans carte, carte du monde ouverte) : ancienne méthode,
-- le groupe de raid le plus touché. Prière de soins (prêtre sans Cercle de soins) : groupe de raid.
local VP = VuhPlus
local A = VP:NewModule("AoE")
A.hits = {}
A.method = nil   -- "map" (distances réelles) ou "group" (par groupe de raid), pour l'affichage

local SPELLS = {
	PRIEST = { group = 596, target = 34861, radius = 15, cap = 5 },        -- Prière de soins, Cercle de soins
	SHAMAN = { target = 1064, radius = 12.5, cap = 4, needInjured = true }, -- Salve de guérison (cible + 3 rebonds)
	DRUID  = { target = 48438, radius = 15, cap = 5 },                      -- Croissance sauvage
}
local HEAL_RANGE = 40           -- portée des sorts de soin (Frames.rangeSpell)
local DUEL_YARDS, FOLLOW_YARDS = 9.9, 28
local MAX_RATIO = 1.35          -- encadrement « assez serré » : borne haute / borne basse (± 15 %)

local function known(id)
	local n = id and GetSpellInfo(id)
	return n and GetSpellInfo(n) and n or nil
end

function A:IsHit(unit)
	local g = UnitGUID(unit)
	return g and self.hits[g] or false
end

-- Échelle de la carte : mètres par unité de carte (hauteur de carte ; largeur ramenée par le rapport 1,5)
local lower, upper, mapKey = nil, nil, nil
local function resetScale() lower, upper = nil, nil end
local function learn(md, inside, yards)
	if md < 0.00005 then return end
	local k = yards / md
	if inside then
		if not upper or k < upper then upper = k end
	else
		if not lower or k > lower then lower = k end
	end
	-- mesures contradictoires (étage différent, carte changée sans prévenir) : on recommence
	if lower and upper and lower > upper * 1.05 then resetScale() end
end
function A:Scale()
	if lower and upper and upper / lower <= MAX_RATIO then return (lower + upper) / 2 end
	return nil
end
-- (diagnostic) encadrement actuel
function A:ScaleBounds() return lower, upper end

local function mapDist(x1, y1, x2, y2)
	local dx, dy = (x1 - x2) * 1.5, y1 - y2
	return math.sqrt(dx * dx + dy * dy)
end

-- Positions du groupe sur la carte en cours (nil si la carte n'est pas utilisable)
local units, posX, posY, nUnits = {}, {}, {}, 0
local function readPositions()
	nUnits = 0
	if WorldMapFrame and WorldMapFrame:IsShown() then return false end   -- carte d'une autre zone peut-être
	local key = (GetCurrentMapAreaID and GetCurrentMapAreaID() or 0) .. ":" .. (GetCurrentMapDungeonLevel and GetCurrentMapDungeonLevel() or 0)
	if key ~= mapKey then mapKey = key; resetScale() end
	local px, py = GetPlayerMapPosition("player")
	if not px or (px == 0 and py == 0) then
		-- la carte est restée sur une autre zone (carte du monde consultée puis fermée) : on la remet
		-- sur la zone actuelle (sinon, sans joueur loin pour la flèche, rien ne la remettait)
		if VP.Frames and VP.Frames.FixMap then VP.Frames:FixMap() end
		return false
	end
	local function add(u)
		if UnitExists(u) and UnitIsConnected(u) then
			local x, y = GetPlayerMapPosition(u)
			if x and not (x == 0 and y == 0) then
				nUnits = nUnits + 1
				units[nUnits], posX[nUnits], posY[nUnits] = u, x, y
			end
		end
	end
	local n = GetNumRaidMembers()
	if n > 0 then
		for i = 1, n do add("raid" .. i) end
	else
		add("player")
		for i = 1, GetNumPartyMembers() do add("party" .. i) end
	end
	return true, px, py
end

-- Apprentissage de l'échelle (aussi hors combat : elle est prête quand le combat commence)
local function calibrate(px, py)
	local spell = VP.Frames and VP.Frames.rangeSpell
	for i = 1, nUnits do
		local u = units[i]
		if not UnitIsUnit(u, "player") and not UnitIsDeadOrGhost(u) then
			local md = mapDist(px, py, posX[i], posY[i])
			if spell then
				local r = IsSpellInRange(spell, u)
				if r == 1 then learn(md, true, HEAL_RANGE) elseif r == 0 then learn(md, false, HEAL_RANGE) end
			end
			learn(md, CheckInteractDistance(u, 3) and true or false, DUEL_YARDS)
			learn(md, CheckInteractDistance(u, 4) and true or false, FOLLOW_YARDS)
		end
	end
end

local groups = {}
local pool, poolN = {}, 0
local function entry(unit, pct)
	poolN = poolN + 1
	local e = pool[poolN]
	if not e then e = {}; pool[poolN] = e end
	e.unit, e.pct = unit, pct
	return e
end

local function injuredPct(u, db)
	if not UnitIsConnected(u) or UnitIsDeadOrGhost(u) then return nil end
	local m = UnitHealthMax(u)
	local pct = m > 0 and UnitHealth(u) / m or 1
	if pct * 100 <= db.pct then return pct end
	return nil
end

local function inRange(u) return UnitIsUnit(u, "player") or UnitInRange(u) end

-- Méthode « par groupe de raid » (sans distances)
function A:ComputeGroups(db, groupSpell)
	for k in pairs(groups) do wipe(groups[k]) end
	local function add(unit, sub)
		if UnitExists(unit) and inRange(unit) then
			local pct = injuredPct(unit, db)
			if pct then
				groups[sub] = groups[sub] or {}
				table.insert(groups[sub], entry(unit, pct))
			end
		end
	end
	local n = GetNumRaidMembers()
	if n > 0 then
		for i = 1, n do
			local _, _, sub = GetRaidRosterInfo(i)
			add("raid" .. i, sub or 1)
		end
	else
		add("player", 1)
		for i = 1, GetNumPartyMembers() do add("party" .. i, 1) end
	end
	local best, bestCount, bestDeficit
	for sub, list in pairs(groups) do
		local c, d = #list, 0
		for _, e in ipairs(list) do d = d + (1 - e.pct) end
		if c >= db.count and (not best or c > bestCount or (c == bestCount and d > bestDeficit)) then
			best, bestCount, bestDeficit = sub, c, d
		end
	end
	if not best then return end
	if groupSpell then
		-- tout le groupe : Prière de soins
		for _, e in ipairs(groups[best]) do
			local g = UnitGUID(e.unit)
			if g then self.hits[g] = true end
		end
	else
		-- la cible la plus blessée du groupe le plus touché
		local low
		for _, e in ipairs(groups[best]) do
			if not low or e.pct < low.pct then low = e end
		end
		local g = low and UnitGUID(low.unit)
		if g then self.hits[g] = true end
	end
end

-- Méthode « distances réelles » : meilleure cible = celle qui a le plus de vie manquante soignable autour
local deficits, near = {}, {}
local function desc(a, b) return a > b end   -- une seule fonction de tri (pas une nouvelle à chaque cible)
function A:ComputeClusters(db, cfg, k)
	local R = cfg.radius / k   -- rayon en unités de carte
	for i = 1, nUnits do deficits[i] = injuredPct(units[i], db) end
	local bestI, bestScore, bestCount
	for c = 1, nUnits do
		local cu = units[c]
		if inRange(cu) and not UnitIsDeadOrGhost(cu) and (not cfg.needInjured or deficits[c]) then
			-- blessés à portée du sort autour de la cible
			local m = 0
			for j = 1, nUnits do
				if deficits[j] and mapDist(posX[c], posY[c], posX[j], posY[j]) <= R then
					m = m + 1
					near[m] = 1 - deficits[j]
				end
			end
			if m >= db.count then
				-- le sort ne soigne que « cap » joueurs : on garde les plus blessés
				for x = m + 1, #near do near[x] = nil end
				table.sort(near, desc)
				local score, cnt = 0, math.min(m, cfg.cap)
				for x = 1, cnt do score = score + near[x] end
				if not bestScore or score > bestScore then bestI, bestScore, bestCount = c, score, cnt end
			end
		end
	end
	if bestI then
		local g = UnitGUID(units[bestI])
		if g then self.hits[g] = true end
	end
end

function A:Compute()
	poolN = 0
	wipe(self.hits)
	local db = VP.db.aoe
	local cfg = SPELLS[VP.class]
	if not db.enabled or not cfg then self.method = nil return end
	local groupSpell, targetSpell = known(cfg.group), known(cfg.target)
	if not groupSpell and not targetSpell then self.method = nil return end
	local ok, px, py = readPositions()
	if ok then calibrate(px, py) end
	local k = ok and self:Scale()
	self.method = (k and targetSpell) and "map" or "group"
	if not UnitAffectingCombat("player") then return end
	if k and targetSpell then
		self:ComputeClusters(db, cfg, k)
	else
		self:ComputeGroups(db, groupSpell)
	end
end

function A:OnLogin()
	-- nouvelle zone : l'échelle est à réapprendre (un changement d'étage est vu par la clé de carte)
	for _, ev in ipairs({ "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
		VP:On(ev, function() mapKey = nil; resetScale() end)
	end
	local acc = 0
	local f = CreateFrame("Frame")
	f:SetScript("OnUpdate", function(_, e)
		acc = acc + e
		if acc < 0.5 then return end
		acc = 0
		A:Compute()
	end)
end
