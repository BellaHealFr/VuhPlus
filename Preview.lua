-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Mode test : faux groupe de 5, 10, 25 ou 40 joueurs pour régler l'affichage
local VP = VuhPlus
local PV = VP:NewModule("Preview")
local F = VP.Frames

local I = "Interface\\Icons\\"
local CLASSES = { "WARRIOR", "PRIEST", "DRUID", "MAGE", "ROGUE", "HUNTER", "PALADIN", "SHAMAN", "WARLOCK", "DEATHKNIGHT" }
local NAMES = { "Thrallinor", "Lumiéra", "Feuillard", "Gelidor", "Ombrelame", "Sylvanie", "Arthos", "Krazug", "Morbius", "Glaciel",
	"Brisevent", "Aldric", "Néria", "Tornade", "Fléau", "Vaillance", "Pyra", "Ezrin", "Draknor", "Ombre",
	"Céleste", "Ironpaw", "Valka", "Zephyr", "Ardent", "Korrin", "Selena", "Brann", "Isolde", "Garrok",
	"Mirela", "Tharion", "Vexa", "Dorran", "Elwyn", "Kaelis", "Rhogar", "Syla", "Torvald", "Yrel" }

-- Situations variées pour voir tous les indicateurs
local SPECIAL = {
	[1] = { role = "TANK", raidIcon = 7, aggro = true, boss = I .. "Spell_Shadow_DeathScream", bossCount = 3, hots = { 1, 2 }, absorb = 0.2 },
	[2] = { role = "HEALER", hots = { 3 }, reminder = I .. "Ability_Shaman_WaterShield" },
	[8] = { role = "TANK", reminder = I .. "Spell_Nature_SkinofEarth", hots = { 4, 5, 6 } },
	[3] = { role = "HEALER", lowMana = true, pct = 0.41 },
	[4] = { dispel = "Curse", dicon = I .. "Spell_Shadow_CurseOfTounges" },
	[5] = { emergency = true, pct = 0.30, healRed = I .. "Ability_Warrior_SavageBlow" },
	[6] = { missing = true, far = true },
	[7] = { role = "TANK", raidIcon = 2, hots = { 2, 4 }, pct = 0.55, bossTarget = true, def = I .. "Ability_Warrior_ShieldWall" },
	[9] = { status = "dead", soul = I .. "Spell_Shadow_SoulGem", deadFor = 83 },
	[10] = { dispel = "Magic", dicon = I .. "Spell_Shadow_ShadowWordPain" },
	[11] = { emergency = true, aoe = true, pct = 0.47 },
	[12] = { aoe = true, incoming = 0.25, pct = 0.51 },
	[13] = { aoe = true, pct = 0.66 },
	[14] = { incoming = 0.35, pct = 0.85, absorb = 0.12, casting = true },
	[15] = { status = "offline" },
	[16] = { raidIcon = 8 },
	[21] = { raidIcon = 1 },
	[23] = { raidIcon = 6 },
	[26] = { raidIcon = 4 },
	[17] = { emergency = true, boss = I .. "Spell_Frost_FrostNova", bossCrit = true, pct = 0.36 },
	[18] = { far = true },
	[19] = { dispel = "Disease", dicon = I .. "Spell_Nature_NullifyDisease" },
	[20] = { status = "afk" },
	[22] = { role = "TANK", hots = { 1 }, absorb = 0.35, pct = 1 },
	[28] = { dispel = "Poison", dicon = I .. "Ability_Rogue_DualWeild" },
	[33] = { boss = I .. "Spell_Shadow_AbominationExplosion", bossCount = 2, bossCan = true },
	[36] = { status = "dead", rez = "cast" },
}
local LFG_TEX = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local ROLE = {
	TANK = { 0, 19/64, 22/64, 41/64 },
	HEALER = { 20/64, 39/64, 1/64, 20/64 },
	DAMAGER = { 20/64, 39/64, 22/64, 41/64 },
}
local POWER = { WARRIOR = 1, ROGUE = 3, DEATHKNIGHT = 6 }

