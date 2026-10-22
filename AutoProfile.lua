-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Changement automatique de profil selon la spé (double spé) et la taille du groupe
-- (comme Cell : disposition par spé ; Danders Frames : profils par taille de raid).
-- Règle : le profil de la TAILLE du groupe s'il est choisi, sinon celui de la SPÉ.
-- Le profil n'est rechargé que si le profil voulu change : un profil chargé à la main reste en place
-- jusqu'au prochain changement de spé ou de taille de groupe.
local VP = VuhPlus
local AP = VP:NewModule("AutoProfile")

AP.SIZES = {
	{ "party", "Seul ou groupe de 5" },
	{ "raid10", "Raid 10" },
	{ "raid25", "Raid 25" },
	{ "raid40", "Raid 40 (champ de bataille...)" },
}

function AP:DB()
	local a = VP.db.autoProfile
	if a.enabled == nil then a.enabled = false end
	for _, k in ipairs({ "spec1", "spec2", "party", "raid10", "raid25", "raid40" }) do
		if a[k] == nil then a[k] = "" end
	end
	return a
end

-- Taille du groupe : celle de l'instance de raid si on y est (un raid 25 à 18 joueurs reste un raid 25)
function AP:SizeKey()
	local n = GetNumRaidMembers()
	if n == 0 then return "party" end
	local ok, _, itype, _, _, maxP = pcall(GetInstanceInfo)
	if ok and itype == "raid" and maxP and maxP > 0 then n = maxP end
	if n <= 10 then return "raid10" elseif n <= 25 then return "raid25" end
	return "raid40"
end

function AP:Wanted()
	local a = self:DB()
	local p = a[self:SizeKey()]
	if p == "" then p = a["spec" .. VP:Spec()] or "" end
	if p ~= "" and VP.db.profiles[p] then return p end
	return nil
end

function AP:Check()
	local a = self:DB()
	if not a.enabled then return end
	local want = self:Wanted()
	if not want or want == a.last then return end
	VP:RunOOC("autoprofile", function()
		-- relu hors combat : la situation a pu changer pendant le combat
		local w = AP:Wanted()
		if w and w ~= a.last then
			a.last = w
			VP:Print("Profil automatique : « " .. w .. " ».")
			VP:LoadProfile(w)
		end
	end)
end

function AP:OnLogin()
	self:DB()
	local pending = false
	local function later() pending = true end
	for _, ev in ipairs({ "ACTIVE_TALENT_GROUP_CHANGED", "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED",
		"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
		VP:On(ev, later)
	end
	-- regroupé : RAID_ROSTER_UPDATE arrive en rafale quand un raid se forme
	local acc = 0
	local f = CreateFrame("Frame")
	f:SetScript("OnUpdate", function(_, e)
		if not pending then return end
		acc = acc + e
		if acc < 1 then return end
		acc, pending = 0, false
		AP:Check()
	end)
end
