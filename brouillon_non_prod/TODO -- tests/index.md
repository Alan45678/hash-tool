# Tests — Vue d'ensemble

**Scope :** documentation de la stratégie de test de `hash_tool`  
**Statut :** spécification — à implémenter  
**Référence audit :** réponse d'analyse du 24/02/2026

---

## Situation actuelle

| Suite | Fichier | Type | Cas | Statut |
|---|---|---|---|---|
| integrity.sh | `tests/run_tests.sh` | Intégration | T00–T14 | ✅ Existant |
| runner.sh + pipeline | `tests/run_tests_pipeline.sh` | Intégration | TP01–TP12b | ✅ Existant |
| core.sh (unitaires) | `tests/run_tests_core.sh` | Unitaire | — | ❌ À créer |
| Docker + entrypoint | `tests/run_tests_docker.sh` | Environnement | — | ❌ À créer |
| Non-régression .b3 | fixture `tests/fixtures/reference.b3` | Régression | — | ❌ À créer |

**Diagnostic principal :** la pyramide des tests est inversée. Les tests d'intégration sont bien couverts, mais les tests unitaires (`core.sh`) et les tests d'environnement (Docker) sont absents. La CI n'existe pas — les tests ne sont lancés que manuellement.

---

## Suites à créer

### `tests/run_tests_core.sh` — Tests unitaires

Teste chaque fonction de `src/lib/core.sh` en isolation, par sourcing direct, sans passer par `integrity.sh`. Priorité maximale : `core_compare` (algorithme complexe, bug historique en v0.7).

→ Spécification complète : [unit-tests.md](unit-tests.md)

### Extensions de `run_tests.sh` — Edge cases

Ajout des cas T15 à T20+ couvrant les noms de fichiers avec caractères spéciaux, les fichiers vides, les caractères HTML dans les chemins, le mode `--quiet` sur `compare`.

→ Spécification complète : [edge-cases.md](edge-cases.md) et [integration-tests.md](integration-tests.md)

### `tests/fixtures/` — Données de référence

Arborescence de fichiers figés commitée dans git, utilisée pour les tests de non-régression du format `.b3` et les tests de cas limites.

→ Spécification complète : [fixtures.md](fixtures.md) et [regression-tests.md](regression-tests.md)

### `tests/run_tests_docker.sh` — Tests d'environnement

Teste le build Docker, l'entrypoint commande par commande, la taille de l'image, et le comportement multi-plateforme (amd64/arm64).

→ Spécification complète : [docker-tests.md](docker-tests.md)

### CI GitHub Actions

Workflow automatique déclenché à chaque push et PR : jobs unitaires, intégration, Docker, ShellCheck, matrice OS.

→ Spécification complète : [ci-cd.md](ci-cd.md)

---

## Arborescence cible

```
tests/
├── run_tests.sh                   ← existant — intégration integrity.sh (T00–T20+)
├── run_tests_pipeline.sh          ← existant — intégration runner.sh (TP01–TP12b)
├── run_tests_core.sh              ← à créer  — unitaires core.sh
├── run_tests_docker.sh            ← à créer  — environnement Docker
└── fixtures/
    ├── data/
    │   ├── alpha.txt              ← fichier texte standard
    │   ├── beta.txt               ← fichier texte standard
    │   ├── fichier avec espaces.txt
    │   ├── fichier&special.txt
    │   ├── <html>chars.txt
    │   └── zero_bytes.bin         ← fichier de taille zéro
    └── reference.b3               ← hash de référence pour non-régression
```

---

## Ordre d'implémentation recommandé

| Priorité | Livrable | Valeur | Effort |
|---|---|---|---|
| 1 | CI GitHub Actions (squelette minimal) | Détection régression sur PR | ~2h |
| 2 | `run_tests_core.sh` | Isolation des bugs `core.sh` | ~4h |
| 3 | `tests/fixtures/` + non-régression `.b3` | Détection régression silencieuse | ~1h |
| 4 | Edge cases T15–T20 dans `run_tests.sh` | Couverture cas limites | ~2h |
| 5 | `run_tests_docker.sh` | Couverture environnement Docker | ~3h |
| 6 | Format TAP dans toutes les suites | Interopérabilité CI | ~2h |

---

## Règle d'or

> Un test n'a de valeur que s'il est lancé automatiquement à chaque modification.  
> La CI est le seul mécanisme qui garantit cette propriété.  
> Implémenter la CI en premier, avant même d'écrire de nouveaux tests.

---

## Documents de cette section

| Document | Contenu |
|---|---|
| [strategy.md](strategy.md) | Décisions, objectifs de couverture, définition de "done" |
| [unit-tests.md](unit-tests.md) | Spécification `run_tests_core.sh` |
| [integration-tests.md](integration-tests.md) | Extensions `run_tests.sh` et `run_tests_pipeline.sh` |
| [regression-tests.md](regression-tests.md) | Non-régression format `.b3`, fixtures statiques |
| [edge-cases.md](edge-cases.md) | Catalogue des cas limites |
| [docker-tests.md](docker-tests.md) | Spécification `run_tests_docker.sh` |
| [fixtures.md](fixtures.md) | Spécification `tests/fixtures/` |
| [tap-format.md](tap-format.md) | Format TAP, helpers bash |
| [ci-cd.md](ci-cd.md) | Workflow GitHub Actions |
