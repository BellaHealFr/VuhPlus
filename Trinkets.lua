-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Bijoux "Utiliser :" : bouton sécurisé + alerte en phase critique
local VP = VuhPlus
local T = VP:NewModule("Trinkets")

local SLOTS = { 13, 14 }

-- Le bijou de cet emplacement a-t-il un effet "Utiliser :" ?
local function hasUse(slot)
	local link = GetInventoryItemLink("player", slot)
	if not link then return false end
	return GetItemSpell(link) ~= nil
end

local function slotEnabled(slot)
	local db = VP.db.trinket
	return (slot == 13 and db.slot13) or (slot == 14 and db.slot14)
end

local function isReady(slot)
	local start, dur, enable = GetInventoryItemCooldown("player", slot)
	if enable ~= 1 then return false end
	return start == 0 or (start + dur - GetTime()) <= 0
end

function T:AnyReady()
	for _, s in ipairs(SLOTS) do
		if slotEnabled(s) and hasUse(s) and isReady(s) then return true end
	end
	return false
end

-- Lignes /use pour les clics de soin (option « bijoux automatiques »)
function T:UseLines()
	local s = ""
	for _, slot in ipairs(SLOTS) do
		if slotEnabled(slot) and hasUse(slot) then s = s .. "/use " .. slot .. "\n" end
	end
	-- bijoux en recharge : « L'objet n'est pas encore prêt » à CHAQUE clic de soin. On efface ce message
	-- AVANT le sort, pour que les vraies erreurs du soin (hors de portée, ligne de vue...) restent visibles.
	if s ~= "" then s = s .. "/script UIErrorsFrame:Clear()\n" end
	return s
end

function T:Refresh()
	self:ApplyPosition()
	self:UpdateLock()
	self:UpdateVisibility()
	self:BuildMacro()
end

-- Macro du bouton : /use de chaque bijou actif ayant un effet "Utiliser :"
function T:BuildMacro()
	if VP.db.clicks.autoTrinket and VP.Clicks.handler then VP.Clicks:Apply() end
	VP:RunOOC("trinketMacro", function()
		local lines = {}
		for _, s in ipairs(SLOTS) do
			if slotEnabled(s) and hasUse(s) then table.insert(lines, "/use " .. s) end
		end
		table.insert(lines, "/script UIErrorsFrame:Clear()")
		T.button:SetAttribute("type", "macro")
		T.button:SetAttribute("macrotext", table.concat(lines, "\n"))
	end)
	self:UpdateIcons()
end

function T:UpdateIcons()
	for i, s in ipairs(SLOTS) do
		local ic = self.icons[i]
		local tex = GetInventoryItemTexture("player", s)
		ic.tex:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
		if slotEnabled(s) and hasUse(s) then
			ic.tex:SetDesaturated(nil); ic:SetAlpha(1)
		else
			ic.tex:SetDesaturated(1); ic:SetAlpha(0.4)
		end
		local start, dur, enable = GetInventoryItemCooldown("player", s)
		CooldownFrame_SetTimer(ic.cd, start or 0, dur or 0, enable or 0)
	end
	local key = GetBindingKey("CLICK VuhPlusTrinketButton:LeftButton")
	self.keyText:SetText(key or "")
end

-- Détection de phase critique ---------------------------------------------
local function pct(u)
	local m = UnitHealthMax(u)
	if not m or m <= 0 then return 1 end
	return UnitHealth(u) / m
end

