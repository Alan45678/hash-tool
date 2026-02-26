Bonne approche. Voici la démarche et les prompts, dans l'ordre.

---

## Principe général

Claude ne peut pas tout générer en un seul prompt — le contexte est trop large et le code produit serait non vérifiable. La bonne méthode : **une session par livrable**, avec à chaque fois le contexte minimal nécessaire et une vérification avant de passer à la suite.

L'ordre est imposé par les dépendances : `helpers-tap.sh` doit exister avant les suites qui le sourcent. Les fixtures doivent exister avant les tests de non-régression. La CI doit référencer des fichiers qui existent.

---

## Étape 1 — `helpers-tap.sh`

**Pourquoi en premier :** toutes les suites de tests le sourcent. C'est la fondation.

**Fichiers à fournir à Claude :**
- `tap-format.md`
- `tests/run_tests.sh` (pour comprendre le style et les helpers existants)

**Prompt :**
```
Tu vas créer le fichier tests/helpers-tap.sh pour le projet hash_tool.

Voici la spécification : [coller tap-format.md]

Voici la suite de tests existante pour comprendre le style du projet : [coller run_tests.sh]

Contraintes :
- bash >= 4, set -euo pipefail
- ShellCheck zéro warning
- Compatible avec la détection CI (variable $CI) : format coloré en local, format TAP en CI
- Toutes les fonctions assert_* documentées avec leur signature en commentaire
- Le fichier doit pouvoir être sourcé sans être exécuté directement (pas de logique au top-level)

Produis uniquement le fichier tests/helpers-tap.sh, complet et prêt à l'emploi.
```

**Vérification avant de continuer :**
```bash
shellcheck tests/helpers-tap.sh
bash -c 'source tests/helpers-tap.sh && echo "sourcing OK"'
```

---

## Étape 2 — `tests/fixtures/`

**Pourquoi en deuxième :** les tests de non-régression et plusieurs tests unitaires s'appuient sur les fixtures. Elles doivent exister avant d'écrire les tests qui les utilisent.

**Fichiers à fournir :**
- `fixtures.md`

**Prompt :**
```
Tu vas créer les fichiers de fixtures pour le projet hash_tool.

Voici la spécification : [coller fixtures.md]

Crée les fichiers suivants avec exactement le contenu spécifié :
- tests/fixtures/data/alpha.txt
- tests/fixtures/data/beta.txt
- tests/fixtures/data/gamma.txt
- tests/fixtures/data/sub/delta.txt
- tests/fixtures/data-edge/fichier avec espaces.txt
- tests/fixtures/data-edge/fichier&special.txt
- tests/fixtures/data-edge/zero_bytes.bin

Pour les fichiers data-edge avec des noms spéciaux (espaces, &), donne-moi les commandes bash 
exactes pour les créer, car les noms ne peuvent pas être représentés directement dans tous les contextes.

Ne génère pas encore reference.b3 — il sera généré après coup avec la commande réelle.
```

**Après la création des fichiers, générer `reference.b3` manuellement :**
```bash
cd tests/fixtures
../../src/integrity.sh compute ./data bases/reference.b3
cat bases/reference.b3   # vérifier le contenu
git add .
git commit -m "test(fixtures): add reference data and edge cases"
```

---

## Étape 3 — `tests/run_tests_core.sh`

**Pourquoi maintenant :** c'est la suite la plus importante (tests unitaires de `core.sh`), et elle ne dépend que de `helpers-tap.sh` et des fixtures.

