-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Liste en direct des joueurs à dissiper (inspirée de Decursive)
local VP = VuhPlus
local LL = VP:NewModule("LiveList")

local MAX_ROWS = 10
local sorted = {}

local function sortFn(a, b)
	if a.priority ~= b.priority then return a.priority end           -- liste de priorité d'abord
	if a.inRange ~= b.inRange then return a.inRange end               -- à portée d'abord
	if (a.blacklisted and true or false) ~= (b.blacklisted and true or false) then return not a.blacklisted end
	if a.rank ~= b.rank then return a.rank < b.rank end               -- ordre des types choisi
	return (a.exp or 0) < (b.exp or 0)                                -- expire le plus tôt
end

function LL:Update()
	local d = VP.db.dispel
	local f = self.frame
	if not d.liveList or not VP.Dispel:Enabled() then f:Hide() return end
	local now = GetTime()
	local rank = self.rank or {}
	self.rank = rank
	wipe(rank)
	for i, t in ipairs(VP.Dispel:Order()) do rank[t] = i end
	wipe(sorted)
	for g, a in pairs(VP.Dispel.afflicted) do
		-- au-delà du balayage des auras (1,5 s en raid 40) : sinon la ligne disparaissait un instant
		if now - (a.seen or 0) > 2.5 then
			VP.Dispel.afflicted[g] = nil
		else
			a.rank = rank[a.dtype] or 9
			sorted[#sorted + 1] = a
		end
	end
	table.sort(sorted, sortFn)
	local n = math.min(#sorted, d.liveListRows or 5)
	-- liste vide : cachée seulement si demandé (« Cacher les fenêtres vides »), plus par le verrouillage
	if n == 0 and VP.db.hideEmpty and VP.db.locked then f:Hide() return end
	f:Show()
	for i = 1, MAX_ROWS do
		local r = self.rows[i]
		local a = sorted[i]
		if i <= n and a then
			r.name:SetText(a.player or "?")
			r.name:SetTextColor(VP.Colors:Class(a.class))
			r.icon.tex:SetTexture(a.icon)
			local col = VP.Colors:Debuff(a.dtype)
			r.icon:SetBackdropBorderColor(col[1], col[2], col[3], 1)
			local left = a.exp and a.exp > 0 and (a.exp - now)
			local state = ""
			if a.blacklisted then state = "|cff888888 hors vue|r"
			elseif not a.inRange then state = "|cff888888 loin|r" end
			r.debuff:SetText((a.debuff or "") .. state)
			r.timer:SetText(left and left > 0 and VP.Frames.fmtLeft(left) or "")
			r:SetAlpha((a.inRange and not a.blacklisted) and 1 or 0.5)
			r:Show()
		else
			r:Hide()
		end
	end
	local key = VP.dispelKeys and VP.dispelKeys[1]
	if n == 0 then
		self.hint:SetText("|cff777777Aucun joueur à dissiper|r")
	elseif VP.db.showFrames == false then
		-- cadres de soin cachés : la liste reste une information (le clic se fait sur les cadres)
		self.hint:SetText("|cff777777Cadres de soin cachés|r")
	else
		self.hint:SetText(key and ("Clic |cffffffff" .. key .. "|r sur le cadre") or "Choisissez une touche (/vp > Dispel)")
	end
	f:SetHeight(26 + math.max(n, 1) * 22)
end

function LL:ApplyPosition()
	local p = VP.db.dispel.liveListPos
	self.frame:ClearAllPoints()
	self.frame:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
	VP:Unplace(self.frame)
	self.frame:SetScale(VP.db.scale or 1)
	if VP.db.locked then self.frame.handle:Hide() else self.frame.handle:Show() end
end

function LL:Refresh()
	if self.frame then self:ApplyPosition(); self:Update() end
	if self.cure then self:ApplyCure() end
end

-- Petits cadres cliquables (comme les mini-cadres de Decursive) ------------------------------
-- Un carré par joueur, tenu par un en-tête de groupe Blizzard : il suit le raid même en combat.
-- Le carré prend la couleur du débuff à dissiper ; clic gauche = Dispel 1, clic droit = Dispel 2,
-- clic milieu = cibler. Affiché d'office quand les cadres de soin sont cachés (réglage « AUTO »).
local cureButtons = {}
function VuhPlus_InitCure(b)
	local T = VP.Theme
	T:Backdrop(b, { 0.12, 0.12, 0.14, 0.9 }, { 0, 0, 0, 1 })
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
	b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.icon:Hide()
	b:HookScript("OnEnter", function(self)
		local u = self:GetAttribute("unit")
		if not u or not UnitExists(u) then return end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(UnitName(u) or "?", VP.Colors:Class(select(2, UnitClass(u))))
		local a = VP.Dispel.afflicted[UnitGUID(u) or ""]
		if a then
			GameTooltip:AddLine((a.debuff or "?") .. " (" .. (VP.Dispel.TYPE_FR[a.dtype] or a.dtype or "") .. ")", 1, 0.8, 0.3)
		else
			GameTooltip:AddLine("Rien à dissiper", 0.6, 0.6, 0.65)
		end
		local s1, s2 = VP.Dispel.slots[1], VP.Dispel.slots[2]
		if s1 then GameTooltip:AddLine("Clic gauche : " .. s1.name, 0.8, 0.8, 0.85) end
		GameTooltip:AddLine("Clic droit : " .. ((s2 or s1) and (s2 or s1).name or "-"), 0.8, 0.8, 0.85)
		GameTooltip:AddLine("Clic milieu : cibler", 0.8, 0.8, 0.85)
		GameTooltip:Show()
	end)
	b:HookScript("OnLeave", function() GameTooltip:Hide() end)
	cureButtons[#cureButtons + 1] = b
end

local CURE_SIZE_SNIPPET = [[
	local s = self:GetParent():GetAttribute("vp-s")
	if s then self:SetWidth(s); self:SetHeight(s) end
]]

function LL:CureWanted()
	local d = VP.db.dispel
	if not VP.Dispel:Enabled() then return false end
	local mode = d.mini or "AUTO"
	if mode == "ON" then return true end
	if mode == "AUTO" then return VP.db.showFrames == false end
	return false
end

-- Attributs et visibilité de l'en-tête : hors combat seulement (sinon à la fin du combat)
function LL:ApplyCure()
	VP:RunOOC("cure", function()
		local d = VP.db.dispel
		local h, a = LL.cureHeader, LL.cure
		local s = d.miniSize or 18
		local s1, s2 = VP.Dispel.slots[1], VP.Dispel.slots[2]
		local function set(k, v) if h:GetAttribute(k) ~= v then h:SetAttribute(k, v) end end
		set("vp-s", s)
		set("*type1", s1 and "spell" or nil)
		set("*spell1", s1 and s1.name or nil)
		set("*type2", (s2 or s1) and "spell" or nil)
		set("*spell2", (s2 or s1) and (s2 or s1).name or nil)
		set("*type3", "target")
		set("showSolo", VP.db.showSolo and true or false)
		for _, b in ipairs(cureButtons) do b:SetWidth(s); b:SetHeight(s) end
		local p = d.miniPos
		a:ClearAllPoints()
		a:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
		VP:Unplace(a)
		a:SetScale(VP.db.scale or 1)
		if LL:CureWanted() then a:Show(); h:Show() else h:Hide(); a:Hide() end
		if VP.db.locked then a.handle:Hide() else a.handle:Show() end
	end)
end

-- Couleurs (non protégées : possibles en combat), 5 fois par seconde
function LL:UpdateCure()
	if not self.cure or not self.cure:IsShown() then return end
	local D = VP.Dispel
	for _, b in ipairs(cureButtons) do
		if b:IsVisible() then
			local u = b:GetAttribute("unit")
			local g = u and UnitGUID(u)
			local a = g and D.afflicted[g]
			if a then
				local c = VP.Colors:Debuff(a.dtype)
				b:SetBackdropColor(c[1], c[2], c[3], 1)
				b:SetBackdropBorderColor(1, 1, 1, 1)
				b.icon:SetTexture(a.icon)
				b.icon:Show()
				b:SetAlpha((a.inRange and not a.blacklisted) and 1 or 0.45)
			else
				b.icon:Hide()
				b:SetBackdropBorderColor(0, 0, 0, 1)
				if u and (not UnitIsConnected(u) or UnitIsDeadOrGhost(u)) then
					b:SetBackdropColor(0.3, 0.08, 0.08, 0.9)
				else
					local r, gg, bl = VP.Colors:Class(u and select(2, UnitClass(u)))
					b:SetBackdropColor(r * 0.35, gg * 0.35, bl * 0.35, 0.9)
				end
				b:SetAlpha(1)
			end
		end
	end
end

function LL:BuildCure()
	local T = VP.Theme
	local a = CreateFrame("Frame", "VuhPlusCureAnchor", UIParent)
	a:SetWidth(10); a:SetHeight(10)
	a:SetMovable(true)
	a:SetClampedToScreen(true)
	a.handle = T:Handle(a, "Petits cadres de dispel",
		function() if not InCombatLockdown() then a:StartMoving() end end,
		function()
			a:StopMovingOrSizing()
			local point, _, relPoint, x, y = a:GetPoint()
			VP.db.dispel.miniPos = { point = point, relPoint = relPoint, x = x, y = y }
			VP:Unplace(a)
		end)
	local h = CreateFrame("Frame", "VuhPlusCureHeader", a, "SecureGroupHeaderTemplate")
	h:SetPoint("TOPLEFT", a, "TOPLEFT", 0, 0)
	h:SetAttribute("template", "VuhPlusCureTemplate")
	h:SetAttribute("templateType", "Button")
	h:SetAttribute("showRaid", true)
	h:SetAttribute("showParty", true)
	h:SetAttribute("showPlayer", true)
	h:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
	h:SetAttribute("groupBy", "GROUP")
	h:SetAttribute("groupingOrder", "1,2,3,4,5,6,7,8")
	-- une ligne de 5 par groupe (8 lignes en raid 40)
	h:SetAttribute("point", "LEFT")
	h:SetAttribute("xOffset", 2)
	h:SetAttribute("unitsPerColumn", 5)
	h:SetAttribute("maxColumns", 8)
	h:SetAttribute("columnAnchorPoint", "TOP")
	h:SetAttribute("columnSpacing", 2)
	h:SetAttribute("vp-s", VP.db.dispel.miniSize or 18)
	h:SetAttribute("initialConfigFunction", CURE_SIZE_SNIPPET)
	h:Hide()
	a:Hide()
	self.cure, self.cureHeader = a, h
	self:ApplyCure()
end

function LL:OnLogin()
	local T = VP.Theme
	local f = CreateFrame("Frame", "VuhPlusLiveList", UIParent)
	f:SetWidth(230); f:SetHeight(48)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	T:Backdrop(f, T.C.bg, T.C.border)
	local stripe = T:Tex(f, "ARTWORK")
	stripe:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	stripe:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
	stripe:SetHeight(2)
	T:RegisterAccent(stripe)
	local title = T:Text(f, 12, nil, nil, nil, true)
	title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
	title:SetText("À dissiper")
	self.hint = T:Text(f, 10, T.C.muted)
	self.hint:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
	f.handle = T:Handle(f, "Liste de dispel",
		function() if not InCombatLockdown() then f:StartMoving() end end,
		function()
			f:StopMovingOrSizing()
			local point, _, relPoint, x, y = f:GetPoint()
			VP.db.dispel.liveListPos = { point = point, relPoint = relPoint, x = x, y = y }
			VP:Unplace(f)
		end)
	self.rows = {}
	for i = 1, MAX_ROWS do
		local r = CreateFrame("Frame", nil, f)
		r:SetWidth(218); r:SetHeight(20)
		r:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -24 - (i - 1) * 22)
		r.icon = CreateFrame("Frame", nil, r)
		r.icon:SetWidth(18); r.icon:SetHeight(18)
		r.icon:SetPoint("LEFT", r, "LEFT", 0, 0)
		T:Backdrop(r.icon, { 0, 0, 0, 1 }, { 0, 0, 0, 1 })
		r.icon.tex = r.icon:CreateTexture(nil, "ARTWORK")
		r.icon.tex:SetPoint("TOPLEFT", r.icon, "TOPLEFT", 1, -1)
		r.icon.tex:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", -1, 1)
		r.icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		r.name = T:Text(r, 12)
		r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
		r.name:SetWidth(80); r.name:SetJustifyH("LEFT")
		r.debuff = T:Text(r, 11, T.C.muted)
		r.debuff:SetPoint("LEFT", r.name, "RIGHT", 4, 0)
		r.debuff:SetWidth(90); r.debuff:SetJustifyH("LEFT")
		r.timer = T:Text(r, 11)
		r.timer:SetPoint("RIGHT", r, "RIGHT", -2, 0)
		r:Hide()
		self.rows[i] = r
	end
	f:Hide()
	self.frame = f
	self:ApplyPosition()
	self:BuildCure()
	-- sorts de dispel appris / changés (spé, talents) : actions des petits cadres à jour
	local function respell() LL:ApplyCure() end
	VP:On("SPELLS_CHANGED", respell)
	VP:On("ACTIVE_TALENT_GROUP_CHANGED", respell)
	VP:On("PLAYER_TALENT_UPDATE", respell)
	local acc = 0
	local drv = CreateFrame("Frame")
	drv:SetScript("OnUpdate", function(_, e)
		acc = acc + e
		if acc < 0.2 then return end
		acc = 0
		LL:Update()
		LL:UpdateCure()
	end)
end
