-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- Faux client World of Warcraft 3.3.5 (Lua 5.1) pour faire tourner le vrai code de VuhPlus.
-- Seules des fonctions qui existent dans le client 3.3.5 sont définies ; toute lecture d'une
-- variable globale inconnue est une erreur (sauf la liste des globales facultatives ci-dessous).

ERRORS, CHAT, ADDONMSG, PRINTS, SOUNDS = {}, {}, {}, {}, {}
local function recordError(msg)
	ERRORS[#ERRORS + 1] = tostring(msg)
end

-- Monde simulé ------------------------------------------------------------------------
W = { now = 1000, lockdown = false, units = {}, byGUID = {}, byName = {}, raid = {}, party = {},
	spellbook = {}, inspect = nil, playerTalents = { 0, 0, 0 }, frames = {}, events = {}, instance = "none",
	leader = nil, officers = {}, readyStatus = {} }

-- Base de sorts (ID -> nom, icône) : seulement ce dont les scénarios ont besoin, le reste est générique
SPELLS = {
	[5487] = "Forme d'ours", [9634] = "Forme d'ours redoutable", [768] = "Forme de félin",
	[48263] = "Présence de givre", [48266] = "Présence de sang", [48265] = "Présence impie",
	[25780] = "Fureur vertueuse", [15473] = "Forme d'Ombre", [24858] = "Forme de sélénien", [33891] = "Arbre de vie",
	[63645] = "Activation de la spécialisation principale", [63644] = "Activation de la spécialisation secondaire",
	[527] = "Dissipation de la magie", [552] = "Abolir maladie", [528] = "Guérison des maladies",
	[2061] = "Soins rapides", [2060] = "Soins supérieurs", [139] = "Rénovation", [17] = "Mot de pouvoir : Bouclier",
	[2050] = "Soins inférieurs", [2006] = "Résurrection", [33076] = "Prière de guérison", [47540] = "Pénitence",
	[48438] = "Croissance sauvage", [20484] = "Renaissance", [29166] = "Innervation", [47788] = "Esprit gardien",
	[33206] = "Suppression de la douleur", [6788] = "Âme affaiblie", [20243] = "Dévastation",
}
local function spellName(id) return SPELLS[id] or ("Sort " .. id) end
local nameToId = {}
for id, n in pairs(SPELLS) do nameToId[n] = id end

-- Objets d'interface ---------------------------------------------------------------------
local methods = {}
local ObjMT = {}
ObjMT.__index = function(t, k)
	local m = methods[k]
	if m then return m end
	-- méthode WoW non simulée : sans effet (les champs de l'addon commencent par une minuscule)
	if type(k) == "string" and k:match("^%u") then return function() end end
	return nil
end

local function runScript(o, name, ...)
	local list = rawget(o, "__scripts")[name]
	if not list then return end
	for _, f in ipairs(list) do
		local ok, err = pcall(f, o, ...)
		if not ok then recordError(err) end
	end
end
SIM_RUNSCRIPT = runScript

local function newObj(kind, name, parent)
	local o = setmetatable({ __kind = kind, __attr = {}, __scripts = {}, __shown = true, __w = 0, __h = 0,
		__parent = parent, __children = {}, __name = name, __events = {}, __alpha = 1, __scale = 1, __text = "",
		__value = 0, __min = 0, __max = 1 }, ObjMT)
	if parent then table.insert(rawget(parent, "__children"), o) end
	if name then _G[name] = o end
	if kind ~= "Texture" and kind ~= "FontString" then table.insert(W.frames, o) end
	return o
end
SIM_NEWOBJ = newObj

function methods:GetObjectType() return self.__kind end
function methods:GetName() return self.__name end
function methods:GetParent() return self.__parent end
function methods:SetParent(p)
	local old = self.__parent
	if old then
		local ch = rawget(old, "__children")
		for i = #ch, 1, -1 do if ch[i] == self then table.remove(ch, i) end end
	end
	self.__parent = p
	if p then table.insert(rawget(p, "__children"), self) end
end
function methods:GetChildren()
	local out = {}
	for _, c in ipairs(self.__children) do if c.__kind ~= "Texture" and c.__kind ~= "FontString" then out[#out + 1] = c end end
	return unpack(out)
end
function methods:IsShown() return self.__shown end
function methods:IsVisible()
	local o = self
	while o do
		if not o.__shown then return false end
		o = o.__parent
	end
	return true
end
function methods:Show()
	if self.__shown then return end
	local was = self:IsVisible()
	self.__shown = true
	if not was and self:IsVisible() then runScript(self, "OnShow") end
end
function methods:Hide()
	if not self.__shown then return end
	local was = self:IsVisible()
	self.__shown = false
	if was then runScript(self, "OnHide") end
end
function methods:SetScript(name, f)
	self.__scripts[name] = f and { f } or nil
end
function methods:GetScript(name)
	local l = self.__scripts[name]
	return l and l[1]
end
function methods:HookScript(name, f)
	local l = self.__scripts[name]
	if not l then l = {}; self.__scripts[name] = l end
	l[#l + 1] = f
end
function methods:RegisterEvent(e) self.__events[e] = true; W.events[e] = true end
function methods:UnregisterEvent(e) self.__events[e] = nil end
function methods:UnregisterAllEvents() self.__events = {} end
function methods:IsEventRegistered(e) return self.__events[e] and 1 or nil end
function methods:SetAttribute(k, v)
	if W.lockdown and self.__protected then error("Action bloquée : SetAttribute en combat sur un cadre protégé (" .. tostring(k) .. ")") end
	self.__attr[k] = v
	runScript(self, "OnAttributeChanged", k, v)
end
function methods:GetAttribute(k) return self.__attr[k] end
function methods:SetWidth(w) self.__w = w end
function methods:SetHeight(h) self.__h = h end
function methods:GetWidth() return self.__w end
function methods:GetHeight() return self.__h end
function methods:GetLeft() return 100 end
function methods:GetRight() return 100 + self.__w end
function methods:GetTop() return 500 end
function methods:GetBottom() return 500 - self.__h end
function methods:GetCenter() return 100 + self.__w / 2, 500 - self.__h / 2 end
function methods:GetPoint() return "CENTER", UIParent, "CENTER", 0, 0 end
function methods:GetEffectiveScale() return self.__scale end
function methods:GetScale() return self.__scale end
function methods:SetScale(s) self.__scale = s end
function methods:GetAlpha() return self.__alpha end
function methods:SetAlpha(a) self.__alpha = a end
function methods:GetFrameLevel() return 1 end
function methods:IsProtected() return self.__protected and true or false end
function methods:IsMovable() return true end
function methods:IsUnderMouse() return false end
function methods:HasFocus() return false end
function methods:CreateTexture(name) return newObj("Texture", name, self) end
function methods:CreateFontString(name) return newObj("FontString", name, self) end
function methods:SetText(t) self.__text = t == nil and "" or tostring(t) end
function methods:GetText() return self.__text end
function methods:GetStringWidth() return #tostring(self.__text) * 6 end
function methods:SetTexture(t) self.__tex = t; return 1 end
function methods:GetTexture() return self.__tex end
function methods:GetStatusBarTexture()
	local t = rawget(self, "__sbt")
	if not t then t = newObj("Texture", nil, self); self.__sbt = t end
	return t
end
function methods:GetThumbTexture()
	local t = rawget(self, "__thumb")
	if not t then t = newObj("Texture", nil, self); self.__thumb = t end
	return t
end
function methods:SetThumbTexture() return 1 end
function methods:SetValue(v) self.__value = v; runScript(self, "OnValueChanged", v) end
function methods:GetValue() return self.__value end
function methods:SetMinMaxValues(a, b) self.__min, self.__max = a, b end
function methods:GetMinMaxValues() return self.__min, self.__max end
function methods:GetVerticalScroll() return 0 end
function methods:GetVerticalScrollRange() return 0 end
function methods:NumLines() return 0 end
function methods:GetColorRGB() return 1, 1, 1 end
function methods:GetNumPoints() return 1 end

-- Création des cadres, avec les modèles utilisés par VuhPlus
local TEMPLATES_ONLOAD = {
	VuhPlusUnitTemplate = function(o) o:RegisterForClicks("AnyUp"); VuhPlus_InitButton(o) end,
	VuhPlusCureTemplate = function(o) o:RegisterForClicks("AnyUp"); VuhPlus_InitCure(o) end,
}
local PROTECTED = { SecureGroupHeaderTemplate = true, SecureGroupPetHeaderTemplate = true, SecureUnitButtonTemplate = true,
	SecureActionButtonTemplate = true, SecureHandlerStateTemplate = true, VuhPlusUnitTemplate = true, VuhPlusCureTemplate = true }
function CreateFrame(kind, name, parent, template)
	local o = newObj(kind, name, parent)
	if template then
		for t in string.gmatch(template, "[^,%s]+") do
			if PROTECTED[t] then o.__protected = true end
			if t == "SecureGroupHeaderTemplate" or t == "SecureGroupPetHeaderTemplate" then o.__header = true end
		end
		for t in string.gmatch(template, "[^,%s]+") do
			local f = TEMPLATES_ONLOAD[t]
			if f then local ok, err = pcall(f, o); if not ok then recordError(err) end end
		end
	end
	return o
end

UIParent = newObj("Frame", "UIParent")
WorldFrame = newObj("Frame", "WorldFrame")
Minimap = newObj("Frame", "Minimap")
WorldMapFrame = newObj("Frame", "WorldMapFrame"); WorldMapFrame.__shown = false
InterfaceOptionsFrame = newObj("Frame", "InterfaceOptionsFrame"); InterfaceOptionsFrame.__shown = false
ColorPickerFrame = newObj("Frame", "ColorPickerFrame"); ColorPickerFrame.__shown = false
GameTooltip = newObj("GameTooltip", "GameTooltip")
ChatFontNormal = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) PRINTS[#PRINTS + 1] = msg end }
for i = 1, 4 do newObj("Button", "PartyMemberFrame" .. i, UIParent) end
for _, n in ipairs({ "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame" }) do newObj("Button", n, UIParent) end
UISpecialFrames, SlashCmdList, UnitPopupMenus = {}, {}, { SELF = { "RAID_TARGET_ICON", "SET_FOCUS", "CANCEL" } }
RAID_CLASS_COLORS = {}
for _, c in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }) do
	RAID_CLASS_COLORS[c] = { r = 0.8, g = 0.6, b = 0.4 }
end
SPELL_FAILED_LINE_OF_SIGHT = "Hors de la ligne de vue"

-- Bibliothèques Lua du client
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
tinsert, tremove = table.insert, table.remove
bit = { band = function(a, b)
	local r, p = 0, 1
	while a > 0 and b > 0 do
		if a % 2 == 1 and b % 2 == 1 then r = r + p end
		a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
	end
	return r
end }
date = os.date
local errHandler = recordError
function geterrorhandler() return errHandler end
function seterrorhandler(f) errHandler = f end
function debugstack() return "" end
function hooksecurefunc(name, f)
	local orig = _G[name]
	_G[name] = function(...) local r = { orig(...) }; f(...); return unpack(r) end
end

-- Unités ---------------------------------------------------------------------------------
local guidN = 0
function SIM_UNIT(def)
	guidN = guidN + 1
	local u = { name = def.name, class = def.class, guid = string.format("0x%016X", guidN), hp = def.hp or 20000,
		maxhp = def.maxhp or 20000, ptype = def.ptype or 0, power = 8000, maxpower = 10000, buffs = {}, debuffs = {},
		combat = false, connected = true, dead = false, visible = true, inRange = true, x = def.x or 0.5, y = def.y or 0.5,
		talents = def.talents or { 0, 0, 0 }, subgroup = def.subgroup or 1, rank = def.rank or 0 }
	W.byGUID[u.guid] = u
	W.byName[u.name] = u
	return u
end
function SIM_SETRAID(list)
	W.raid, W.party = {}, {}
	for i, u in ipairs(list) do W.raid[i] = u end
end
function SIM_SETPARTY(list)
	W.raid, W.party = {}, {}
	for i, u in ipairs(list) do W.party[i] = u end
end

function SIM_RESOLVE(token)
	if type(token) ~= "string" then return nil end
	if token == "player" then return W.player end
	local n = tonumber(token:match("^raid(%d+)$"))
	if n then return W.raid[n] end
	n = tonumber(token:match("^party(%d+)$"))
	if n then return W.party[n] end
	if token == "target" then return W.target end
	if token == "focus" then return W.focus end
	if token:match("^raidpet") or token:match("^partypet") or token == "pet" or token:match("^boss") or token:match("target$") then return nil end
	return W.byName[token]
end
local R = SIM_RESOLVE

function UnitExists(u) return R(u) ~= nil and 1 or nil end
function UnitGUID(u) local x = R(u); return x and x.guid end
function UnitName(u) local x = R(u); if x then return x.name, nil end end
function UnitClass(u) local x = R(u); if x then return x.class, x.class end end
function UnitIsPlayer(u) return R(u) and 1 or nil end
function UnitIsUnit(a, b) local x, y = R(a), R(b); return x and y and x == y and 1 or nil end
function UnitPowerType(u) local x = R(u); return x and x.ptype or 0 end
function UnitPower(u) local x = R(u); return x and x.power or 0 end
function UnitPowerMax(u) local x = R(u); return x and x.maxpower or 0 end
function UnitHealth(u) local x = R(u); return x and x.hp or 0 end
function UnitHealthMax(u) local x = R(u); return x and x.maxhp or 0 end
function UnitIsConnected(u) local x = R(u); return x and x.connected and 1 or nil end
function UnitIsDeadOrGhost(u) local x = R(u); return x and x.dead and 1 or nil end
function UnitIsGhost() return nil end
function UnitIsFeignDeath() return nil end
function UnitIsAFK() return nil end
function UnitIsCharmed() return nil end
function UnitIsVisible(u) local x = R(u); return x and x.visible and 1 or nil end
function UnitInRange(u) local x = R(u); return x and x.inRange and 1 or nil end
function UnitAffectingCombat(u) local x = R(u); return x and x.combat and 1 or nil end
function UnitIsFriend() return 1 end
function UnitCanAttack() return nil end
function UnitThreatSituation() return nil end
function UnitGroupRolesAssigned() return false, false, false end
function UnitFactionGroup() return "Alliance", "Alliance" end
function UnitPlayerControlled(u) return R(u) and 1 or nil end
function UnitIsPartyLeader(u) local x = R(u); return x and W.leader == x and 1 or nil end
function UnitInRaid(u)
	local x = R(u)
	for i, y in ipairs(W.raid) do if y == x then return i - 1 end end
	return nil
end
function UnitInParty(u)
	local x = R(u)
	if x == W.player and #W.party > 0 then return 1 end
	for _, y in ipairs(W.party) do if y == x then return 1 end end
	return nil
end

local function auraList(x, filter)
	if filter and filter:find("HARMFUL") then return x.debuffs end
	return x.buffs
end
function UnitAura(u, i, filter)
	local x = R(u)
	if not x then return nil end
	local list = auraList(x, filter)
	local a
	if type(i) == "number" then a = list[i] else for _, b in ipairs(list) do if b.name == i then a = b break end end end
	if not a then return nil end
	return a.name, "", a.icon or "Interface\\Icons\\X", a.count or 0, a.dtype, a.dur or 0, a.exp or 0, a.caster, nil, nil, a.id
end
function UnitBuff(u, i) return UnitAura(u, i, "HELPFUL") end
function UnitDebuff(u, i) return UnitAura(u, i, "HARMFUL") end
function GetPlayerMapPosition(u) local x = R(u); if x then return x.x, x.y end return 0, 0 end
function GetPlayerFacing() return 0 end
function GetPlayerInfoByGUID(g) local x = W.byGUID[g]; if x then return x.class, x.class, nil, nil, nil, x.name end end

-- Groupe
function GetNumRaidMembers() return #W.raid end
function GetNumPartyMembers() return #W.party end
function GetRaidRosterInfo(i)
	local x = W.raid[i]
	if not x then return nil end
	return x.name, x.rank, x.subgroup, 80, x.class, x.class, "Zone", x.connected and 1 or nil, x.dead and 1 or nil, x.raidRole
end
function IsRaidLeader() return W.leader == W.player and 1 or nil end
function IsRaidOfficer() return W.officers[W.player] and 1 or nil end
function IsPartyLeader() return W.leader == W.player and 1 or nil end
function GetReadyCheckStatus(u) local x = R(u); return x and W.readyStatus[x] end
function DoReadyCheck() W.didReadyCheck = true end
function ConfirmReadyCheck() end

-- Talents et inspection
function GetActiveTalentGroup() return 1 end
function GetTalentTabInfo(i, inspect)
	local who = inspect and W.inspectDone or (not inspect and W.player)
	local src = who and who.talents
	return (who and who.class or "?") .. " arbre " .. i, "", src and src[i] or 0
end
function CanInspect(u) return R(u) and 1 or nil end
function CheckInteractDistance(u) local x = R(u); return x and x.inRange and 1 or nil end
function NotifyInspect(u) W.inspect = R(u) end
function ClearInspectPlayer() W.inspect = nil end

-- Sorts et objets
function GetSpellInfo(v)
	if type(v) == "number" then return spellName(v), nil, "Interface\\Icons\\S" .. v end
	if type(v) == "string" and W.spellbook[v] then return v, nil, "Interface\\Icons\\S" .. (nameToId[v] or 0) end
	return nil
end
function GetSpellName() return nil end
function GetSpellCooldown() return 0, 0, 1 end
function IsSpellInRange(_, u) local x = R(u); if not x then return nil end return x.inRange and 1 or 0 end
function GetInventoryItemLink() return nil end
function GetInventoryItemTexture() return nil end
function GetInventoryItemCooldown() return 0, 0, 1 end
function GetItemSpell() return nil end
function GetWeaponEnchantInfo() return nil end
function GetNumMacros() return 0, 0 end
function GetMacroInfo() return nil end
function GetCursorInfo() return nil end
function GetCursorPosition() return 0, 0 end
function ClearCursor() end
function GetBindingKey() return nil end
function GetRaidTargetIndex() return nil end
function SetRaidTarget() end
function SetRaidTargetIconTexture() end

-- Divers
function GetTime() return W.now end
function InCombatLockdown() return W.lockdown and 1 or nil end
function IsInInstance() return W.instance ~= "none" and 1 or nil, W.instance end
function GetInstanceInfo() return "Zone", W.instance, 1, "10 joueurs", 10 end
function GetRealmName() return "Royaume" end
function GetCVar() return "0" end
function GetCurrentMapAreaID() return 1 end
function GetCurrentMapDungeonLevel() return 0 end
function SetMapToCurrentZone() end
function GetCurrentKeyBoardFocus() return nil end
function IsShiftKeyDown() return nil end
function IsControlKeyDown() return nil end
function IsAltKeyDown() return nil end
function IsMouseButtonDown() return nil end
function PlaySound(s) SOUNDS[#SOUNDS + 1] = s end
function SendChatMessage(msg, ch) CHAT[#CHAT + 1] = { msg = msg, ch = ch, from = W.player and W.player.name } end
function SendAddonMessage(p, msg, ch) ADDONMSG[#ADDONMSG + 1] = { prefix = p, msg = msg, ch = ch, from = W.player and W.player.name } end
function CooldownFrame_SetTimer() end
function GameTooltip_SetDefaultAnchor() end
function RegisterStateDriver() end
function UnregisterStateDriver() end
function RegisterUnitWatch() end
function UnregisterUnitWatch() end
function InterfaceOptions_AddCategory() end
function UIDropDownMenu_Initialize() end
function ToggleDropDownMenu() end
function UnitPopup_ShowMenu() end
function PartyMemberFrame_UpdateMember() end
function UpdateAddOnMemoryUsage() end
function GetAddOnMemoryUsage() return 1234 end
function UpdateAddOnCPUUsage() end
function GetAddOnCPUUsage() return 0 end

-- Globales qui peuvent légitimement être absentes (bibliothèques facultatives, cadres chargés à la demande)
local OPTIONAL = { LibStub = true, InspectFrame = true, VuhPlusDB = true, RESULT = true }
setmetatable(_G, { __index = function(_, k)
	if OPTIONAL[k] then return nil end
	error("variable globale inconnue du faux client : " .. tostring(k), 2)
end })

-- Pilotage ---------------------------------------------------------------------------------
function SIM_FIRE(event, ...)
	for _, f in ipairs(W.frames) do
		if rawget(f, "__events")[event] then runScript(f, "OnEvent", event, ...) end
	end
end
-- avance le temps de « sec » secondes, par images de « step » (OnUpdate des cadres visibles)
function SIM_RUN(sec, step)
	step = step or 0.05
	local t = 0
	while t < sec - 1e-9 do
		W.now = W.now + step
		t = t + step
		local n = #W.frames
		for i = 1, n do
			local f = W.frames[i]
			if rawget(f, "__scripts").OnUpdate and f:IsVisible() then runScript(f, "OnUpdate", step) end
		end
	end
end
function SIM_COMBAT(on)
	W.lockdown = on
	W.player.combat = on
	for _, u in ipairs(W.raid) do u.combat = on end
	for _, u in ipairs(W.party) do u.combat = on end
	SIM_FIRE(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
end
function SIM_LOADADDON(dir)
	local toc = assert(io.open(dir .. "/VuhPlus.toc", "rb")):read("*a")
	local files = {}
	for line in toc:gmatch("[^\r\n]+") do
		if line:match("%.lua$") then files[#files + 1] = line end
	end
	for _, f in ipairs(files) do
		local src = assert(io.open(dir .. "/" .. f, "rb")):read("*a")
		local chunk, err = loadstring(src, "@" .. f)
		if not chunk then error(err) end
		local ok, e = pcall(chunk, "VuhPlus", {})
		if not ok then recordError(f .. " : " .. tostring(e)) end
	end
	return files
end
