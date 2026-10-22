-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- Outils communs aux scénarios : démarrage de l'addon, vérifications, compte rendu
local out = {}
local nOK, nKO = 0, 0
function LOG(s) out[#out + 1] = s end
function CHECK(label, cond, detail)
	if cond then nOK = nOK + 1; out[#out + 1] = "  [OK]    " .. label
	else nKO = nKO + 1; out[#out + 1] = "  [ÉCHEC] " .. label .. (detail and (" (" .. tostring(detail) .. ")") or "") end
end
function FINISH(title)
	out[#out + 1] = string.format("  %d vérification(s) réussie(s), %d échec(s), %d erreur(s) Lua", nOK, nKO, #ERRORS)
	for i = 1, math.min(#ERRORS, 10) do out[#out + 1] = "    erreur : " .. ERRORS[i] end
	if nKO > 0 or #ERRORS > 0 then out[#out + 1] = "  => ÉCHEC" end
	RESULT = "== " .. title .. " ==\n" .. table.concat(out, "\n")
end

-- Démarre l'addon comme le client : chargement des fichiers, ADDON_LOADED, PLAYER_LOGIN, entrée dans le monde
function BOOT(player, savedVars)
	W.player = player
	W.byName[player.name] = player
	VuhPlusDB = savedVars
	SIM_LOADADDON(ADDON_DIR)
	SIM_FIRE("ADDON_LOADED", "VuhPlus")
	SIM_FIRE("PLAYER_LOGIN")
	SIM_FIRE("PLAYER_ENTERING_WORLD")
	SIM_RUN(1)
end

function BUFF(u, id, extra)
	local a = { name = SPELLS[id] or ("Sort " .. id), id = id, dur = 0, exp = 0 }
	for k, v in pairs(extra or {}) do a[k] = v end
	table.insert(u.buffs, a)
	return a
end
function UNBUFF(u, id)
	for i = #u.buffs, 1, -1 do if u.buffs[i].id == id then table.remove(u.buffs, i) end end
end
function inList(list, name)
	for n in string.gmatch(list or "", "[^,]+") do if n == name then return true end end
	return false
end