**Fichiers à fournir :**
- `unit-tests.md` (spécification complète avec les 53 cas)
- `src/lib/core.sh` (code à tester)
- `src/lib/ui.sh` (nécessaire pour `die()`)
- `tests/helpers-tap.sh` (créé à l'étape 1)
- `tests/run_tests.sh` (pour le style)

**Prompt — partie 1 : structure + tests CU01–CU27 :**
```
Tu vas créer tests/run_tests_core.sh pour le projet hash_tool.

Voici la spécification des tests à implémenter : [coller unit-tests.md]

Voici le code à tester :
[coller src/lib/core.sh]
[coller src/lib/ui.sh]

Voici les helpers disponibles : [coller tests/helpers-tap.sh]

Contraintes :
- bash >= 4, set -euo pipefail, ShellCheck zéro warning
- Sourcer directement src/lib/ui.sh et src/lib/core.sh (pas passer par integrity.sh)
- Chaque test est isolé dans sa propre fonction, avec son propre WORKDIR local
- trap EXIT pour nettoyage garanti
- Format TAP (via helpers-tap.sh)

Pour cette première partie, implémente :
- La structure du fichier (shebang, setup, sourcing, teardown)
- Les tests CU01 à CU27 (core_assert_b3_valid, core_assert_target_valid, core_compute)

Je validerai cette partie avant de te demander la suite.
```

**Vérification intermédiaire :**
```bash
shellcheck tests/run_tests_core.sh
cd tests && ./run_tests_core.sh 2>&1 | head -40
```

**Prompt — partie 2 : tests CU28–CU53 :**
```
Voici la suite de tests run_tests_core.sh produite à l'étape précédente : [coller le fichier]

Continue en ajoutant les tests :
- CU28 à CU35 (core_verify)
- CU36 à CU48 (core_compare — la plus critique)
- CU49 à CU53 (core_make_result_dir)

Appends ces tests au fichier existant. Respecte le style et la structure déjà en place.
Fais particulièrement attention à CU42–CU44 : chemins avec espaces, &, et chevrons dans core_compare.
```

**Vérification finale :**
```bash
shellcheck tests/run_tests_core.sh
cd tests && ./run_tests_core.sh
# Tous les tests doivent passer
```

---

## Étape 4 — Extensions de `run_tests.sh` (T15–T20)

**Fichiers à fournir :**
- `integration-tests.md` (section "Extensions de run_tests.sh")
- `tests/run_tests.sh` (fichier existant à modifier)
- `tests/helpers-tap.sh`

**Prompt :**
```
Tu vas modifier tests/run_tests.sh pour y ajouter les cas T15 à T20.

Voici la spécification des nouveaux cas : [coller la section "Extensions de run_tests.sh" de integration-tests.md]

Voici le fichier actuel à modifier : [coller run_tests.sh]

Contraintes :
- Ne pas modifier les cas existants T00–T14
- Ajouter T15–T20 après T14, avant le bloc de résultats final
- Migrer les helpers pass()/fail() vers helpers-tap.sh en ajoutant : source "$(dirname "$0")/helpers-tap.sh"
- ShellCheck zéro warning
- T16 (HTML escaping) : les assertions doivent vérifier &lt; et &gt; dans report.html, pas <script>

Produis le fichier run_tests.sh complet modifié.
```

**Vérification :**
```bash
shellcheck tests/run_tests.sh
cd tests && ./run_tests.sh
```

---

## Étape 5 — Extensions de `run_tests_pipeline.sh` (TP13–TP15)

**Même approche que l'étape 4.**

**Fichiers à fournir :**
- `integration-tests.md` (section "Extensions de run_tests_pipeline.sh")
- `tests/run_tests_pipeline.sh` (fichier existant)
- `tests/helpers-tap.sh`

**Prompt :**
```
Tu vas modifier tests/run_tests_pipeline.sh pour y ajouter les cas TP13 à TP15.

Voici la spécification : [coller la section "Extensions de run_tests_pipeline.sh" de integration-tests.md]

Voici le fichier actuel : [coller run_tests_pipeline.sh]

Contraintes :
- Ne pas modifier les cas existants TP01–TP12b
- Ajouter TP13–TP15 après TP12b
- Migrer vers helpers-tap.sh
- ShellCheck zéro warning
- TP13 : créer explicitement un dossier source corrompu distinct du dossier source propre

Produis le fichier run_tests_pipeline.sh complet modifié.
```

---

## Étape 6 — Test de non-régression dans `run_tests.sh`

**Ce test dépend de `reference.b3` généré à l'étape 2.**

**Fichiers à fournir :**
- `regression-tests.md`
- `tests/run_tests.sh` (version modifiée à l'étape 4)

**Prompt :**
```
Tu vas ajouter un test de non-régression dans tests/run_tests.sh.

Voici la spécification : [coller regression-tests.md]

Voici le fichier actuel : [coller run_tests.sh modifié]

Ajoute une section "T_REG — Non-régression format .b3" avec les tests T_REG01 à T_REG06 
tels que spécifiés. 

Le test T_REG01 doit :
- Vérifier que tests/fixtures/bases/reference.b3 existe (SKIP sinon avec tap_skip)
- Lancer compute sur tests/fixtures/data/
- Faire un diff bit-à-bit avec reference.b3
- En cas d'échec, afficher le diff (limité à 20 lignes) pour faciliter le diagnostic

Produis le fichier run_tests.sh complet final.
```

---

## Étape 7 — `tests/run_tests_docker.sh`

**Cette suite est indépendante — pas de dépendance aux autres suites bash.**

**Fichiers à fournir :**
- `docker-tests.md`
- `docker/entrypoint.sh`
- `tests/helpers-tap.sh`

**Prompt :**
```
Tu vas créer tests/run_tests_docker.sh pour le projet hash_tool.

Voici la spécification complète : [coller docker-tests.md]

Voici l'entrypoint à tester : [coller docker/entrypoint.sh]

Voici les helpers disponibles : [coller helpers-tap.sh]

Contraintes :
- bash >= 4, set -euo pipefail, ShellCheck zéro warning
- Skip automatique si Docker n'est pas disponible (command -v docker)
- Skip automatique si l'image hash_tool n'est pas buildée (sauf avec --build)
- Chaque test TD* crée ses propres tmpdir avec mktemp -d et les nettoie via trap EXIT
- Les tests TB* (build) sont dans une section séparée et ne tournent que si --build est passé
- Format TAP via helpers-tap.sh

Implémente tous les tests TB01–TB04, TE01–TE07, TD01–TD11.
```

**Vérification :**
```bash
shellcheck tests/run_tests_docker.sh
docker build -t hash_tool .
cd tests && ./run_tests_docker.sh --build
```

---

## Étape 8 — `.github/workflows/ci.yml`

**Dernière étape — la CI référence tous les fichiers créés précédemment.**

**Fichiers à fournir :**
- `ci-cd.md`
- La liste des fichiers de tests existants (pour vérifier les chemins)

**Prompt :**
```
Tu vas créer .github/workflows/ci.yml pour le projet hash_tool.

Voici la spécification complète : [coller ci-cd.md]

Les fichiers de tests qui existent maintenant :
- tests/helpers-tap.sh
- tests/run_tests.sh
- tests/run_tests_pipeline.sh
- tests/run_tests_core.sh
- tests/run_tests_docker.sh
- tests/fixtures/bases/reference.b3

Contraintes :
- Jobs lint, unit, integration, pipeline, non-regression en parallèle (needs: lint uniquement)
- Job docker-build conditionnel (main, develop, ou PR modifiant Dockerfile/.dockerignore/docker/)
- Job docker-arm64 avec continue-on-error: true, uniquement sur main
- Matrice ubuntu-22.04 + ubuntu-24.04 pour unit et integration
- concurrency avec cancel-in-progress pour éviter les runs redondants sur une même PR
- Upload d'artefacts TAP avec if: always() sur chaque job
- Pas de secrets requis

Produis le fichier .github/workflows/ci.yml complet.
```

**Vérification :**
```bash
# Installer actionlint si disponible
actionlint .github/workflows/ci.yml

# Ou vérifier manuellement la syntaxe YAML
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo "YAML valide"
```

---

## Récapitulatif de la démarche

| Étape | Livrable | Dépend de | Vérification |
|---|---|---|---|
| 1 | `helpers-tap.sh` | — | `shellcheck` + sourcing |
| 2 | `tests/fixtures/` | — | génération manuelle de `reference.b3` |
| 3a | `run_tests_core.sh` CU01–CU27 | 1, 2 | `shellcheck` + run partiel |
| 3b | `run_tests_core.sh` CU28–CU53 | 3a | run complet, 0 FAIL |
| 4 | `run_tests.sh` T15–T20 | 1 | `shellcheck` + run complet |
| 5 | `run_tests_pipeline.sh` TP13–TP15 | 1 | `shellcheck` + run complet |
| 6 | Non-régression dans `run_tests.sh` | 2, 4 | run complet, T_REG01 pass |
| 7 | `run_tests_docker.sh` | 1, image Docker | `shellcheck` + run avec `--build` |
| 8 | `ci.yml` | 1–7 tous présents | `actionlint` ou YAML lint |

**Règle absolue :** ne passer à l'étape N+1 que si l'étape N passe ShellCheck et produit zéro FAIL. Un test qui échoue dès la création est soit mal implémenté, soit révèle un bug réel dans le code — dans les deux cas, à traiter avant de continuer.