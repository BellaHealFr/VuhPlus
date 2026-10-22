## Ce que change cette proposition

<!-- En quelques phrases : le problème ou le besoin, et la solution. Mentionnez le ticket concerné (#123). -->

## Vérifications

- [ ] Testé en jeu sur un client **3.3.5a**
- [ ] Testé en groupe ou en raid si la modification touche le groupe, les rôles ou les messages entre joueurs
- [ ] Aucune fonction absente de l'API 3.3.5 (`C_Timer`, `ENCOUNTER_START`, `RegisterAddonMessagePrefix`…)
- [ ] Rien de protégé modifié en combat (passage par `VP:RunOOC`)
- [ ] Banc de simulation vert : `python tests/run.py . tests/scenario_*.lua`
- [ ] Textes affichés et commentaires en français
- [ ] Nouvelle clé de réglage déclarée dans `VP.defaults` ; ancien format converti dans `migrate` si besoin
- [ ] Messages entre joueurs VuhPlus compatibles (anciens messages lus ou ignorés sans erreur)
- [ ] Section ajoutée ou complétée dans `CHANGELOG.md`

En proposant cette contribution, j'accepte qu'elle soit publiée sous la licence du projet (GPL-3.0 avec les conditions de `NOTICE.md`).
