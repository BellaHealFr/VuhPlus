-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Boîte à outils d'interface moderne (fenêtre de configuration)
local VP = VuhPlus
local UI = VP:NewModule("UI")
local T = VP.Theme

local COL2 = 316      -- position de la 2e colonne
local HALF_W = 290    -- largeur d'un élément en demi-colonne
local FULL_W = 600
local HEAD_H = 36     -- hauteur de l'en-tête d'une carte (section)
UI.FULL_W = FULL_W

-- bordure douce de l'interface (les icônes et les cadres de soin gardent leur bordure noire)
local function edge(f)
	local c = T.C.edge
	f:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
end
UI.Edge = edge

-- Icône du jeu, avec un point d'interrogation si la texture n'existe pas dans ce client
local QM = "Interface\\Icons\\INV_Misc_QuestionMark"
local function setIcon(tex, path)
	if not path or not tex:SetTexture(path) then tex:SetTexture(QM) end
end
UI.SetIcon = setIcon

-- Rectangle (fond + bordure 1 px) dessiné en textures sur la page : toujours SOUS les réglages
local function newBox(parent, bg, border)
	local b = { parent = parent, e = {} }
	b.bg = T:Tex(parent, "BACKGROUND", bg[1], bg[2], bg[3], bg[4] or 1)
	for i = 1, 4 do b.e[i] = T:Tex(parent, "BORDER", border[1], border[2], border[3], border[4] or 1) end
	function b:Set(x, y, w, h)
		local p, e = self.parent, self.e
		h = math.max(2, h)
		self.bg:ClearAllPoints(); self.bg:SetPoint("TOPLEFT", p, "TOPLEFT", x, y); self.bg:SetWidth(w); self.bg:SetHeight(h)
		e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT", p, "TOPLEFT", x, y); e[1]:SetWidth(w); e[1]:SetHeight(1)
		e[2]:ClearAllPoints(); e[2]:SetPoint("TOPLEFT", p, "TOPLEFT", x, y - h + 1); e[2]:SetWidth(w); e[2]:SetHeight(1)
		e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT", p, "TOPLEFT", x, y - 1); e[3]:SetWidth(1); e[3]:SetHeight(h - 2)
		e[4]:ClearAllPoints(); e[4]:SetPoint("TOPLEFT", p, "TOPLEFT", x + w - 1, y - 1); e[4]:SetWidth(1); e[4]:SetHeight(h - 2)
	end
	return b
end

-- Lien vers un autre onglet (« Dispel  » ») ; anchor : section à mettre en évidence
local function linkButton(parent, tabId, anchor, label)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(18)
	local t = T:Text(b, 12)
	t:SetPoint("LEFT", b, "LEFT", 0, 0)
	local tab = UI:TabById(tabId)
	t:SetText((label or (tab and tab.label) or tabId) .. "  »")
	T:RegisterAccent(t, "text")
	b:SetWidth(t:GetStringWidth() + 4)
	b:SetScript("OnEnter", function() t:SetTextColor(1, 1, 1) end)
	b:SetScript("OnLeave", function() local r, g, bl = T:Accent(); t:SetTextColor(r, g, bl) end)
	b:SetScript("OnClick", function() PlaySound("igMainMenuOptionCheckBoxOn"); UI:Go(tabId, anchor) end)
	return b
end
UI.LinkButton = linkButton

-- Page : réglages en une ou deux colonnes, rangés dans des cartes repliables ----------
-- Chaque élément garde sa position « naturelle » (baseY) ; Relayout le place en tenant
-- compte des cartes repliées au-dessus de lui.
local Page = {}
Page.__index = Page

function UI:NewPage(parent)
	local p = setmetatable({}, Page)
	p.frame = CreateFrame("Frame", nil, parent)
	p.frame:SetWidth(FULL_W + 32)
	p.frame:SetHeight(100)
	p.y = -18
	p.widgets = {}
	p.texts = {}     -- libellés des réglages, pour la recherche
	p.sections = {}  -- cartes
	p.anchors = {}   -- sections nommées (lien direct depuis l'accueil ou un autre onglet)
	return p
end

function Page:Place(f, h, half)
	f:ClearAllPoints()
	if half then
		if self.halfPending then
			f.vpX, f.baseY = 16 + COL2, self.halfY
			self.halfPending = false
			self.y = self.halfY - math.max(h, self.halfH)
		else
			self.halfY, self.halfH = self.y, h
			f.vpX, f.baseY = 16, self.y
			self.halfPending = true
			self.y = self.y - h
		end
	else
		self.halfPending = false
		f.vpX, f.baseY = 16, self.y
		self.y = self.y - h
	end
	f.vpSec = self.cur
	-- les notes et liens ne comptent pas dans « n réglages masqués »
	if self.cur and not self.noCount then self.cur.count = self.cur.count + 1 end
	self.noCount = nil
	f:SetPoint("TOPLEFT", self.frame, "TOPLEFT", f.vpX, f.baseY)
	table.insert(self.widgets, f)
	self.last = f
end

function Page:NoCount() self.noCount = true end

-- hauteur gagnée par les cartes repliées situées au-dessus de y
local function hiddenAbove(page, y)
	local off = 0
	for _, s in ipairs(page.sections) do
		if s.collapsed and s.bottom and s.bottom >= y then off = off + (s.top - s.bottom - HEAD_H) end
	end
	return off
end

function Page:Relayout()
	for _, w in ipairs(self.widgets) do
		local s = w.vpSec
		if s and s.collapsed then
			if not w.vpFolded then w.vpFolded = true; w:Hide() end
		else
			if w.vpFolded then w.vpFolded = nil; w:Show() end
			w:ClearAllPoints()
			w:SetPoint("TOPLEFT", self.frame, "TOPLEFT", w.vpX, w.baseY + hiddenAbove(self, w.baseY))
		end
	end
	for _, s in ipairs(self.sections) do
		if s.bottom then
			local top = s.top + hiddenAbove(self, s.top)
			local h = s.collapsed and HEAD_H or (s.top - s.bottom)
			s.box:Set(4, top, FULL_W + 24, h)
			s.head:ClearAllPoints()
			s.head:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 4, top)
			s.anchor:ClearAllPoints()
			s.anchor:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 4, top)
			s.anchor:SetHeight(h)
			if s.collapsed then s.sep:Hide() else s.sep:Show() end
			s.head:Refresh()
		end
	end
	if self.fullH then
		self.fullH = -self.y + 24 - hiddenAbove(self, self.y)
		self.frame:SetHeight(self.fullH)
	end
end

-- Un élément a changé de hauteur (delta > 0 : plus haut) : tout ce qui est en dessous se décale
function Page:Shift(f, delta)
	local y0 = f.baseY
	for _, w in ipairs(self.widgets) do
		if w ~= f and w.baseY and w.baseY < y0 then w.baseY = w.baseY - delta end
	end
	for _, s in ipairs(self.sections) do
		if s.top < y0 then s.top = s.top - delta end
		if s.bottom and s.bottom < y0 then s.bottom = s.bottom - delta end
	end
	self.y = self.y - delta
	self:Relayout()
end

function Page:Gap(h)
	self.halfPending = false
	self.y = self.y - (h or 8)
end

function Page:CloseSection()
	local s = self.cur
	if not s then return end
	self.halfPending = false
	self.y = self.y - 6
	s.bottom = self.y
	self.cur = nil
end

function Page:Finish()
	self:CloseSection()
	self.fullH = 0
	self:Relayout()
end

function Page:RefreshAll()
	for _, w in ipairs(self.widgets) do
		if w.Refresh then w:Refresh() end
	end
end

-- Titre de page
function Page:Title(title, desc)
	local f = CreateFrame("Frame", nil, self.frame)
	f:SetWidth(FULL_W)
	local t = T:Text(f, 22)
	t:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	t:SetText(title)
	local h = 26
	if desc then
		local d = T:Text(f, 13, T.C.muted)
		d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
		d:SetWidth(FULL_W)
		d:SetJustifyH("LEFT")
		d:SetText(desc)
		h = h + d:GetHeight() + 6
	end
	f:SetHeight(h)
	self:NoCount()
	self:Place(f, h + 4)
end

-- Section : une carte avec un en-tête cliquable (replier / déplier).
-- opts.adv : réglages avancés, repliés en mode « Essentiel » ; opts.key : lien direct ;
-- opts.desc : petit texte à droite de l'en-tête.
function Page:Section(text, opts)
	opts = opts or {}
	self:CloseSection()
	self:Gap(#self.sections > 0 and 10 or 4)
	local page = self
	local s = { adv = opts.adv, top = self.y, count = 0 }
	s.collapsed = (opts.adv and not UI:ShowAll()) and true or false
	s.box = newBox(self.frame, T.C.card, T.C.edge)
	s.sep = T:Tex(self.frame, "BORDER", 1, 1, 1, 0.05)
	s.sep:SetHeight(1)
	s.anchor = CreateFrame("Frame", nil, self.frame)
	s.anchor:SetWidth(FULL_W + 24); s.anchor:SetHeight(HEAD_H)
	s.anchor.vpSec = s
	local h = CreateFrame("Button", nil, self.frame)
	h:SetWidth(FULL_W + 24); h:SetHeight(HEAD_H)
	s.sep:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 1, 0)
	s.sep:SetPoint("TOPRIGHT", h, "BOTTOMRIGHT", -1, 0)
	local hl = T:Tex(h, "BACKGROUND", 1, 1, 1, 0.025)
	hl:SetPoint("TOPLEFT", h, "TOPLEFT", 1, -1)
	hl:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -1, 1)
	hl:Hide()
	local chev = T:Text(h, 15, T.C.muted)
	chev:SetPoint("LEFT", h, "LEFT", 12, 0)
	chev:SetWidth(10)
	local t = T:Text(h, 14)
	t:SetPoint("LEFT", h, "LEFT", 28, 0)
	t:SetText(text)
	if opts.adv then
		local badge = CreateFrame("Frame", nil, h)
		badge:SetHeight(16)
		T:Backdrop(badge, { 0, 0, 0, 0 }, T.C.edge)
		local bt = T:Text(badge, 10, T.C.muted)
		bt:SetPoint("CENTER", badge, "CENTER", 0, 0)
		bt:SetText("AVANCÉ")
		badge:SetWidth(bt:GetStringWidth() + 12)
		badge:SetPoint("LEFT", t, "RIGHT", 10, 0)
	end
	local sum = T:Text(h, 12, T.C.muted)
	sum:SetPoint("RIGHT", h, "RIGHT", -14, 0)
	sum:SetJustifyH("RIGHT")
	function h:Refresh()
		chev:SetText(s.collapsed and "+" or "-")
		if s.collapsed then
			sum:SetText(s.count .. (s.count > 1 and " réglages repliés" or " réglage replié"))
		else
			sum:SetText(opts.desc or "")
		end
	end
	h:SetScript("OnEnter", function() hl:Show(); chev:SetTextColor(1, 1, 1) end)
	h:SetScript("OnLeave", function() hl:Hide(); chev:SetTextColor(T.C.muted[1], T.C.muted[2], T.C.muted[3]) end)
	h:SetScript("OnClick", function()
		s.collapsed = not s.collapsed
		PlaySound("igMainMenuOptionCheckBoxOn")
		page:Relayout()
		UI:UpdateScrollBar()
	end)
	s.head = h
	table.insert(self.sections, s)
	if opts.key then self.anchors[opts.key] = s.anchor end
	self.cur = s
	self.y = self.y - HEAD_H - 10
	self.last = s.anchor
end

