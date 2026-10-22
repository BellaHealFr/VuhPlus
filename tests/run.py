# Copyright (C) 2026 BellaHealFr. Licence GPL-3.0-only avec conditions supplémentaires
# (mention de l'auteur, nom « VuhPlus » réservé) : voir LICENSE et NOTICE.md.
#
# Banc de simulation de VuhPlus : fait tourner le vrai code de l'addon dans Lua 5.1 avec un faux client 3.3.5.
# Utilisation, depuis la racine du dépôt :
#   pip install lupa
#   python tests/run.py . tests/scenario_*.lua
# Chaque scénario part d'un client neuf. Code de sortie 1 si une vérification échoue ou si une erreur Lua survient.
import os
import sys

import lupa.lua51 as lua51

here = os.path.dirname(os.path.abspath(__file__))


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def main():
    if len(sys.argv) < 3:
        print('Utilisation : python tests/run.py <dossier de l\'addon> <scénario.lua> [...]')
        return 2
    addon = sys.argv[1].replace('\\', '/')
    failures = 0
    for scenario in sys.argv[2:]:
        rt = lua51.LuaRuntime(encoding='utf-8', unpack_returned_tuples=True)
        rt.globals().ADDON_DIR = addon
        rt.execute(read(os.path.join(here, 'mock.lua')))
        rt.execute(read(os.path.join(here, 'common.lua')))
        try:
            rt.execute(read(scenario))
        except Exception as e:  # erreur dans le scénario lui-même
            print('ÉCHEC DU SCÉNARIO', scenario, ':', e)
            errors = rt.eval('ERRORS')
            for i in range(1, min(len(errors), 8) + 1):
                print('   erreur :', errors[i])
            failures += 1
            continue
        result = rt.eval('rawget(_G, "RESULT")') or ('ÉCHEC : le scénario ' + scenario + ' ne s\'est pas terminé')
        print(result)
        if 'ÉCHEC' in result:
            failures += 1
    print('Banc : %d scénario(s), %d en échec' % (len(sys.argv) - 2, failures))
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
