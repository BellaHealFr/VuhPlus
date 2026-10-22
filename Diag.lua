-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Diagnostic (/vp diag) : journal de ce qui arrive aux cadres de soin à la connexion
-- (créés, affichés, masqués et par qui, position, taille, erreurs Lua). Le journal est enregistré
-- dans VuhPlusDB.diag.logs, un par personnage, pour être relu dans le fichier de sauvegarde.
local VP = VuhPlus
local DG = VP:NewModule("Diag")

local MAX_LINES = 400
local MARKS = { 0.5, 1, 2, 3, 5, 8, 12, 20 }   -- relevés de l'état, en secondes après le démarrage
local EVENTS = { "PLAYER_ENTERING_WORLD", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE", "PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "UNIT_PET" }
local started = false

local function log(msg)
	local t = DG.cur
	-- diagnostic arrêté (/vp diag) : le gestionnaire d'erreurs reste en place jusqu'au /reload, il ne doit plus écrire
	if not t or #t >= MAX_LINES or not (VP.db and VP.db.diag and VP.db.diag.on) then return end
	t[#t + 1] = string.format("%.2f %s", GetTime() - (VP.loadTime or GetTime()), msg)
end

local function num(v) return v and string.format("%.1f", v) or "nil" end
local function yn(v) return v and "oui" or "non" end

local function describe(f)
	if not f then return "absent" end
	return "affiché=" .. yn(f:IsShown()) .. " visible=" .. yn(f:IsVisible()) .. " alpha=" .. num(f:GetAlpha())
		.. " échelle=" .. num(f:GetScale()) .. " pos=" .. num(f:GetLeft()) .. "," .. num(f:GetTop())
		.. " taille=" .. num(f:GetWidth()) .. "x" .. num(f:GetHeight())
end

function DG:Snapshot(why)
	local P, d = VP.Panels, VP.db
	log("--- " .. why .. " | " .. tostring(UnitName("player")) .. " " .. tostring(VP.class) .. " spé " .. VP:Spec()
		.. " | combat=" .. yn(InCombatLockdown()) .. " groupe=" .. GetNumPartyMembers() .. " raid=" .. GetNumRaidMembers())
	log("réglages : cadres=" .. tostring(d.showFrames) .. " seul=" .. tostring(d.showSolo) .. " tri=" .. tostring(d.sortMode)
		.. " verrou=" .. tostring(d.locked) .. " échelle=" .. tostring(d.scale)
		.. " écran=" .. num(UIParent:GetWidth()) .. "x" .. num(UIParent:GetHeight()))
	if not P or not P.anchors.main or not P.groups then log("panneaux non créés") return end
	log("ancre : " .. describe(P.anchors.main))
	log("en-tête unique : " .. describe(P.headers.main))
	local g = P.groups[1]
	log("groupe 1 : " .. describe(g) .. " showSolo=" .. tostring(g:GetAttribute("showSolo"))
		.. " showPlayer=" .. tostring(g:GetAttribute("showPlayer")) .. " groupFilter=" .. tostring(g:GetAttribute("groupFilter"))
		.. " nameList=" .. tostring(g:GetAttribute("nameList")) .. " enfants=" .. select("#", g:GetChildren()))
	local list = VP.Frames.buttons
	local vis = 0
	for _, b in ipairs(list) do if b:IsVisible() then vis = vis + 1 end end
	log("cadres : " .. #list .. " créés, " .. vis .. " visibles")
	for i = 1, math.min(#list, 6) do
		local b = list[i]
		log("  cadre " .. i .. " (" .. tostring(b:GetName()) .. ", unité " .. tostring(b:GetAttribute("unit")) .. ") : " .. describe(b))
	end
end

-- note chaque masquage avec la pile d'appels : elle dit quel fichier (de quel addon) l'a provoqué
local function watch(f, label)
	if not f or f.vpDiag then return end
	f.vpDiag = true
	pcall(f.HookScript, f, "OnHide", function() log("MASQUÉ : " .. label .. "\n" .. (debugstack(2, 12, 0) or "")) end)
	pcall(f.HookScript, f, "OnShow", function() log("AFFICHÉ : " .. label) end)
end

function DG:Start()
	local d = VP.db.diag
	d.logs = d.logs or {}
	self.cur = {}
	d.logs[VP.charKey or (UnitName("player") or "?")] = self.cur
	self.t0, self.nextMark = GetTime(), 1
	if started then self:Snapshot("relance") return end
	started = true
	local P = VP.Panels
	local old = geterrorhandler()
	seterrorhandler(function(msg)
		log("ERREUR : " .. tostring(msg) .. "\n" .. (debugstack(2, 8, 0) or ""))
		return old(msg)
	end)
	watch(P.anchors.main, "ancre principale")
	watch(P.headers.main, "en-tête unique")
	if P.groups then
		for i = 1, 8 do watch(P.groups[i], "groupe " .. i) end
	end
	for _, ev in ipairs(EVENTS) do
		VP:On(ev, function(e) if VP.db.diag.on then log("événement " .. e) end end)
	end
	local function scanButtons()
		for _, b in ipairs(VP.Frames.buttons) do
			if not b.vpDiag then
				log("cadre créé : " .. tostring(b:GetName()) .. " : " .. describe(b))
				watch(b, "cadre " .. tostring(b:GetName()))
			end
		end
	end
	scanButtons()
	local f = CreateFrame("Frame")
	f:SetScript("OnUpdate", function()
		if not VP.db.diag.on then return end
		scanButtons()
		local m = MARKS[DG.nextMark]
		if m and GetTime() - DG.t0 >= m then
			DG.nextMark = DG.nextMark + 1
			DG:Snapshot("+" .. m .. " s")
		end
	end)
	self:Snapshot("démarrage")
end

function DG:Toggle()
	local d = VP.db.diag
	d.on = not d.on
	if d.on then
		d.logs = {}
		self:Start()
		VP:Print("Diagnostic activé. Connectez le personnage où les cadres disparaissent, attendez 20 secondes, "
			.. "puis déconnectez-vous : le journal est enregistré avec les réglages. |cffffff00/vp diag|r pour l'arrêter.")
	else
		VP:Print("Diagnostic arrêté.")
	end
end

function DG:OnLogin()
	if VP.db.diag.on then
		self:Start()
		VP:Print("|cffff8800Diagnostic actif|r : attendez 20 secondes puis déconnectez-vous (/vp diag pour l'arrêter).")
	end
end
