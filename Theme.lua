-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Thème visuel moderne : couleurs, polices, bordures fines, couleur d'accent
local VP = VuhPlus
local T = VP:NewModule("Theme")

T.TEX = "Interface\\Buttons\\WHITE8X8"
T.FONT = "Fonts\\ARIALN.TTF"        -- police nette et étroite (incluse dans le client)
T.FONT_TITLE = "Fonts\\FRIZQT__.TTF"

-- Polices incluses dans le client 3.3.5
T.FONTS = {
	{ "ARIALN", "Arial étroit (moderne)", "Fonts\\ARIALN.TTF" },
	{ "FRIZ", "Friz Quadrata (Blizzard)", "Fonts\\FRIZQT__.TTF" },
	{ "MORPH", "Morpheus (médiéval)", "Fonts\\MORPHEUS.TTF" },
	{ "SKURRI", "Skurri (gras)", "Fonts\\skurri.ttf" },
}
function T:FontPath(key)
	-- police SharedMedia : « LSM:Nom »
	if key and string.sub(key, 1, 4) == "LSM:" then
		local lsm = self:LSM()
		local path = lsm and lsm:Fetch("font", string.sub(key, 5), true)
		if path then return path end
	end
	for _, f in ipairs(self.FONTS) do
		if f[1] == key then return f[3] end
	end
	return self.FONT
end

-- LibSharedMedia-3.0 (facultative) : textures et polices partagées avec les autres addons
function T:LSM()
	return LibStub and LibStub("LibSharedMedia-3.0", true)
end
-- Chemin d'une texture de barre SharedMedia (nil si aucune choisie ou introuvable)
function T:BarTexture(name)
	if not name or name == "" then return nil end
	local lsm = self:LSM()
	return lsm and lsm:Fetch("statusbar", name, true) or nil
