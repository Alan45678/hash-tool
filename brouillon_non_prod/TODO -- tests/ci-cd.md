# CI/CD — Spécification GitHub Actions

---

## Objectifs

1. **Détection automatique des régressions** : chaque push et chaque PR déclenchent les tests.
2. **Blocage des PRs cassées** : une PR ne peut pas merger si un test échoue.
3. **Feedback rapide** : les tests unitaires et d'intégration donnent un résultat en < 2 minutes.
4. **Isolation des tests lents** : les tests Docker (build arm64, QEMU) sont séparés et ne bloquent pas le feedback rapide.
5. **Artefacts accessibles** : les résultats de tests sont téléchargeables depuis l'interface GitHub même en cas d'échec.

---

## Architecture des jobs

```
push / PR
    │
    ├── [job: lint]          ShellCheck sur tous les scripts
    │       ↓
    ├── [job: unit]          run_tests_core.sh    (~30s)
    │       ↓
    ├── [job: integration]   run_tests.sh         (~60s)
    │       ↓
    ├── [job: pipeline]      run_tests_pipeline.sh (~60s)
    │
    └── [job: docker]        (déclenché sur : push main + PR modifiant Dockerfile)
            ├── docker build amd64
            ├── run_tests_docker.sh (sans --build, image en cache)
            └── docker build arm64  (QEMU, séparé, peut échouer sans bloquer)
```

Les jobs `unit`, `integration`, `pipeline` sont **indépendants et parallèles** — ils peuvent tourner simultanément. Le job `docker` est conditionnel.

---

## Fichier `.github/workflows/ci.yml`

```yaml
name: CI

on:
  push:
    branches: ["main", "develop"]
  pull_request:
    branches: ["main"]

# Annuler les runs en cours si un nouveau push arrive sur la même PR
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:

  # ============================================================
  # Job : lint — ShellCheck sur tous les scripts
  # ============================================================
  lint:
    name: ShellCheck
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Installer ShellCheck
        run: sudo apt-get install -y shellcheck

      - name: ShellCheck — scripts principaux
        run: |
          shellcheck \
            src/integrity.sh \
            runner.sh \
            src/lib/core.sh \
            src/lib/ui.sh \
            src/lib/results.sh \
            src/lib/report.sh \
            docker/entrypoint.sh

      - name: ShellCheck — suites de tests
        run: |
          shellcheck \
            tests/run_tests.sh \
            tests/run_tests_pipeline.sh \
            tests/run_tests_core.sh \
            tests/run_tests_docker.sh \
            tests/helpers-tap.sh

  # ============================================================
  # Job : unit — Tests unitaires core.sh
  # ============================================================
  unit:
    name: Tests unitaires (core.sh)
    runs-on: ubuntu-latest
    needs: lint   # ne lance pas les tests si ShellCheck échoue

    strategy:
      matrix:
        os: [ubuntu-22.04, ubuntu-24.04]

    steps:
      - uses: actions/checkout@v4

      - name: Installer les dépendances
        run: sudo apt-get install -y b3sum

      - name: Lancer run_tests_core.sh
        run: |
          cd tests
          ./run_tests_core.sh 2>&1 | tee /tmp/core-results.tap
        env:
          CI: "true"

      - name: Uploader les résultats
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: unit-test-results-${{ matrix.os }}
          path: /tmp/core-results.tap
          retention-days: 7

  # ============================================================
  # Job : integration — Tests d'intégration integrity.sh
  # ============================================================
  integration:
    name: Tests d'intégration (integrity.sh)
    runs-on: ubuntu-latest
    needs: lint

    strategy:
      matrix:
        os: [ubuntu-22.04, ubuntu-24.04]

    steps:
      - uses: actions/checkout@v4

      - name: Installer les dépendances
        run: sudo apt-get install -y b3sum

      - name: Lancer run_tests.sh
        run: |
          cd tests
          ./run_tests.sh 2>&1 | tee /tmp/integration-results.tap
        env:
          CI: "true"

      - name: Uploader les résultats
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: integration-test-results-${{ matrix.os }}
          path: /tmp/integration-results.tap
          retention-days: 7

  # ============================================================
  # Job : pipeline — Tests d'intégration runner.sh
  # ============================================================
  pipeline:
    name: Tests pipeline (runner.sh)
    runs-on: ubuntu-latest
    needs: lint

    steps:
      - uses: actions/checkout@v4

      - name: Installer les dépendances
        run: sudo apt-get install -y b3sum jq

      - name: Lancer run_tests_pipeline.sh
        run: |
          cd tests
          ./run_tests_pipeline.sh 2>&1 | tee /tmp/pipeline-results.tap
        env:
          CI: "true"

      - name: Uploader les résultats
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: pipeline-test-results
          path: /tmp/pipeline-results.tap
          retention-days: 7

  # ============================================================
  # Job : non-regression — Test de non-régression format .b3
  # ============================================================
  non-regression:
    name: Non-régression format .b3
    runs-on: ubuntu-latest
    needs: lint

    steps:
      - uses: actions/checkout@v4

      - name: Installer b3sum
        run: sudo apt-get install -y b3sum

      - name: Vérifier reference.b3
        run: |
          cd tests/fixtures
          ../../src/integrity.sh compute ./data /tmp/output_reg.b3
          diff bases/reference.b3 /tmp/output_reg.b3 || {
            echo "ERREUR : régression du format .b3 détectée"
            echo "--- reference.b3 (attendu) ---"
            head -5 bases/reference.b3
            echo "--- output produit ---"
            head -5 /tmp/output_reg.b3
            exit 1
          }
          echo "Format .b3 stable"

  # ============================================================
  # Job : docker-build — Build et tests Docker (amd64)
  # ============================================================
  docker-build:
    name: Docker build + tests (amd64)
    runs-on: ubuntu-latest
    needs: lint

    # Ne tourner que sur main, develop, et les PRs modifiant Docker
    if: |
      github.ref == 'refs/heads/main' ||
      github.ref == 'refs/heads/develop' ||
      contains(github.event.pull_request.changed_files, 'Dockerfile') ||
      contains(github.event.pull_request.changed_files, '.dockerignore') ||
      contains(github.event.pull_request.changed_files, 'docker/')

    steps:
      - uses: actions/checkout@v4

      - name: Build image Docker amd64
        run: docker build --platform linux/amd64 -t hash_tool .

      - name: Vérifier la taille de l'image
        run: |
          SIZE=$(docker image inspect hash_tool --format='{{.Size}}')
          SIZE_MB=$(( SIZE / 1024 / 1024 ))
          echo "Taille image : ${SIZE_MB} Mo"
          [ "$SIZE_MB" -lt 30 ] || { echo "ERREUR : image trop lourde (${SIZE_MB} Mo)"; exit 1; }

      - name: Lancer run_tests_docker.sh
        run: |
          cd tests
          ./run_tests_docker.sh 2>&1 | tee /tmp/docker-results.tap
        env:
          CI: "true"

      - name: Uploader les résultats
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: docker-test-results
          path: /tmp/docker-results.tap
          retention-days: 7

  # ============================================================
  # Job : docker-arm64 — Build arm64 (QEMU, peut être lent)
  # ============================================================
  docker-arm64:
    name: Docker build (arm64)
    runs-on: ubuntu-latest
    needs: docker-build
    # Ce job peut échouer sans bloquer le merge (continue-on-error)
    continue-on-error: true

    if: github.ref == 'refs/heads/main'

    steps:
      - uses: actions/checkout@v4

      - name: Setup QEMU
        uses: docker/setup-qemu-action@v3

      - name: Setup Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build image arm64
        run: |
          docker buildx build \
            --platform linux/arm64 \
            -t hash_tool:arm64 \
            --load \
            .

      - name: Test basique arm64
        run: docker run --rm --platform linux/arm64 hash_tool version
```