-- Texte libre (dynamique si getText fourni)
function Page:Note(text, getText)
	local f = CreateFrame("Frame", nil, self.frame)
	f:SetWidth(FULL_W)
	local t = T:Text(f, 12, T.C.muted)
	t:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	t:SetWidth(FULL_W); t:SetJustifyH("LEFT")
	-- texte dynamique : on le calcule tout de suite pour réserver la bonne hauteur
	local first = text
	if not first and getText then
		local ok, res = pcall(getText)
		first = ok and res or nil
	end
	t:SetText(first or "")
	f:SetHeight(math.max(16, t:GetHeight()))
	local page = self
	if getText then
		f.Refresh = function()
			t:SetText(getText())
			-- le texte a changé de hauteur (liste qui s'allonge...) : la suite de la page se décale
			local newH = math.max(16, t:GetHeight() or 16)
			local delta = newH - f:GetHeight()
			if math.abs(delta) > 0.5 then
				f:SetHeight(newH)
				page:Shift(f, delta)
			end
		end
	end
	self:NoCount()
	self:Place(f, f:GetHeight() + 8)
	return f
end

-- Lien vers le réglage d'un autre onglet : « La police se règle dans  Style  » »
function Page:Link(text, tabId, anchor, label)
	local f = CreateFrame("Frame", nil, self.frame)
	f:SetWidth(FULL_W); f:SetHeight(28)
	T:Backdrop(f, { 1, 1, 1, 0.02 }, T.C.edge)
	local t = T:Text(f, 12, T.C.muted)
	t:SetPoint("LEFT", f, "LEFT", 10, 0)
	t:SetText(text)
	local b = linkButton(f, tabId, anchor, label)
	b:SetPoint("LEFT", t, "RIGHT", 8, 0)
	self:NoCount()
	self:Place(f, 36)
	return f
end

-- Interrupteur. tip : explication (affichée sous le libellé en pleine largeur, au survol en
-- demi-colonne) ; link = { tabId, anchor, libellé } : lien vers la page qui possède ce réglage.
function Page:Toggle(label, get, set, half, tip, link)
	local w = half and HALF_W or FULL_W
	local b = CreateFrame("Button", nil, self.frame)
	b:SetWidth(w)
	local track = CreateFrame("Frame", nil, b)
	track:SetWidth(32); track:SetHeight(16)
	T:Backdrop(track, T.C.control, T.C.edge)
	local knob = T:Tex(track, "OVERLAY", 0.5, 0.52, 0.57)
	knob:SetWidth(10); knob:SetHeight(10)
	local lk, lkw = nil, 0
	if link then
		lk = linkButton(b, link[1], link[2], link[3])
		lkw = lk:GetWidth() + 12
	end
	local txt = T:Text(b, 13)
	txt:SetJustifyH("LEFT")
	txt:SetWidth(w - 42 - lkw)
	local inline = tip and not half
	local h = 24
	if inline then
		track:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -3)
		txt:SetPoint("TOPLEFT", b, "TOPLEFT", 42, -3)
		txt:SetText(label)
		local d = T:Text(b, 12, T.C.muted)
		d:SetPoint("TOPLEFT", txt, "BOTTOMLEFT", 0, -3)
		d:SetWidth(w - 42 - lkw); d:SetJustifyH("LEFT")
		d:SetText(tip)
		h = math.max(24, 3 + (txt:GetHeight() or 14) + 3 + d:GetHeight() + 2)
		if lk then lk:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, -2) end
	else
		track:SetPoint("LEFT", b, "LEFT", 0, 0)
		txt:SetPoint("LEFT", b, "LEFT", 42, 0)
		txt:SetText(tip and (label .. "  |cff6f7581(?)|r") or label)
		if lk then lk:SetPoint("RIGHT", b, "RIGHT", 0, 0) end
	end
	b:SetHeight(h)
	function b:Refresh()
		local on = get()
		knob:ClearAllPoints()
		if on then
			knob:SetPoint("RIGHT", track, "RIGHT", -3, 0)
			local r, g, bl = T:Accent()
			knob:SetVertexColor(1, 1, 1)
			track:SetBackdropColor(r, g, bl, 1)
			track:SetBackdropBorderColor(r, g, bl, 1)
		else
			knob:SetPoint("LEFT", track, "LEFT", 3, 0)
			knob:SetVertexColor(0.5, 0.52, 0.57)
			local c = T.C.control
			track:SetBackdropColor(c[1], c[2], c[3], 1)
			edge(track)
		end
	end
	b:SetScript("OnClick", function(self)
		set(not get())
		PlaySound("igMainMenuOptionCheckBoxOn")
		self:Refresh()
		UI:RefreshNav()
	end)
	b:SetScript("OnEnter", function(self)
		txt:SetTextColor(1, 1, 1)
		if tip and not inline then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(label)
			GameTooltip:AddLine(tip, 0.8, 0.8, 0.85, true)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function()
		txt:SetTextColor(T.C.text[1], T.C.text[2], T.C.text[3])
		GameTooltip:Hide()
	end)
	self:Place(b, h + 6, half)
	b:Refresh()
	return b
end

-- Curseur moderne
function Page:Slider(label, minv, maxv, step, get, set, suffix, half)
	local f = CreateFrame("Frame", nil, self.frame)
	local w = half and HALF_W - 20 or FULL_W - 20
	f:SetWidth(w); f:SetHeight(40)
	local txt = T:Text(f, 13)
	txt:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	txt:SetText(label)
	local val = T:Text(f, 13)
	T:RegisterAccent(val, "text")
	local s = CreateFrame("Slider", nil, f)
	s:SetOrientation("HORIZONTAL")
	s:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -22)
	s:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -22)
	s:SetHeight(14)
	s:EnableMouse(true)
	s:EnableMouseWheel(true)
	s:SetMinMaxValues(minv, maxv)
	s:SetValueStep(step)
	local track = T:Tex(s, "BACKGROUND", 0.17, 0.185, 0.215, 1)
	track:SetHeight(4)
	track:SetPoint("LEFT", s, "LEFT", 0, 0)
	track:SetPoint("RIGHT", s, "RIGHT", 0, 0)
	s:SetThumbTexture(T.TEX)
	local thumb = s:GetThumbTexture()
	thumb:SetWidth(8); thumb:SetHeight(14)
	thumb:SetVertexColor(1, 1, 1)
	local fill = T:Tex(s, "ARTWORK")
	fill:SetHeight(4)
	fill:SetPoint("LEFT", track, "LEFT", 0, 0)
	fill:SetPoint("RIGHT", thumb, "CENTER", 0, 0)
	T:RegisterAccent(fill)
	-- valeur affichée arrondie au pas du curseur (évite « 1.1111111 % »)
	local dec = (step < 1) and (step < 0.1 and 2 or 1) or 0
	local function show(v)
		v = math.floor(v / step + 0.5) * step
		val:SetText((dec > 0 and string.format("%." .. dec .. "f", v) or tostring(math.floor(v + 0.5))) .. (suffix or ""))
		if f.fitLabel then f.fitLabel() end
	end
	function f:Refresh()
		s.loading = true
		s:SetValue(get())
		show(get())
		s.last = get()
		s.loading = nil
	end
	s:SetScript("OnValueChanged", function(self, v)
		v = math.floor(v / step + 0.5) * step
		show(v)
		if not self.loading and v ~= self.last then
			self.last = v
			set(v)
		end
	end)
	-- molette : fait défiler la page (sinon on change les réglages par accident en descendant) ;
	-- Maj + molette : règle le curseur
	s:SetScript("OnMouseWheel", function(self, delta)
		if not IsShiftKeyDown() then
			local sc = UI.scroll
			local fn = sc and sc:GetScript("OnMouseWheel")
			if fn then fn(sc, delta) end
			return
		end
		local v = self:GetValue() + delta * step
		self:SetValue(math.max(minv, math.min(maxv, v)))
	end)
	-- boutons - / + (réglage précis au clic)
	local function nudge(dir)
		local v = math.max(minv, math.min(maxv, s:GetValue())) + dir * step
		s:SetValue(math.max(minv, math.min(maxv, v)))
	end
	local plus = UI:Button(f, "+", 20, function() nudge(1) end)
	plus:SetHeight(18)
	plus:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 1)
	local minus = UI:Button(f, "-", 20, function() nudge(-1) end)
	minus:SetHeight(18)
	minus:SetPoint("RIGHT", plus, "LEFT", -3, 0)
	val:SetPoint("RIGHT", minus, "LEFT", -8, 0)
	-- le libellé s'arrête avant la valeur
	txt:SetHeight(16)
	txt:SetJustifyH("LEFT")
	f.fitLabel = function()
		txt:SetWidth(math.max(60, w - (val:GetStringWidth() or 0) - 64))
	end
	f.fitLabel()
	self:Place(f, 50, half)
	f:Refresh()
	return f
end

-- Bouton plat ; accent = bouton principal (plein, couleur d'accent)
function UI:Button(parent, label, width, onClick, accent)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(width or 140); b:SetHeight(26)
	T:Backdrop(b, T.C.control, T.C.edge)
	local txt = T:Text(b, 12)
	txt:SetPoint("CENTER", b, "CENTER", 0, 0)
	txt:SetText(label)
	b.text = txt
	b.accent = accent
	if accent then
		T:RegisterAccent(b, "backdrop")
		local c = T.C.onAccent
		txt:SetTextColor(c[1], c[2], c[3])
		txt:SetShadowOffset(0, 0)
	end
	b:SetScript("OnEnter", function(self)
		if self.accent then
			self.vpHover = true
			local r, g, bl = T:Accent()
			self:SetBackdropColor(math.min(1, r + 0.12), math.min(1, g + 0.12), math.min(1, bl + 0.12), 1)
		else
			self:SetBackdropColor(T.C.hover[1], T.C.hover[2], T.C.hover[3], 1)
			if not self.waiting then self:SetBackdropBorderColor(T:Accent()) end
		end
	end)
	b:SetScript("OnLeave", function(self)
		if self.value ~= nil and self:GetParent().Refresh then self:GetParent():Refresh() return end
		if self.accent then
			self.vpHover = nil
			local r, g, bl = T:Accent()
			self:SetBackdropColor(r, g, bl, 1)
		else
			self:SetBackdropColor(T.C.control[1], T.C.control[2], T.C.control[3], 1)
			if self.waiting then return end
			if self.Refresh then self:Refresh() else edge(self) end
		end
	end)
	b:SetScript("OnClick", function(self, ...) PlaySound("igMainMenuOptionCheckBoxOn"); onClick(self, ...) end)
	return b
end

-- Rangée de boutons
function Page:Buttons(list)
	local f = CreateFrame("Frame", nil, self.frame)
	f:SetWidth(FULL_W); f:SetHeight(28)
	local x = 0
	for _, def in ipairs(list) do
		local b = UI:Button(f, def[1], def[3] or 150, def[2], def[4])
		b:SetPoint("LEFT", f, "LEFT", x, 0)
		x = x + (def[3] or 150) + 8
	end
	self:NoCount()
	self:Place(f, 36)
	return f
end

-- Tâches de l'accueil : « Que voulez-vous faire ? » ; chaque tâche ouvre la bonne page
-- { label, where, tab, anchor, icon }
function Page:Tasks(list)
	local f = CreateFrame("Frame", nil, self.frame)
	local w = math.floor((FULL_W - 8) / 2)
	f:SetWidth(FULL_W)
	for i, tk in ipairs(list) do
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		local b = CreateFrame("Button", nil, f)
		b:SetWidth(w); b:SetHeight(44)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", col * (w + 8), -row * 50)
		T:Backdrop(b, T.C.control, T.C.edge)
		local ic = b:CreateTexture(nil, "ARTWORK")
		ic:SetWidth(26); ic:SetHeight(26)
		ic:SetPoint("LEFT", b, "LEFT", 10, 0)
		ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		setIcon(ic, tk.icon)
		local l = T:Text(b, 13)
		l:SetPoint("TOPLEFT", b, "TOPLEFT", 46, -8)
		l:SetWidth(w - 54); l:SetHeight(15); l:SetJustifyH("LEFT")
		l:SetText(tk.label)
		local wh = T:Text(b, 11)
		wh:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -2)
		wh:SetWidth(w - 54); wh:SetHeight(13); wh:SetJustifyH("LEFT")
		wh:SetText(tk.where)
		T:RegisterAccent(wh, "text")
		b:SetScript("OnEnter", function(self)
			self:SetBackdropColor(T.C.hover[1], T.C.hover[2], T.C.hover[3], 1)
			self:SetBackdropBorderColor(T:Accent())
		end)
		b:SetScript("OnLeave", function(self)
			self:SetBackdropColor(T.C.control[1], T.C.control[2], T.C.control[3], 1)
			edge(self)
		end)
		b:SetScript("OnClick", function()
			PlaySound("igMainMenuOptionCheckBoxOn")
			UI:Go(tk.tab, tk.anchor)
		end)
	end
	local rows = math.ceil(#list / 2)
	f:SetHeight(rows * 50)
	self:NoCount()
	self:Place(f, rows * 50 + 4)
	return f
end

-- Liste déroulante -----------------------------------------------------------------
local popup
local function closePopup() if popup then popup:Hide() end end
UI.ClosePopup = closePopup

local function openPopup(owner, choices, get, set, onPick)
	if not popup then
		popup = CreateFrame("Frame", "VuhPlusDropdownPopup", UIParent)
		popup:SetFrameStrata("FULLSCREEN_DIALOG")
		popup:EnableMouse(true)
		T:Backdrop(popup, T.C.panel, T.C.edge)
		popup.items = {}
	end
	for _, it in ipairs(popup.items) do it:Hide() end
	-- largeur de colonne : au moins celle du bouton, assez pour le plus long libellé
	local w = owner:GetWidth()
	for i, ch in ipairs(choices) do
		local it = popup.items[i]
		if not it then
			it = CreateFrame("Button", nil, popup)
			it:SetHeight(22)
			it.text = T:Text(it, 12)
			it.text:SetPoint("LEFT", it, "LEFT", 10, 0)
			it.text:SetJustifyH("LEFT")
			it.hl = T:Tex(it, "BACKGROUND", 1, 1, 1, 0.06)
			it.hl:SetAllPoints(it)
			it.hl:Hide()
			it.mark = T:Tex(it, "ARTWORK")
			it.mark:SetWidth(3)
			it.mark:SetPoint("TOPLEFT", it, "TOPLEFT", 0, 0)
			it.mark:SetPoint("BOTTOMLEFT", it, "BOTTOMLEFT", 0, 0)
			T:RegisterAccent(it.mark)
			it:SetScript("OnEnter", function(self) self.hl:Show() end)
			it:SetScript("OnLeave", function(self) self.hl:Hide() end)
			popup.items[i] = it
		end
		it.text:SetWidth(0)
		it.text:SetText(ch[2])
		local sw = it.text:GetStringWidth() or 0
		if sw + 24 > w then w = sw + 24 end
	end
	w = math.min(w, 340)
	for i, ch in ipairs(choices) do
		local it = popup.items[i]
		-- longues listes : plusieurs colonnes de 15 lignes
		local col = math.floor((i - 1) / 15)
		local row = (i - 1) % 15
		it:SetWidth(w - 2)
		it.text:SetWidth(w - 16)
		it:ClearAllPoints()
		it:SetPoint("TOPLEFT", popup, "TOPLEFT", 1 + col * w, -1 - row * 22)
		if ch[1] == get() then it.mark:Show() else it.mark:Hide() end
		it:SetScript("OnClick", function()
			set(ch[1])
			closePopup()
			if onPick then onPick() end
		end)
		it:Show()
	end
	local cols = math.ceil(#choices / 15)
	popup:SetWidth(w * cols)
	popup:SetHeight(math.min(#choices, 15) * 22 + 2)
	popup:SetClampedToScreen(true)
	popup:ClearAllPoints()
	-- trop large pour s'ouvrir vers la droite : on l'aligne sur le bord droit du bouton
	local right = (owner:GetRight() or 0) + w * cols
	if cols > 1 and right > (UIParent:GetRight() or 99999) then
		popup:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -2)
	else
		popup:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
	end
	popup.owner = owner
	popup:Show()
end
UI.OpenPopup = function(...) return openPopup(...) end

-- choices : liste { valeur, libellé }, ou fonction qui la renvoie (liste relue à chaque ouverture)
function Page:Dropdown(label, choicesArg, get, set, half)
	local function list()
		local c = type(choicesArg) == "function" and choicesArg() or choicesArg
		if not c or #c == 0 then c = { { "", "(aucun)" } } end
		return c
	end
	local f = CreateFrame("Frame", nil, self.frame)
	local w = half and HALF_W - 20 or 300
	f:SetWidth(w); f:SetHeight(46)
	local txt = T:Text(f, 12, T.C.muted)
	txt:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	txt:SetText(label)
	local b = CreateFrame("Button", nil, f)
	b:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -18)
	b:SetWidth(w); b:SetHeight(26)
	T:Backdrop(b, T.C.control, T.C.edge)
	local arrow = T:Text(b, 12, T.C.muted)
	arrow:SetPoint("RIGHT", b, "RIGHT", -10, 0)
	arrow:SetText("v")
	-- texte limité à la largeur du bouton (coupé avec « ... » au lieu de déborder)
	local val = T:Text(b, 12)
	val:SetPoint("LEFT", b, "LEFT", 10, 0)
	val:SetPoint("RIGHT", arrow, "LEFT", -6, 0)
	val:SetHeight(14)
	val:SetJustifyH("LEFT")
	function f:Refresh()
		local cur = get()
		local choices = list()
		for _, ch in ipairs(choices) do
			if ch[1] == cur then val:SetText(ch[2]) return end
		end
		val:SetText(choices[1][2])
	end
	b:SetScript("OnClick", function(self)
		if popup and popup:IsShown() and popup.owner == self then closePopup() return end
		openPopup(self, list(), get, set, function() f:Refresh() end)
	end)
	b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(T:Accent()) end)
	b:SetScript("OnLeave", function(self) edge(self) end)
	self:Place(f, 52, half)
	f:Refresh()
	return f
end

-- Champ de texte -------------------------------------------------------------------
function UI:EditBox(parent, width)
	local e = CreateFrame("EditBox", nil, parent)
	e:SetWidth(width); e:SetHeight(24)
	e:SetAutoFocus(false)
	e:SetFontObject(ChatFontNormal)
	e:SetFont(T.FONT, 12, "")
	e:SetTextInsets(8, 8, 0, 0)
	e:SetTextColor(T.C.text[1], T.C.text[2], T.C.text[3])
	T:Backdrop(e, T.C.control, T.C.edge)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(T:Accent()) end)
	e:HookScript("OnEditFocusLost", function(self) edge(self) end)
	return e
