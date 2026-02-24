# Stratégie de test — Décisions et objectifs

---

## Contexte

`hash_tool` est un outil de vérification d'intégrité. Une erreur non détectée dans sa logique de comparaison ou de vérification peut conduire à un faux négatif : une corruption de données passant inaperçue. Le niveau d'exigence sur la fiabilité du code est donc élevé, même si l'outil n'opère pas dans un contexte adversarial.

---

## Objectifs de couverture

### Par module

| Module | Type de test requis | Couverture cible |
|---|---|---|
| `src/lib/core.sh` | Unitaire | 100% des fonctions publiques, toutes les branches |
| `src/lib/ui.sh` | Intégration (via integrity.sh) | Chemins nominaux + mode `--quiet` |
| `src/lib/results.sh` | Intégration (via integrity.sh) | Fichiers produits, contenu, cas absent |
| `src/lib/report.sh` | Intégration + edge cases HTML | Échappement, cas vide, cas plein |
| `src/integrity.sh` | Intégration | T00–T20+, tous les modes |
| `runner.sh` | Intégration | TP01–TP12b+, tous les champs JSON |
| `docker/entrypoint.sh` | Environnement | Toutes les commandes, cas d'erreur |
| `Dockerfile` | Build | amd64, arm64, taille image |

### Par type de test

| Type | Suite | Objectif |
|---|---|---|
| Unitaire | `run_tests_core.sh` | Localiser précisément l'origine d'un bug |
| Intégration | `run_tests.sh`, `run_tests_pipeline.sh` | Valider les interfaces entre modules |
| Non-régression | fixture `reference.b3` + diff | Détecter les régressions silencieuses de format |
| Edge cases | T15–T20+ dans `run_tests.sh` | Garantir la robustesse sur les entrées limites |
| Environnement | `run_tests_docker.sh` | Valider l'image Docker et l'entrypoint |

---

## Définition de "done" pour un test

Un test est considéré complet quand :

1. **Il a un nom explicite** décrivant la condition testée et le résultat attendu.  
   Exemple : `test_compare_chemins_avec_esperluette_dans_modifies_b3`

2. **Il est isolé** : il ne dépend d'aucun autre test, d'aucun fichier extérieur au `WORKDIR`, d'aucune variable globale non initialisée localement.

3. **Il est reproductible** : relancé 10 fois dans 10 environnements différents, il donne le même résultat.

4. **Il documente l'oracle** : le commentaire ou le nom du test indique ce qui est vérifié et pourquoi c'est le bon résultat attendu.

5. **Il nettoie après lui** : tout fichier temporaire créé est supprimé, même en cas d'échec (via `trap EXIT`).

6. **Il passe ShellCheck** sans warning.

---

## Politique ShellCheck

ShellCheck zéro warning est une condition bloquante. Aucune PR ne peut merger si ShellCheck produit un warning sur les fichiers suivants :

```
src/integrity.sh
runner.sh
src/lib/core.sh
src/lib/ui.sh
src/lib/results.sh
src/lib/report.sh
docker/entrypoint.sh
tests/run_tests.sh
tests/run_tests_pipeline.sh
tests/run_tests_core.sh        ← nouveau
tests/run_tests_docker.sh      ← nouveau
```

Commande de vérification :
```bash
shellcheck src/integrity.sh runner.sh src/lib/*.sh docker/entrypoint.sh tests/*.sh
```

---

## Règles d'écriture des tests

### Isolation

```bash
# ✓ Correct : WORKDIR isolé par test ou par suite
local WORKDIR
WORKDIR=$(mktemp -d /tmp/integrity-test.XXXXXX)
trap "rm -rf '$WORKDIR'" EXIT
```

```bash
# ✓ Correct : cd isolé dans un sous-shell
( cd "$WORKDIR" && bash "$INTEGRITY" compute . base.b3 )
```

```bash
# ❌ Interdit : cd sans sous-shell
cd "$WORKDIR"
bash "$INTEGRITY" compute . base.b3
# Le répertoire courant fuit vers les tests suivants
```

### Variables d'environnement

```bash
# ✓ Correct : RESULTATS_DIR local à la suite
export RESULTATS_DIR="$WORKDIR/resultats"

# ❌ Interdit : RESULTATS_DIR global non réinitialisé entre les suites
```

### Assertions

Toute assertion doit produire un message explicite en cas d'échec :

```bash
# ✓ Correct
assert_contains "modifies.b3 contient beta.txt" "beta.txt" "$(cat modifies.b3)"

# ❌ Insuffisant
[ -s modifies.b3 ] && pass "ok" || fail "ko"
# → en cas d'échec, impossible de savoir ce qui était attendu
```

### Nettoyage garanti

```bash
# Pattern obligatoire pour tout fichier temporaire
local tmpfile
tmpfile=$(mktemp)
trap "rm -f '$tmpfile'" EXIT
# ... utilisation de tmpfile ...
# Pas besoin de rm explicite — le trap s'en charge
```

---

## Politique de mise à jour des fixtures

Quand un test de non-régression échoue suite à une modification intentionnelle du comportement :

1. Vérifier que la modification est délibérée et documentée dans `CHANGELOG.md`.
2. Regénérer la fixture : `cd tests/fixtures && ../../src/integrity.sh compute ./data reference.b3`
3. Commiter `reference.b3` avec un message explicite : `fix(fixtures): update reference.b3 after sort order change in core_compute`
4. Le diff de `reference.b3` dans la PR est un signal de revue — tout reviewer doit l'examiner.

---

## Politique de mise à jour des suites existantes

À chaque bug corrigé dans le code, un test de non-régression couvrant ce bug doit être ajouté **dans la même PR**. Référence : le changelog documente trois bugs qui auraient été détectés plus tôt avec des tests unitaires (v0.6 : `grep -c '.'`, `sort -k2` ; v0.7 : parsing `awk $2` sur chemins avec espaces).

---

## Ce qui n'est pas testé — limites acceptées

| Scénario | Raison de l'exclusion |
|---|---|
| Performances / temps d'exécution | Trop dépendant du matériel, faux positifs en CI |
| Comportement sur systèmes de fichiers exotiques (NTFS, exFAT) | Environnement CI Linux uniquement |
| Internationalisation (noms de fichiers non UTF-8) | Comportement documenté comme "octets opaques", hors scope |
| Comportement sur bash 3.x (macOS défaut) | Rejeté explicitement par `integrity.sh` au démarrage |
| Concurrence / appels parallèles | `hash_tool` est mono-processus par conception |