---

## Conditions de blocage des PRs

Configurer dans les **Branch Protection Rules** de GitHub (`Settings > Branches > main`) :

| Check requis | Job concerné | Bloquant |
|---|---|---|
| ShellCheck | `lint` | Oui |
| Tests unitaires (ubuntu-22.04) | `unit` | Oui |
| Tests unitaires (ubuntu-24.04) | `unit` | Oui |
| Tests d'intégration (ubuntu-22.04) | `integration` | Oui |
| Tests d'intégration (ubuntu-24.04) | `integration` | Oui |
| Tests pipeline | `pipeline` | Oui |
| Non-régression .b3 | `non-regression` | Oui |
| Docker build amd64 | `docker-build` | Oui (si Dockerfile modifié) |
| Docker build arm64 | `docker-arm64` | Non (`continue-on-error: true`) |

---

## Gestion des artefacts

Chaque job uploade ses résultats TAP en artefact. Ils sont accessibles depuis l'onglet "Actions" de GitHub pendant 7 jours.

En cas d'échec, la procédure de diagnostic :
1. Cliquer sur le job échoué dans l'interface Actions.
2. Consulter les logs en ligne (résultats TAP affichés dans le terminal).
3. Télécharger l'artefact correspondant si un contexte plus détaillé est nécessaire.

---

## Déclenchement manuel

Le workflow peut être déclenché manuellement depuis l'interface GitHub Actions (`workflow_dispatch`) :

```yaml
on:
  push: ...
  pull_request: ...
  workflow_dispatch:    # ← déclenchement manuel
    inputs:
      run_docker_arm64:
        description: 'Lancer le build arm64 (lent)'
        type: boolean
        default: false
```

---

## Secrets et variables d'environnement

Aucun secret n'est requis pour la CI de base — `hash_tool` n'a pas de dépendances réseau dans ses tests (tout est local).

Si des notifications (Slack, email) sont ajoutées dans le futur :
- `SLACK_WEBHOOK_URL` → `Settings > Secrets > Actions`
- Ne jamais logger les secrets dans les steps

---

## Durée estimée par run CI

| Job | Durée estimée |
|---|---|
| lint (ShellCheck) | ~15s |
| unit (ubuntu-22.04) | ~30s |
| unit (ubuntu-24.04) | ~30s |
| integration (ubuntu-22.04) | ~60s |
| integration (ubuntu-24.04) | ~60s |
| pipeline | ~60s |
| non-regression | ~20s |
| docker-build + tests amd64 | ~3-4 min |
| docker-arm64 (QEMU) | ~8-12 min |

**Durée totale pour un push standard** (sans Docker) : ~2 minutes (jobs parallèles).  
**Durée avec Docker** : ~5 minutes (Docker build en parallèle des autres jobs).

---

## Évolutions futures

| Évolution | Priorité | Description |
|---|---|---|
| Publication TAP → rapport HTML | Basse | Utiliser `dorny/test-reporter` pour afficher les résultats dans les PR checks |
| Cache des dépendances apt | Moyenne | `actions/cache` sur `/var/cache/apt` — gain ~20s par job |
| Scheduled run nocturne | Basse | `on: schedule: cron: '0 3 * * *'` — détecte les régressions dues à des mises à jour de dépendances système |
| Notification sur échec | Basse | Webhook Slack sur `main` uniquement, pas sur les PRs |
