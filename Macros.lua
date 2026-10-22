-- Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
-- (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.

-- VuhPlus - Bibliothèque de macros pour le clic-soin
--  * macros de plusieurs lignes, rangées dans une bibliothèque, réutilisables sur n'importe quel clic,
--    touche ou molette (action « M:Nom ») ;
--  * deux jetons : @vp (dans les conditions : [@vp,dead]) et {vp} (unité brute : /focus {vp}) ;
--  * vérification avant d'enregistrer : sorts inconnus, lignes trop longues, crochets, jeton oublié... ;
--  * import des macros du jeu (générales et du personnage) avec conversion automatique de
--    [@mouseover] / [target=mouseover] en [@vp] ;
--  * modèles prêts à l'emploi selon votre classe, avec les noms de sorts de votre langue ;
--  * icône automatique (premier sort de la macro) et aperçu du texte réellement exécuté.
local VP = VuhPlus
local M = VP:NewModule("Macros")

M.MAX_LINE = 255     -- limite du jeu par ligne
M.MAX_TOTAL = 1023   -- au-delà, le jeu peut tronquer le texte

function M:List()
	VP.db.macros = VP.db.macros or {}
	return VP.db.macros
end

function M:Find(name)
	if not name then return nil end
	local l = string.lower(name)
	for i, m in ipairs(self:List()) do
		if string.lower(m.name) == l then return m, i end
	end
end

-- nom libre : « Macro », « Macro 2 »...
function M:FreeName(base)
	base = base or "Macro"
	if not self:Find(base) then return base end
	local i = 2
	while self:Find(base .. " " .. i) do i = i + 1 end
	return base .. " " .. i
end

function M:Add(name, body)
	local m = { name = self:FreeName(name), body = body or "/cast [@vp] " }
	table.insert(self:List(), m)
	return m
end

function M:Delete(name)
	local m, i = self:Find(name)
	if not m then return end
	table.remove(self:List(), i)
	-- les clics qui utilisaient cette macro sont vidés
	self:ReplaceRefs("M:" .. m.name, "")
	VP.Clicks:Apply()
end

-- Renomme et met à jour tous les clics / touches qui l'utilisent
function M:Rename(m, newName)
	newName = (newName or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if newName == "" or newName == m.name then return end
	local other = self:Find(newName)
	if other and other ~= m then VP:Print("Une macro porte déjà ce nom.") return end
	local old = m.name
	m.name = newName
	self:ReplaceRefs("M:" .. old, "M:" .. newName)
	VP.Clicks:Apply()
end

-- « M:Nom », « m: nom »... -> « nom » (pour comparer les références)
local function refName(v)
	local n = type(v) == "string" and string.match(v, "^[Mm]:%s*(.-)%s*$")
	return n and string.lower(n)
end
M.refName = refName

-- parcourt toutes les actions enregistrées (toutes classes / spés) et remplace une valeur
function M:ReplaceRefs(oldVal, newVal)
	local db = VP.db
	local lo = refName(oldVal)
	local function fix(v) return (lo and refName(v) == lo) and newVal or v end
	for cls, specs in pairs(db.binds or {}) do
		if type(specs) == "table" then
			for k, binds in pairs(specs) do
				if type(binds) == "table" then
					for key, v in pairs(binds) do binds[key] = fix(v) end
				else
					specs[k] = fix(binds)   -- ancien format (classe pas encore convertie)
				end
			end
		end
	end
	for _, root in ipairs({ "keys", "hostile" }) do
		for _, specs in pairs(db[root] or {}) do
			if type(specs) == "table" then
				for _, list in pairs(specs) do
					if type(list) == "table" then
						for _, e in pairs(list) do
							if type(e) == "table" then e.action = fix(e.action) end
						end
					end
				end
			end
		end
	end
end

-- Où cette macro est-elle utilisée ? (libellés des combinaisons de la spé active)
function M:Uses(m)
	local C = VP.Clicks
	local val = string.lower(m.name)
	local out = {}
	for _, e in ipairs(C:Combos()) do
		local v = C:Binds()[e[1]]
		if e[1] ~= "" and refName(v) == val then out[#out + 1] = e[2] end
	end
	for _, k in ipairs(C:Keys()) do
		if refName(k.action) == val and k.key and k.key ~= "" then out[#out + 1] = "touche " .. k.key end
	end
	return out
end

-- Assigne la macro à une combinaison souris / molette (la retire de son ancienne place si demandé)
function M:Assign(m, combo)
	if not combo or combo == "" then return end
	VP.Clicks:Binds()[combo] = "M:" .. m.name
	VP.Clicks:Apply()
end

-- Icône : premier sort / objet de la macro
function M:Icon(m)
	for line in string.gmatch((m.body or "") .. "\n", "([^\n]*)\n") do
		local cmd, rest = string.match(line, "^%s*/(%a+)%s*(.*)$")
		if cmd then
			cmd = string.lower(cmd)
			if cmd == "cast" or cmd == "lancer" or cmd == "castsequence" or cmd == "use" or cmd == "utiliser" then
				local first = string.match(rest:gsub("%b[]", ""), "^%s*([^;,]+)")
				if first then
					first = first:gsub("^%s*reset=%S+%s*", ""):gsub("%s+$", "")
					local _, _, icon = GetSpellInfo(first)
					if icon then return icon end
					local slot = tonumber(first)
					if slot then
						local t = GetInventoryItemTexture("player", slot)
						if t then return t end
					end
				end
			end
		end
	end
	return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Texte réellement exécuté pour une unité donnée (aperçu)
function M:Resolve(body, unit)
	body = body or ""
	body = body:gsub("{vp}", unit)
	body = body:gsub("@vp", "@" .. unit)
	return body
end

-- Vérification : renvoie une liste de { niveau, texte } (niveau : "err", "warn", "info")
local KNOWN_CMDS = {
	cast = true, lancer = true, castsequence = true, use = true, utiliser = true, stopcasting = true,
	target = true, cible = true, tar = true, focus = true, clearfocus = true, assist = true, cancelaura = true,
	cancelform = true, startattack = true, stopattack = true, petattack = true, equip = true, equipslot = true,
	say = true, s = true, yell = true, y = true, party = true, p = true, raid = true, ra = true, rw = true,
	w = true, whisper = true, script = true, run = true, click = true, dismount = true, stopmacro = true,
	cleartarget = true, targetlasttarget = true, castrandom = true, userandom = true, emote = true, e = true,
	console = true, changeactionbar = true, swapactionbar = true, petfollow = true, petstay = true,
	petpassive = true, petdefensive = true, petaggressive = true, ["?"] = true,
	targetexact = true, targetenemy = true, targetfriend = true, targetparty = true, targetraid = true,
	targetlastenemy = true, targetlastfriend = true, targetenemyplayer = true, targetfriendplayer = true,
	equipset = true, usetalents = true, petautocaston = true, petautocastoff = true, petautocasttoggle = true,
	follow = true, f = true, g = true, guild = true, o = true, officer = true, bg = true, battleground = true,
	cibler = true, focaliser = true, assister = true, arreterincantation = true, utiliseraleatoire = true,
	readycheck = true, roll = true, random = true, afk = true, dnd = true, stopwatch = true,
}
-- Conditions reconnues par le client 3.3.5 (« no » devant est accepté : nodead, nocombat...)
local KNOWN_CONDS = {
	help = true, harm = true, exists = true, dead = true, combat = true, mod = true, modifier = true,
	button = true, btn = true, channeling = true, equipped = true, worn = true, flying = true, flyable = true,
	indoors = true, outdoors = true, mounted = true, swimming = true, stealth = true, stance = true, form = true,
	group = true, party = true, raid = true, pet = true, actionbar = true, bar = true, bonusbar = true,
	vehicleui = true, unithasvehicleui = true, target = true, spec = true, canexitvehicle = true,
}
local MOD_VALUES = { shift = true, ctrl = true, alt = true, lshift = true, rshift = true,
	lctrl = true, rctrl = true, lalt = true, ralt = true }
-- Commandes qui exécutent du code Lua : à vérifier avant d'utiliser une macro reçue d'un autre joueur
local CODE_CMDS = { script = true, run = true, console = true }
local CAST_CMDS = { cast = true, lancer = true, castsequence = true, castrandom = true }

function M:Check(body)
	local out = {}
	local function add(level, txt) out[#out + 1] = { level, txt } end
	body = body or ""
	if body:gsub("%s", "") == "" then add("err", "La macro est vide.") return out end
	-- longueur RÉELLE au clic : chaque @vp devient « @raidpet40 » (pire cas), le jeu tronquerait au-delà
	local realTotal = #self:Resolve(body, "raidpet40")
	if realTotal > self.MAX_TOTAL then
		add("err", "Trop longue : " .. realTotal .. " caractères une fois @vp remplacé (" .. self.MAX_TOTAL .. " au maximum).")
	end
	local n, usesVP = 0, false
	for line in string.gmatch(body .. "\n", "([^\n]*)\n") do
		n = n + 1
		-- longueur après remplacement des jetons (« @vp » devient « @raidpet25 »)
		local real = #self:Resolve(line, "raidpet40")
		if real > self.MAX_LINE then add("err", "Ligne " .. n .. " trop longue (" .. real .. " > " .. self.MAX_LINE .. ").") end
		local opens = select(2, line:gsub("%[", ""))
		local closes = select(2, line:gsub("%]", ""))
		if opens ~= closes then add("err", "Ligne " .. n .. " : crochets [ ] mal fermés.") end
		if string.find(line, "@vp", 1, true) or string.find(line, "{vp}", 1, true) then usesVP = true end
		if string.find(string.lower(line), "mouseover", 1, true) then
			add("warn", "Ligne " .. n .. " : « mouseover » vise le cadre survolé, utilisez plutôt @vp (bouton « Convertir »).")
		end
		if string.find(line, "@vp", 1, true) then
			-- @vp doit être dans des crochets
			local stripped = line:gsub("%b[]", "")
			if string.find(stripped, "@vp", 1, true) then
				add("warn", "Ligne " .. n .. " : @vp hors des crochets. Écrivez [@vp] (ou {vp} hors crochets, ex. /focus {vp}).")
			end
		end
		-- conditions [ ... ] : mot-clé inconnu = probablement une faute de frappe ([@vp,ded], [mod:shfit]...)
		for group in string.gmatch(line, "%[([^%]]*)%]") do
			for tok in string.gmatch(group, "[^,]+") do
				tok = tok:gsub("^%s+", ""):gsub("%s+$", "")
				if tok ~= "" and string.sub(tok, 1, 1) ~= "@" then
					local key = string.lower(string.match(tok, "^([^:=]+)") or tok)
					key = key:gsub("%s+$", "")
					local base = string.match(key, "^no(.+)$")
					if not KNOWN_CONDS[key] and not (base and KNOWN_CONDS[base]) then
						add("warn", "Ligne " .. n .. " : condition « " .. tok .. " » inconnue (faute de frappe ?).")
					elseif key == "mod" or key == "modifier" or key == "nomod" or key == "nomodifier" then
						-- valeurs : shift / ctrl / alt (gauche ou droite), ou une action du jeu en majuscules (SELFCAST...)
						local vals = string.match(tok, "^[^:]+:(.+)$")
						for v in string.gmatch(vals or "", "[^/]+") do
							v = v:gsub("^%s+", ""):gsub("%s+$", "")
							if not MOD_VALUES[string.lower(v)] and not string.match(v, "^[%u_]+$") then
								add("warn", "Ligne " .. n .. " : touche « " .. v .. " » inconnue dans « " .. tok .. " » (shift, ctrl ou alt).")
							end
						end
					end
				end
			end
		end
		local cmd, rest = string.match(line, "^%s*/(%S+)%s*(.*)$")
		if cmd then
			cmd = string.lower(cmd)
			if CODE_CMDS[cmd] then
				add("warn", "Ligne " .. n .. " : /" .. cmd .. " exécute du code. N'utilisez que des macros dont vous connaissez la source.")
			end
			if not KNOWN_CMDS[cmd] and not string.match(cmd, "^%d") then
				add("warn", "Ligne " .. n .. " : commande /" .. cmd .. " inconnue (vérifiez l'orthographe).")
			end
			if CAST_CMDS[cmd] then
				-- chaque sort séparé par ; (conditions) ou , (séquence)
				local spells = rest:gsub("%b[]", ""):gsub("^%s*reset=%S+%s*", "")
				for raw in string.gmatch(spells .. ";", "([^;,]*)[;,]") do
					local sp = raw:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^!", "")
					if sp ~= "" and not tonumber(sp) and not GetSpellInfo(sp) then
						add("warn", "Ligne " .. n .. " : sort « " .. sp .. " » inconnu de votre personnage.")
					end
				end
			end
		elseif line:gsub("%s", "") ~= "" and not string.match(line, "^%s*#") then
			add("warn", "Ligne " .. n .. " : ne commence pas par /.")
		end
	end
	if not usesVP then
		add("info", "Aucun @vp : la macro ne visera pas le joueur cliqué (elle agit sur votre cible actuelle).")
	end
	if #out == 0 then add("ok", "Macro valide.") end
	return out
end

-- Conversion d'une macro « survol » : [@mouseover] / [target=mouseover] / [@target] -> [@vp]
function M:Convert(body, alsoTarget)
	body = body or ""
	body = body:gsub("target%s*=%s*mouseover", "@vp"):gsub("@mouseover", "@vp")
	if alsoTarget then body = body:gsub("target%s*=%s*target", "@vp"):gsub("@target", "@vp") end
	-- un /cast sans aucune condition : on ajoute [@vp]
	local lines = {}
	for raw in string.gmatch(body .. "\n", "([^\n]*)\n") do
		local line = raw
		local pre, rest = string.match(line, "^(%s*/[Cc][Aa][Ss][Tt]%s+)(.*)$")
		if pre and not string.find(rest, "[", 1, true) and not string.find(rest, ";", 1, true) and rest ~= "" then
			line = pre .. "[@vp] " .. rest
		end
		lines[#lines + 1] = line
	end
	if lines[#lines] == "" then lines[#lines] = nil end
	return table.concat(lines, "\n")
end

-- Macros du jeu (Échap > Macros) : générales puis du personnage
function M:GameMacros()
	local out = {}
	local nGlobal, nChar = GetNumMacros()
	local function add(i, kind)
		local name, icon, body = GetMacroInfo(i)
		if name then out[#out + 1] = { index = i, name = name, icon = icon, body = body or "", kind = kind } end
	end
	for i = 1, (nGlobal or 0) do add(i, "générale") end
	for i = 37, 36 + (nChar or 0) do add(i, "personnage") end
	return out
end

function M:ImportGame(index)
	local name, _, body = GetMacroInfo(index)
	if not name then return end
	-- déjà importée telle quelle : on la réutilise au lieu d'en créer une copie
	local conv = self:Convert(body or "")
	local ex = self:Find(name)
	if ex and ex.body == conv then return ex end
	local m = self:Add(name, conv)
	VP:Print("Macro « " .. m.name .. " » importée" .. (m.body ~= body and " (convertie pour le clic-soin)" or "") .. ".")
	return m
end

-- Modèles selon la classe (noms de sorts lus dans la langue du jeu) ----------------
local function S(id) return GetSpellInfo(id) or ("sort " .. id) end
function M:Templates()
	local t = {}
	local function add(label, body) t[#t + 1] = { label, body } end
	local cls = VP.class
	local REZ = { PALADIN = 7328, PRIEST = 2006, SHAMAN = 2008, DRUID = 50769 }
	local MAIN = { PALADIN = 19750, PRIEST = 2061, SHAMAN = 8004, DRUID = 8936 }
	local BIG = { PALADIN = 635, PRIEST = 2060, SHAMAN = 331, DRUID = 5185 }
	if MAIN[cls] then
		add("Soin, ou résurrection si mort", "/cast [@vp,dead] " .. S(REZ[cls]) .. "; [@vp] " .. S(MAIN[cls]))
		add("Arrêter l'incantation et soigner", "/stopcasting\n/cast [@vp] " .. S(MAIN[cls]))
		add("Bijoux + gros soin", "/use 13\n/use 14\n/cast [@vp] " .. S(BIG[cls]))
		add("Petit soin (Maj : gros soin)", "/cast [@vp,mod:shift] " .. S(BIG[cls]) .. "; [@vp] " .. S(MAIN[cls]))
	end
	if cls == "SHAMAN" then
		add("Rapidité de la nature + Vague de soins", "/cast " .. S(16188) .. "\n/cast [@vp] " .. S(331))
		add("Remous puis Salve de guérison", "/castsequence [@vp] reset=6 " .. S(61295) .. ", " .. S(1064))
		add("Bouclier de terre", "/cast [@vp] " .. S(974))
		add("Purifier l'esprit (Maj : Guérison des toxines)", "/cast [@vp,mod:shift] " .. S(526) .. "; [@vp] " .. S(51886))
	elseif cls == "PRIEST" then
		add("Bouclier (Maj : Rénovation)", "/cast [@vp,mod:shift] " .. S(139) .. "; [@vp] " .. S(17))
		add("Focalisation intérieure + Soins supérieurs", "/cast " .. S(14751) .. "\n/cast [@vp] " .. S(2060))
		add("Prière de guérison", "/cast [@vp] " .. S(33076))
		add("Soin de lien", "/cast [@vp] " .. S(32546))
		add("Esprit gardien (Maj : Suppression de la douleur)", "/cast [@vp,mod:shift] " .. S(33206) .. "; [@vp] " .. S(47788))
	elseif cls == "DRUID" then
		add("Rapidité de la nature + Toucher guérisseur", "/cast " .. S(17116) .. "\n/cast [@vp] " .. S(5185))
		add("Renaissance en combat, Ranimer hors combat", "/cast [@vp,dead,combat] " .. S(20484) .. "; [@vp,dead] " .. S(50769))
		add("Récupération puis Prompte guérison", "/castsequence [@vp] reset=15 " .. S(774) .. ", " .. S(18562))
		add("Innervation sur le joueur cliqué", "/cast [@vp] " .. S(29166))
	elseif cls == "PALADIN" then
		add("Faveur divine + Horion sacré", "/cast " .. S(20216) .. "\n/cast [@vp] " .. S(20473))
		add("Guide de lumière", "/cast [@vp] " .. S(53563))
		add("Main de sacrifice (Maj : de protection)", "/cast [@vp,mod:shift] " .. S(1022) .. "; [@vp] " .. S(6940))
		add("Imposition des mains (Maj : Main de liberté)", "/cast [@vp,mod:shift] " .. S(1044) .. "; [@vp] " .. S(633))
	end
	add("Définir la focalisation", "/focus {vp}")
	add("Cibler et assister", "/target {vp}\n/assist")
	return t
end

-- Copie d'une macro (« Nom (copie) ») ----------------------------------------------
function M:Duplicate(m)
	if not m then return end
	return self:Add(m.name .. " (copie)", m.body)
end

-- Partage en texte (copier-coller entre joueurs), même format sûr que les profils ---------
M.PREFIX = "VUHPLUSMAC1:"
function M:Export(list)
	local out = {}
	for _, m in ipairs(list or self:List()) do out[#out + 1] = { name = m.name, body = m.body } end
	return self.PREFIX .. VP.Share:Serialize(out)
end

-- Renvoie : nombre ajouté, nombre déjà présent, liste des macros contenant du code (/script...) ; ou nil, erreur
function M:ImportText(text)
	text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if string.sub(text, 1, #self.PREFIX) ~= self.PREFIX then
		return nil, "ce n'est pas un texte de macros VuhPlus (il doit commencer par " .. self.PREFIX .. ")"
	end
	local data, err = VP.Share:Deserialize(string.sub(text, #self.PREFIX + 1))
	if type(data) ~= "table" then return nil, err or "contenu invalide" end
	local added, same, code = 0, 0, {}
	for _, e in ipairs(data) do
		-- seulement des entrées propres : nom et texte, longueurs raisonnables
		if type(e) == "table" and type(e.name) == "string" and type(e.body) == "string"
			and e.name ~= "" and #e.name <= 40 and #e.body <= self.MAX_TOTAL then
			local ex = self:Find(e.name)
			if ex and ex.body == e.body then
				same = same + 1
			else
				local m = self:Add(e.name, e.body)
				added = added + 1
				for line in string.gmatch(e.body .. "\n", "([^\n]*)\n") do
					local c = string.match(line, "^%s*/(%a+)")
					if c and CODE_CMDS[string.lower(c)] then code[#code + 1] = m.name break end
				end
			end
		end
	end
	return added, same, code
end

-- Jetons et conditions à insérer depuis l'éditeur
M.SNIPPETS = {
	{ "[@vp]", "[@vp] " }, { "[@vp,dead]", "[@vp,dead] " }, { "[@vp,help]", "[@vp,help] " },
	{ "{vp}", "{vp}" }, { "[combat]", "[combat] " }, { "[nocombat]", "[nocombat] " },
	{ "[mod:shift]", "[mod:shift] " }, { "[mod:ctrl]", "[mod:ctrl] " }, { "[mod:alt]", "[mod:alt] " },
	{ "/cast", "/cast " }, { "/stopcasting", "/stopcasting\n" }, { "/use 13", "/use 13\n" }, { "/use 14", "/use 14\n" },
	{ "/castsequence", "/castsequence [@vp] reset=10 " },
}