end

function Page:Input(label, get, set, width)
	local f = CreateFrame("Frame", nil, self.frame)
	f:SetWidth(FULL_W); f:SetHeight(24)
	local txt = T:Text(f, 13)
	txt:SetPoint("LEFT", f, "LEFT", 0, 0)
	txt:SetWidth(180); txt:SetJustifyH("LEFT")
	txt:SetText(label)
	local e = UI:EditBox(f, width or 300)
	e:SetPoint("LEFT", f, "LEFT", 186, 0)
	f.edit = e
	if get then
		function f:Refresh() e:SetText(get() or "") end
		e:SetScript("OnEnterPressed", function(self) set(self:GetText()); self:ClearFocus() end)
		e:SetScript("OnEditFocusLost", function(self) set(self:GetText()) end)
		f:Refresh()
	else
		e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	end
	self:Place(f, 30)
	return f
end

-- Zone de texte sur plusieurs lignes (avec défilement) ; set() à la perte du focus
function Page:TextArea(get, set, height)
	local f = CreateFrame("Frame", nil, self.frame)
	f:SetWidth(FULL_W); f:SetHeight(height or 140)
	T:Backdrop(f, { 0.03, 0.03, 0.04, 1 }, T.C.edge)
	local sf = CreateFrame("ScrollFrame", nil, f)
	sf:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
	sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6)
	local e = CreateFrame("EditBox", nil, sf)
	e:SetMultiLine(true)
	e:SetAutoFocus(false)
	e:SetMaxLetters(4000)
	e:SetWidth(FULL_W - 14)
	e:SetFontObject(ChatFontNormal)
	e:SetTextInsets(2, 2, 2, 2)
	sf:SetScrollChild(e)
	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", function(s, delta)
		s:SetVerticalScroll(math.max(0, math.min(s:GetVerticalScrollRange(), s:GetVerticalScroll() - delta * 20)))
	end)
	e:SetScript("OnCursorChanged", function(_, x, y, w, h)
		local top, cur, hgt = -y, sf:GetVerticalScroll(), sf:GetHeight()
		if top < cur then sf:SetVerticalScroll(top)
		elseif top + h > cur + hgt then sf:SetVerticalScroll(top + h - hgt) end
	end)
	e:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
	e:SetScript("OnEditFocusGained", function() f:SetBackdropBorderColor(T:Accent()) end)
	e:SetScript("OnEditFocusLost", function(s)
		edge(f)
		if set then set(s:GetText()) end
	end)
	f:EnableMouse(true)
	f:SetScript("OnMouseDown", function() e:SetFocus() end)
	f.edit = e
	function f:Refresh() if get and GetCurrentKeyBoardFocus() ~= e then e:SetText(get() or "") end end
	f:Refresh()
	self:Place(f, (height or 140) + 8)
	return f
end

-- Case d'action de clic : texte + glisser-déposer depuis le grimoire
function UI:ActionEdit(parent, width, get, set)
	local e = UI:EditBox(parent, width)
	local function commit(self)
		set(VP.Clicks:FromText(self:GetText()))
		if InCombatLockdown() then VP:Print("Enregistré : appliqué à la fin du combat.") end
	end
	local function drop(self)
		local kind, slot, book = GetCursorInfo()
		if kind == "macro" and VP.Macros then
			-- macro du jeu glissée sur une case : importée dans la bibliothèque puis assignée
			ClearCursor()
			local m = VP.Macros:ImportGame(slot)
			if m then
				self:SetText("M:" .. m.name)
				commit(self)
				self:ClearFocus()
			end
			return
		end
		if kind ~= "spell" then return end
		local spellName = GetSpellName(slot, book)
		ClearCursor()
		if spellName then
			self:SetText(spellName)
			commit(self)
			self:ClearFocus()
		end
	end
	e.Refresh = function(self) self:SetText(VP.Clicks:ToText(get())) end
	e:SetScript("OnEnterPressed", function(self) commit(self); self:ClearFocus() end)
	e:SetScript("OnEditFocusLost", commit)
	e:SetScript("OnReceiveDrag", drop)
	e:SetScript("OnMouseUp", function(self) local k = GetCursorInfo(); if k == "spell" or k == "macro" then drop(self) end end)
	e:Refresh()
	return e
end

function Page:Action(label, get, set)
	local f = CreateFrame("Frame", nil, self.frame)
	f:SetWidth(FULL_W); f:SetHeight(24)
	local txt = T:Text(f, 13)
	txt:SetPoint("LEFT", f, "LEFT", 0, 0)
	txt:SetText(label)
	local e = UI:ActionEdit(f, 330, get, set)
	e:SetPoint("LEFT", f, "LEFT", 186, 0)
	function f:Refresh() e:Refresh() end
	self:Place(f, 28)
	return f
end

-- Ligne de clic : [touche] [icône] [sort] [état]
local function statusParts(f)
	f.icon = CreateFrame("Frame", nil, f)
	f.icon:SetWidth(22); f.icon:SetHeight(22)
	T:Backdrop(f.icon, { 0, 0, 0, 1 }, { 0, 0, 0, 1 })
	f.icon.tex = f.icon:CreateTexture(nil, "ARTWORK")
	f.icon.tex:SetPoint("TOPLEFT", f.icon, "TOPLEFT", 1, -1)
	f.icon.tex:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT", -1, 1)
	f.icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.status = T:Text(f, 11)
	f.status:SetJustifyH("LEFT")
	function f:UpdateStatus(val)
		local icon, text, ok = VP.Clicks:Describe(val)
		if icon then self.icon.tex:SetTexture(icon); self.icon.tex:Show() else self.icon.tex:Hide() end
		if ok then
			-- type d'action, comme VuhDo : Sort / Commande / Macro / Objet / Dispel
			self.status:SetText("|cff55dd77" .. VP.Clicks:TypeLabel(val) .. "|r")
		else
			self.status:SetText(text or "")
		end
	end
end

function Page:Binding(label, get, set)
	local f = CreateFrame("Frame", nil, self.frame)
	f:SetWidth(FULL_W); f:SetHeight(28)
	local chip = CreateFrame("Frame", nil, f)
	chip:SetWidth(150); chip:SetHeight(24)
	chip:SetPoint("LEFT", f, "LEFT", 0, 0)
	T:Backdrop(chip, T.C.panel, T.C.edge)
	local ct = T:Text(chip, 12)
	ct:SetPoint("LEFT", chip, "LEFT", 8, 0)
	ct:SetText(label)
	statusParts(f)
	f.icon:SetPoint("LEFT", f, "LEFT", 158, 0)
	local e = UI:ActionEdit(f, 250, get, function(v) set(v); f:UpdateStatus(v) end)
	e:SetPoint("LEFT", f, "LEFT", 186, 0)
	f.status:SetPoint("LEFT", f, "LEFT", 444, 0)
	f.status:SetWidth(110)
	function f:Refresh() e:Refresh(); self:UpdateStatus(get()) end
	f:Refresh()
	self:Place(f, 30)
	return f
end

