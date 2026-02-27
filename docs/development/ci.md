# CI/CD

## Workflow GitHub Actions

Fichier : `.github/workflows/ci.yml`.
Déclencheurs : push sur toutes les branches, pull request vers toutes les branches.

## Jobs définis

**Tests fonctionnels et unitaires** (matrix : ubuntu-22.04, ubuntu-24.04) :
- Installation des dépendances : b3sum, jq, shellcheck
- `cd tests && ./run_tests.sh` — suite T00-T20
- `cd tests && ./run_tests_pipeline.sh` — suite TP01-TP12
- `cd tests && ./run_tests_core.sh` — suite CU01-CU53
- ShellCheck sur tous les scripts
- Upload des artefacts de test en cas d'échec (rétention 7 jours)

**Docker build & smoke tests** (ubuntu-latest) :
- `docker build -t hash_tool .` — vérifie que l'image se construit sans erreur
- Smoke tests via `docker run` : version, help, check-env, compute/verify sur données temporaires

## Makefile et CI

Les jobs CI reproduisent exactement ce que `make test` et `make lint` exécutent
en local. Un contributeur peut valider localement avant de pousser :
```bash
make lint    # reproduit le job ShellCheck
make test    # reproduit les trois suites de tests
```

## `.dockerignore` en CI

Les tests, la documentation et les données utilisateur sont exclus du contexte
de build. Le contexte envoyé au daemon Docker est minimal (~quelques Ko).
Les scripts de `tests/` ne sont pas disponibles dans l'image — les smoke tests
CI s'exécutent côté hôte via `docker run`.

## Étendre la CI

Pour ajouter un job : créer un step dans `ci.yml` suivant la convention existante.
Pour ajouter un test d'intégration : ajouter le cas dans `tests/run_tests.sh`
et référencer le script dans un job CI dédié si les tests sont longs.