function T:IsCritical()
	local db = VP.db.trinket
	local playerLow = (not UnitIsDeadOrGhost("player")) and pct("player") * 100 <= db.playerPct
	local raidLow = false
	if db.mode ~= "PLAYER" then
		local count = 0
		local nRaid = GetNumRaidMembers()
		if nRaid > 0 then
			for i = 1, nRaid do
				local u = "raid" .. i
				if UnitIsConnected(u) and not UnitIsDeadOrGhost(u) and pct(u) * 100 <= db.raidPct then count = count + 1 end
			end
		else
			for i = 0, GetNumPartyMembers() do
				local u = (i == 0) and "player" or ("party" .. i)
				if UnitIsConnected(u) and not UnitIsDeadOrGhost(u) and pct(u) * 100 <= db.raidPct then count = count + 1 end
			end
		end
		raidLow = count >= db.raidCount
	end
	if db.mode == "PLAYER" then return playerLow end
	if db.mode == "RAID" then return raidLow end
	return playerLow or raidLow
end

local lastSound = 0
function T:SetAlert(on)
	local db = VP.db.trinket
	if on then
		self.glow:Show()
		if db.alertText then self.alert:Show() end
		if db.sound and GetTime() - lastSound > 10 then
			lastSound = GetTime()
			PlaySound("RaidWarning")
		end
	else
		self.glow:Hide()
		self.alert:Hide()
	end
end

function T:TestAlert()
	self.testUntil = GetTime() + 4
	VP:Print("Test de l'alerte bijoux (4 secondes).")
end

-- Position ------------------------------------------------------------------
function T:ApplyPosition()
	VP:RunOOC("trinketPos", function()
		local p = VP.db.trinket.pos
		T.button:SetScale(VP.db.trinket.scale or 1)
		T.button:ClearAllPoints()
		T.button:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
		VP:Unplace(T.button)
	end)
end

function T:UpdateVisibility()
	VP:RunOOC("trinketVis", function()
		local db = VP.db.trinket
		if db.enabled and db.showButton then T.button:Show() else T.button:Hide() end
	end)
end

function T:UpdateLock()
	if VP.db.locked then self.moveTip:Hide() else self.moveTip:Show() end
end

