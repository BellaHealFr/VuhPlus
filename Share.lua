-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Import / export de profils en texte (copier-coller entre joueurs)
-- Format maison, lu par un petit analyseur : un texte importé n'est JAMAIS exécuté comme du code
-- (pas de loadstring), il ne peut contenir que des tables, textes, nombres et booléens.
--   table  : { clé = valeur ; ... }      texte : "..." (\\ \" \n et \p pour « | »)
--   nombre : #12.5                        booléen : T / F
local VP = VuhPlus
local SH = VP:NewModule("Share")

SH.PREFIX = "VUHPLUS1:"
local MAX_LEN, MAX_DEPTH = 300000, 25

-- Écriture ----------------------------------------------------------------------------
local function escape(s)
	return (s:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\n", "\\n"):gsub("|", "\\p"))
end
local function write(v, out, depth)
	local t = type(v)
	if t == "string" then out[#out + 1] = "\"" .. escape(v) .. "\""
	elseif t == "number" then out[#out + 1] = "#" .. tostring(v)
	elseif t == "boolean" then out[#out + 1] = v and "T" or "F"
	elseif t == "table" then
		if depth > MAX_DEPTH then out[#out + 1] = "{}" return end
		out[#out + 1] = "{"
		-- clés triées : le même profil donne toujours le même texte
		local keys = {}
		for k in pairs(v) do
			local kt = type(k)
			if (kt == "string" or kt == "number") and type(v[k]) ~= "function" and type(v[k]) ~= "userdata" then keys[#keys + 1] = k end
		end
		table.sort(keys, function(a, b)
			if type(a) == type(b) then return a < b end
			return type(a) == "number"
		end)
		for _, k in ipairs(keys) do
			write(k, out, depth + 1)
			out[#out + 1] = "="
			write(v[k], out, depth + 1)
			out[#out + 1] = ";"
		end
		out[#out + 1] = "}"
	else
		out[#out + 1] = "F"
	end
end
function SH:Serialize(v)
	local out = {}
	write(v, out, 0)
	return table.concat(out)
end

-- Lecture -----------------------------------------------------------------------------
local UNESC = { ["\\"] = "\\", ["\""] = "\"", n = "\n", p = "|" }
function SH:Deserialize(str)
	if type(str) ~= "string" or #str > MAX_LEN then return nil, "texte trop long" end
	local pos = 1
	local function skip() pos = str:find("[^%s]", pos) or (#str + 1) end
	local value
	local function readString()
		pos = pos + 1   -- guillemet ouvrant
		local buf = {}
		while true do
			local c = str:sub(pos, pos)
			if c == "" then error("texte non terminé") end
			if c == "\"" then pos = pos + 1 break end
			if c == "\\" then
				local n = str:sub(pos + 1, pos + 1)
				if not UNESC[n] then error("échappement inconnu") end
				buf[#buf + 1] = UNESC[n]
				pos = pos + 2
			else
				buf[#buf + 1] = c
				pos = pos + 1
			end
		end
		return table.concat(buf)
	end
	function value(depth)
		if depth > MAX_DEPTH then error("trop de niveaux") end
		skip()
		local c = str:sub(pos, pos)
		if c == "\"" then return readString()
		elseif c == "#" then
			local num = str:match("^#(-?[%d%.eE%+%-]+)", pos)
			local n = num and tonumber(num)
			if not n then error("nombre invalide") end
			pos = pos + 1 + #num
			return n
		elseif c == "T" then pos = pos + 1 return true
		elseif c == "F" then pos = pos + 1 return false
		elseif c == "{" then
			pos = pos + 1
			local t = {}
			while true do
				skip()
				if str:sub(pos, pos) == "}" then pos = pos + 1 break end
				local k = value(depth + 1)
				if type(k) ~= "string" and type(k) ~= "number" then error("clé invalide") end
				skip()
				if str:sub(pos, pos) ~= "=" then error("« = » attendu") end
				pos = pos + 1
				t[k] = value(depth + 1)
				skip()
				if str:sub(pos, pos) == ";" then pos = pos + 1 end
			end
			return t
		end
		error("caractère inattendu « " .. c .. " »")
	end
	local ok, res = pcall(value, 0)
	if not ok then return nil, tostring(res):gsub("^.-:%d+: ", "") end
	return res
end

-- Profils -----------------------------------------------------------------------------
-- Réglages actuels (comme « Enregistrer le profil »)
function SH:CurrentSettings()
	local p = {}
	for k in pairs(VP.defaults) do
		if VP.db[k] ~= nil then p[k] = VP.deepCopy(VP.db[k]) end
	end
	p.hotSlots = VP.db.hotSlots and VP.deepCopy(VP.db.hotSlots) or nil
	return p
end

function SH:Export(profileName)
	local data
	if profileName and profileName ~= "" then
		data = VP.db.profiles[profileName]
		if not data then return nil, "profil introuvable : " .. profileName end
	else
		data = self:CurrentSettings()
	end
	return self.PREFIX .. self:Serialize(data)
end

-- Vérification EN PROFONDEUR d'après les réglages par défaut : une valeur du mauvais type est retirée
-- (le défaut la remplace au chargement). Sans ça, une couleur { "a" } ou une taille en texte passait
-- et provoquait des erreurs Lua à chaque mise à jour des cadres.
local function sanitize(v, def, depth)
	if type(v) ~= "table" or type(def) ~= "table" or depth > 8 then return end
	for k, val in pairs(v) do
		local dk = def[k]
		if dk ~= nil then
			if type(val) ~= type(dk) then v[k] = nil
			elseif type(val) == "table" then sanitize(val, dk, depth + 1) end
		end
	end
end

-- Bornes des réglages qui changent la taille des cadres (mêmes limites que les curseurs)
local LIMITS = {
	width = { 40, 300 }, hpHeight = { 12, 120 }, manaHeight = { 1, 30 }, fontSize = { 8, 28 }, scale = { 0.5, 3 },
	scale25 = { 0.5, 2 }, scale40 = { 0.5, 2 }, hotSize = { 8, 48 }, bossSize = { 12, 64 }, dispelSize = { 10, 48 },
	remindSize = { 10, 48 }, indSize = { 10, 48 }, raidIconSize = { 8, 48 }, arrowSize = { 8, 48 },
	xGap = { 0, 20 }, yGap = { 0, 20 }, padX = { 0, 30 }, padY = { 0, 30 }, perColumn = { 1, 10 },
}

-- Emplacements de HoTs : par classe, 6 emplacements { spell = texte, color = { r, g, b }, ... }
local function sanitizeSlots(t)
	for class, list in pairs(t) do
		if type(class) ~= "string" or type(list) ~= "table" then t[class] = nil
		else
			for i, sl in pairs(list) do
				if type(i) ~= "number" or type(sl) ~= "table" then list[i] = nil
				else
					if type(sl.spell) ~= "string" then sl.spell = "" end
					local c = sl.color
					if type(c) ~= "table" or type(c[1]) ~= "number" or type(c[2]) ~= "number" or type(c[3]) ~= "number" then
						sl.color = { 0.5, 0.5, 0.5 }
					end
					if sl.pos ~= nil and type(sl.pos) ~= "string" then sl.pos = nil end
					for _, f in ipairs({ "offX", "offY", "size" }) do
						if sl[f] ~= nil and type(sl[f]) ~= "number" then sl[f] = 0 end
					end
				end
			end
		end
	end
end

function SH:Import(text, name)
	text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if text:sub(1, #self.PREFIX) ~= self.PREFIX then return false, "ce n'est pas un texte VuhPlus (il doit commencer par " .. self.PREFIX .. ")" end
	local data, err = self:Deserialize(text:sub(#self.PREFIX + 1))
	if type(data) ~= "table" then return false, err or "contenu invalide" end
	-- seules les clés de réglages connues sont gardées (rien d'autre n'entre dans la sauvegarde)
	local clean = {}
	-- et seulement avec le bon type (un nombre reste un nombre...) : un texte abîmé ne casse pas l'addon
	for k, v in pairs(data) do
		if (VP.defaults[k] ~= nil and type(v) == type(VP.defaults[k])) or (k == "hotSlots" and type(v) == "table") then clean[k] = v end
	end
	for k, v in pairs(clean) do
		if k == "hotSlots" then sanitizeSlots(v)
		elseif type(v) == "table" then sanitize(v, VP.defaults[k], 1)
		elseif LIMITS[k] and type(v) == "number" then
			clean[k] = math.max(LIMITS[k][1], math.min(LIMITS[k][2], v))
		end
	end
	if not next(clean) then return false, "aucun réglage reconnu" end
	name = (name and name ~= "") and name or ("Importé " .. date("%d/%m %H:%M"))
	VP.db.profiles[name] = clean
	return true, name
end

-- Fenêtre de texte (export : sélectionné, prêt pour Ctrl+C ; import : coller puis valider) -------
function SH:Window(title, text, onOk, okLabel)
	local T, UI = VP.Theme, VP.UI
	local w = self.win
	if not w then
		w = CreateFrame("Frame", "VuhPlusShareWindow", UIParent)
		w:SetWidth(520); w:SetHeight(360)
		w:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
		w:SetFrameStrata("FULLSCREEN_DIALOG")
		w:EnableMouse(true); w:SetMovable(true)
		w:RegisterForDrag("LeftButton")
		w:SetScript("OnDragStart", w.StartMoving)
		w:SetScript("OnDragStop", w.StopMovingOrSizing)
		T:Backdrop(w, T.C.bg, T.C.border)
		w.title = T:Text(w, 14, nil, nil, nil, true)
		w.title:SetPoint("TOPLEFT", w, "TOPLEFT", 12, -10)
		w.hint = T:Text(w, 11, T.C.muted)
		w.hint:SetPoint("TOPLEFT", w.title, "BOTTOMLEFT", 0, -4)
		local box = CreateFrame("Frame", nil, w)
		box:SetPoint("TOPLEFT", w, "TOPLEFT", 12, -50)
		box:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -12, 44)
		T:Backdrop(box, { 0.03, 0.03, 0.04, 1 }, T.C.border)
		local sf = CreateFrame("ScrollFrame", nil, box)
		sf:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -6)
		sf:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -6, 6)
		local e = CreateFrame("EditBox", nil, sf)
		e:SetMultiLine(true)
		e:SetAutoFocus(false)
		e:SetMaxLetters(0)
		e:SetWidth(480)
		e:SetFontObject(ChatFontNormal)
		e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
		sf:SetScrollChild(e)
		sf:EnableMouseWheel(true)
		sf:SetScript("OnMouseWheel", function(self, delta)
			self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 30)))
		end)
		box:EnableMouse(true)
		box:SetScript("OnMouseDown", function() e:SetFocus() end)
		w.edit = e
		w.ok = UI:Button(w, "Valider", 140, function() if w.onOk then w.onOk(e:GetText()) end end, true)
		w.ok:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -12, 12)
		local close = UI:Button(w, "Fermer", 100, function() w:Hide() end)
		close:SetPoint("RIGHT", w.ok, "LEFT", -8, 0)
		tinsert(UISpecialFrames, "VuhPlusShareWindow")   -- Échap ferme la fenêtre
		self.win = w
	end
	w.title:SetText(title)
	w.onOk = onOk
	if onOk then
		w.ok.text:SetText(okLabel or "Valider")
		w.ok:Show()
		w.hint:SetText("Collez le texte (Ctrl+V) puis validez.")
	else
		w.ok:Hide()
		w.hint:SetText("Texte sélectionné : Ctrl+C pour le copier.")
	end
	w.edit:SetText(text or "")
	w:Show()
	w.edit:SetFocus()
	if not onOk then w.edit:HighlightText() end
end