-- Pastilles de choix (une seule sélectionnée), sur plusieurs lignes
function Page:Chips(label, choices, get, set, perRow)
	perRow = perRow or 4
	local f = CreateFrame("Frame", nil, self.frame)
	f:SetWidth(FULL_W)
	local txt = T:Text(f, 13)
	txt:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	txt:SetText(label or "")
	local top = label and -20 or 0
	local w = math.floor((FULL_W - (perRow - 1) * 6) / perRow)
	f.chips = {}
	for i, ch in ipairs(choices) do
		local col = (i - 1) % perRow
		local row = math.floor((i - 1) / perRow)
		local b = UI:Button(f, ch[2], w, function()
			set(ch[1])
			UI:RefreshCurrent()
		end)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", col * (w + 6), top - row * 30)
		b.value = ch[1]
		f.chips[i] = b
	end
	local rows = math.ceil(#choices / perRow)
	f:SetHeight(-top + rows * 30)
	function f:Refresh()
		local cur = get()
		for _, b in ipairs(self.chips) do
			if b.value == cur then
				b:SetBackdropBorderColor(T:Accent())
				b:SetBackdropColor(T.C.hover[1], T.C.hover[2], T.C.hover[3], 1)
				b.text:SetTextColor(1, 1, 1)
			else
				edge(b)
				b:SetBackdropColor(T.C.control[1], T.C.control[2], T.C.control[3], 1)
				b.text:SetTextColor(T.C.muted[1], T.C.muted[2], T.C.muted[3])
			end
		end
	end
	f:Refresh()
	self:Place(f, f:GetHeight() + 8)
	return f
end

-- Emplacement de HoT : [Emplacement N] [icône] [sort] [Les miens] [Des autres] [couleur]
local function toggleChip(parent, label, width, get, set)
	local b = UI:Button(parent, label, width, function() set(not get()); end)
	function b:Refresh()
		if get() then
			self:SetBackdropBorderColor(T:Accent())
			self.text:SetTextColor(1, 1, 1)
		else
			edge(self)
			self.text:SetTextColor(T.C.muted[1], T.C.muted[2], T.C.muted[3])
		end
	end
	b:HookScript("OnClick", function(self) self:Refresh() end)
	b:Refresh()
	return b
end

-- Schéma de position (comme VuhDo) : une barre et 13 pastilles autour / dedans
function Page:PositionPicker(label, getPos, setPos)
	local f = CreateFrame("Frame", nil, self.frame)
	f:SetWidth(FULL_W); f:SetHeight(150)
	local txt = T:Text(f, 13)
	txt:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	if type(label) == "function" then f.labelFn = label else txt:SetText(label) end
	local rect = CreateFrame("Frame", nil, f)
	rect:SetWidth(200); rect:SetHeight(70)
	rect:SetPoint("TOPLEFT", f, "TOPLEFT", 60, -42)
	T:Backdrop(rect, { 0.2, 0.6, 0.3, 0.55 }, T.C.edge)
	local rt = T:Text(rect, 11, T.C.muted)
	rt:SetPoint("CENTER", rect, "CENTER", 0, 0)
	rt:SetText("barre de vie")
	f.dots = {}
	for _, pe in ipairs(VP.Frames.POS_LIST) do
		local key = pe[1]
		local p = VP.Frames.POS[key]
		local d = CreateFrame("Button", nil, f)
		d:SetWidth(16); d:SetHeight(16)
		local mul = p[5] and 4 or 3
		d:SetPoint(p[1], rect, p[2], p[3] * mul, p[4] * mul)
		T:Backdrop(d, T.C.control, T.C.edge)
		d:SetFrameLevel(rect:GetFrameLevel() + 2)
		d.key = key
		d:SetScript("OnClick", function()
			setPos(key)
			PlaySound("igMainMenuOptionCheckBoxOn")
			UI:RefreshCurrent()
		end)
		d:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(pe[2])
			GameTooltip:Show()
		end)
		d:SetScript("OnLeave", function() GameTooltip:Hide() end)
		f.dots[#f.dots + 1] = d
	end
	local cur = T:Text(f, 12)
	cur:SetPoint("TOPLEFT", f, "TOPLEFT", 300, -60)
	cur:SetWidth(250); cur:SetJustifyH("LEFT")
	function f:Refresh()
		if self.labelFn then txt:SetText(self.labelFn()) end
		local pos = getPos()
		local name = pos
		for _, pe in ipairs(VP.Frames.POS_LIST) do if pe[1] == pos then name = pe[2] end end
		cur:SetText("Position choisie :\n|cffffffff" .. (name or "?") .. "|r\n\n|cff999999Cliquez une pastille autour\nou dans la barre.|r")
		for _, d in ipairs(self.dots) do
			if d.key == pos then
				local r, g, b = T:Accent()
				d:SetBackdropColor(r, g, b, 1)
				d:SetBackdropBorderColor(1, 1, 1, 1)
			else
				d:SetBackdropColor(T.C.control[1], T.C.control[2], T.C.control[3], 1)
				edge(d)
			end
		end
	end
	f:Refresh()
	self:Place(f, 158)
	return f
end

-- Placement précis à la souris : une copie agrandie d'un cadre de soin où chaque icône
-- se glisse exactement où on veut (précision au pixel), avec flèches pour ajuster d'1 pixel.
-- api : list() -> clés ; info(key) -> pos, offX%, offY%, largeur, hauteur, texture, nom
--       selected() / select(key) ; setOff(key, x%, y%) ; commit()
local ANCH = {
	TOPLEFT = { 0, 0 }, TOP = { 0.5, 0 }, TOPRIGHT = { 1, 0 },
	LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 1 }, BOTTOM = { 0.5, 1 }, BOTTOMRIGHT = { 1, 1 },
}
function Page:HotDesigner(api)
	local f = CreateFrame("Frame", nil, self.frame)
	local CANVAS_H = 190
	f:SetWidth(FULL_W); f:SetHeight(CANVAS_H + 64)
	local canvas = CreateFrame("Frame", nil, f)
	canvas:SetWidth(FULL_W); canvas:SetHeight(CANVAS_H)
	canvas:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	T:Backdrop(canvas, { 0.05, 0.05, 0.065, 1 }, T.C.edge)
	-- le cadre agrandi
	local frame = CreateFrame("Frame", nil, canvas)
	T:Backdrop(frame, { 0, 0, 0, 1 }, { 0, 0, 0, 1 })
	local bar = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
	bar:SetTexture(T.TEX); bar:SetVertexColor(0.2, 0.62, 0.32, 1)
	local mana = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
	mana:SetTexture(T.TEX); mana:SetVertexColor(0.25, 0.52, 1, 1)
	local nameTxt = T:Text(frame, 13)
	nameTxt:SetText("Nom du joueur")
	nameTxt:SetTextColor(1, 1, 1, 0.35)
	-- grille d'aide (tous les 10 px du vrai cadre)
	local grid = {}
	local info = T:Text(f, 12)
	info:SetPoint("TOPLEFT", canvas, "BOTTOMLEFT", 0, -8)
	info:SetWidth(FULL_W - 240); info:SetJustifyH("LEFT")
	local help = T:Text(f, 11, T.C.muted)
	help:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -4)
	help:SetWidth(FULL_W - 240); help:SetJustifyH("LEFT")
	help:SetText("Glisser : déplacer. Molette sur l'icône : taille (Maj : 4 px). Flèches : 1 px (Maj : 5 px).")
	f.icons = {}
	local S, W, FH, barH = 3, 80, 40, 32

	-- rectangle d'une icône dans le vrai cadre (pixels, y vers le bas)
	local function rect(pos, x, y, w, h)
		local p = VP.Frames.POS[pos] or VP.Frames.POS.C
		local rl, rt, rr, rb
		if p[5] then rl, rt, rr, rb = 0, 0, W, FH else rl, rt, rr, rb = 1, 1, W - 1, 1 + barH end
		local ra, ia = ANCH[p[2]] or ANCH.CENTER, ANCH[p[1]] or ANCH.CENTER
		local px = rl + ra[1] * (rr - rl) + p[3] + x * W / 100
		local py = rt + ra[2] * (rb - rt) - (p[4] + y * FH / 100)
		return px - ia[1] * w, py - ia[2] * h
	end

	local function getIcon(i)
		local ic = f.icons[i]
		if ic then return ic end
		ic = CreateFrame("Button", nil, frame)
		T:Backdrop(ic, { 0, 0, 0, 1 }, { 0, 0, 0, 1 })
		ic.tex = ic:CreateTexture(nil, "ARTWORK")
		ic.tex:SetPoint("TOPLEFT", ic, "TOPLEFT", 1, -1)
		ic.tex:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT", -1, 1)
		ic.num = T:Text(ic, 11, nil, "OUTLINE")
		ic.num:SetPoint("TOPLEFT", ic, "TOPLEFT", 1, -1)
		ic:RegisterForClicks("LeftButtonUp")
		ic:EnableMouseWheel(true)
		ic:SetScript("OnMouseWheel", function(self, delta)
			if not api.setSize then return end
			api.select(self.key)
			local _, _, _, w = api.info(self.key)
			local step = IsShiftKeyDown() and 4 or 1
			api.setSize(self.key, math.max(6, math.min(64, math.floor(w + 0.5) + delta * step)))
			api.commit()
			UI:RefreshCurrent()
		end)
		ic:SetScript("OnMouseDown", function(self, button)
			if button and button ~= "LeftButton" then return end
			api.select(self.key)
			self.lx, self.ly, self.moved = nil, nil, nil
			local cx, cy = GetCursorPosition()
			local es = self:GetEffectiveScale()
			local _, x, y = api.info(self.key)
			self.drag = { cx = cx / es, cy = cy / es, x = x, y = y }
			UI:RefreshCurrent()
		end)
		ic:SetScript("OnMouseUp", function(self)
			if self.drag then
				self.drag = nil
				if self.moved then api.commit() end   -- simple clic = sélection, rien à appliquer
				UI:RefreshCurrent()
			end
		end)
		ic:SetScript("OnUpdate", function(self)
			local dg = self.drag
			if not dg then return end
			if not IsMouseButtonDown("LeftButton") then
				self.drag = nil
				if self.moved then api.commit() end
				UI:RefreshCurrent()
				return
			end
			local cx, cy = GetCursorPosition()
			local es = self:GetEffectiveScale()
			-- déplacement en pixels du vrai cadre, arrondi au pixel
			local dx = math.floor(((cx / es - dg.cx) / S) + 0.5)
			local dy = math.floor(((cy / es - dg.cy) / S) + 0.5)
			local nx = math.floor((dg.x * W / 100 + dx) + 0.5) * 100 / W
			local ny = math.floor((dg.y * FH / 100 + dy) + 0.5) * 100 / FH
			if nx ~= self.lx or ny ~= self.ly then
				self.lx, self.ly, self.moved = nx, ny, true
				api.setOff(self.key, nx, ny)
				f:Redraw()
			end
		end)
		ic:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			local _, _, _, _, _, _, label = api.info(self.key)
			GameTooltip:AddLine(label or "")
			GameTooltip:AddLine("Glisser pour placer au pixel près", 0.8, 0.8, 0.8)
			GameTooltip:Show()
		end)
		ic:SetScript("OnLeave", function() GameTooltip:Hide() end)
		f.icons[i] = ic
		return ic
	end

	function f:Redraw()
		local d = VP.db
		W, FH, barH = d.width, VP.Frames:FrameHeight(), d.hpHeight
		-- échelle : le cadre agrandi tient dans la zone avec une marge pour les positions « dehors »
		S = math.max(1.5, math.min((FULL_W - 160) / W, (CANVAS_H - 70) / FH, 6))
		frame:SetWidth(W * S); frame:SetHeight(FH * S)
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", canvas, "CENTER", 0, 0)
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", frame, "TOPLEFT", S, -S)
		bar:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", (W - 1) * S, -(1 + barH) * S)
		if d.showMana then
			mana:Show()
			mana:ClearAllPoints()
			mana:SetPoint("TOPLEFT", frame, "TOPLEFT", S, -(2 + barH) * S)
			mana:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -S, S)
		else
			mana:Hide()
		end
		nameTxt:ClearAllPoints()
		nameTxt:SetPoint("CENTER", frame, "TOPLEFT", W * S / 2, -(1 + barH / 2) * S)
		-- grille (lignes tous les 10 px)
		local gi = 0
		for gx = 10, W - 1, 10 do
			gi = gi + 1
			local g = grid[gi] or frame:CreateTexture(nil, "BACKGROUND", nil, 2)
			grid[gi] = g
			g:SetTexture(T.TEX); g:SetVertexColor(1, 1, 1, 0.07)
			g:ClearAllPoints()
			g:SetPoint("TOPLEFT", frame, "TOPLEFT", gx * S, -S)
			g:SetWidth(1); g:SetHeight(barH * S)
			g:Show()
		end
		for gy = 10, barH, 10 do
			gi = gi + 1
			local g = grid[gi] or frame:CreateTexture(nil, "BACKGROUND", nil, 2)
			grid[gi] = g
			g:SetTexture(T.TEX); g:SetVertexColor(1, 1, 1, 0.07)
			g:ClearAllPoints()
			g:SetPoint("TOPLEFT", frame, "TOPLEFT", S, -(1 + gy) * S)
			g:SetWidth((W - 2) * S); g:SetHeight(1)
			g:Show()
		end
		for i = gi + 1, #grid do grid[i]:Hide() end

		local sel = api.selected()
		local keys = api.list()
		local selInfo
		for i, key in ipairs(keys) do
			local ic = getIcon(i)
			ic.key = key
			local pos, x, y, w, h, tex, label, num = api.info(key)
			local l, t = rect(pos, x, y, w, h)
			ic:ClearAllPoints()
			ic:SetPoint("TOPLEFT", frame, "TOPLEFT", l * S, -t * S)
			ic:SetWidth(math.max(6, w * S)); ic:SetHeight(math.max(6, h * S))
			ic.tex:SetTexture(tex)
			ic.num:SetText(num or "")
			local isSel = key == sel
			if isSel then
				local r, g, b = T:Accent()
				ic:SetBackdropBorderColor(r, g, b, 1)
				ic:SetAlpha(1)
				ic:SetFrameLevel(frame:GetFrameLevel() + 10 + #keys)   -- toujours au-dessus des autres
				selInfo = { pos = pos, x = x, y = y, label = label, l = l, t = t, w = w }
			else
				ic:SetBackdropBorderColor(0, 0, 0, 1)
				ic:SetAlpha(sel and 0.55 or 1)
				ic:SetFrameLevel(frame:GetFrameLevel() + 5 + i)
			end
			ic:Show()
		end
		for i = #keys + 1, #f.icons do f.icons[i]:Hide() end
		if selInfo then
			local pname = selInfo.pos
			for _, pe in ipairs(VP.Frames.POS_LIST) do if pe[1] == selInfo.pos then pname = pe[2] end end
			info:SetText(string.format("|cffffffff%s|r  ·  %s  ·  X %+d px  ·  Y %+d px  ·  Taille %d px",
				selInfo.label or "?", pname or "?",
				math.floor(selInfo.x * W / 100 + 0.5), math.floor(selInfo.y * FH / 100 + 0.5), math.floor((selInfo.w or 0) + 0.5)))
		else
			info:SetText("Cliquez une icône pour la choisir.")
		end
		if VP.db.iconLayout == "AUTO" then
			help:SetText("|cffff8800Mode de placement « Alignement automatique » : les positions et tailles réglées ici "
				.. "ne s'appliquent qu'en mode « Individuel ».|r")
		else
			help:SetText("Glisser : déplacer. Molette sur l'icône : taille (Maj : 4 px). Flèches : 1 px (Maj : 5 px).")
		end
	end

	-- flèches d'ajustement fin
	-- l'icône choisie doit être dessinée dans l'éditeur (ex. le texte de surplus de soin ne l'est pas)
	local function drawn(key)
		if not key then return false end
		for _, k in ipairs(api.list()) do if k == key then return true end end
		return false
	end
	local function nudge(dx, dy)
		local key = api.selected()
		if not drawn(key) then return end
		local step = IsShiftKeyDown() and 5 or 1
		local _, x, y = api.info(key)
		local px = math.floor(x * W / 100 + 0.5) + dx * step
		local py = math.floor(y * FH / 100 + 0.5) + dy * step
		api.setOff(key, px * 100 / W, py * 100 / FH)
		api.commit()
		UI:RefreshCurrent()
	end
	local function arrow(txt, x, y, dx, dy)
		local b = UI:Button(f, txt, 28, function() nudge(dx, dy) end)
		b:SetHeight(22)
		b:SetPoint("TOPRIGHT", canvas, "BOTTOMRIGHT", x, y)
		return b
	end
	-- taille de l'icône choisie : - / + (Maj : 4 px) et retour à la taille par défaut
	local function resize(delta)
		local key = api.selected()
		if not drawn(key) or not api.setSize then return end
		local _, _, _, w = api.info(key)
		local step = IsShiftKeyDown() and 4 or 1
		api.setSize(key, delta == 0 and 0 or math.max(6, math.min(64, math.floor(w + 0.5) + delta * step)))
		api.commit()
		UI:RefreshCurrent()
	end
	local function sizeBtn(txt, w, x, y, delta)
		local b = UI:Button(f, txt, w, function() resize(delta) end)
		b:SetHeight(22)
		b:SetPoint("TOPRIGHT", canvas, "BOTTOMRIGHT", x, y)
		return b
	end
	sizeBtn("Taille -", 60, -170, -6, -1)
	sizeBtn("Taille +", 60, -106, -6, 1)
	sizeBtn("Taille par défaut", 124, -106, -30, 0)
	arrow("^", -36, -6, 0, 1)
	arrow("<", -70, -30, -1, 0)
	arrow("v", -36, -30, 0, -1)
	arrow(">", -2, -30, 1, 0)

	function f:Refresh() self:Redraw() end
	f:Redraw()
	self:Place(f, CANVAS_H + 66)
	return f
end

-- Éditeur de macros : liste à gauche, texte sur plusieurs lignes à droite, vérification en direct,
-- jetons à insérer, modèles, import des macros du jeu, assignation à un clic.
function Page:MacroEditor()
	local MC = VP.Macros
	local f = CreateFrame("Frame", nil, self.frame)
	local H = 458
	f:SetWidth(FULL_W); f:SetHeight(H)
	local sel   -- macro choisie

	-- liste ---------------------------------------------------------------
	local list = CreateFrame("Frame", nil, f)
	list:SetWidth(170); list:SetHeight(H - 62)
	list:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	T:Backdrop(list, T.C.panel, T.C.edge)
	local rows, ROWS, offset = {}, 15, 0
	local edit, nameBox   -- créés plus bas
	-- avant de changer de macro : on enregistre ce qui est en cours d'écriture DANS LA BONNE macro
	local function flush()
		if edit and edit:HasFocus() then edit:ClearFocus() end
		if nameBox and nameBox:HasFocus() then nameBox:ClearFocus() end
	end
	local function selectMacro(m) flush(); sel = m; f:Refresh() end
	for i = 1, ROWS do
		local r = CreateFrame("Button", nil, list)
		r:SetHeight(24)
		r:SetPoint("TOPLEFT", list, "TOPLEFT", 2, -2 - (i - 1) * 26)
		r:SetPoint("TOPRIGHT", list, "TOPRIGHT", -2, -2 - (i - 1) * 26)
		r.icon = r:CreateTexture(nil, "ARTWORK")
		r.icon:SetWidth(20); r.icon:SetHeight(20)
		r.icon:SetPoint("LEFT", r, "LEFT", 2, 0)
		r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		r.text = T:Text(r, 12)
		r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
		r.text:SetWidth(130); r.text:SetJustifyH("LEFT")
		r.bg = T:Tex(r, "BACKGROUND", 1, 1, 1, 0.07)
		r.bg:SetAllPoints(r)
		r:SetScript("OnClick", function(self) if self.m then selectMacro(self.m) end end)
		rows[i] = r
	end
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(_, delta)
		offset = math.max(0, math.min(math.max(0, #MC:List() - ROWS), offset - delta))
		f:Refresh()
	end)
	local function btn(parent, label, w, fn)
		local b = UI:Button(parent, label, w, fn)
		b:SetHeight(22)
		return b
	end
	local bNew = btn(f, "Nouvelle", 82, function() flush(); selectMacro(MC:Add("Macro")) end)
	bNew:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -6)
	local bDel = btn(f, "Supprimer", 82, function()
		flush()
		if sel then MC:Delete(sel.name); sel = nil; f:Refresh() end
	end)
	bDel:SetPoint("LEFT", bNew, "RIGHT", 6, 0)
	local bDup = btn(f, "Dupliquer", 82, function()
		flush()
		if sel then selectMacro(MC:Duplicate(sel)) end
	end)
	bDup:SetPoint("TOPLEFT", bNew, "BOTTOMLEFT", 0, -6)
	-- partage : exporter cette macro / toutes, ou importer un texte reçu
	local bShare = btn(f, "Partager...", 82, function(self)
		flush()
		UI.OpenPopup(self, {
			{ 1, "Exporter cette macro" }, { 2, "Exporter toutes les macros" }, { 3, "Importer des macros..." },
		}, function() return nil end, function(choice)
			if choice == 1 and sel then
				VP.Share:Window("Exporter « " .. sel.name .. " »", MC:Export({ sel }))
			elseif choice == 2 then
				VP.Share:Window("Exporter toutes les macros", MC:Export())
			elseif choice == 3 then
				VP.Share:Window("Importer des macros", "", function(text)
					local added, same, code = MC:ImportText(text)
					if not added then VP:Print("|cffff6666Import impossible : " .. tostring(same) .. "|r") return end
					VP:Print(added .. " macro(s) importée(s)" .. (same > 0 and (", " .. same .. " déjà présente(s)") or "") .. ".")
					if #code > 0 then
						VP:Print("|cffffaa33Attention : " .. table.concat(code, ", ") .. " contien(nen)t /script, /run ou /console "
							.. "(du code exécuté au clic). Lisez-les avant de les assigner.|r")
					end
					VP.Share.win:Hide()
					f:Refresh()
				end, "Importer")
			end
		end)
	end)
	bShare:SetPoint("LEFT", bDup, "RIGHT", 6, 0)

	-- éditeur --------------------------------------------------------------
	local X = 182
	local nameLbl = T:Text(f, 12, T.C.muted)
	nameLbl:SetPoint("TOPLEFT", f, "TOPLEFT", X, -4)
	nameLbl:SetText("Nom")
	nameBox = UI:EditBox(f, 200)
	nameBox:SetPoint("TOPLEFT", f, "TOPLEFT", X + 40, 0)
	nameBox:SetScript("OnEditFocusGained", function(self) self.m = sel end)
	nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	nameBox:SetScript("OnEditFocusLost", function(self)
		if self.m then MC:Rename(self.m, self:GetText()) end
		self.m = nil
		f:Refresh()
	end)
	local icon = f:CreateTexture(nil, "ARTWORK")
	icon:SetWidth(26); icon:SetHeight(26)
	icon:SetPoint("LEFT", nameBox, "RIGHT", 10, 0)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local count = T:Text(f, 11, T.C.muted)
	count:SetPoint("LEFT", icon, "RIGHT", 8, 0)

	-- zone de texte sur plusieurs lignes (avec défilement)
	local box = CreateFrame("Frame", nil, f)
	box:SetPoint("TOPLEFT", f, "TOPLEFT", X, -32)
	box:SetWidth(FULL_W - X); box:SetHeight(150)
	T:Backdrop(box, { 0.03, 0.03, 0.04, 1 }, T.C.edge)
	local sf = CreateFrame("ScrollFrame", nil, box)
	sf:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -6)
	sf:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -6, 6)
	edit = CreateFrame("EditBox", nil, sf)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetMaxLetters(MC.MAX_TOTAL + 200)
	edit:SetWidth(FULL_W - X - 14)
	edit:SetFontObject(ChatFontNormal)
	edit:SetTextInsets(2, 2, 2, 2)
	sf:SetScrollChild(edit)
	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", function(self, delta)
		local v = math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 20))
		self:SetVerticalScroll(v)
	end)
	edit:SetScript("OnCursorChanged", function(self, x, y, w, h)
		-- garde le curseur visible
		local top = -y
		local cur = sf:GetVerticalScroll()
		local hgt = sf:GetHeight()
		if top < cur then sf:SetVerticalScroll(top)
		elseif top + h > cur + hgt then sf:SetVerticalScroll(top + h - hgt) end
	end)
	box:EnableMouse(true)
	box:SetScript("OnMouseDown", function() edit:SetFocus() end)
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	local checkText
	-- edit.m : la macro réellement en cours d'écriture (fixée quand le texte prend le focus)
	local function save()
		local m = edit.m or sel
		if not m then return end
		local body = edit:GetText() or ""
		if body ~= m.body then
			m.body = body
			VP.Clicks:Apply()
		end
	end
	edit:SetScript("OnEditFocusGained", function(self)
		if not sel then self:ClearFocus() return end   -- aucune macro : rien à écrire
		self.m = sel
	end)
	edit:SetScript("OnTextChanged", function(self, user)
		if not sel then return end
		local body = self:GetText() or ""
		count:SetText(#body .. " / " .. MC.MAX_TOTAL)
		f:ShowCheck(body)
		if user then f.dirty = true end
	end)
	edit:SetScript("OnEditFocusLost", function(self) save(); self.m = nil; f:Refresh() end)
	-- dépôt d'un sort du grimoire ou d'une macro du jeu dans le texte
	local function drop()
		local kind, a1, a2 = GetCursorInfo()
		if kind == "spell" then
			local n = GetSpellName(a1, a2)
			ClearCursor()
			if n and sel then edit:SetFocus(); edit:Insert(n) end
		elseif kind == "macro" then
			ClearCursor()
			flush()
			local m = MC:ImportGame(a1)
			if m then selectMacro(m) end
		end
	end
	edit:SetScript("OnReceiveDrag", drop)
	edit:SetScript("OnMouseUp", function() local k = GetCursorInfo(); if k == "spell" or k == "macro" then drop() end end)
	box:SetScript("OnReceiveDrag", drop)

	-- jetons à insérer
	local sx, sy = X, -188
	for _, sn in ipairs(MC.SNIPPETS) do
		local b = btn(f, sn[1], math.max(44, 8 + #sn[1] * 7), function()
			if not sel then return end
			edit:SetFocus()
			edit:Insert(sn[2])
		end)
		local w = b:GetWidth()
		if sx + w > FULL_W then sx = X; sy = sy - 25 end
		b:SetPoint("TOPLEFT", f, "TOPLEFT", sx, sy)
		sx = sx + w + 4
	end

	-- vérification
	checkText = T:Text(f, 11)
	checkText:SetPoint("TOPLEFT", f, "TOPLEFT", X, sy - 32)
	checkText:SetWidth(FULL_W - X); checkText:SetJustifyH("LEFT")
	local COL = { err = "|cffff5555", warn = "|cffffaa33", info = "|cff99aaff", ok = "|cff55ff55" }
	function f:ShowCheck(body)
		local lines = {}
		local issues = MC:Check(body)
		for i, r in ipairs(issues) do
			if i > 3 then lines[#lines + 1] = "|cff888888(+" .. (#issues - 3) .. " autre(s))|r"; break end
			local t = r[2]
			if #t > 70 then t = string.sub(t, 1, 67) .. "..." end
			lines[#lines + 1] = (COL[r[1]] or "") .. t .. "|r"
		end
		checkText:SetText(table.concat(lines, "\n"))
	end

	-- actions
	local ay = sy - 100
	local bConv = btn(f, "Convertir le survol en @vp", 190, function()
		if not sel then return end
		edit:SetText(MC:Convert(edit:GetText(), false)); save(); f:Refresh()
	end)
	bConv:SetPoint("TOPLEFT", f, "TOPLEFT", X, ay)
	local bTest = btn(f, "Aperçu", 80, function()
		if not sel then return end
		local u = UnitExists("target") and "target" or "player"
		VP:Print("Aperçu de « " .. sel.name .. " » sur " .. (UnitName(u) or u) .. " :")
		for line in string.gmatch(MC:Resolve(edit:GetText() or "", u) .. "\n", "([^\n]*)\n") do
			if line ~= "" then VP:Print("  |cffffffff" .. line .. "|r") end
		end
	end)
	bTest:SetPoint("LEFT", bConv, "RIGHT", 6, 0)
	local bTpl = btn(f, "Modèles", 90, function(self)
		local tpl = MC:Templates()
		local choices = {}
		for i, t in ipairs(tpl) do choices[i] = { i, t[1] } end
		flush()
		UI.OpenPopup(self, choices, function() return nil end, function(i)
			selectMacro(MC:Add(tpl[i][1], tpl[i][2]))
			VP.Clicks:Apply()
		end)
	end)
	bTpl:SetPoint("LEFT", bTest, "RIGHT", 6, 0)
	local bImp = btn(f, "Importer une macro du jeu", 190, function(self)
		local gm = MC:GameMacros()
		if #gm == 0 then VP:Print("Aucune macro dans le jeu (Échap > Macros).") return end
		local choices = {}
		for i, g in ipairs(gm) do choices[i] = { g.index, g.name .. " |cff888888(" .. g.kind .. ")|r" } end
		flush()
		UI.OpenPopup(self, choices, function() return nil end, function(idx)
			local m = MC:ImportGame(idx)
			if m then selectMacro(m); VP.Clicks:Apply() end
		end)
	end)
	bImp:SetPoint("TOPLEFT", bConv, "BOTTOMLEFT", 0, -6)
	local bAssign = btn(f, "Assigner à un clic...", 170, function(self)
		if not sel then return end
		local choices = {}
		for _, e in ipairs(VP.Clicks:Combos()) do
			if e[1] ~= "" then
				local cur = VP.Clicks:Binds()[e[1]]
				local lbl = e[2]
				if cur and cur ~= "" then lbl = lbl .. " |cff888888(" .. VP.Clicks:ToText(cur) .. ")|r" end
				choices[#choices + 1] = { e[1], lbl }
			end
		end
		UI.OpenPopup(self, choices, function() return nil end, function(combo)
			MC:Assign(sel, combo)
			local lbl = combo
			for _, e in ipairs(VP.Clicks:Combos()) do if e[1] == combo then lbl = e[2] end end
			VP:Print("« " .. sel.name .. " » assignée à : " .. lbl .. ".")
			f:Refresh()
		end)
	end)
	bAssign:SetPoint("LEFT", bImp, "RIGHT", 6, 0)
	local uses = T:Text(f, 11, T.C.muted)
	uses:SetPoint("TOPLEFT", bImp, "BOTTOMLEFT", 0, -8)
	uses:SetWidth(FULL_W - X); uses:SetJustifyH("LEFT")

	function f:Refresh()
		local L = MC:List()
		if sel and not MC:Find(sel.name) then sel = nil end
		if not sel then sel = L[1] end
		offset = math.max(0, math.min(offset, math.max(0, #L - ROWS)))
		for i = 1, ROWS do
			local r, m = rows[i], L[i + offset]
			r.m = m
			if m then
				r.icon:SetTexture(MC:Icon(m))
				r.text:SetText(m.name)
				if m == sel then r.bg:Show(); r.text:SetTextColor(1, 1, 1) else r.bg:Hide(); r.text:SetTextColor(T.C.muted[1], T.C.muted[2], T.C.muted[3]) end
				r:Show()
			else
				r:Hide()
			end
		end
		if sel then
			if not nameBox:HasFocus() then nameBox:SetText(sel.name) end
			if not edit:HasFocus() then edit:SetText(sel.body or "") end
			icon:SetTexture(MC:Icon(sel))
			count:SetText(#(sel.body or "") .. " / " .. MC.MAX_TOTAL)
			self:ShowCheck(sel.body)
			local u = MC:Uses(sel)
			uses:SetText(#u > 0 and ("Utilisée par : |cffffffff" .. table.concat(u, ", ") .. "|r")
				or "Pas encore utilisée : « Assigner à un clic... », ou écrivez |cffffffffM:" .. sel.name .. "|r dans une case de clic ou de touche.")
		else
			nameBox:SetText("")
			edit:SetText("")
			icon:SetTexture(nil)
			count:SetText("")
			checkText:SetText("|cff888888Aucune macro : « Nouvelle », « Modèles » ou « Importer une macro du jeu ».|r")
			uses:SetText("")
		end
	end
	f:Refresh()
	self:Place(f, H + 6)
	return f
end

-- Emplacement de HoT : ligne 1 [Emplacement N] [icône] [sort] [liste] [Les miens] [Des autres] [couleur]
--                      ligne 2 position
function Page:HotSlot(i, getSlot)
	local f = CreateFrame("Frame", nil, self.frame)
	f:SetWidth(FULL_W); f:SetHeight(58)
	T:Backdrop(f, T.C.panel, T.C.edge)
	local ct = T:Text(f, 12, nil, nil, nil, true)
	ct:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -9)
	ct:SetText("Emplacement " .. i)
	T:RegisterAccent(ct, "text")
	local icon = CreateFrame("Frame", nil, f)
	icon:SetWidth(22); icon:SetHeight(22)
	icon:SetPoint("TOPLEFT", f, "TOPLEFT", 112, -4)
	T:Backdrop(icon, { 0, 0, 0, 1 }, { 0, 0, 0, 1 })
	icon.tex = icon:CreateTexture(nil, "ARTWORK")
	icon.tex:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
	icon.tex:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
	icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local function updIcon()
		local sp = getSlot().spell
		-- (aussi pour les sorts hors du grimoire : Viveterre, Égide divine, Rénovation du Puits de lumière...)
		local ic = VP.Frames:SpellIcon(sp)
		if sp ~= "" and ic then icon.tex:SetTexture(ic); icon.tex:Show() else icon.tex:Hide() end
	end
	local e = UI:EditBox(f, 150)
	e:SetPoint("TOPLEFT", f, "TOPLEFT", 140, -4)
	local function commit(self)
		local t = (self:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
		getSlot().spell = t
		updIcon()
	end
	local function drop(self)
		local kind, slot, book = GetCursorInfo()
		if kind ~= "spell" then return end
		local spellName = GetSpellName(slot, book)
		ClearCursor()
		if spellName then self:SetText(spellName); commit(self); self:ClearFocus() end
	end
	e:SetScript("OnEnterPressed", function(self) commit(self); self:ClearFocus() end)
	e:SetScript("OnEditFocusLost", commit)
	e:SetScript("OnReceiveDrag", drop)
	e:SetScript("OnMouseUp", function(self) local k = GetCursorInfo(); if k == "spell" or k == "macro" then drop(self) end end)

	-- liste des sorts de la classe du personnage
	local list = UI:Button(f, "v", 22, function(self)
		local choices = { { "", "(vide)" } }
		for _, id in ipairs(VP.Frames.CLASS_SPELLS[VP.class] or {}) do
			local n = GetSpellInfo(id)
			if n then choices[#choices + 1] = { n, n } end
		end
		openPopup(e, choices, function() return getSlot().spell end, function(v)
			getSlot().spell = v
			e:SetText(v)
			updIcon()
		end)
	end)
	list:SetPoint("LEFT", e, "RIGHT", 2, 0)
	list:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Sorts de ma classe")
		GameTooltip:Show()
	end)
	list:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local mine = toggleChip(f, "Les miens", 70, function() return getSlot().own end, function(v) getSlot().own = v end)
	mine:SetPoint("TOPLEFT", f, "TOPLEFT", 324, -4)
	local others = toggleChip(f, "Des autres", 70, function() return getSlot().others end, function(v) getSlot().others = v end)
	others:SetPoint("TOPLEFT", f, "TOPLEFT", 398, -4)
	local sw = CreateFrame("Button", nil, f)
	sw:SetWidth(24); sw:SetHeight(24)
	sw:SetPoint("TOPLEFT", f, "TOPLEFT", 474, -4)
	T:Backdrop(sw, { 1, 1, 1, 1 }, T.C.edge)
	local function updSwatch()
		local c = getSlot().color
		sw:SetBackdropColor(c[1], c[2], c[3], 1)
	end
	sw:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Couleur du carré")
		GameTooltip:AddLine("Utilisée quand l'affichage est « Carrés de couleur ».", 0.8, 0.8, 0.85, true)
		GameTooltip:Show()
	end)
	sw:SetScript("OnLeave", function() GameTooltip:Hide() end)
	sw:SetScript("OnClick", function()
		local c = getSlot().color
		local prev = { c[1], c[2], c[3] }
		ColorPickerFrame.hasOpacity = false
		ColorPickerFrame.previousValues = { r = prev[1], g = prev[2], b = prev[3] }
		ColorPickerFrame.func = function()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			c[1], c[2], c[3] = r, g, b
			updSwatch()
		end
		ColorPickerFrame.cancelFunc = function()
			c[1], c[2], c[3] = prev[1], prev[2], prev[3]
			updSwatch()
		end
		ColorPickerFrame:SetColorRGB(c[1], c[2], c[3])
		ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
		ColorPickerFrame:Hide()
		ColorPickerFrame:Show()
	end)

	-- ligne 2 : position de cet emplacement
	local pl = T:Text(f, 12, T.C.muted)
	pl:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -36)
	pl:SetText("Position :")
	local pb = UI:Button(f, "", 200, function(self)
		openPopup(self, VP.Frames.POS_LIST, function() return getSlot().pos end, function(v)
			local sl = getSlot()
			if sl.pos ~= v then sl.offX, sl.offY = 0, 0 end   -- nouvelle zone = position propre
			sl.pos = v
			VP.Frames:Refresh()
			UI:RefreshCurrent()
		end)
	end)
	pb:SetPoint("TOPLEFT", f, "TOPLEFT", 112, -31)
	local function updPos()
		local pos = getSlot().pos
		for _, pe in ipairs(VP.Frames.POS_LIST) do if pe[1] == pos then pb.text:SetText(pe[2]) end end
	end

	function f:Refresh()
		e:SetText(getSlot().spell or "")
		updIcon(); updSwatch(); updPos(); mine:Refresh(); others:Refresh()
	end
	f:Refresh()
	self:Place(f, 64)
	return f
end

-- Couleur personnalisable : [pastille colorée avec le nom] [Fond] [Texte]
-- getC() renvoie la table { r, g, b, bg=?, text=? } modifiée sur place
local function openColor(c, onChange)
	local prev = { c[1], c[2], c[3] }
	ColorPickerFrame.hasOpacity = false
	ColorPickerFrame.previousValues = { r = prev[1], g = prev[2], b = prev[3] }
	ColorPickerFrame.func = function()
		local r, g, b = ColorPickerFrame:GetColorRGB()
		c[1], c[2], c[3] = r, g, b
		onChange()
	end
	ColorPickerFrame.cancelFunc = function()
		c[1], c[2], c[3] = prev[1], prev[2], prev[3]
		onChange()
	end
	ColorPickerFrame:SetColorRGB(c[1], c[2], c[3])
	ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
	ColorPickerFrame:Hide()
	ColorPickerFrame:Show()
end
UI.OpenColor = openColor

function Page:Color(label, getC, flags, half, onChange)
	local f = CreateFrame("Frame", nil, self.frame)
	f:SetWidth(half and HALF_W or FULL_W); f:SetHeight(26)
	local sw = CreateFrame("Button", nil, f)
	sw:SetWidth(150); sw:SetHeight(24)
	sw:SetPoint("LEFT", f, "LEFT", 0, 0)
	T:Backdrop(sw, { 1, 1, 1, 1 }, T.C.edge)
	T:Gloss(sw)
	local txt = T:Text(sw, 12, nil, "OUTLINE")
	txt:SetPoint("CENTER", sw, "CENTER", 0, 0)
	txt:SetText(label)
	local function changed()
		if onChange then onChange() end
		f:Refresh()
		VP.Frames:Refresh()
	end
	sw:SetScript("OnClick", function() openColor(getC(), changed) end)
	sw:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Cliquez pour changer la couleur")
		GameTooltip:Show()
	end)
	sw:SetScript("OnLeave", function() GameTooltip:Hide() end)
	local chips = {}
	local x = 158
	if flags and flags.bg then
		local b = toggleChip(f, "Fond", 52, function() return getC().bg end, function(v) getC().bg = v; changed() end)
		b:SetPoint("LEFT", f, "LEFT", x, 0)
		chips[#chips + 1] = b
		x = x + 56
	end
	if flags and flags.text then
		local b = toggleChip(f, "Texte", 52, function() return getC().text end, function(v) getC().text = v; changed() end)
		b:SetPoint("LEFT", f, "LEFT", x, 0)
		chips[#chips + 1] = b
	end
	function f:Refresh()
		local c = getC()
		sw:SetBackdropColor(c[1], c[2], c[3], 1)
		for _, b in ipairs(chips) do b:Refresh() end
	end
	f:Refresh()
	self:Place(f, 30, half)
	return f
end

-- Bandeau d'état (texte dynamique encadré)
function Page:Banner(getText)
	local f = CreateFrame("Frame", nil, self.frame)
	f:SetWidth(FULL_W); f:SetHeight(30)
	T:Backdrop(f, T.C.control, T.C.edge)
	local bar = T:Tex(f, "ARTWORK")
	bar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
	bar:SetWidth(3)
	T:RegisterAccent(bar)
	local t = T:Text(f, 12)
	t:SetPoint("LEFT", f, "LEFT", 12, 0)
	t:SetWidth(FULL_W - 20); t:SetJustifyH("LEFT")
	function f:Refresh() t:SetText(getText()) end
	f:Refresh()
	self:Place(f, 38)
	return f
end

-- Capture d'une touche + action
local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true }
function Page:KeyAction(getKey, setKey, getAct, setAct)
	local f = CreateFrame("Frame", nil, self.frame)
	f:SetWidth(FULL_W); f:SetHeight(24)
	local b = UI:Button(f, "", 168, function() end)
	b:SetPoint("LEFT", f, "LEFT", 0, 0)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local function show()
		local k = getKey()
		b.text:SetText((k and k ~= "") and k or "|cff777777Cliquer pour choisir|r")
	end
	local function stop()
		b.waiting = nil
		b:EnableKeyboard(false)
		b:EnableMouseWheel(false)
		edge(b)
		show()
	end
	local function prefix()
		local p = ""
		if IsAltKeyDown() then p = p .. "ALT-" end
		if IsControlKeyDown() then p = p .. "CTRL-" end
		if IsShiftKeyDown() then p = p .. "SHIFT-" end
		return p
	end
	b:SetScript("OnClick", function(self, button)
		if button == "RightButton" then setKey(""); stop() return end
		self.waiting = true
		self.text:SetText("|cffffff00Appuyez sur une touche...|r")
		self:SetBackdropBorderColor(T:Accent())
		self:EnableKeyboard(true)
		self:EnableMouseWheel(true)
	end)
	b:SetScript("OnKeyDown", function(self, key)
		if not self.waiting then return end
		if key == "ESCAPE" then stop() return end
		if MODIFIER_KEYS[key] then return end
		setKey(prefix() .. key)
		stop()
	end)
	b:SetScript("OnMouseWheel", function(self, delta)
		if not self.waiting then return end
		setKey(prefix() .. (delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"))
		stop()
	end)
	b:SetScript("OnHide", function() if b.waiting then stop() end end)
	statusParts(f)
	f.icon:SetPoint("LEFT", f, "LEFT", 176, 0)
	local e = UI:ActionEdit(f, 230, getAct, function(v) setAct(v); f:UpdateStatus(v) end)
	e:SetPoint("LEFT", f, "LEFT", 204, 0)
	f.status:SetPoint("LEFT", f, "LEFT", 444, 0)
	f.status:SetWidth(110)
	function f:Refresh() show(); e:Refresh(); self:UpdateStatus(getAct()) end
	f:Refresh()
	self:Place(f, 30)
	return f
end

-- Sélecteur de couleur d'accent (pastilles)
function Page:AccentPicker(label)
	local f = CreateFrame("Frame", nil, self.frame)
	f:SetWidth(FULL_W); f:SetHeight(44)
	local txt = T:Text(f, 13)
	txt:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	txt:SetText(label)
	f.swatches = {}
	for i, a in ipairs(T.ACCENTS) do
		local s = CreateFrame("Button", nil, f)
		s:SetWidth(76); s:SetHeight(22)
		s:SetPoint("TOPLEFT", f, "TOPLEFT", (i - 1) * 84, -18)
		T:Backdrop(s, { a[3], a[4], a[5], 0.85 }, T.C.edge)
		local n = T:Text(s, 11, { 0.05, 0.05, 0.05 })
		n:SetShadowOffset(0, 0)
		n:SetPoint("CENTER", s, "CENTER", 0, 0)
		n:SetText(a[2])
		s:SetScript("OnClick", function()
			VP.db.accent = a[1]
			T:ApplyAccent()
			UI:RefreshCurrent()
			f:Refresh()
		end)
		s.key = a[1]
		f.swatches[i] = s
	end
	function f:Refresh()
		for _, s in ipairs(self.swatches) do
			if s.key == VP.db.accent then s:SetBackdropBorderColor(1, 1, 1, 1) else edge(s) end
		end
	end
	f:Refresh()
	self:Place(f, 52)
	return f
end

-- Recherche ------------------------------------------------------------------------
-- Chaque réglage créé sur une page enregistre son libellé : on peut ensuite le retrouver
-- (« bouclier », « portée »...) sans connaître l'onglet. Accents et majuscules ignorés.
local ACC = { ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
	["î"] = "i", ["ï"] = "i", ["ô"] = "o", ["ö"] = "o", ["ù"] = "u", ["û"] = "u", ["ü"] = "u", ["ç"] = "c",
	["œ"] = "oe", ["À"] = "a", ["Â"] = "a", ["É"] = "e", ["È"] = "e", ["Ê"] = "e", ["Î"] = "i", ["Ô"] = "o",
	["Ù"] = "u", ["Û"] = "u", ["Ç"] = "c" }
local function clean(txt)
	return (txt:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""))
end
local function norm(txt)
	return string.lower((clean(txt):gsub("[\192-\223][\128-\191]", ACC)))
end
UI.norm = norm
local function index(page, txt)
	if type(txt) ~= "string" or txt == "" then return end
	local t = clean(txt)
	page.texts[#page.texts + 1] = { raw = t, n = norm(t), frame = page.last }
end
-- les méthodes qui créent un réglage enregistrent leur libellé (premier argument)
for _, name in ipairs({ "Title", "Section", "Note", "Toggle", "Slider", "Dropdown", "Input", "Color", "Action",
	"Binding", "Chips", "PositionPicker", "AccentPicker" }) do
	local orig = Page[name]
	if orig then
		Page[name] = function(self, label, ...)
			local r = orig(self, label, ...)
			index(self, label)
			return r
		end
	end
end
do
	local orig = Page.Buttons
	Page.Buttons = function(self, list)
		local r = orig(self, list)
		for _, def in ipairs(list) do index(self, def[1]) end
		return r
	end
	local origT = Page.Tasks
	Page.Tasks = function(self, list)
		local r = origT(self, list)
		for _, tk in ipairs(list) do index(self, tk.label) end
		return r
	end
end

-- Catégories de la barre latérale, rangées par question du joueur (les onglets non listés vont dans « Autres »)
UI.CATEGORIES = {
	{ "Démarrer", { "home", "profiles" } },
	{ "Soigner", { "clicks", "hots", "macros" } },
	{ "Aides au soin", { "dispel", "debuffs", "buffs", "trinkets", "aoe" } },
	{ "Affichage", { "dims", "look", "ind", "icons", "panels", "pets" } },
	{ "Raid", { "cds", "lead" } },
	{ "Alertes", { "alerts" } },
}

-- Mode « Essentiel » (réglages avancés repliés) ou « Tous les réglages »
function UI:ShowAll() return VP.db and VP.db.uiShowAll and true or false end
function UI:SetShowAll(v)
	VP.db.uiShowAll = v and true or false
	for _, t in ipairs(self.tabs) do
		if t.page then
			for _, s in ipairs(t.page.sections) do
				if s.adv then s.collapsed = not v end
			end
			t.page:Relayout()
		end
	end
	if self.modeRefresh then self.modeRefresh() end
	self:UpdateScrollBar()
end

-- Fenêtre principale ----------------------------------------------------------------
-- opts : icon (texture du jeu), keys (synonymes pour la recherche), active (fonction : la
-- fonctionnalité est-elle activée ? point de couleur dans le menu)
UI.tabs = {}
function UI:AddTab(id, label, build, opts)
	opts = opts or {}
	table.insert(self.tabs, { id = id, label = label, build = build, icon = opts.icon, keys = opts.keys, active = opts.active })
end

function UI:TabById(id)
	for _, t in ipairs(self.tabs) do if t.id == id then return t end end
end

-- Ouvre un onglet par son identifiant ; anchor : section à mettre en évidence (tâches, liens)
function UI:Go(id, anchor)
	if not self.window or not self.window:IsShown() then
		self:Open(id)
	else
		local t = self:TabById(id)
		if t then self:Select(t) end
	end
	if anchor then
		local t = self:TabById(id)
		local f = t and t.page and t.page.anchors[anchor]
		if f then self:Reveal(t, f) end
	end
end

-- Construit toutes les pages (une seule fois) pour pouvoir chercher dans tous les onglets
function UI:BuildAllPages()
	for _, t in ipairs(self.tabs) do
		if not t.page then
			t.page = UI:NewPage(self.scroll)
			t.build(t.page)
			t.page:Finish()
			t.page.frame:Hide()
		end
	end
end

-- Résultats de recherche : { tab, label, frame }
function UI:Search(text)
	local q = norm(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if #q < 2 then return nil end
	self:BuildAllPages()
	local out, seen = {}, {}
	-- les onglets dont le nom ou un synonyme correspond passent en premier, puis les réglages
	for _, item in ipairs(self.navOrder or {}) do
		local t = item.tab
		if t and (norm(t.label):find(q, 1, true) or (t.keys and norm(t.keys):find(q, 1, true))) then
			out[#out + 1] = { tab = t, label = t.label, isTab = true }
		end
	end
	for _, item in ipairs(self.navOrder or {}) do
		local t = item.tab
		if t then
			for _, e in ipairs(t.page.texts) do
				local key = t.id .. "|" .. e.n
				if not seen[key] and e.n:find(q, 1, true) then
					seen[key] = true
					out[#out + 1] = { tab = t, label = e.raw, frame = e.frame }
				end
			end
		end
	end
	return out
end

-- Ouvre l'onglet, déplie la carte si besoin, fait défiler jusqu'au réglage et le fait briller
function UI:Reveal(tab, frame)
	self:Select(tab)
	if not frame then return end
	local s = frame.vpSec
	if s and s.collapsed then
		s.collapsed = false
		tab.page:Relayout()
		self:UpdateScrollBar()
	end
	local top, ft = tab.page.frame:GetTop(), frame:GetTop()
	if top and ft then
		local range = self.scroll:GetVerticalScrollRange() or 0
		self.scroll:SetVerticalScroll(math.max(0, math.min(range, top - ft - 30)))
		self:UpdateScrollBar()
	end
	local fl = self.flash
	if not fl then
		fl = CreateFrame("Frame", nil, self.window)
		fl.tex = T:Tex(fl, "OVERLAY")
		fl.tex:SetAllPoints(fl)
		fl:SetScript("OnUpdate", function(f)
			local left = (f.untilT or 0) - GetTime()
			if left <= 0 then f:Hide() return end
			local r, g, b = T:Accent()
			f.tex:SetVertexColor(r, g, b, 0.18 * math.min(1, left))
		end)
		self.flash = fl
	end
	fl:SetParent(tab.page.frame)
	fl:SetFrameLevel(tab.page.frame:GetFrameLevel() + 8)
	fl:ClearAllPoints()
	fl:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
	fl:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
	fl.untilT = GetTime() + 1.8
	fl:Show()
end

function UI:RefreshNav()
	for _, t in ipairs(self.tabs) do
		if t.nav then t.nav:Refresh() end
	end
end

function UI:RefreshCurrent()
	if self.current and self.current.page then self.current.page:RefreshAll() end
	self:RefreshNav()
end

function UI:Select(tab)
	closePopup()
	for _, t in ipairs(self.tabs) do
		if t.page then t.page.frame:Hide() end
	end
	if not tab.page then
		tab.page = UI:NewPage(self.scroll)
		tab.build(tab.page)
		tab.page:Finish()
	end
	self.current = tab
	if self.crumb then
		local cat
		for _, c in ipairs(UI.CATEGORIES) do
			for _, id in ipairs(c[2]) do if id == tab.id then cat = c[1] end end
		end
		self.crumb:SetText((cat and (cat .. "   |cff5d636e/|r   ") or "") .. "|cffffffff" .. tab.label .. "|r")
	end
	self.scroll:SetScrollChild(tab.page.frame)
	tab.page.frame:Show()
	tab.page:RefreshAll()
	self.scroll:SetVerticalScroll(0)
	self:UpdateScrollBar()
	self:RefreshNav()
end

function UI:UpdateScrollBar()
	if not self.scroll then return end
	local range = self.scroll:GetVerticalScrollRange()
	local sb = self.scrollbar
	if range and range > 1 then
		sb:SetMinMaxValues(0, range)
		sb:SetValue(math.min(range, self.scroll:GetVerticalScroll()))
		sb:Show()
	else
		self.scroll:SetVerticalScroll(0)
		sb:Hide()
	end
end

-- Échelle de la fenêtre de configuration (lisibilité), indépendante de l'échelle des cadres
function UI:ApplyScale()
	if not self.window then return end
	local s = VP.db and tonumber(VP.db.uiScale) or 1
	self.window:SetScale(math.max(0.7, math.min(1.4, s)))
end

local WIN_W, WIN_H, SIDE_W = 880, 680, 200

function UI:Build()
	local w = CreateFrame("Frame", "VuhPlusConfig", UIParent)
	w:SetWidth(WIN_W); w:SetHeight(WIN_H)
	w:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	w:SetFrameStrata("DIALOG")
	w:SetToplevel(true)
	w:EnableMouse(true)
	w:SetMovable(true)
	w:SetClampedToScreen(true)
	w:RegisterForDrag("LeftButton")
	w:SetScript("OnDragStart", w.StartMoving)
	w:SetScript("OnDragStop", w.StopMovingOrSizing)
	w:SetScript("OnHide", function()
		closePopup()
		-- le mode test lancé depuis la fenêtre s'arrête avec elle (sinon les vrais cadres restent cachés)
		local PV = VP.Preview
		if PV and PV.shown and PV.fromUI then PV:Hide() end
		if PV then PV.fromUI = nil end
	end)
	T:Backdrop(w, T.C.bg, T.C.border)
	w:Hide()
	table.insert(UISpecialFrames, "VuhPlusConfig")
	self.window = w

	-- Barre de titre --------------------------------------------------------------
	local top = T:Tex(w, "ARTWORK")
	top:SetHeight(2)
	top:SetPoint("TOPLEFT", w, "TOPLEFT", 1, -1)
	top:SetPoint("TOPRIGHT", w, "TOPRIGHT", -1, -1)
	T:RegisterAccent(top)
	local titleLine = T:Tex(w, "ARTWORK", 1, 1, 1, 0.06)
	titleLine:SetHeight(1)
	titleLine:SetPoint("TOPLEFT", w, "TOPLEFT", 1, -50)
	titleLine:SetPoint("TOPRIGHT", w, "TOPRIGHT", -1, -50)
	local logo = T:Text(w, 20)
	logo:SetPoint("TOPLEFT", w, "TOPLEFT", 18, -16)
	logo:SetText("Vuh")
	local logo2 = T:Text(w, 20)
	logo2:SetPoint("LEFT", logo, "RIGHT", 0, 0)
	logo2:SetText("Plus")
	T:RegisterAccent(logo2, "text")
	local badge = CreateFrame("Frame", nil, w)
	badge:SetHeight(18)
	T:Backdrop(badge, { 0, 0, 0, 0 }, T.C.edge)
	local bt = T:Text(badge, 10, T.C.muted)
	bt:SetPoint("CENTER", badge, "CENTER", 0, 0)
	bt:SetText("V" .. VP.version .. "  ·  WOTLK 3.3.5  ·  par BellaHealFr")
	badge:SetWidth(bt:GetStringWidth() + 14)
	badge:SetPoint("LEFT", logo2, "RIGHT", 12, 0)
	-- où suis-je ? « Catégorie / Onglet »
	local crumb = T:Text(w, 13, T.C.muted)
	crumb:SetPoint("LEFT", badge, "RIGHT", 18, 0)
	self.crumb = crumb

	local close = CreateFrame("Button", nil, w)
	close:SetWidth(28); close:SetHeight(28)
	close:SetPoint("TOPRIGHT", w, "TOPRIGHT", -10, -12)
	local cx = T:Text(close, 18, T.C.muted)
	cx:SetPoint("CENTER", close, "CENTER", 0, 0)
	cx:SetText("x")
	close:SetScript("OnEnter", function() cx:SetTextColor(T.C.danger[1], T.C.danger[2], T.C.danger[3]) end)
	close:SetScript("OnLeave", function() cx:SetTextColor(T.C.muted[1], T.C.muted[2], T.C.muted[3]) end)
	close:SetScript("OnClick", function() w:Hide() end)

	-- Essentiel / Tous les réglages (les réglages avancés sont repliés, jamais supprimés)
	local function seg(label, width, value)
		local b = UI:Button(w, label, width, function() UI:SetShowAll(value) end)
		b:SetHeight(24)
		function b:Refresh()
			if UI:ShowAll() == value then
				self:SetBackdropColor(T.C.hover[1], T.C.hover[2], T.C.hover[3], 1)
				self:SetBackdropBorderColor(T:Accent())
				self.text:SetTextColor(1, 1, 1)
			else
				self:SetBackdropColor(T.C.control[1], T.C.control[2], T.C.control[3], 1)
				edge(self)
				self.text:SetTextColor(T.C.muted[1], T.C.muted[2], T.C.muted[3])
			end
		end
		return b
	end
	local bAll = seg("Tous les réglages", 118, true)
	bAll:SetPoint("RIGHT", close, "LEFT", -12, 0)
	local bEss = seg("Essentiel", 80, false)
	bEss:SetPoint("RIGHT", bAll, "LEFT", -4, 0)
	local segL = T:Text(w, 12, T.C.muted)
	segL:SetPoint("RIGHT", bEss, "LEFT", -8, 0)
	segL:SetText("Afficher")
	for _, b in ipairs({ bAll, bEss }) do
		b:HookScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
			GameTooltip:AddLine("Essentiel : les réglages avancés sont repliés")
			GameTooltip:AddLine("Ils restent accessibles : cliquez sur l'en-tête d'une carte « Avancé ».", 0.8, 0.8, 0.85, true)
			GameTooltip:Show()
		end)
		b:HookScript("OnLeave", function() GameTooltip:Hide() end)
	end
	self.modeRefresh = function() bAll:Refresh(); bEss:Refresh() end
	self.modeRefresh()

	-- Barre latérale -----------------------------------------------------------------
	local side = CreateFrame("Frame", nil, w)
	side:SetPoint("TOPLEFT", w, "TOPLEFT", 1, -51)
	side:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", 1, 1)
	side:SetWidth(SIDE_W)
	T:Backdrop(side, T.C.panel, { 0, 0, 0, 0 })
	local sep = T:Tex(side, "BORDER", 1, 1, 1, 0.06)
	sep:SetWidth(1)
	sep:SetPoint("TOPRIGHT", side, "TOPRIGHT", 0, 0)
	sep:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", 0, 0)
	-- Recherche
	local search = UI:EditBox(side, SIDE_W - 20)
	search:SetHeight(26)
	search:SetPoint("TOPLEFT", side, "TOPLEFT", 10, -10)
	search:SetBackdropColor(0.047, 0.051, 0.063, 1)
	local ph = T:Text(search, 12, T.C.faint)
	ph:SetPoint("LEFT", search, "LEFT", 9, 0)
	ph:SetText("Rechercher : dissiper, son...")
	self.search = search

	-- Onglets rangés par catégorie
	local order, used = {}, {}
	for _, cat in ipairs(UI.CATEGORIES) do
		local items = {}
		for _, id in ipairs(cat[2]) do
			local t = self:TabById(id)
			if t then items[#items + 1] = t; used[t] = true end
		end
		if #items > 0 then
			order[#order + 1] = { header = cat[1] }
			for _, t in ipairs(items) do order[#order + 1] = { tab = t } end
		end
	end
	local rest = {}
	for _, t in ipairs(self.tabs) do if not used[t] then rest[#rest + 1] = t end end
	if #rest > 0 then
		order[#order + 1] = { header = "Autres" }
		for _, t in ipairs(rest) do order[#order + 1] = { tab = t } end
	end
	self.navOrder = order
	local navFrames = {}
	local y = -46
	for _, item in ipairs(order) do
		if item.header then
			local h = T:Text(side, 10, T.C.muted)
			h:SetPoint("TOPLEFT", side, "TOPLEFT", 16, y - 8)
			h:SetText(string.upper(item.header))
			navFrames[#navFrames + 1] = h
			y = y - 24
		else
			local tab = item.tab
			local b = CreateFrame("Button", nil, side)
			b:SetHeight(22)
			b:SetPoint("TOPLEFT", side, "TOPLEFT", 0, y)
			b:SetPoint("TOPRIGHT", side, "TOPRIGHT", -1, y)
			local bg = T:Tex(b, "BACKGROUND", 1, 1, 1, 0.06)
			bg:SetAllPoints(b)
			bg:Hide()
			local mark = T:Tex(b, "ARTWORK")
			mark:SetWidth(3)
			mark:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -3)
			mark:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 3)
			T:RegisterAccent(mark)
			local ic = b:CreateTexture(nil, "ARTWORK")
			ic:SetWidth(14); ic:SetHeight(14)
			ic:SetPoint("LEFT", b, "LEFT", 16, 0)
			ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			setIcon(ic, tab.icon)
			local txt = T:Text(b, 13)
			txt:SetPoint("LEFT", ic, "RIGHT", 9, 0)
			txt:SetText(tab.label)
			-- point de couleur : la fonction est activée
			local dot = T:Tex(b, "ARTWORK")
			dot:SetWidth(5); dot:SetHeight(5)
			dot:SetPoint("RIGHT", b, "RIGHT", -12, 0)
			T:RegisterAccent(dot)
			dot:Hide()
			function b:Refresh()
				local sel = UI.current == tab
				if sel then
					bg:Show(); mark:Show(); txt:SetTextColor(1, 1, 1); ic:SetAlpha(1)
				else
					bg:Hide(); mark:Hide(); txt:SetTextColor(T.C.muted[1], T.C.muted[2], T.C.muted[3]); ic:SetAlpha(0.7)
				end
				local on = false
				if tab.active then
					local ok, res = pcall(tab.active)
					on = ok and res and true or false
				end
				if on then dot:Show() else dot:Hide() end
			end
			b:SetScript("OnEnter", function()
				if UI.current ~= tab then txt:SetTextColor(0.88, 0.89, 0.92); ic:SetAlpha(1) end
			end)
			b:SetScript("OnLeave", function() b:Refresh() end)
			b:SetScript("OnClick", function() PlaySound("igMainMenuOptionCheckBoxOn"); UI:Select(tab) end)
			tab.nav = b
			b:Refresh()
			navFrames[#navFrames + 1] = b
			y = y - 22
		end
	end
	for _, t in ipairs(self.tabs) do
		-- sécurité : tout onglet a un bouton (même vide) pour RefreshCurrent / Select
		if not t.nav then t.nav = { Refresh = function() end } end
	end

	-- Résultats de recherche (à la place des onglets pendant la recherche)
	local results, RES = {}, 15
	local count = T:Text(side, 10, T.C.muted)
	count:SetPoint("TOPLEFT", side, "TOPLEFT", 16, -50)
	count:Hide()
	for i = 1, RES do
		local r = CreateFrame("Button", nil, side)
		r:SetHeight(32)
		r:SetPoint("TOPLEFT", side, "TOPLEFT", 4, -68 - (i - 1) * 33)
		r:SetPoint("TOPRIGHT", side, "TOPRIGHT", -5, -68 - (i - 1) * 33)
		local bg = T:Tex(r, "BACKGROUND", 1, 1, 1, 0.05)
		bg:SetAllPoints(r)
		bg:Hide()
		r.label = T:Text(r, 12)
		r.label:SetPoint("TOPLEFT", r, "TOPLEFT", 10, -3)
		r.label:SetWidth(SIDE_W - 26); r.label:SetHeight(14); r.label:SetJustifyH("LEFT")
		r.where = T:Text(r, 10)
		r.where:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -1)
		r.where:SetWidth(SIDE_W - 26); r.where:SetHeight(12); r.where:SetJustifyH("LEFT")
		T:RegisterAccent(r.where, "text")
		r:SetScript("OnEnter", function() bg:Show() end)
		r:SetScript("OnLeave", function() bg:Hide() end)
		r:SetScript("OnClick", function(self) if self.res then UI:Reveal(self.res.tab, self.res.frame) end end)
		r:Hide()
		results[i] = r
	end
	local function showNav(on)
		for _, f in ipairs(navFrames) do if on then f:Show() else f:Hide() end end
	end
	local function update()
		local text = search:GetText() or ""
		if text == "" and GetCurrentKeyBoardFocus() ~= search then ph:Show() else ph:Hide() end
		local list = UI:Search(text)
		if not list then
			showNav(true)
			count:Hide()
			for i = 1, RES do results[i]:Hide() end
			return
		end
		showNav(false)
		count:SetText(#list == 0 and "AUCUN RÉSULTAT" or (#list .. " RÉSULTAT" .. (#list > 1 and "S" or "")
			.. (#list > RES and (" (" .. RES .. " PREMIERS)") or "")))
		count:Show()
		for i = 1, RES do
			local r, res = results[i], list[i]
			r.res = res
			if res then
				r.label:SetText(res.isTab and ("|cffffffff" .. res.label .. "|r") or res.label)
				r.where:SetText(res.isTab and "Page" or res.tab.label)
				r:Show()
			else
				r:Hide()
			end
		end
	end
	search:SetScript("OnTextChanged", update)
	search:HookScript("OnEditFocusGained", function() ph:Hide() end)
	search:HookScript("OnEditFocusLost", update)
	search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
	search:SetScript("OnEnterPressed", function(self)
		-- Entrée : ouvre le premier résultat
		self:ClearFocus()
		local r = results[1]
		if r:IsShown() and r.res then UI:Reveal(r.res.tab, r.res.frame) end
	end)

	-- Zone de contenu défilante ---------------------------------------------------------
	local sf = CreateFrame("ScrollFrame", nil, w)
	sf:SetPoint("TOPLEFT", side, "TOPRIGHT", 8, -6)
	sf:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -18, 52)
	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange()
		local v = math.max(0, math.min(range, self:GetVerticalScroll() - delta * 48))
		self:SetVerticalScroll(v)
		UI:UpdateScrollBar()
	end)
	sf:SetScript("OnScrollRangeChanged", function() UI:UpdateScrollBar() end)
	self.scroll = sf

	local sb = CreateFrame("Slider", nil, w)
	sb:SetOrientation("VERTICAL")
	sb:EnableMouse(true)   -- pour pouvoir saisir la barre de défilement
	sb:SetWidth(6)
	sb:SetPoint("TOPRIGHT", w, "TOPRIGHT", -6, -56)
	sb:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -6, 54)
	local sbt = T:Tex(sb, "BACKGROUND", 1, 1, 1, 0.04)
	sbt:SetAllPoints(sb)
	sb:SetThumbTexture(T.TEX)
	local thumb = sb:GetThumbTexture()
	thumb:SetWidth(6); thumb:SetHeight(40)
	T:RegisterAccent(thumb, "vertex", 0.8)
	sb:SetScript("OnValueChanged", function(_, v) sf:SetVerticalScroll(v) end)
	sb:Hide()
	self.scrollbar = sb

	-- Pied de fenêtre : raccourcis + Annuler / Valider -------------------------------------
	local foot = CreateFrame("Frame", nil, w)
	foot:SetPoint("BOTTOMLEFT", side, "BOTTOMRIGHT", 0, 0)
	foot:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -1, 1)
	foot:SetHeight(48)
	T:Backdrop(foot, { 0.071, 0.078, 0.094, 1 }, { 0, 0, 0, 0 })
	local line = T:Tex(foot, "ARTWORK", 1, 1, 1, 0.07)
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", foot, "TOPLEFT", 0, 0)
	line:SetPoint("TOPRIGHT", foot, "TOPRIGHT", 0, 0)
	-- raccourcis toujours visibles : mode test (faux raid de 25) et déplacement des cadres
	local bTest, bLock
	local function footRefresh()
		local PV = VP.Preview
		local on = PV and PV.shown
		bTest.text:SetText(on and "Arrêter le test" or "Mode test")
		if on then bTest.text:SetTextColor(T:Accent()) else bTest.text:SetTextColor(T.C.text[1], T.C.text[2], T.C.text[3]) end
		bLock.text:SetText(VP.db.locked and "Déplacer les cadres" or "Verrouiller les cadres")
	end
	bTest = UI:Button(foot, "Mode test", 130, function()
		local PV = VP.Preview
		if PV.shown then PV:Hide() else PV:Show(25); PV.fromUI = true end
		footRefresh()
		UI:RefreshCurrent()
	end)
	bTest:SetPoint("LEFT", foot, "LEFT", 14, 0)
	bTest:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Faux raid de 25 joueurs pour régler l'affichage")
		GameTooltip:AddLine("Choisissez 5, 10 ou 40 joueurs dans « Taille et disposition »", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	bTest:HookScript("OnLeave", function() GameTooltip:Hide() end)
	bLock = UI:Button(foot, "Déplacer les cadres", 150, function()
		VP.db.locked = not VP.db.locked
		VP:RefreshAll()
		footRefresh()
		UI:RefreshCurrent()
	end)
	bLock:SetPoint("LEFT", bTest, "RIGHT", 8, 0)
	bLock:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Affiche des poignées au-dessus des panneaux pour les déplacer")
		GameTooltip:AddLine("Les changements s'affichent tout de suite ; « Annuler » rétablit tout", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	bLock:HookScript("OnLeave", function() GameTooltip:Hide() end)
	self.footRefresh = footRefresh
	w:HookScript("OnShow", footRefresh)
	local ok = UI:Button(foot, "Valider", 120, function()
		UI.snapshot = nil
		VP.Clicks:Apply()
		w:Hide()
		VP:Print("Réglages validés et enregistrés.")
	end, true)
	ok:SetPoint("RIGHT", foot, "RIGHT", -14, 0)
	local cancel = UI:Button(foot, "Annuler", 110, function() UI:Revert() end)
	cancel:SetPoint("RIGHT", ok, "LEFT", -8, 0)
	cancel.text:SetTextColor(T.C.danger[1], T.C.danger[2], T.C.danger[3])
	self:ApplyScale()
end

-- Copie des réglages à l'ouverture, pour pouvoir annuler
-- (le mode Essentiel / Tous et l'échelle de la fenêtre ne sont pas annulés par « Annuler »)
local SKIP = { profiles = true, chars = true, uiShowAll = true, uiScale = true }
function UI:TakeSnapshot()
	local snap = {}
	for k, v in pairs(VP.db) do
		if not SKIP[k] then snap[k] = VP.deepCopy(v) end
	end
	self.snapshot = snap
end

function UI:Revert()
	if not self.snapshot then return end
	if InCombatLockdown() then VP:Print("Impossible d'annuler en combat.") return end
	-- une saisie en cours ne doit pas s'écrire dans les réglages rétablis
	local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
	if focus then focus:ClearFocus() end
	for k in pairs(VP.db) do
		if not SKIP[k] then VP.db[k] = nil end
	end
	for k, v in pairs(self.snapshot) do VP.db[k] = VP.deepCopy(v) end
	VP:RefreshAll()
	VP.Theme:ApplyAccent()
	self:TakeSnapshot()
	self:InvalidatePages()
	VP:Print("Modifications annulées : réglages rétablis comme à l'ouverture.")
end

-- Les pages gardent des liens vers les tables de réglages lues à leur construction : après un
-- chargement de profil, une remise à zéro des couleurs ou une annulation, on les reconstruit.
function UI:InvalidatePages()
	for _, t in ipairs(self.tabs) do
		if t.page then t.page.frame:Hide(); t.page = nil end
	end
	if self.window and self.window:IsShown() then self:Select(self.current or self.tabs[1]) end
end

function UI:Open(tabId)
	if not self.window then self:Build() end
	local w = self.window
	if not w:IsShown() then self:TakeSnapshot() end
	w:Show()
	local target = self.current or self.tabs[1]
	if tabId then
		for _, t in ipairs(self.tabs) do if t.id == tabId then target = t end end
	end
	self:Select(target)
end

function UI:Toggle()
	if self.window and self.window:IsShown() then self.window:Hide() else self:Open() end
end