function T:OnLogin()
	local TH = VP.Theme
	local b = CreateFrame("Button", "VuhPlusTrinketButton", UIParent, "SecureActionButtonTemplate")
	b:SetWidth(78); b:SetHeight(40)
	b:RegisterForClicks("LeftButtonUp")   -- clic droit = déplacer, pas utiliser les bijoux
	b:SetMovable(true)
	b:SetClampedToScreen(true)
	b:RegisterForDrag("RightButton")
	TH:Backdrop(b, TH.C.bg, TH.C.border)
	b:SetScript("OnDragStart", function(self)
		if not VP.db.locked and not InCombatLockdown() then self:StartMoving() end
	end)
	b:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relPoint, x, y = self:GetPoint()
		VP.db.trinket.pos = { point = point, relPoint = relPoint, x = x, y = y }
		if not InCombatLockdown() then VP:Unplace(self) end
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("VuhPlus - Bijoux")
		GameTooltip:AddLine("Clic gauche : utiliser les bijoux actifs", 1, 1, 1)
		GameTooltip:AddLine("Clic droit glissé : déplacer (déverrouillé)", 1, 1, 1)
		GameTooltip:AddLine("Raccourci : Échap > Raccourcis > VuhPlus", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	self.button = b

	self.icons = {}
	for i = 1, 2 do
		local f = CreateFrame("Frame", nil, b)
		f:SetWidth(34); f:SetHeight(34)
		f:SetPoint("LEFT", b, "LEFT", 3 + (i - 1) * 38, 0)
		TH:Backdrop(f, { 0, 0, 0, 1 }, { 0, 0, 0, 1 })
		f.tex = f:CreateTexture(nil, "ARTWORK")
		f.tex:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
		f.tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
		f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
		f.cd:SetAllPoints(f.tex)
		f:EnableMouse(false)
		self.icons[i] = f
	end

	-- lueur : bordure d'accent qui pulse
	local glow = CreateFrame("Frame", nil, b)
	glow:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 3)
	glow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
	glow:SetBackdrop({ edgeFile = TH.TEX, edgeSize = 2 })
	TH:RegisterAccent(glow, "border")
	glow:Hide()
	self.glow = glow

	local key = TH:Text(b, 10, TH.C.muted, "OUTLINE")
	key:SetPoint("TOPRIGHT", b, "TOPRIGHT", -3, -3)
	self.keyText = key

	local mt = TH:Text(b, 11)
	mt:SetPoint("BOTTOMLEFT", b, "TOPLEFT", 0, 3)
	mt:SetText("Bijoux  |cff888888(clic droit glissé)|r")
	TH:RegisterAccent(mt, "text")
	self.moveTip = mt

	-- bannière d'alerte moderne
	local alert = CreateFrame("Frame", "VuhPlusTrinketAlert", UIParent)
	alert:SetWidth(360); alert:SetHeight(46)
	alert:SetPoint("CENTER", UIParent, "CENTER", 0, 170)
	alert:SetFrameStrata("HIGH")
	TH:Backdrop(alert, TH.C.bg, TH.C.border)
	local stripe = TH:Tex(alert, "ARTWORK")
	stripe:SetPoint("TOPLEFT", alert, "TOPLEFT", 1, -1)
	stripe:SetPoint("BOTTOMLEFT", alert, "BOTTOMLEFT", 1, 1)
	stripe:SetWidth(4)
	TH:RegisterAccent(stripe)
	local at = TH:Text(alert, 18, nil, nil, nil, true)
	at:SetPoint("TOPLEFT", alert, "TOPLEFT", 18, -7)
	at:SetText("Phase critique")
	local sub = TH:Text(alert, 12, TH.C.muted)
	sub:SetPoint("TOPLEFT", at, "BOTTOMLEFT", 0, -2)
	sub:SetText("Utilisez vos bijoux maintenant")
	alert.icons = {}
	for i = 1, 2 do
		local ic = alert:CreateTexture(nil, "ARTWORK")
		ic:SetWidth(30); ic:SetHeight(30)
		ic:SetPoint("RIGHT", alert, "RIGHT", -8 - (2 - i) * 34, 0)
		ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		alert.icons[i] = ic
	end
	alert:SetScript("OnShow", function(self)
		for i, s in ipairs(SLOTS) do self.icons[i]:SetTexture(GetInventoryItemTexture("player", s)) end
	end)
	alert:Hide()
	self.alert = alert

	self:ApplyPosition()
	self:UpdateLock()
	self:UpdateVisibility()
	self:BuildMacro()

	VP:On("UNIT_INVENTORY_CHANGED", function(_, unit) if unit == "player" then T:BuildMacro() end end)
	VP:On("PLAYER_EQUIPMENT_CHANGED", function() T:BuildMacro() end)
	VP:On("UPDATE_BINDINGS", function() T:UpdateIcons() end)
	VP:On("BAG_UPDATE_COOLDOWN", function() T:UpdateIcons() end)
	VP:On("ACTIONBAR_UPDATE_COOLDOWN", function() T:UpdateIcons() end)

	-- Surveillance 5x/s, pulsation de l'alerte
	local acc, pulse = 0, 0
	local driver = CreateFrame("Frame")
	driver:SetScript("OnUpdate", function(_, elapsed)
		pulse = pulse + elapsed
		-- pulsation seulement quand l'alerte est visible (inutile de redessiner à chaque image sinon)
		if T.glow:IsShown() then
			local a = 0.5 + 0.5 * math.abs(math.sin(pulse * 4))
			T.glow:SetAlpha(a)
			T.alert:SetAlpha(0.75 + 0.25 * a)
		end
		acc = acc + elapsed
		if acc < 0.2 then return end
		acc = 0
		local db = VP.db.trinket
		if T.testUntil and GetTime() < T.testUntil then T:SetAlert(true) return end
		T.testUntil = nil
		if not db.enabled or VP.db.alerts.quiet then T:SetAlert(false) return end
		if db.onlyInCombat and not UnitAffectingCombat("player") then T:SetAlert(false) return end
		T:SetAlert(T:AnyReady() and T:IsCritical())
	end)
end
