# Tests

## Structure des tests
```
tests/
  run_tests.sh           -> tests fonctionnels integrity.sh (T00-T20)
  run_tests_core.sh      -> tests unitaires src/lib/core.sh (CU01-CU53)
  run_tests_pipeline.sh  -> tests d'intégration runner.sh (TP01-TP12)
```

## Exécution
```bash
# Tous les tests via Makefile (recommandé)
make test

# Suites individuelles
cd tests && bash run_tests.sh
cd tests && bash run_tests_core.sh
cd tests && bash run_tests_pipeline.sh
```

Prérequis : `hash-tool check-env` doit retourner OK.
Les données de test dans `examples/workspace/` doivent être dans leur état d'origine.

## Lint
```bash
make lint
```

Lance ShellCheck sur tous les scripts : `src/integrity.sh`, `src/lib/*.sh`,
`runner.sh`, `docker/entrypoint.sh`, `tests/*.sh`. Aucun avertissement toléré.

## Données de test

`examples/workspace/_data-source/` et `examples/workspace/_data-destination/` :
4 fichiers lorem-ipsum dont un différent entre les deux dossiers (`lorem-ipsum-01-modif.txt`).
`examples/workspace/bases/` : bases pré-calculées de référence.
`examples/workspace/result/` : résultats de compare de référence.

Ne pas modifier ces fichiers — les assertions de la suite dépendent de leur état exact.

## Ajouter un test

Convention : chaque cas est une fonction `test_<nom>()` retournant `0` (succès)
ou `1` (échec). Ajouter la fonction dans le fichier de test correspondant,
puis l'enregistrer dans l'orchestrateur `run_tests.sh`. Les données de test
supplémentaires se placent dans `examples/` en suivant la structure existante.

## CI

Les tests sont exécutés automatiquement dans le workflow GitHub Actions à chaque
push et pull request. Voir `development/ci.md` pour les détails.