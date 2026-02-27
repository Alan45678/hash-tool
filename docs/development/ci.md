# CI/CD

## Workflow GitHub Actions
Fichier : `.github/workflows/ci.yml`.
Déclencheurs : push sur `main`, pull request vers `main`.

## Jobs définis
**Build Docker** : `docker build -t hash_tool .` - vérifie que l'image se
construit sans erreur depuis le `Dockerfile`.

**Smoke tests** : série de tests rapides sur l'image buildée :
- `docker run hash_tool version` - image exécutable
- `docker run hash_tool help` - entrypoint fonctionnel
- `docker run hash_tool check-env` - dépendances présentes
- `compute` via volume sur données temporaires - workflow de base fonctionnel
- `verify` sur la base produite - cohérence compute/verify
- Commande inconnue -> exit non-zéro - gestion d'erreur de l'entrypoint

## `.dockerignore` en CI
Les tests, la documentation et les données utilisateur sont exclus du contexte
de build. Le contexte envoyé au daemon Docker est minimal (~quelques Ko).
Conséquence : les scripts de `tests/` ne sont pas disponibles dans l'image -
les smoke tests CI s'exécutent côté hôte via `docker run`.

## Étendre la CI
Pour ajouter un job : créer un step dans `ci.yml` suivant la convention existante.
Pour ajouter un test d'intégration : ajouter le cas dans `tests/run_tests.sh`
et référencer le script dans un job CI dédié si les tests sont longs.
Les tests unitaires peuvent être lancés nativement si b3sum est installé sur
le runner GitHub Actions (ubuntu-latest).