PV.buttons = {}
PV.size = 25

local function fakeData(i)
	local d = SPECIAL[i] or {}
	d.name = NAMES[i]
	d.class = CLASSES[(i - 1) % #CLASSES + 1]
	d.pct = d.pct or (0.6 + ((i * 37) % 40) / 100)
	if d.pct > 1 then d.pct = 1 end
	return d
end

function PV:Build()
	local holder = CreateFrame("Frame", "VuhPlusPreview", VP.Panels.anchors.main)
	holder:SetPoint("TOPLEFT", VP.Panels.anchors.main, "TOPLEFT", 0, 0)
	holder:SetWidth(10); holder:SetHeight(10)
	holder:Hide()
	self.holder = holder
	for i = 1, 40 do
		local b = CreateFrame("Button", nil, holder)
		F:SetupButton(b, true)
		b.data = fakeData(i)
		b.drift = (i % 3) * 0.7
		-- grande flèche de guidage (comme en jeu) : par-dessus le cadre survolé hors de portée
		local big = CreateFrame("Frame", nil, holder)   -- pas enfant du cadre : garde son opacité
		big:SetFrameLevel(b:GetFrameLevel() + 30)
		big:SetPoint("CENTER", b.hp, "CENTER", 0, 0)
		big.shadow = big:CreateTexture(nil, "BACKGROUND")
		big.shadow:SetTexture("Interface\\Minimap\\MinimapArrow")
		big.shadow:SetVertexColor(0, 0, 0, 0.7)
		big.shadow:SetPoint("TOPLEFT", big, "TOPLEFT", -2, 2)
		big.shadow:SetPoint("BOTTOMRIGHT", big, "BOTTOMRIGHT", 2, -2)
		big.arrow = big:CreateTexture(nil, "ARTWORK")
		big.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
		big.arrow:SetAllPoints(big)
		big:Hide()
		b.bigArrow = big
		b:EnableMouse(true)
		b:HookScript("OnEnter", function(self) self.pvHover = true; PV:Paint() end)
		b:HookScript("OnLeave", function(self) self.pvHover = nil; PV:Paint() end)
		self.buttons[i] = b
	end
	self.titles = {}
	for g = 1, 8 do
		local t = VP.Theme:Text(holder, 11, VP.Theme.C.muted)
		t:SetJustifyH("CENTER")
		t:SetText("Groupe " .. g)
		self.titles[g] = t
	end
	local tag = VP.Theme:Text(holder, 11, nil, "OUTLINE")
	tag:SetPoint("BOTTOMLEFT", holder, "TOPLEFT", 0, 22)
	self.tag = tag
	local t = 0
	holder:SetScript("OnUpdate", function(_, e)
		t = t + e
		if t < 0.25 then return end
		t = 0
		PV:Paint()
	end)
end

function PV:Layout()
	local d = VP.db
	local P = VP.Panels
	local fh = F:FrameHeight()
	local grid = P:UseGrid()
	local groups = P:UseGroups() and not grid
	-- grille par rôle : remplie ligne par ligne, sans titres
	local gridCols = math.max(1, math.ceil(self.size / math.max(1, d.perColumn)))
	for g = 1, 8 do self.titles[g]:Hide() end
	for i, b in ipairs(self.buttons) do
		if i <= self.size then
			b:ClearAllPoints()
			if groups then
				local g = math.floor((i - 1) / 5)
				local row = (i - 1) % 5
				local x, y = P:GroupOrigin(g)
				b:SetPoint("TOPLEFT", self.holder, "TOPLEFT", x, y - row * (fh + d.yGap))
				if row == 0 and d.groupTitles then
					local t = self.titles[g + 1]
					t:ClearAllPoints()
					t:SetPoint("BOTTOMLEFT", b, "TOPLEFT", 0, 2)
					t:SetWidth(d.width)
					t:Show()
				end
			elseif grid then
				local col = (i - 1) % gridCols
				local row = math.floor((i - 1) / gridCols)
				b:SetPoint("TOPLEFT", self.holder, "TOPLEFT", d.padX + col * (d.width + d.xGap), -d.padY - row * (fh + d.yGap))
			else
				local col = math.floor((i - 1) / d.perColumn)
				local row = (i - 1) % d.perColumn
				b:SetPoint("TOPLEFT", self.holder, "TOPLEFT", d.padX + col * (d.width + d.xGap), -d.padY - row * (fh + d.yGap))
			end
			b:SetWidth(d.width)
			b:SetHeight(fh)
			F:LayoutButton(b)
			b:Show()
		else
			b:Hide()
		end
	end
	self.tag:SetText("|cffffcc00MODE TEST|r  " .. self.size .. " joueurs  ·  /vp apercu pour quitter")
end

local S, A = {}, {}
-- tables propres à chaque faux cadre, réutilisées à chaque image (avant : ~800 tables créées par seconde)
local function pvTables(b)
	local t = b.pv
	if not t then
		t = { reminder = {}, boss = {}, hots = {}, hotE = {}, def = {}, healRed = {} }
		for k = 1, F.NUM_SLOTS do t.hotE[k] = {} end
		b.pv = t
	end
	return t
end
function PV:Paint()
	local now = GetTime()
	local slots = VP.Frames:HotSlots()
	for i = 1, self.size do
		local b = self.buttons[i]
		local f = b.data
		local pt = pvTables(b)
		wipe(S); wipe(A)
		S.name, S.class, S.isPlayer, S.friendly = f.name, f.class, true, true
		local pct = f.pct
		if not f.status and pct < 1 then
			pct = math.max(0.05, math.min(0.99, pct + math.sin(now * 0.8 + b.drift) * 0.06))
		end
		S.maxhp = 22000
		S.hp = math.floor(S.maxhp * pct)
		S.alive = f.status ~= "dead" and f.status ~= "offline"
		S.status = f.status
		S.incoming = f.incoming and S.maxhp * f.incoming or nil
		S.absorb = f.absorb and S.maxhp * f.absorb or nil
		S.deadFor = f.deadFor and VP.db.deadTimer and (f.deadFor + now % 60) or nil
		S.rez = f.rez and VP.db.rezStatus and f.rez or nil
		S.casting = f.casting and VP.db.castHighlight
		S.ptype = POWER[f.class] or 0
		S.powerMax = 100
		S.power = f.lowMana and 12 or 70
		S.lowMana = f.lowMana and VP.db.lowMana
		S.aggro = f.aggro
		S.raidIcon = f.raidIcon
		S.emergency = f.emergency and VP.db.emergency
		S.aoe = f.aoe and VP.db.aoe.enabled
		if f.reminder and VP.db.buffs.grayFrames then
			pt.reminder.icon = f.reminder
			S.reminder = pt.reminder
		end
		S.bossTarget = f.bossTarget and VP.db.indBossTarget
		-- couronne : chef sur le 1er joueur fictif, assistant sur le 7e
		if VP.db.showLeader then
			if i == 1 then S.leadTex = F.LEADER_TEX
			elseif i == 7 and VP.db.showAssist then S.leadTex = F.ASSIST_TEX end
		end
		local role = f.role or (VP.db.roleShowDps and "DAMAGER")
		if role then
			local r = ROLE[role]
			S.roleTex, S.roleL, S.roleR, S.roleT, S.roleB = LFG_TEX, r[1], r[2], r[3], r[4]
		end
		local guide = f.far and b.pvHover and VP.db.guideArrow
		if guide then
			local d = VP.db
			local size = F:GuideSize()
			b.bigArrow:SetWidth(size); b.bigArrow:SetHeight(size)
			F.place(b.bigArrow, b, d.iconPos.guide or "C", 0, 0, "guide")
			F.rotateTex(b.bigArrow.arrow, now * 1.5 + b.drift)
			F.rotateTex(b.bigArrow.shadow, now * 1.5 + b.drift)
			local c = d.colors.arrow
			b.bigArrow.arrow:SetVertexColor(c[1], c[2], c[3])
			b.bigArrow:Show()
		else
			b.bigArrow:Hide()
		end
		if f.far then b:SetAlpha(VP.db.rangeFade and VP.db.rangeAlpha or 1) end
		if f.far and VP.db.arrows and not guide then
			F.rotateTex(b.arrow, now * 1.5 + b.drift)
			local c = VP.db.colors.arrow
			b.arrow:SetVertexColor(c[1], c[2], c[3])
			b.arrow:Show()
		else
			b.arrow:Hide()
			if not f.far then b:SetAlpha(1) end
		end
		F:PaintHealth(b, S)

		if f.dispel then
			A.dtype, A.dicon, A.hint = f.dispel, f.dicon, VP.dispelKeys and VP.dispelKeys[1] or "Mil"
		end
		if f.boss then
			local bo = pt.boss
			bo.icon, bo.count, bo.dur, bo.exp = f.boss, f.bossCount, 20, now + 20 - (now % 20)
			bo.crit, bo.isCrit, bo.can = f.bossCrit and VP.db.debuffs.critGlow, f.bossCrit, f.bossCan
			bo.dtype = f.bossCan and "Magic" or nil
			A.boss = bo
		end
		-- HoTs : on remplit les emplacements configurés
		if f.hots and VP.db.showHots then
			local hots = pt.hots
			wipe(hots)
			for _, slotIndex in ipairs(f.hots) do
				local slot = slots[slotIndex]
				if slot and slot.spell and slot.spell ~= "" then
					-- (aussi pour les sorts hors du grimoire : Viveterre, Égide divine...)
					local icon = F:SpellIcon(slot.spell)
					local dur = 12 + slotIndex * 6
					local left = dur - ((now + b.drift * 4 + slotIndex * 3) % dur)
					-- sort à charges (Bouclier de terre, Prière de guérison) : charges qui descendent de 6 à 1
					-- (avant : toujours l'emplacement 2, même Rétablissement ou le Bouclier sacré montraient des charges)
					local isCharge = F:IsChargeSpell(slot.spell) and true or false
					local ch = isCharge and (6 - math.floor(((now + b.drift * 4) % 18) / 3)) or nil
					local e = pt.hotE[slotIndex]
					e.icon, e.count, e.charge = icon or I .. "INV_Misc_QuestionMark", ch, isCharge
					e.expiring = ch and ch <= 1 or (not ch and left < 3)
					e.dur, e.exp = dur, now + left
					hots[slotIndex] = e
				end
			end
			A.hots = hots
		end
		A.missing = f.missing and VP.db.buffs.showMissing
		A.tank = f.role == "TANK"
		if VP.db.indicators then
			if f.def and VP.db.indDefensive then
				local e = pt.def
				e.icon, e.dur, e.exp = f.def, 12, now + 12 - (now % 12)
				A.def = e
			end
			if f.healRed and VP.db.indHealRed then
				local e = pt.healRed
				e.icon, e.count, e.dur, e.exp = f.healRed, 2, 10, now + 10 - (now % 10)
				A.healRed = e
			end
			if f.soul and VP.db.indSoul then A.soul = f.soul end
		end
		F:PaintAuras(b, A)
	end
end

function PV:Show(size)
	if InCombatLockdown() then VP:Print("Mode test impossible en combat.") return end
	if not self.holder then self:Build() end
	self.size = size or self.size or 25
	self.shown = true
	self:Layout()
	self:Paint()
	self.holder:Show()
	VP.Panels:LayoutGroups()
end

function PV:Hide()
	self.shown = false
	if self.holder then self.holder:Hide() end
	VP.Panels:LayoutGroups()
end

function PV:Toggle(size)
	self.fromUI = nil
	if self.shown and (not size or size == self.size) then self:Hide() else self:Show(size) end
end

function PV:Refresh()
	if self.shown then self:Layout(); self:Paint() end
end

function PV:OnLogin()
	VP:On("PLAYER_REGEN_DISABLED", function() if PV.shown then PV:Hide() end end)
end