end
-- Listes pour les menus : { clé, libellé } (60 au plus)
function T:LSMList(kind, prefix)
	local out = {}
	local lsm = self:LSM()
	if not lsm then return out end
	for _, name in ipairs(lsm:List(kind)) do
		if #out >= 60 then break end
		out[#out + 1] = { (prefix or "") .. name, name }
	end
	return out
end

T.ACCENTS = {
	{ "vert",   "Émeraude", 0.20, 0.85, 0.55 },
	{ "bleu",   "Azur",     0.30, 0.62, 1.00 },
	{ "violet", "Améthyste",0.68, 0.45, 1.00 },
	{ "or",     "Or",       1.00, 0.76, 0.25 },
	{ "rouge",  "Rubis",    1.00, 0.36, 0.40 },
	{ "cyan",   "Turquoise",0.20, 0.85, 0.90 },
}

T.C = {
	bg      = { 0.059, 0.063, 0.078, 0.97 },  -- fond de fenêtre
	panel   = { 0.075, 0.082, 0.102, 1 },     -- barre latérale, encarts
	card    = { 0.090, 0.102, 0.125, 1 },     -- cartes (sections)
	control = { 0.122, 0.137, 0.165, 1 },     -- boutons, listes, champs, interrupteurs
	hover   = { 0.155, 0.170, 0.200, 1 },
	border  = { 0, 0, 0, 1 },                 -- bordure noire (cadres de soin, icônes)
	edge    = { 1, 1, 1, 0.09 },              -- bordure douce de l'interface
	line    = { 1, 1, 1, 0.06 },
	text    = { 0.925, 0.933, 0.949 },
	muted   = { 0.56, 0.585, 0.63 },
	faint   = { 0.44, 0.46, 0.51 },
	danger  = { 1, 0.54, 0.55 },
	onAccent = { 0.03, 0.08, 0.05 },          -- texte sur un bouton plein de couleur d'accent
}

function T:Accent()
	local key = VP.db and VP.db.accent or "vert"
	for _, a in ipairs(self.ACCENTS) do
		if a[1] == key then return a[3], a[4], a[5] end
	end
	local a = self.ACCENTS[1]
	return a[3], a[4], a[5]
end

-- Éléments qui suivent la couleur d'accent (recolorés quand on la change)
T.accented = {}
function T:RegisterAccent(obj, kind, alpha)
	table.insert(self.accented, { obj = obj, kind = kind or "vertex", alpha = alpha or 1 })
	self:ColorAccent(self.accented[#self.accented])
end
function T:ColorAccent(e)
	local r, g, b = self:Accent()
	local o = e.obj
	if e.kind == "text" then o:SetTextColor(r, g, b, e.alpha)
	elseif e.kind == "border" then o:SetBackdropBorderColor(r, g, b, e.alpha)
	elseif e.kind == "bar" then o:SetStatusBarColor(r, g, b, e.alpha)
	elseif e.kind == "backdrop" then
		-- bouton plein (principal) : ne pas écraser la couleur de survol en cours
		if not o.vpHover then o:SetBackdropColor(r, g, b, e.alpha) end
		o:SetBackdropBorderColor(r, g, b, 1)
	else o:SetVertexColor(r, g, b, e.alpha) end
end
function T:ApplyAccent()
	for _, e in ipairs(self.accented) do self:ColorAccent(e) end
end

-- Fond + bordure 1 pixel
function T:Backdrop(f, bg, border)
	f:SetBackdrop({ bgFile = self.TEX, edgeFile = self.TEX, edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	bg = bg or self.C.bg
	border = border or self.C.border
	f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
	f:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

function T:SetFont(fs, size, flags, title, path)
	fs:SetFont(path or (title and self.FONT_TITLE or self.FONT), size or 12, flags or "")
	if not flags or flags == "" then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	else
		fs:SetShadowOffset(0, 0)
	end
end

function T:Text(parent, size, color, flags, layer, title)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	self:SetFont(fs, size, flags, title)
	color = color or self.C.text
	fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
	return fs
end

function T:Tex(parent, layer, r, g, b, a)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	t:SetTexture(self.TEX)
	if r then t:SetVertexColor(r, g, b, a or 1) end
	return t
end

-- Léger dégradé de brillance (donne du relief aux barres plates)
function T:Gloss(parent)
	local t = parent:CreateTexture(nil, "OVERLAY")
	t:SetTexture(self.TEX)
	t:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	t:SetPoint("BOTTOMRIGHT", parent, "RIGHT", 0, 0)
	t:SetGradientAlpha("VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.08)
	return t
end

-- Poignée de déplacement moderne (pilule d'accent)
function T:Handle(anchor, label, onStart, onStop)
	local h = CreateFrame("Button", nil, anchor)
	h:SetHeight(16)
	h:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
	self:Backdrop(h, self.C.panel, self.C.border)
	local bar = self:Tex(h, "ARTWORK")
	bar:SetPoint("TOPLEFT", h, "TOPLEFT", 1, -1)
	bar:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 1, 1)
	bar:SetWidth(3)
	self:RegisterAccent(bar)
	local txt = self:Text(h, 11)
	txt:SetPoint("LEFT", h, "LEFT", 9, 0)
	txt:SetText(label .. "  |cff888888(glisser)|r")
	h:SetWidth(math.max(110, txt:GetStringWidth() + 18))
	h:RegisterForDrag("LeftButton")
	h:SetScript("OnDragStart", onStart)
	h:SetScript("OnDragStop", onStop)
	h:SetScript("OnEnter", function(self) self:SetBackdropColor(T.C.hover[1], T.C.hover[2], T.C.hover[3], 1) end)
	h:SetScript("OnLeave", function(self) self:SetBackdropColor(T.C.panel[1], T.C.panel[2], T.C.panel[3], 1) end)
	return h
end

-- Raccourcit un nom UTF-8 à n caractères
function T:Truncate(s, n)
	if not s or not n or n <= 0 then return s end
	local out, count = "", 0
	for ch in string.gmatch(s, "[%z\1-\127\194-\244][\128-\191]*") do
		count = count + 1
		if count > n then return out end
		out = out .. ch
	end
	return out
end

function T:Refresh()
	self:ApplyAccent()
end
