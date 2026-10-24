<div align="center">

# VuhPlus

**Cadres de raid pour soigneurs, pour World of Warcraft 3.3.5 (Wrath of the Lich King)**

*Par un passionné de Wrath of the Lich King, pour tous ceux qui soignent encore le Norfendre.*

![Client](https://img.shields.io/badge/client-3.3.5a-1e90ff)
![Lua](https://img.shields.io/badge/Lua-5.1-000080)
![Dépendances](https://img.shields.io/badge/d%C3%A9pendances-aucune-success)
![Langue](https://img.shields.io/badge/langue-fran%C3%A7ais-informational)
![Licence](https://img.shields.io/badge/licence-GPL--3.0-blue)
[![Téléchargements](https://img.shields.io/github/downloads/BellaHealFr/VuhPlus/total?label=t%C3%A9l%C3%A9chargements&color=success)](../../releases)

</div>

---

VuhPlus remplace les cadres de groupe et de raid du jeu par des cadres pensés pour le soin : un clic sur un joueur lance le sort choisi, et chaque cadre montre ce qu'un soigneur doit savoir à cet instant. Vie manquante, HoTs, débuff à dissiper, débuff de boss, bouclier, soins entrants, aggro, portée.

Il réunit dans un seul addon ce qui demande d'habitude plusieurs outils séparés : cadres de raid et soin au clic, assistant de dispel, suivi des débuffs de boss, recharges du raid, outils de chef de raid, vérification des consommables.

Il a été conçu pour les joueurs passionnés de la 3.3.5, ceux qui enchaînent les raids et veulent un outil qui ne casse pas en plein combat. Chaque fonction a été écrite pour ce client et ses limites, pas adaptée d'une version plus récente du jeu.

## Par un passionné, pour les passionnés

Pour beaucoup d'entre nous, Wrath of the Lich King reste l'extension de référence. Naxxramas suspendue au-dessus de la Désolation des dragons. Les modes difficiles d'Ulduar, Yogg-Saron et ses gardiens, le défi d'Algalon l'Observateur. L'Épreuve du croisé et ses tentatives comptées. Puis la Citadelle de la Couronne de glace, aile après aile, jusqu'au Trône de glace et au dernier face-à-face avec Arthas. Et enfin le Sanctum rubis, où Halion attend dans les deux royaumes.

Pour un soigneur, ces combats se jouent à la seconde. VuhPlus a été construit autour d'eux :

- **Les débuffs de boss qui comptent sont reconnus et classés.** Empalé de Gargamoelle, Spores gazeuses de Pulentraille, Infection mutante de Trognepus, Peste libérée du professeur Putricide, Soif de sang frénétique de la reine de sang Lana'thel, Tombeau de glace de Sindragosa, Profanation et Moisson d'âme du Roi-liche, Combustion ardente d'Halion, Poigne de pierre de Kologarn, Incinérer la chair de Jaraxxus. Chacun a une priorité de 1 à 10 ; à partir de 8, la grande icône clignote.
- **L'icône dit quoi faire, pas seulement ce qui se passe.** Sa bordure prend la couleur du type de débuff quand VOTRE personnage peut le retirer, devient orange quand le débuff est critique et qu'il faut soigner fort, et reste grise quand il n'y a rien à faire.
- **Les combats contre un PNJ allié sont prévus.** Les cadres Cible et Focalisation acceptent aussi un PNJ : mettez Valithria Marcherêve en focalisation et soignez-la au clic comme un joueur.
- **Le cadre « Cible du boss »** montre le joueur que le boss frappe : quand les tanks alternent, on soigne le bon sans le chercher.
- **La rez de combat se gère d'un coup d'œil** : « Mort 1:23 » sur le cadre, une ligne « Rez combat » qui dit qui a Renaissance ou Réanimation d'un allié de prête, et les pierres d'âme posées.

L'objectif est simple : vous laisser regarder le combat plutôt que vos cadres, essai après essai, jusqu'à ce que le Roi-liche tombe.

## Pourquoi VuhPlus

### Il reconnaît les rôles, même en 3.3.5

En 3.3.5, le jeu ne connaît le rôle d'un joueur que s'il est passé par la Recherche de donjon. Pour le reste, un raid monté à la main n'a ni tanks ni soigneurs aux yeux du jeu. VuhPlus le détermine lui-même, à partir de plusieurs sources :

- **le rôle forcé à la main** (`/vp role Nom tank`), qui l'emporte toujours ;
- **la spé envoyée par le joueur lui-même**, s'il utilise VuhPlus : connue tout de suite, sans inspection ni distance ;
- **un sort de talent profond vu en combat** : un guerrier qui lance Dévastation est Protection, un prêtre qui lance Pénitence est Discipline ;
- **l'inspection discrète des talents**, hors combat, une personne à la fois, avec deux lectures identiques exigées et les réponses aberrantes du serveur rejetées ;
- **les indices visibles** : forme d'ours ou de félin du druide, Fureur vertueuse du paladin, Forme d'Ombre du prêtre.

Le chevalier de la mort peut tanker dans ses trois arbres : son rôle vient de sa présence (givre ou non), sans inspection.

Un druide farouche peut tanker ou faire des dégâts avec les mêmes talents : sa forme décide. Mais un tank qui passe un instant en félin pour se déplacer reste un tank : l'autre forme ne compte que si elle est gardée 30 secondes d'affilée en combat.

Avec ces rôles, le raid peut être trié **par rôle**, en blocs (Tanks / Soigneurs / DPS) ou **en grille** : le raid garde sa forme habituelle mais se remplit ligne par ligne, tanks en haut.

### Les joueurs VuhPlus s'entraident

Le client 3.3.5 ne transmet pas tout à tout le monde. Les joueurs qui utilisent VuhPlus comblent ces trous entre eux, par de petits messages d'addon invisibles :

- **Appel (ready check) visible par tout le raid.** Le serveur n'envoie les réponses qu'au chef et aux assistants. Chaque joueur VuhPlus annonce sa propre réponse, et un chef ou un assistant VuhPlus relaie celles qu'il reçoit : avec un seul d'entre eux, tout le raid voit les coches et les croix.
- **Recharges exactes.** Chaque joueur VuhPlus envoie la vraie recharge de ses sorts (talents et glyphes compris) et la liste de ceux qu'il possède. Pour lui, le panneau des recharges n'estime plus : il sait.
- **Spé partagée.** Chaque joueur VuhPlus envoie l'arbre principal de ses talents : son rôle est connu sans inspection, et un changement de spé suit aussitôt.

Rien de ce qui est reçu n'est exécuté : seuls des noms de membres du groupe et des nombres sont lus, et tout le reste est ignoré.

### Conçu pour jouer sans être gêné par des bugs

- **Aucune dépendance.** VuhPlus n'embarque aucune bibliothèque. LibHealComm-4.0 (soins entrants), LibSharedMedia-3.0 (textures et polices) et LibResComm-1.0 (résurrections en cours des autres) sont utilisées si vous les avez installées, et seulement dans ce cas.
- **Erreurs isolées.** Chaque module reçoit les événements du jeu séparément : une erreur inattendue dans l'un est signalée normalement sans empêcher les autres de fonctionner, et un module en erreur au démarrage n'empêche pas les suivants de démarrer.
- **Rien d'interdit en combat.** Les cadres de soin sont des cadres sécurisés du jeu. Tout ce qui ne peut pas changer en combat (disposition, clics, tri) est mis en attente et appliqué à la fin du combat, au lieu de provoquer une erreur « action bloquée ».
- **Pensé pour les raids de 25 et 40.** Les événements du jeu sont regroupés à l'image suivante, la vérification de sécurité est répartie sur plusieurs images, les minuteurs ne tournent que sur les cadres qui en affichent, et les textes ne sont réécrits que lorsqu'ils changent.
- **Import sans risque.** Un profil ou une macro reçus d'un autre joueur sont lus par un petit analyseur, jamais exécutés comme du code. Seuls les réglages connus, du bon type et dans les bornes des curseurs sont gardés.
- **Vérifié.** Le code est vérifié en Lua 5.1 à chaque modification publiée, et les scénarios importants (rôles, appel, recharges partagées, import, charge d'un raid 25) ont été joués dans un banc de simulation qui fait tourner le vrai code.

## Fonctionnalités

### Soin au clic

- **56 combinaisons** : les 5 boutons de la souris et la molette (haut et bas), chacun avec 8 combinaisons de Alt, Ctrl et Maj.
- **14 touches du clavier au survol** : survolez un cadre, appuyez sur la touche, le sort part sur ce joueur.
- **Un jeu de clics par spé** (double spé), copiable d'une spé à l'autre.
- Glissez un sort du grimoire sur une case, ou écrivez son nom. Mots spéciaux : cible, menu, focus, assister, dispel1, dispel2.
- **Clic intelligent** : un clic sur un mort hors combat lance votre résurrection.
- **Bijoux automatiques** (facultatif) : chaque soin cliqué utilise aussi vos bijoux « Utiliser : » prêts.
- **Allié contrôlé par l'ennemi** : trois sorts au choix (Métamorphose, Maléfice, Cyclone...) sur un joueur sous Domination mentale.
- **Clic-soin sur les cadres Blizzard** (facultatif) : portrait, cible, focalisation, familier, groupe.

### Macros de clic-soin

- Bibliothèque de macros de plusieurs lignes, utilisables sur n'importe quel clic, touche ou molette (`M:Nom`).
- Deux jetons : `@vp` dans les conditions (`/cast [@vp,dead] Résurrection; [@vp] Soins rapides`) et `{vp}` hors conditions (`/focus {vp}`).
- **Vérification en direct** : conditions mal écrites (`[@vp,ded]`, `[mod:shfit]`), sorts inconnus, crochets mal fermés, longueur réelle une fois `@vp` remplacé, et commandes qui exécutent du code (`/script`, `/run`, `/console`).
- Modèles par classe, import des macros du jeu avec conversion automatique de `[@mouseover]` en `[@vp]`, partage en texte entre joueurs.

### Ce que montre un cadre

| Élément | Signification |
|---|---|
| Barre de la couleur d'un type de débuff, bordure qui clignote, son | un débuff que VOTRE personnage peut dissiper |
| Grande icône au centre | le débuff de boss le plus prioritaire, avec cumuls et durée |
| Petites icônes | vos HoTs (6 emplacements), temps restant, spirale, charges |
| Fines barres en haut | durée de vos HoTs sur les tanks |
| Barre verte claire | soins entrants (avec LibHealComm-4.0), limités aux 4 prochaines secondes |
| Fine barre bleu pâle | boucliers (Mot de pouvoir : Bouclier, Égide divine, Bouclier sacré...) |
| « +3.2k » | surplus de soin : soins en cours au-delà de la vie manquante |
| Bordure rouge qui s'éteint | dégâts brutaux : plus de 30 % de la vie perdus en 1,5 s |
| Bordure orange | mode urgence : les joueurs les plus blessés |
| Teinte d'accent | conseil de soin de zone |
| Cadre gris | il vous manque un buff de soigneur, ou votre tank n'a pas le sien |
| Icône à gauche / à droite | gros défensif actif / soins réduits |
| Flèche | direction d'un joueur hors de portée de votre soin |
| « Mort 1:23 », « Rez... », « Rez en attente » | temps depuis la mort, résurrection en cours ou à accepter |
| « Boit 45% » | joueur en train de boire hors combat |

Chaque icône a sa position, son décalage et sa taille, réglables sur un schéma ou à la souris, au pixel près, sur une copie agrandie d'un cadre.

### Dispel

- Pour les paladins, prêtres, druides, chamans et mages, selon les sorts réellement présents dans le grimoire.
- Deux sorts de dispel sur la touche de votre choix, avec la touche écrite sur le cadre.
- Portée réelle de VOTRE sort de dispel ; un joueur hors de vue est oublié quelques secondes.
- Rien d'inutile : affaiblissements sans effet sur la classe du joueur (Malédiction des langages sur un guerrier), débuffs à ne pas retirer, Abolir déjà actif. Affliction instable est signalée « DANGER ».
- Fenêtre « À dissiper » triée (prioritaires, à portée, ordre des types, expiration).
- **Petits cadres cliquables** : un carré par joueur, coloré quand il y a quelque chose à dissiper. Ils fonctionnent même en combat et même quand les cadres de soin sont cachés, pour un DPS ou un mage qui décurse.

### Débuffs de boss

90 identifiants d'affaiblissements intégrés, pour Naxxramas, Malygos, Sartharion, Ulduar, l'Épreuve du croisé, Onyxia, la Citadelle de la Couronne de glace et le Sanctum rubis. Chacun a une priorité de 1 à 10. Votre liste personnelle s'y ajoute (« Nom » ou « Nom = 9 »). Les débuffs sans intérêt pour un soigneur (Rassasié après un Héroïsme, Récemment bandé...) ne sont jamais affichés.

### Buffs et rappels de soigneur

- Point jaune sur les joueurs à qui il manque un de vos buffs de groupe.
- **Cadre gris** quand il vous manque un buff personnel (Bouclier d'eau, Arme Viveterre, Feu intérieur, Sceau) ou que votre tank n'a pas le sien (Bouclier de terre, Épines, Guide de lumière, Bouclier sacré, Mot de pouvoir : Bouclier). Un tank qui porte déjà le Bouclier de terre, les Épines ou le Gardien de peur d'un autre joueur n'est pas grisé.
- Fenêtre Buffs : un clic lance le buff manquant. Raccourci « Buff intelligent ».

### Soin de zone avec de vraies distances

Le client 3.3.5 donne la position de chaque joueur sur la carte, mais pas la taille de la carte. VuhPlus l'apprend en jeu en comparant avec des distances connues : la portée de votre soin (40 m), la distance de duel et celle de suivi. Il teinte ensuite la cible qui a le plus de vie manquante soignable autour d'elle : Cercle de soins et Croissance sauvage (15 m, 5 joueurs), Salve de guérison (cible blessée et 12,5 m). Sans carte utilisable, il revient au groupe de raid le plus touché.

### Raid et chef de raid

- **Recharges du raid** : qui a quoi de prêt (Suppression de la douleur, Esprit gardien, Main de sacrifice, Maîtrise des auras, hymnes, Totem de vague de mana, Innervation, Héroïsme...), ligne « Rez combat » et pierres d'âme posées.
- **Annonces discrètes** de vos gros sorts : une ligne au groupe pour les sorts de raid, en instance seulement, et des barres de temps à l'écran.
- **Barre d'outils** : appel, pull 5 ou 10 secondes, les 8 symboles, vérification des consommables.
- **Consommables** : flacon (ou deux élixirs) et nourriture vérifiés à chaque appel.
- **État du raid** : morts, déconnectés, loin, mana moyenne des soigneurs.
- **Rapport de mort** : le dernier coup reçu, dans votre chat ou annoncé par le chef.
- **Assignations de soin** (« Bella = Tankor, Arthos ») : bordure sur vos cibles, annonce au raid.
- **Alertes** : aggro sur vous, autre tank en danger, bijoux prêts en phase critique.

### Panneaux

Raid par groupe, par classe, par nom, par rôle en blocs ou par rôle en grille. Tanks principaux, Mes tanks, Projecteur (jusqu'à 10 joueurs choisis), Cible, cible de la cible, Focalisation, Cible du boss, Cible de la focalisation. Familiers sous leur maître, à côté du raid ou dans un panneau séparé.

### Configuration

- Fenêtre en français, une page par fonction, rangée en six groupes.
- **Recherche avec synonymes** : « purifier », « décurse » et « cleanse » mènent tous au dispel.
- Mode Essentiel (réglages avancés repliés) ou Tous les réglages.
- **Mode test** : un faux groupe de 5, 10, 25 ou 40 joueurs pour tout régler sans être en raid.
- Réglages par personnage, profils, profil automatique selon la spé ou la taille du groupe, import et export en texte.
- « Annuler » rétablit tous les réglages tels qu'à l'ouverture de la fenêtre.

## Installation

1. Téléchargez `VuhPlus-x.y.z.zip` dans **[Releases](../../releases)**.
   > **Attention** : n'utilisez pas le bouton vert *Code → Download ZIP*, qui produit un dossier `VuhPlus-main` que le jeu ne charge pas.
2. Quittez complètement le jeu.
3. Supprimez l'ancien dossier `Interface/AddOns/VuhPlus` s'il existe, puis décompressez l'archive dans `World of Warcraft/Interface/AddOns/`. Vous devez obtenir `AddOns/VuhPlus/VuhPlus.toc`.
4. Désactivez les autres cadres de raid (VuhDo, Grid...) pour ne pas avoir deux cadres.
5. Relancez le jeu, puis tapez `/vp`.

Vos réglages sont conservés d'une version à l'autre.

**Facultatif :** installez LibHealComm-4.0 (version 3.3.5) pour les soins entrants, SharedMedia pour plus de textures et de polices, LibResComm-1.0 pour voir les résurrections en cours des autres joueurs.

## Commandes

| Commande | Effet |
|---|---|
| `/vp` ou `/vuhplus` | ouvrir la configuration (aussi : bouton de la minicarte) |
| `/vp aide` | liste des commandes |
| `/vp apercu` | mode test : faux groupe pour régler l'affichage |
| `/vp lock`, `/vp unlock` | verrouiller ou déplacer les cadres |
| `/vp reset` | positions par défaut |
| `/vp role [Nom] heal\|tank\|dps\|auto` | forcer le rôle d'un joueur (ou de votre cible) |
| `/vp tank [Nom]` | ajouter ou retirer un joueur de « Mes tanks » |
| `/vp spot [Nom]` | ajouter ou retirer un joueur du Projecteur |
| `/vp cadres` | afficher ou cacher les cadres de soin |
| `/vp silence` | couper ou remettre toutes les alertes |
| `/vp cd` | afficher ou cacher les recharges du raid |
| `/vp outils` | afficher ou cacher la barre d'outils de raid (`/vp outils test` : essai de 60 s) |
| `/vp conso` | vérifier flacons et nourriture (`/vp conso raid` : l'annoncer) |
| `/vp dispel` | ce que votre personnage peut dissiper |
| `/vp profil save\|load\|suppr Nom` | gérer les profils |
| `/vp perf` | mémoire et processeur utilisés par VuhPlus |
| `/vp test` | tester l'alerte des bijoux |
| `/vp diag` | journal de diagnostic des cadres (pour un signalement de bug) |

Raccourcis (Échap > Raccourcis > VuhPlus) : utiliser les bijoux, buff intelligent.

## Sous le capot

| | |
|---|---|
| Client | 3.3.5a (build 12340), `## Interface: 30300` |
| Langage | Lua 5.1, API WoW 3.3.5 |
| Dépendances | aucune. LibHealComm-4.0, LibSharedMedia-3.0 et LibResComm-1.0 sont utilisées si elles sont présentes. |
| Code | environ 15 000 lignes, 27 fichiers |

Le fonctionnement complet est décrit dans **[docs/CONSTRUCTION.md](docs/CONSTRUCTION.md)** : architecture, moteur de mise à jour, détection des rôles, dispel, soin de zone, messages entre joueurs VuhPlus, interface, performances et vérification.

L'historique des versions est dans **[CHANGELOG.md](CHANGELOG.md)**.

## Contribuer

Les signalements de bugs et les suggestions sont les bienvenus dans l'onglet **Issues**. Pour un problème de cadres qui disparaissent, le journal de `/vp diag` aide beaucoup.

Pour proposer une modification du code, lisez **[CONTRIBUTING.md](CONTRIBUTING.md)**.

## Retrouvez mes projets pour WotLK 3.3.5

Tous mes addons sont écrits pour le client 3.3.5a, en français et sans dépendance. Ils fonctionnent très bien ensemble.

| Addon | Pour quoi faire | Version | Téléchargements |
|---|---|---|---|
| **[Zénith](https://github.com/BellaHealFr/Zenith)** | Compteur de combat : dégâts, soins, boucliers, les mêmes chiffres pour tout le groupe, relecture des combats, records par boss. | [![Version](https://img.shields.io/github/v/release/BellaHealFr/Zenith?label=&color=1e90ff)](https://github.com/BellaHealFr/Zenith/releases/latest) | [![Téléchargements](https://img.shields.io/github/downloads/BellaHealFr/Zenith/total?label=&color=success)](https://github.com/BellaHealFr/Zenith/releases) |
| **[VuhPlus](https://github.com/BellaHealFr/VuhPlus)** | Cadres de raid pour soigneurs : soin au clic, dispel, débuffs de boss, rôles reconnus, recharges du raid. | [![Version](https://img.shields.io/github/v/release/BellaHealFr/VuhPlus?label=&color=1e90ff)](https://github.com/BellaHealFr/VuhPlus/releases/latest) | [![Téléchargements](https://img.shields.io/github/downloads/BellaHealFr/VuhPlus/total?label=&color=success)](https://github.com/BellaHealFr/VuhPlus/releases) |
| **[Strata](https://github.com/BellaHealFr/Strata)** | Carte du monde continue : trois continents sur une seule carte, zoom et déplacement libres, vos zones découvertes, votre groupe. | [![Version](https://img.shields.io/github/v/release/BellaHealFr/Strata?label=&color=1e90ff)](https://github.com/BellaHealFr/Strata/releases/latest) | [![Téléchargements](https://img.shields.io/github/downloads/BellaHealFr/Strata/total?label=&color=success)](https://github.com/BellaHealFr/Strata/releases) |

## Licence

Copyright (C) 2026 BellaHealFr.

VuhPlus est un logiciel libre distribué sous **GNU GPL v3** (`GPL-3.0-only`), avec des conditions supplémentaires prévues par l'article 7 de la licence. Vous pouvez l'utiliser, l'étudier, le modifier et le redistribuer. Toute version redistribuée, modifiée ou non, doit :

- rester sous la même licence, code source compris ;
- conserver la mention de l'auteur ;
- si elle est modifiée, être clairement signalée comme différente de l'original, sous **un autre nom que « VuhPlus »** et avec un autre dossier d'installation.

Texte complet : [`LICENSE`](LICENSE). Conditions supplémentaires : [`NOTICE.md`](NOTICE.md).

VuhPlus s'inspire de l'ergonomie de VuhDo sans en reprendre le code, et n'est pas affilié à ses auteurs. World of Warcraft est une marque de Blizzard Entertainment. Ce projet n'est ni affilié à Blizzard Entertainment, ni approuvé par lui.

---

<div align="center">

Créé par **BellaHealFr**

*Pour tous ceux qui n'ont jamais quitté le Norfendre.*

</div>
