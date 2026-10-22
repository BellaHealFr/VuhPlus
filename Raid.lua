-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Outils de raid : alertes (aggro, tank en danger), état du raid, rapport de mort, barre d'outils
-- Inspiré des « Raid tools » de Cell et des niveaux d'alerte de HealBot.
local VP = VuhPlus
local R = VP:NewModule("Raid")

local band = bit and bit.band
local GROUP_MASK = 0x00000007   -- COMBATLOG_OBJECT_AFFILIATION_MINE | PARTY | RAID
local PLAYER_TYPE = 0x00000400  -- COMBATLOG_OBJECT_TYPE_PLAYER

local unitsBuf = {}
local function groupUnits()
	local t = unitsBuf
	wipe(t)
	local n = GetNumRaidMembers()
	if n > 0 then
		for i = 1, n do t[#t + 1] = "raid" .. i end
	else
		t[1] = "player"
		for i = 1, GetNumPartyMembers() do t[#t + 1] = "party" .. i end
	end
	return t
end

-- Bandeau d'alerte (aggro / tank en danger) ---------------------------------------
function R:Flash(text, r, g, b)
	local f = self.banner
	f.text:SetText(text)
	f.text:SetTextColor(r or 1, g or 0.3, b or 0.3)
	f.until_ = GetTime() + 2.5
	f:Show()
end

-- Alertes : aggro sur moi, tank sous le seuil ------------------------------------
local hadAggro, lowTank, lastTankSound = false, {}, 0
function R:CheckAlerts()
	local d = VP.db.alerts
	if d.quiet then return end   -- mode silencieux (/vp silence)
	-- aggro sur moi (utile pour un soigneur ou un DPS) ; jamais pour un tank : l'aggro, c'est son travail
	-- (rôle détecté par les talents, la Présence de givre ou la forme d'ours, ou forcé avec /vp role)
	local myRole = VP.Roles and VP.Roles:GetRole("player")
	if d.aggro and myRole ~= "TANK" then
		local t = UnitThreatSituation("player")
		local now = t and t >= 2 and UnitAffectingCombat("player")
		if now and not hadAggro then
			if d.sound then PlaySound("RaidWarning") end
			self:Flash("Vous avez l'aggro !", 1, 0.25, 0.25)
		end
		hadAggro = now
	else
		hadAggro = false
	end
	-- tank en danger
	if d.tankLow and VP.Buffs then
		for _, u in ipairs(groupUnits()) do
			local g = UnitGUID(u)
			if g and UnitIsDeadOrGhost(u) then
				lowTank[g] = nil   -- après une résurrection, l'alerte doit pouvoir se redéclencher
			-- pas d'alerte sur soi-même : le tank voit déjà sa propre vie
			elseif g and UnitIsConnected(u) and not UnitIsUnit(u, "player") and VP.Buffs:IsTank(u) then
				local m = UnitHealthMax(u)
				local pct = m > 0 and UnitHealth(u) / m * 100 or 100
				if pct <= d.tankPct then
					if not lowTank[g] then
						lowTank[g] = true
						if d.sound and GetTime() - lastTankSound > 3 then
							lastTankSound = GetTime()
							PlaySound("RaidWarning")
						end
						self:Flash((UnitName(u) or "Tank") .. " en danger : " .. math.floor(pct) .. " %", 1, 0.6, 0.1)
					end
				elseif pct > d.tankPct + 10 then
					lowTank[g] = nil
				end
			end
		end
	end
end

-- État du raid : morts, déconnectés, hors de portée, mana des soigneurs -----------
function R:UpdateStatus()
	local d = VP.db.alerts
	local st = self.status
	if not d.status then st:Hide() return end
	local dead, off, far, n = 0, 0, 0, 0
	local mana, healers = 0, 0
	for _, u in ipairs(groupUnits()) do
		if UnitExists(u) then
			n = n + 1
			if not UnitIsConnected(u) then off = off + 1
			elseif UnitIsDeadOrGhost(u) then dead = dead + 1
			elseif not UnitIsUnit(u, "player") and not UnitInRange(u) then far = far + 1 end
			if UnitIsConnected(u) and VP.Roles and VP.Roles:GetRole(u) == "HEALER" and UnitPowerType(u) == 0 then
				local m = UnitPowerMax(u, 0)
				if m and m > 0 then
					mana = mana + UnitPower(u, 0) / m
					healers = healers + 1
				end
			end
		end
	end
	-- seul : cachée seulement si demandé (« Cacher les fenêtres vides »), plus par le verrouillage
	if n <= 1 and VP.db.hideEmpty and VP.db.locked then st:Hide() return end
	local parts = {}
	parts[#parts + 1] = (dead > 0 and "|cffff5555" or "|cff888888") .. "Morts " .. dead .. "|r"
	parts[#parts + 1] = (off > 0 and "|cffaaaaaa" or "|cff666666") .. "Déco " .. off .. "|r"
	parts[#parts + 1] = (far > 0 and "|cffffcc33" or "|cff888888") .. "Loin " .. far .. "|r"
	if healers > 0 then
		local pct = math.floor(mana / healers * 100)
		local col = pct < 25 and "|cffff5555" or (pct < 50 and "|cffffcc33" or "|cff55aaff")
		parts[#parts + 1] = col .. "Mana soigneurs " .. pct .. " %|r"
	end
	st.text:SetText(table.concat(parts, "   "))
	st:SetWidth(st.text:GetStringWidth() + 16)
	st:Show()
end

-- Rapport de mort : dernier coup reçu ----------------------------------------------
local lastHit = {}
local feignName = GetSpellInfo(5384)   -- Feinte de mort (chasseur)
-- une table par joueur, réutilisée (le journal de combat envoie des centaines d'événements par seconde)
local function setHit(guid, spell, amount, src)
	local h = lastHit[guid]
	if not h then h = {}; lastHit[guid] = h end
	h.spell, h.amount, h.src = spell, amount, src
end
-- SPELL_INSTAKILL : mort instantanée (sans dégâts) ; sans lui, le rapport donnait le coup PRÉCÉDENT
local WATCH = { SWING_DAMAGE = true, SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true, RANGE_DAMAGE = true,
	ENVIRONMENTAL_DAMAGE = true, SPELL_INSTAKILL = true, UNIT_DIED = true }
function R:OnCombatLog(event, srcName, dstGUID, dstName, dstFlags, a9, a10, a11, a12)
	if not WATCH[event] then return end
	if not band or band(dstFlags or 0, GROUP_MASK) == 0 or band(dstFlags or 0, PLAYER_TYPE) == 0 then return end
	if event == "SWING_DAMAGE" then
		setHit(dstGUID, "Mêlée", a9, srcName)
	elseif event == "SPELL_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" or event == "RANGE_DAMAGE" then
		setHit(dstGUID, a10, a12, srcName)
	elseif event == "ENVIRONMENTAL_DAMAGE" then
		setHit(dstGUID, a9, a10, "Environnement")
	elseif event == "SPELL_INSTAKILL" then
		setHit(dstGUID, a10, "mort instantanée", srcName)
	elseif event == "UNIT_DIED" then
		local h = lastHit[dstGUID]
		local msg = (dstName or "?") .. " est mort"
		if h and h.spell then
			msg = msg .. " : " .. tostring(h.spell) .. " (" .. tostring(h.amount or "?") .. ")" .. (h.src and (" de " .. h.src) or "")
		end
		if h then h.spell, h.amount, h.src = nil, nil, nil end
		-- feinte de mort (chasseur) : pas une vraie mort
		-- (la fonction UnitIsFeignDeath n'existe pas toujours : on regarde aussi le buff lui-même)
		if dstName and ((UnitIsFeignDeath and UnitIsFeignDeath(dstName))
			or (feignName and UnitBuff(dstName, feignName))) then return end
		local d = VP.db.alerts
		if d.deathReport == "SELF" then
			VP:Print("|cffff5555" .. msg .. "|r")
		elseif d.deathReport == "GROUP" then
			-- annonce groupée : les morts des 2 dernières secondes partent ensemble (pas 25 lignes au wipe),
			-- et seulement par le chef / un assistant (sinon chaque joueur VuhPlus répète la même chose)
			R:QueueDeath(dstName or "?", h and h.spell and msg or nil)
		end
	end
end

local deaths, deathAt = {}, nil
function R:QueueDeath(name, detail)
	deaths[#deaths + 1] = detail or (name .. " est mort")
	deathAt = deathAt or GetTime()
end
function R:FlushDeaths()
	if not deathAt or GetTime() - deathAt < 2 then return end
	deathAt = nil
	local ch = VP:GroupChannel()
	-- en groupe de 5 aussi, seul le chef annonce (avant : chaque joueur VuhPlus du groupe répétait les morts)
	local lead
	if GetNumRaidMembers() > 0 then lead = IsRaidLeader() or IsRaidOfficer() else lead = IsPartyLeader() end
	if ch and lead then
		if #deaths <= 3 then
			for _, m in ipairs(deaths) do SendChatMessage("[VuhPlus] " .. m, ch) end
		else
			SendChatMessage("[VuhPlus] " .. #deaths .. " morts : " .. deaths[1] .. " ...", ch)
		end
	else
		for _, m in ipairs(deaths) do VP:Print("|cffff5555" .. m .. "|r") end
	end
	wipe(deaths)
end

-- Barre d'outils : appel, compte à rebours, symboles --------------------------------
local countdown

-- droits : en raid il faut être chef ou assistant ; en groupe, chef pour l'appel
local function isLead()
	if GetNumRaidMembers() > 0 then return IsRaidLeader() or IsRaidOfficer() end
	if GetNumPartyMembers() > 0 then return IsPartyLeader() end
	return false
end
local function canMark()
	if GetNumRaidMembers() > 0 then return IsRaidLeader() or IsRaidOfficer() end
	return true
end
R.isLead, R.canMark = isLead, canMark

-- Test de la barre (/vp outils test, bouton dans les options) : barre affichée 60 s, l'appel et le pull
-- restent dans votre chat ; les symboles et la vérification des consommables fonctionnent pour de vrai
local TEST_TIME = 60
function R:TestTools()
	if R.testUntil then
		R.testUntil = nil
		VP:Print("Test de la barre d'outils terminé.")
	else
		R.testUntil = GetTime() + TEST_TIME
		VP:Print("Test de la barre d'outils pendant " .. TEST_TIME .. " s : l'appel et le pull restent dans votre chat, "
			.. "les symboles se posent vraiment sur votre cible. Recliquez sur « Tester » pour arrêter.")
	end
	R:ApplyTools()
end

function R:ReadyCheck()
	if R.testUntil then
		VP:Print("|cffffff00[Test]|r Un appel (ready check) serait lancé : chaque joueur répond, les cadres affichent une coche, "
			.. "et les joueurs pas prêts sont listés dans le chat.")
	elseif GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then
		VP:Print("Appel impossible : vous n'êtes pas en groupe.")
	elseif not isLead() then
		VP:Print("Appel impossible : il faut être chef" .. (GetNumRaidMembers() > 0 and " ou assistant du raid." or " du groupe."))
	else
		DoReadyCheck()
	end
end

-- Pose un symbole sur la cible ; reclic sur le même symbole = le retire (comme Blizzard)
function R:Mark(idx)
	if not UnitExists("target") then VP:Print("Ciblez d'abord un joueur ou un monstre.") return end
	if not canMark() then VP:Print("Symboles impossibles : il faut être chef ou assistant du raid.") return end
	if idx ~= 0 and GetRaidTargetIndex("target") == idx then idx = 0 end
	SetRaidTarget("target", idx)
end

-- Retire les symboles de tous les membres du groupe
function R:ClearMarks()
	if not canMark() then VP:Print("Symboles impossibles : il faut être chef ou assistant du raid.") return end
	local n = GetNumRaidMembers()
	if n > 0 then
		for i = 1, n do
			local u = "raid" .. i
			if GetRaidTargetIndex(u) then SetRaidTarget(u, 0) end
		end
	else
		if GetRaidTargetIndex("player") then SetRaidTarget("player", 0) end
		for i = 1, GetNumPartyMembers() do
			local u = "party" .. i
			if GetRaidTargetIndex(u) then SetRaidTarget(u, 0) end
		end
	end
	if UnitExists("target") and GetRaidTargetIndex("target") then SetRaidTarget("target", 0) end
end
function R:Pull(seconds)
	if countdown then countdown = nil; VP:Print("Compte à rebours annulé.") return end
	local ch = VP:GroupChannel()
	if ch == "RAID" and (IsRaidLeader() or IsRaidOfficer()) then ch = "RAID_WARNING" end
	if R.testUntil then ch = nil end   -- test : le compte à rebours reste dans votre chat
	countdown = { left = seconds, next = GetTime(), ch = ch }
end

function R:TickPull()
	if not countdown then return end
	if GetTime() < countdown.next then return end
	local msg = countdown.left > 0 and ("Pull dans " .. countdown.left) or "PULL !"
	if countdown.ch then SendChatMessage(msg, countdown.ch) else VP:Print(msg) end
	if countdown.left <= 0 then countdown = nil return end
	countdown.left = countdown.left - 1
	-- après un gel du jeu (écran de chargement...) on ne rattrape pas en rafale
	countdown.next = math.max(countdown.next + 1, GetTime() + 0.5)
end

function R:ApplyTools()
	local d = VP.db.alerts
	local tb = self.tools
	local p = d.toolsPos
	tb:ClearAllPoints()
	tb:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
	VP:Unplace(tb)
	tb:SetScale(VP.db.scale or 1)
	if d.tools or R.toolsTemp or R.testUntil then tb:Show() else tb:Hide() end
	if R.testUntil then tb.testLabel:Show() else tb.testLabel:Hide() end
	if VP.db.locked then tb.handle:Hide() else tb.handle:Show() end
	local sp = d.statusPos
	self.status:ClearAllPoints()
	self.status:SetPoint(sp.point, UIParent, sp.relPoint, sp.x, sp.y)
	VP:Unplace(self.status)
	self.status:SetScale(VP.db.scale or 1)
	if VP.db.locked then self.status.handle:Hide() else self.status.handle:Show() end
end

function R:Refresh()
	if self.tools then self:ApplyTools(); self:UpdateStatus() end
end

-- Proposition de la barre d'outils quand on devient chef ou assistant du raid ----------
-- toolsAsk : "ASK" (demander), "AUTO" (afficher automatiquement), "NEVER" (ne rien proposer)
local wasLead, declined = false, false
function R:CheckLead()
	local d = VP.db.alerts
	-- en champ de bataille, le chef est désigné automatiquement : pas de proposition
	local _, itype = IsInInstance()
	local inRaid = GetNumRaidMembers() > 0 and itype ~= "pvp"
	local lead = inRaid and (IsRaidLeader() or IsRaidOfficer()) and true or false
	if not inRaid then declined = false end
	if lead and not wasLead then
		wasLead = true
		if d.tools then return end                      -- déjà affichée en permanence
		local mode = d.toolsAsk or "ASK"
		if mode == "AUTO" then
			R.toolsTemp = true
			R:ApplyTools()
		elseif mode == "ASK" and not declined then
			R:ShowLeadPrompt()
		end
	elseif not lead and wasLead then
		wasLead = false
		R.prompt:Hide()
		if R.toolsTemp then R.toolsTemp = false; R:ApplyTools() end
	end
end

function R:ShowLeadPrompt()
	local f = self.prompt
	f.until_ = GetTime() + 30
	f:Show()
	if VP.db.alerts.sound then PlaySound("igMainMenuOpen") end
end

function R:BuildLeadPrompt()
	local T = VP.Theme
	local UI = VP.UI
	local f = CreateFrame("Frame", "VuhPlusLeadPrompt", UIParent)
	f:SetWidth(360); f:SetHeight(86)
	f:SetPoint("TOP", UIParent, "TOP", 0, -140)
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)
	T:Backdrop(f, T.C.bg, T.C.border)
	local stripe = T:Tex(f, "ARTWORK")
	stripe:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	stripe:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
	stripe:SetHeight(2)
	T:RegisterAccent(stripe)
	local title = T:Text(f, 13, nil, nil, nil, true)
	title:SetPoint("TOP", f, "TOP", 0, -10)
	title:SetText("Vous êtes chef ou assistant du raid")
	local txt = T:Text(f, 12, T.C.muted)
	txt:SetPoint("TOP", title, "BOTTOM", 0, -4)
	txt:SetText("Afficher la barre d'outils de raid (appel, pull, symboles) ?")
	local yes = UI:Button(f, "Oui", 90, function()
		R.toolsTemp = true; R:ApplyTools(); f:Hide()
	end)
	yes:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 10)
	local no = UI:Button(f, "Non", 90, function()
		declined = true; f:Hide()
	end)
	no:SetPoint("LEFT", yes, "RIGHT", 6, 0)
	local always = UI:Button(f, "Toujours", 140, function()
		VP.db.alerts.toolsAsk = "AUTO"
		R.toolsTemp = true; R:ApplyTools(); f:Hide()
		VP:Print("La barre d'outils s'affichera automatiquement quand vous êtes chef ou assistant (/vp > Outils de chef pour changer).")
	end)
	always:SetPoint("LEFT", no, "RIGHT", 6, 0)
	f:SetScript("OnUpdate", function(self)
		if self.until_ and GetTime() > self.until_ then self:Hide() end
	end)
	f:Hide()
	self.prompt = f
end

local function savePos(f, key)
	local point, _, relPoint, x, y = f:GetPoint()
	VP.db.alerts[key] = { point = point, relPoint = relPoint, x = x, y = y }
	VP:Unplace(f)
end

function R:OnLogin()
	local T = VP.Theme
	local UI = VP.UI

	-- bandeau d'alerte
	local bn = CreateFrame("Frame", "VuhPlusAlertBanner", UIParent)
	bn:SetWidth(420); bn:SetHeight(40)
	bn:SetPoint("CENTER", UIParent, "CENTER", 0, 230)
	bn:SetFrameStrata("HIGH")
	T:Backdrop(bn, T.C.bg, T.C.border)
	local stripe = T:Tex(bn, "ARTWORK")
	stripe:SetPoint("TOPLEFT", bn, "TOPLEFT", 1, -1)
	stripe:SetPoint("BOTTOMLEFT", bn, "BOTTOMLEFT", 1, 1)
	stripe:SetWidth(4)
	T:RegisterAccent(stripe)
	bn.text = T:Text(bn, 18, nil, nil, nil, true)
	bn.text:SetPoint("CENTER", bn, "CENTER", 0, 0)
	bn:Hide()
	bn:SetScript("OnUpdate", function(self)
		if self.until_ and GetTime() > self.until_ then self:Hide() end
	end)
	self.banner = bn

	-- état du raid
	local st = CreateFrame("Frame", "VuhPlusRaidStatus", UIParent)
	st:SetHeight(20); st:SetWidth(200)
	st:SetMovable(true); st:SetClampedToScreen(true)
	T:Backdrop(st, T.C.bg, T.C.border)
	st.text = T:Text(st, 11)
	st.text:SetPoint("LEFT", st, "LEFT", 8, 0)
	st.handle = T:Handle(st, "État du raid",
		function() st:StartMoving() end,
		function() st:StopMovingOrSizing(); savePos(st, "statusPos") end)
	st:Hide()
	self.status = st

	-- barre d'outils
	local tb = CreateFrame("Frame", "VuhPlusRaidTools", UIParent)
	tb:SetWidth(9 * 22 + 3 * 63 + 53 + 12); tb:SetHeight(28)
	tb:SetMovable(true); tb:SetClampedToScreen(true)
	T:Backdrop(tb, T.C.bg, T.C.border)
	tb.handle = T:Handle(tb, "Outils de raid",
		function() tb:StartMoving() end,
		function() tb:StopMovingOrSizing(); savePos(tb, "toolsPos") end)
	local x = 4
	local function btn(label, w, fn, tip)
		local b = UI:Button(tb, label, w, fn)
		b:SetHeight(20)
		b:SetPoint("LEFT", tb, "LEFT", x, 0)
		b:SetScript("OnEnter", function(self)
			self:SetBackdropColor(T.C.hover[1], T.C.hover[2], T.C.hover[3], 1)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine(tip)
			GameTooltip:Show()
		end)
		b:HookScript("OnLeave", function() GameTooltip:Hide() end)
		x = x + w + 3
		return b
	end
	btn("Appel", 60, function() R:ReadyCheck() end, "Lancer un appel (ready check)\nChef ou assistant requis en raid")
	btn("Pull 5", 60, function() R:Pull(5) end, "Compte à rebours de 5 secondes dans le chat\nRecliquer pour annuler")
	btn("Pull 10", 60, function() R:Pull(10) end, "Compte à rebours de 10 secondes dans le chat\nRecliquer pour annuler")
	btn("Conso", 50, function() VP.Consumables:Report(IsShiftKeyDown()) end,
		"Vérifier flacons / élixirs et nourriture du groupe\nMaj+clic : annoncer le résultat au groupe / raid")
	for i = 1, 8 do
		local idx = i
		local b = CreateFrame("Button", nil, tb)
		b:SetWidth(20); b:SetHeight(20)
		b:SetPoint("LEFT", tb, "LEFT", x, 0)
		local t = b:CreateTexture(nil, "ARTWORK")
		t:SetAllPoints(b)
		t:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
		SetRaidTargetIconTexture(t, idx)
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		b:SetScript("OnClick", function(_, button)
			R:Mark(button == "RightButton" and 0 or idx)
		end)
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine("Poser ce symbole sur votre cible")
			GameTooltip:AddLine("Reclic sur le même symbole ou clic droit : le retirer", 0.8, 0.8, 0.8)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		x = x + 22
	end
	-- bouton « Aucun » : retire le symbole de la cible ; Maj+clic : de tout le groupe
	local nb = CreateFrame("Button", nil, tb)
	nb:SetWidth(20); nb:SetHeight(20)
	nb:SetPoint("LEFT", tb, "LEFT", x, 0)
	T:Backdrop(nb, T.C.panel, T.C.border)
	local nx = T:Text(nb, 14, T.C.danger)
	nx:SetPoint("CENTER", nb, "CENTER", 0, 1)
	nx:SetText("x")
	nb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	nb:SetScript("OnClick", function(_, button)
		if IsShiftKeyDown() or button == "RightButton" then R:ClearMarks() else R:Mark(0) end
	end)
	nb:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Aucun symbole")
		GameTooltip:AddLine("Clic : retirer le symbole de votre cible", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("Maj+clic ou clic droit : retirer ceux de tout le groupe", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	nb:SetScript("OnLeave", function() GameTooltip:Hide() end)
	x = x + 22
	-- mode test : rappel sous la barre
	tb.testLabel = T:Text(tb, 11, { 1, 0.85, 0.2 })
	tb.testLabel:SetPoint("TOP", tb, "BOTTOM", 0, -3)
	tb.testLabel:SetText("TEST : l'appel et le pull restent dans votre chat")
	tb.testLabel:Hide()
	tb:Hide()
	self.tools = tb
	self:ApplyTools()

	self:BuildLeadPrompt()
	local function leadCheck() R:CheckLead() end
	VP:On("RAID_ROSTER_UPDATE", leadCheck)
	VP:On("PARTY_LEADER_CHANGED", leadCheck)
	VP:On("PLAYER_ENTERING_WORLD", leadCheck)

	VP:On("COMBAT_LOG_EVENT_UNFILTERED", function(_, _, event, _, srcName, _, dstGUID, dstName, dstFlags, a9, a10, a11, a12)
		if VP.db.alerts.deathReport ~= "OFF" then R:OnCombatLog(event, srcName, dstGUID, dstName, dstFlags, a9, a10, a11, a12) end
	end)
	local acc, accS = 0, 0
	local drv = CreateFrame("Frame")
	drv:SetScript("OnUpdate", function(_, e)
		R:TickPull()
		R:FlushDeaths()
		if R.testUntil and GetTime() > R.testUntil then R:TestTools() end   -- fin du test
		acc = acc + e
		accS = accS + e
		if acc >= 0.25 then
			acc = 0
			R:CheckAlerts()
		end
		if accS >= 1 then
			accS = 0
			R:UpdateStatus()
		end
	end)
end
