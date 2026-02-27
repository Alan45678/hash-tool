# Tests

## Structure des tests
```
tests/
  run_tests.sh           -> orchestrateur, lance tous les tests
  run_tests_core.sh      -> tests unitaires des fonctions de src/lib/core.sh
  run_tests_pipeline.sh  -> tests d'intégration des pipelines JSON
```

## Exécution
```bash
# Tous les tests
bash tests/run_tests.sh

# Tests unitaires core uniquement
bash tests/run_tests_core.sh

# Tests pipeline uniquement
bash tests/run_tests_pipeline.sh
```
Prérequis : `hash-tool check-env` doit retourner OK.
Les données de test dans `examples/` doivent être dans leur état d'origine.

## Données de test
`examples/workspace/_data-source/` et `examples/workspace/_data-destination/` : 4 fichiers
lorem-ipsum dont un différent entre les deux dossiers (`lorem-ipsum-01-modif.txt`).
`examples/workspace/bases/` : bases pré-calculées de référence.
`examples/workspace/result/` : résultats de compare de référence.

## Ajouter un test
Convention : chaque cas est une fonction `test_<nom>()` retournant `0` (succès)
ou `1` (échec). Ajouter la fonction dans le fichier de test correspondant,
puis l'enregistrer dans l'orchestrateur `run_tests.sh`. Les données de test
supplémentaires se placent dans `examples/` en suivant la structure existante.

## CI
Les tests sont exécutés automatiquement dans le workflow GitHub Actions.
Voir `development/ci.md` pour les détails.
