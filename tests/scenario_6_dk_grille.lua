-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- Scénario 6 : chevalier de la mort qui passe de tank à DPS (et l'inverse), forme de la grille par rôle
local me = SIM_UNIT({ name = "Bella", class = "PRIEST", talents = { 10, 51, 0 } })
W.spellbook["Soins inférieurs"] = true
BOOT(me, nil)
local dk = SIM_UNIT({ name = "Mortis", class = "DEATHKNIGHT", ptype = 6 })
local mage = SIM_UNIT({ name = "Givre", class = "MAGE" })
SIM_SETRAID({ me, dk, mage })
BUFF(dk, 48263)   -- Présence de givre
VuhPlusDB.sortMode = "ROLE"
SIM_FIRE("RAID_ROSTER_UPDATE")
SIM_RUN(6)
local R, P = VuhPlus.Roles, VuhPlus.Panels
local function block() -- 1 = Tanks, 2 = Soigneurs, 3 = DPS
	for i = 1, 3 do if inList(P.groups[i]:GetAttribute("nameList"), "Mortis") then return i end end
end
CHECK("DK en présence de givre : bloc Tanks", R:GetRole("raid2") == "TANK" and block() == 1, block())

-- 1. changement de spé hors combat, puis présence de sang : DPS tout de suite
SIM_FIRE("UNIT_SPELLCAST_SUCCEEDED", "raid2", "Activation de la spécialisation secondaire")
SIM_RUN(1)
UNBUFF(dk, 48263); BUFF(dk, 48266); SIM_FIRE("UNIT_AURA", "raid2")
SIM_RUN(6)
CHECK("spé changée puis présence de sang hors combat : bloc DPS", R:GetRole("raid2") == "DAMAGER" and block() == 3, block())

-- 2. sans changement de spé, retour en présence de givre hors combat : tank tout de suite
UNBUFF(dk, 48266); BUFF(dk, 48263); SIM_FIRE("UNIT_AURA", "raid2")
SIM_RUN(6)
CHECK("présence de givre reprise hors combat : bloc Tanks", R:GetRole("raid2") == "TANK" and block() == 1, block())

-- 3. en combat, présence impie 10 s (vitesse) : reste tank
SIM_COMBAT(true)
UNBUFF(dk, 48263); BUFF(dk, 48265); SIM_FIRE("UNIT_AURA", "raid2")
SIM_RUN(10)
UNBUFF(dk, 48265); BUFF(dk, 48263); SIM_FIRE("UNIT_AURA", "raid2")
SIM_RUN(2)
CHECK("présence impie 10 s en combat : reste tank", R:GetRole("raid2") == "TANK", R:GetRole("raid2"))
SIM_COMBAT(false); SIM_RUN(6)

-- 4. mort : plus de présence lisible, le rôle reste
UNBUFF(dk, 48263); dk.dead = true; SIM_FIRE("UNIT_AURA", "raid2"); SIM_RUN(6)
CHECK("DK mort sans présence : reste tank", R:GetRole("raid2") == "TANK" and block() == 1, block())
dk.dead = false; BUFF(dk, 48263)

-- 5. grille par rôle : colonnes pleines (5 par colonne), seule la dernière reçoit le reste
VuhPlusDB.sortMode = "ROLEGRID"
VuhPlusDB.perColumn = 5
local function raidOf(n)
	local list = { me }
	for i = 2, n do list[i] = SIM_UNIT({ name = "Joueur" .. string.format("%02d", i), class = "MAGE", subgroup = math.ceil(i / 5) }) end
	SIM_SETRAID(list)
	SIM_FIRE("RAID_ROSTER_UPDATE")
	SIM_RUN(6)
end
-- place réelle de chaque morceau de la grille (le faux client ne retient pas les points d'ancrage)
local at = {}
for i = 1, 8 do
	local g = P.groups[i]
	g.SetPoint = function(_, _, _, _, x, y) at[i] = { x, y } end
end
-- hauteur de chaque colonne : un morceau de k joueurs, rempli vers la droite, occupe k colonnes de sa ligne
local function columns()
	local d = VuhPlusDB
	local h, placed = {}, 0
	for i = 1, 8 do
		if P.groups[i]:IsShown() and at[i] then
			local col = math.floor((at[i][1] - d.padX) / (d.width + d.xGap) + 0.5)
			for _ in string.gmatch(P.groups[i]:GetAttribute("nameList") or "", "[^,]+") do
				h[col + 1] = (h[col + 1] or 0) + 1
				col, placed = col + 1, placed + 1
			end
		end
	end
	return table.concat(h, "/"), placed
end
for _, case in ipairs({ { 10, "5/5" }, { 11, "5/5/1" }, { 25, "5/5/5/5/5" }, { 26, "5/5/5/5/5/1" }, { 23, "5/5/5/5/3" }, { 40, "5/5/5/5/5/5/5/5" } }) do
	raidOf(case[1])
	local shape, placed = columns()
	CHECK("grille à " .. case[1] .. " joueurs : colonnes " .. case[2], shape == case[2] and placed == case[1] and P.gridRows == 5,
		shape .. ", " .. placed .. " placés, " .. tostring(P.gridRows) .. " lignes")
end

-- 6. raid 25 rejoint par un 26e puis un 27e joueur, avec des rôles mélangés (2 tanks, 6 soigneurs, DPS) :
-- plus de lignes coupées par un changement de rôle, la grille doit tenir dans les 8 en-têtes
local function mixedRaid(n)
	raidOf(n)
	VuhPlusDB.roleOverride = {}
	for i = 2, n do
		local nm = string.lower(W.raid[i].name)
		if i <= 3 then VuhPlusDB.roleOverride[nm] = "TANK" elseif i <= 8 then VuhPlusDB.roleOverride[nm] = "HEALER" end
	end
	P:RolesChanged(); SIM_RUN(6)
end
for _, case in ipairs({ { 25, "5/5/5/5/5" }, { 26, "5/5/5/5/5/1" }, { 27, "5/5/5/5/5/2" } }) do
	mixedRaid(case[1])
	local shape, placed = columns()
	local segs = 0
	for i = 1, 8 do if P.groups[i]:IsShown() then segs = segs + 1 end end
	CHECK("grille, rôles mélangés, " .. case[1] .. " joueurs : colonnes " .. case[2], shape == case[2] and placed == case[1],
		shape .. ", " .. placed .. " placés, " .. segs .. " morceaux")
	-- tanks sur la 1re ligne
	local top = true
	for i = 1, 8 do
		local nl = P.groups[i]:GetAttribute("nameList") or ""
		if P.groups[i]:IsShown() and (inList(nl, "Joueur02") or inList(nl, "Joueur03")) and at[i][2] ~= -VuhPlusDB.padY then top = false end
	end
	CHECK("grille, " .. case[1] .. " joueurs : tanks sur la ligne du haut", top)
end

-- 7. même raid de 27 dans les autres tris : aucun joueur perdu
VuhPlusDB.sortMode = "ROLE"
P:ApplyRoleHeaders(); P:LayoutGroups(); SIM_RUN(6)
local nRole = 0
for i = 1, 3 do for _ in string.gmatch(P.groups[i]:GetAttribute("nameList") or "", "[^,]+") do nRole = nRole + 1 end end
CHECK("tri par rôle en blocs, 27 joueurs : 27 placés (2 tanks, 6 soigneurs, 19 DPS)",
	nRole == 27 and #P.roleLists[1] == 2 and #P.roleLists[2] == 6 and #P.roleLists[3] == 19,
	nRole .. " : " .. #P.roleLists[1] .. "/" .. #P.roleLists[2] .. "/" .. #P.roleLists[3])
VuhPlusDB.sortMode = "GROUP"
P:ApplyRoleHeaders(); P:LayoutGroups(); SIM_RUN(6)
local c = P:GroupCounts()
CHECK("tri par groupe, 27 joueurs : groupes 5/5/5/5/5/2", table.concat(c, "/", 1, 6) == "5/5/5/5/5/2" and P.groups[6]:IsShown(),
	table.concat(c, "/"))
CHECK("raid de 27 : échelle « raid 40 » appliquée (plus de 25 joueurs)", P:EffScale() == (VuhPlusDB.autoScale and VuhPlusDB.scale40 or VuhPlusDB.scale))

FINISH("Scénario 6 : DK tank / DPS et grille par rôle")
