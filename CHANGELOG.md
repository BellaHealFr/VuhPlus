# Historique des versions

## 5.9.0

### Ajouts
- **Spé partagée entre joueurs VuhPlus.** Chaque joueur VuhPlus envoie au groupe l'arbre principal de ses talents. Son rôle est connu tout de suite, sans inspection et sans devoir être à 28 m, et un changement de spé suit aussitôt. Les joueurs sans VuhPlus sont toujours inspectés.
- Réglage « Partager ma spé avec les joueurs VuhPlus » (page Indicateurs), activé par défaut.

### Corrections
- En groupe de 5, le rapport de mort annoncé au groupe n'est plus envoyé que par le chef. Avant, chaque joueur VuhPlus du groupe répétait les mêmes morts.

### Performances
- Moins de mémoire allouée par la mise à jour des auras des cadres (environ 9 % en raid 25 dans le banc de simulation).

### Projet
- Publication du code source sous licence GPL-3.0 avec conditions supplémentaires (`LICENSE`, `NOTICE.md`).
- Documentation : `README.md`, `docs/CONSTRUCTION.md`, `CONTRIBUTING.md`.
- Banc de simulation (`tests/`) : le vrai code de l'addon joué dans Lua 5.1 avec un faux client 3.3.5.
- Vérification et publication automatiques sur GitHub.

## 5.8.6

### Corrections
- **Tri par rôle : un druide tank qui passe un instant en forme de félin ne change plus de bloc.** L'autre forme ne compte que si elle est gardée 30 secondes d'affilée en combat. Même règle pour un chevalier de la mort qui change de présence. Après un changement de spé, la nouvelle forme compte tout de suite.

## 5.8.5

- **Appel (ready check) visible par tout le raid** : chaque joueur VuhPlus annonce sa réponse, et un chef ou assistant VuhPlus relaie celles que le serveur lui envoie.
- **Annonces discrètes** : une seule ligne au groupe, seulement pour les sorts de raid et seulement en instance ; le reste dans votre chat.

## 5.8.4 et versions antérieures

Versions publiées avant la tenue de ce journal. Leurs nouveautés sont décrites dans `LISEZMOI.txt`, livré avec l'addon.
