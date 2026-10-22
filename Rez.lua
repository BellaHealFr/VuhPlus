-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Résurrections en cours (comme le moniteur de résurrection de SmartRes2 / oRA)
-- Sur le cadre d'un joueur mort :
--   « Rez... »         : quelqu'un est en train de le ressusciter (inutile d'en lancer une 2e)
--   « Rez en attente » : la résurrection a réussi, il doit seulement l'accepter (60 s)
-- Sources :
--   * vos propres résurrections : toujours (début / fin de votre incantation) ;
--   * résurrections RÉUSSIES de tout le groupe : journal de combat (SPELL_RESURRECT), sans rien installer ;
--   * résurrections EN COURS des autres : seulement si la bibliothèque facultative LibResComm-1.0
--     est installée (chez eux aussi : elle passe par les messages entre addons).
local VP = VuhPlus
local RZ = VP:NewModule("Rez")

-- Résurrection (prêtre), Rédemption, Esprit ancestral, Ranimer, Renaissance, Réanimation d'un allié
local REZ_IDS = { 2006, 7328, 2008, 50769, 20484, 61999 }
local PENDING_TIME = 60   -- durée de la proposition de résurrection

RZ.names = {}      -- nom de sort localisé -> true
RZ.casting = {}    -- joueur visé -> { by = lanceur, untilT = fin prévue }
RZ.pending = {}    -- joueur visé -> heure d'expiration de la proposition

-- Clé d'un joueur : « Nom » ou « Nom-Royaume » (joueurs d'autres royaumes en champ de bataille)
local function key(u)
	local n, r = UnitName(u)
	if not n then return nil end
	if r and r ~= "" then return n .. "-" .. r end
	return n
end

-- État de résurrection d'une unité morte : "cast", lanceur | "pending" | nil
function RZ:Status(u)
	local k = key(u)
	if not k then return nil end
	local now = GetTime()
	local c = self.casting[k]
	if c then
		if c.untilT > now then return "cast", c.by end
		self.casting[k] = nil
	end
	local p = self.pending[k]
	if p then
		if p > now then return "pending" end
		self.pending[k] = nil
	end
	return nil
end

-- Le joueur est de nouveau vivant : plus rien à afficher
function RZ:Clear(u)
	local k = key(u)
	if k then self.casting[k], self.pending[k] = nil, nil end
end

-- Redessine les cadres (la vie et le texte d'état)
local function changed()
	local F = VP.Frames
	if F and F.dirtyH then
		for _, b in ipairs(F.buttons) do F.dirtyH[b] = true end
	end
end

local function untilFrom(endTime)
	local now = GetTime()
	local e = tonumber(endTime)
	-- selon les versions, la fin est donnée en secondes ou en millisecondes
	if e and e > now + 100 then e = e / 1000 end
	if not e or e < now or e > now + 15 then e = now + 10 end
	return e + 0.5
end

function RZ:OnLogin()
	for _, id in ipairs(REZ_IDS) do
		local n = GetSpellInfo(id)
		if n then self.names[n] = true end
	end
	local mine   -- joueur que JE suis en train de ressusciter
	VP:On("UNIT_SPELLCAST_SENT", function(_, unit, spell, _, target)
		if unit ~= "player" or not RZ.names[spell or ""] or not target or target == "" then return end
		mine = target
		RZ.casting[target] = { by = UnitName("player"), untilT = GetTime() + 12 }
		changed()
	end)
	local function stop(_, unit)
		if unit ~= "player" or not mine then return end
		RZ.casting[mine] = nil   -- réussie : SPELL_RESURRECT (journal de combat) passe à « en attente »
		mine = nil
		changed()
	end
	for _, ev in ipairs({ "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
		"UNIT_SPELLCAST_FAILED_QUIET", "UNIT_SPELLCAST_STOP" }) do
		VP:On(ev, stop)
	end
	-- résurrection réussie (n'importe qui) : la proposition attend d'être acceptée
	VP:On("COMBAT_LOG_EVENT_UNFILTERED", function(_, _, event, _, _, _, _, dstName)
		if event ~= "SPELL_RESURRECT" or not dstName then return end
		RZ.casting[dstName] = nil
		RZ.pending[dstName] = GetTime() + PENDING_TIME
		changed()
	end)

	-- LibResComm-1.0 (facultative) : résurrections en cours des autres joueurs
	local lib = LibStub and LibStub("LibResComm-1.0", true)
	if lib and lib.RegisterCallback then
		self.lib = lib
		pcall(lib.RegisterCallback, RZ, "ResComm_ResStart", function(_, resser, endTime, target)
			if not target then return end
			RZ.casting[target] = { by = resser, untilT = untilFrom(endTime) }
			changed()
		end)
		pcall(lib.RegisterCallback, RZ, "ResComm_ResEnd", function(_, _, target)
			if target then RZ.casting[target] = nil; changed() end
		end)
		pcall(lib.RegisterCallback, RZ, "ResComm_Ressed", function(_, target)
			if target then RZ.casting[target] = nil; RZ.pending[target] = GetTime() + PENDING_TIME; changed() end
		end)
		pcall(lib.RegisterCallback, RZ, "ResComm_ResExpired", function(_, target)
			if target then RZ.pending[target] = nil; changed() end
		end)
	end
end
