-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Assignations de soin : « Bella = Tankor, Arthos » (une ligne par soigneur)
--  * vos cibles assignées ont une bordure bleue sur leurs cadres ;
--  * elles peuvent remplir le panneau « Projecteur » ;
--  * le chef des soigneurs peut annoncer les assignations au raid.
local VP = VuhPlus
local AS = VP:NewModule("Assign")

AS.map = {}       -- soigneur (minuscules) -> { cibles }
AS.mine = {}      -- cible (minuscules) -> true : MES cibles

local function trim(s) return (s and s:gsub("^%s+", ""):gsub("%s+$", "")) or "" end
local function low(s) return string.lower(s or "") end

-- Texte -> table (lignes « Soigneur = cible1, cible2 » ; « # » ou « -- » : commentaire)
function AS:Parse(text)
	wipe(self.map)
	self.lines = {}
	for line in string.gmatch((text or "") .. "\n", "([^\n]*)\n") do
		line = trim(line)
		if line ~= "" and not line:find("^#") and not line:find("^%-%-") then
			local healer, rest = line:match("^([^=:]+)[=:](.*)$")
			healer = trim(healer)
			if healer ~= "" and rest then
				local targets = {}
				for t in string.gmatch(rest, "[^,;/]+") do
					t = trim(t)
					if t ~= "" then targets[#targets + 1] = t end
				end
				if #targets > 0 then
					self.map[low(healer)] = targets
					self.lines[#self.lines + 1] = { healer = healer, targets = targets }
				end
			end
		end
	end
	wipe(self.mine)
	local me = self.map[low(UnitName("player"))]
	if me then for _, t in ipairs(me) do self.mine[low(t)] = true end end
end

-- appelé à chaque mise à jour de vie : retour immédiat si je n'ai aucune cible
function AS:IsMine(name)
	if not name or next(self.mine) == nil then return false end
	return self.mine[low(name)] or false
end

-- Mes cibles (noms tels qu'écrits)
function AS:MyTargets()
	return self.map[low(UnitName("player"))] or {}
end

function AS:Text() return VP.db.assign.text or "" end
function AS:SetText(text)
	VP.db.assign.text = text or ""
	self:Parse(VP.db.assign.text)
	self:Changed()
end

-- Tout ce qui dépend des assignations : cadres et panneau Projecteur
function AS:Changed()
	if VP.Panels and VP.Panels.ApplySpotlight then VP.Panels:ApplySpotlight() end
	if VP.Frames then
		for _, b in ipairs(VP.Frames.buttons) do
			if b:IsVisible() then VP.Frames:UpdateHealth(b) end
		end
	end
end

-- Modèle : un soigneur par ligne (rôle détecté), cibles à compléter
function AS:Template()
	local t, tanks = {}, {}
	local function scan(u)
		if not UnitExists(u) then return end
		local r = VP.Roles and VP.Roles:GetRole(u)
		local name = UnitName(u)
		if r == "HEALER" then t[#t + 1] = name .. " = "
		elseif r == "TANK" or (VP.Buffs and VP.Buffs:IsTank(u)) then tanks[#tanks + 1] = name end
	end
	local n = GetNumRaidMembers()
	if n > 0 then for i = 1, n do scan("raid" .. i) end
	else
		scan("player")
		for i = 1, GetNumPartyMembers() do scan("party" .. i) end
	end
	if #t == 0 then t[1] = (UnitName("player") or "Moi") .. " = " end
	local head = "# Tanks : " .. (#tanks > 0 and table.concat(tanks, ", ") or "?")
	return head .. "\n" .. table.concat(t, "\n")
end

-- Annonce au raid / groupe (ou dans mon chat si seul)
function AS:Announce()
	if not self.lines or #self.lines == 0 then VP:Print("Aucune assignation à annoncer.") return end
	local ch = VP:GroupChannel()
	local function say(msg)
		if ch then SendChatMessage(msg, ch) else VP:Print(msg) end
	end
	say("Assignations de soin :")
	for i, l in ipairs(self.lines) do
		if i > 12 then break end   -- pas de pluie de messages
		say(l.healer .. " -> " .. table.concat(l.targets, ", "))
	end
end

function AS:OnLogin()
	VP.db.assign.text = VP.db.assign.text or ""
	self:Parse(VP.db.assign.text)
	self:Changed()   -- le Projecteur (créé avant ce module) reçoit mes cibles
	VP:On("PLAYER_ENTERING_WORLD", function() AS:Parse(VP.db.assign.text); AS:Changed() end)
end
