# Contribuer à VuhPlus

Merci de vouloir améliorer VuhPlus ! Que vous soyez joueur ou développeur, il y a une place pour vous.

## Signaler un problème ou proposer une idée

Ouvrez un ticket dans l'onglet **Issues** et choisissez le formulaire :
- **Signaler un problème** : erreur Lua, cadres qui disparaissent ou se placent mal, clic qui ne lance pas le bon sort, alerte fausse ;
- **Proposer une idée** : nouvelle fonction, amélioration de l'interface.

Pour des cadres qui disparaissent ou se placent mal, le plus utile est le **journal de diagnostic** : tapez `/vp diag`, reconnectez le personnage concerné, attendez 20 secondes, déconnectez-vous, puis joignez la partie `diag` du fichier `WTF/Account/<compte>/SavedVariables/VuhPlus.lua`.

Avant d'ouvrir un ticket, vérifiez qu'il n'existe pas déjà.

## Proposer une modification du code

1. **Discutez-en d'abord** dans un ticket si la modification est importante : cela évite de travailler pour rien.
2. Créez une copie du dépôt (*Fork*), puis une branche au nom parlant (`correction-tri-role`, `dispel-familiers`…).
3. Lisez **[docs/CONSTRUCTION.md](docs/CONSTRUCTION.md)**, qui explique le fonctionnement complet. Sa section [Contribuer](docs/CONSTRUCTION.md#contribuer) donne les règles :
   - Lua 5.1 et API 3.3.5 uniquement ;
   - aucune bibliothèque embarquée ;
   - rien de protégé en combat (passer par `VP:RunOOC`) ;
   - textes en français ;
   - compatibilité des données sauvegardées et des messages entre joueurs VuhPlus.
4. **Lancez le banc de simulation** depuis la racine du dépôt :
   ```
   pip install lupa
   python tests/run.py . tests/scenario_*.lua
   ```
   Ajoutez un scénario si votre modification s'y prête.
5. **Testez en jeu** sur un client 3.3.5a, en groupe ou en raid si la modification touche le groupe, les rôles ou les messages entre joueurs.
6. Ouvrez une demande de fusion (*Pull Request*) et remplissez la liste de vérifications.

La vérification automatique (syntaxe Lua 5.1, fichiers du `.toc`, numéros de version, en-têtes de licence, banc de simulation) doit être verte.

## Style

- Une tabulation pour l'indentation des fichiers Lua.
- Commentaires en français, qui expliquent **pourquoi** plutôt que **quoi**.
- Messages de commit courts, en français, à l'infinitif : « Corriger le tri par rôle du druide », « Ajouter le partage de la spé ».

## Licence des contributions

VuhPlus est publié sous **GPL-3.0** avec les conditions supplémentaires de [`NOTICE.md`](NOTICE.md). Toute contribution est publiée sous cette même licence. Vous restez l'auteur de votre contribution, et votre nom apparaît dans l'historique du dépôt.
