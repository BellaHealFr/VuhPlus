-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Alerte de dégâts brutaux (comme l'indicateur d'attaque entrante de HealBot)
-- Un joueur qui perd plus de X % de sa vie max en moins de N secondes : bordure rouge qui s'éteint
-- doucement. On repère le gros coup AVANT que la barre soit basse.
local VP = VuhPlus
local SP = VP:NewModule("Spikes")

local band = bit and bit.band
local GROUP_MASK = 0x00000007   -- COMBATLOG_OBJECT_AFFILIATION_MINE | PARTY | RAID
local PLAYER_TYPE = 0x00000400  -- COMBATLOG_OBJECT_TYPE_PLAYER
local SIZE = 12                 -- coups gardés par joueur (tampon circulaire, sans créer de tables)

local hits = {}   -- GUID -> { t = {}, a = {}, i = n, last = heure de la dernière alerte }

local function record(guid, amount)
	local h = hits[guid]
	if not h then h = { t = {}, a = {}, i = 0, last = 0 }; hits[guid] = h end
	h.i = h.i % SIZE + 1
	local now = GetTime()
	h.t[h.i], h.a[h.i] = now, amount
	return h, now
end

function SP:OnDamage(guid, amount)
	local db = VP.db.spike
	if not amount or amount <= 0 then return end
	local h, now = record(guid, amount)
	if now - h.last < 1 then return end   -- déjà signalé à l'instant
	local list = VP.Frames:ButtonsFor(guid)
	local b = list and list[1]
	if not b or not b.unit then return end
	local maxhp = UnitHealthMax(b.unit)
	if not maxhp or maxhp <= 0 then return end
	local sum, win = 0, db.window or 1.5
	for k = 1, SIZE do
		local t = h.t[k]
		if t and now - t <= win then sum = sum + h.a[k] end
	end
	if sum / maxhp * 100 < (db.pct or 30) then return end
	if db.skipTanks and VP.Buffs and VP.Buffs:IsTank(b.unit) then return end
	h.last = now
	for i = 1, #list do VP.Frames:Spike(list[i]) end
	if db.sound and not VP.db.alerts.quiet then PlaySound("igPlayerInviteDecline") end
end

function SP:OnLogin()
	VP:On("COMBAT_LOG_EVENT_UNFILTERED", function(_, _, event, _, _, _, dstGUID, _, dstFlags, a9, a10, a11, a12)
		-- le type d'événement d'abord : la grande majorité des événements du journal s'arrête ici
		local amount
		if event == "SWING_DAMAGE" then amount = a9
		elseif event == "SPELL_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" or event == "RANGE_DAMAGE" then amount = a12
		elseif event == "ENVIRONMENTAL_DAMAGE" then amount = a10
		else return end
		if not VP.db.spike.enabled then return end
		if not band or band(dstFlags or 0, GROUP_MASK) == 0 or band(dstFlags or 0, PLAYER_TYPE) == 0 then return end
		SP:OnDamage(dstGUID, amount)
	end)
	-- oubli des joueurs partis (évite de garder des tables inutiles toute la soirée)
	VP:On("RAID_ROSTER_UPDATE", function()
		for g in pairs(hits) do
			local l = VP.Frames:ButtonsFor(g)
			if not l or #l == 0 then hits[g] = nil end
		end
	end)
end
