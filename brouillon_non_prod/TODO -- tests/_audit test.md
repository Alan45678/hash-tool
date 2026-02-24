## Analyse de la situation actuelle

La suite actuelle (`run_tests.sh` T00-T14, `run_tests_pipeline.sh` TP01-TP12b) est une suite d'**intégration fonctionnelle** bash-pur. Les tests sont bien structurés mais présentent des lacunes structurelles significatives.

---

## Diagnostic des lacunes

**Ce qui manque par couche :**

**1. Tests unitaires de `core.sh`** — inexistants. Les fonctions `core_compute`, `core_verify`, `core_compare`, `core_assert_b3_valid` sont testées uniquement via le pipeline complet `integrity.sh`. Un bug dans `core_compare` est difficile à isoler.

**2. Couverture des cas limites absente :**
- Fichiers de taille 0 dans `compute` (comportement ETA sur `fsize == 0`)
- Base `.b3` avec chemins mixtes relatifs/absolus — `core_assert_b3_valid` ne le détecte pas
- Dossier source avec des milliers de fichiers (performances, comptage ETA)
- Liens symboliques — comportement non documenté, non testé
- Noms de fichiers avec newlines — `mapfile -d ''` devrait tenir mais aucun test
- Fichiers binaires larges — ETA réaliste ?

**3. Tests de régression sur le format `.b3`** — aucun test ne vérifie que le format produit par `core_compute` est **bit-à-bit compatible** avec un `b3sum` direct (T11 le fait partiellement mais pas sur les cas limites).

**4. Tests de l'output HTML** — `report.html` est vérifié uniquement par présence de fichier et présence d'un pattern. Pas de validation de structure HTML, pas de test sur l'échappement (`html_escape`), pas de test sur des chemins avec `<`, `>`, `&`.

**5. Absence totale de CI** — les tests ne tournent que localement, aucune garantie sur les PRs.

**6. Pas de test de performance / régression de temps** — aucun seuil.

**7. Pas de test de `--quiet` sur `compare`** — T12 couvre `verify` et `compute` mais pas `compare`.

**8. `entrypoint.sh` non testé** — la couche Docker est entièrement aveugle.

---

## Recommandations structurées

### Niveau 1 — Tests unitaires `core.sh` (priorité haute)

Créer `tests/run_tests_core.sh` — teste chaque fonction de `core.sh` en isolation, en sourçant directement `core.sh` sans passer par `integrity.sh`.

```bash
# Pattern : source les modules directement
QUIET=0
source "$SCRIPT_DIR/../src/lib/ui.sh"
source "$SCRIPT_DIR/../src/lib/core.sh"

# Test core_assert_b3_valid
test_assert_b3_valid_fichier_absent() {
    core_assert_b3_valid "/tmp/inexistant.b3" 2>/dev/null && fail "doit exit 1" || pass "fichier absent → exit 1"
}

test_assert_b3_valid_ligne_invalide() {
    echo "ligne_sans_format" > /tmp/bad.b3
    core_assert_b3_valid /tmp/bad.b3 2>/dev/null && fail "doit exit 1" || pass "format invalide → exit 1"
}

# Test core_compare isolation
test_compare_chemins_avec_esperluette() {
    echo "aaa...64chars...  ./a&b.txt" > "$old"
    echo "bbb...64chars...  ./a&b.txt" > "$new"
    core_compare "$old" "$new" "$outdir"
    assert_contains "chemin avec & dans modifies" "a&b.txt" "$(cat $outdir/modifies.b3)"
}
```

Cas critiques à couvrir :
- `core_assert_b3_valid` : fichier absent, dossier, vide, format invalide, lignes mixtes valides/invalides
- `core_compare` : chemins avec espaces, `&`, `<`, `>`, fichiers identiques, tous modifiés, tous disparus, tous nouveaux
- `core_make_result_dir` : collision de noms, permissions insuffisantes
- `core_compute` : dossier vide (doit lever une erreur via `core_assert_target_valid`), fichier de taille 0, lien symbolique

### Niveau 2 — Cas limites manquants dans les suites existantes

Ajouter dans `run_tests.sh` :

- **T15** : fichier avec newline dans le nom (`$'nom\nfichier.txt'`) — `mapfile -d ''` doit tenir
- **T16** : fichier avec caractères HTML (`<script>.txt`, `a&b.txt`) — vérifier l'échappement dans `report.html`
- **T17** : `compare` sans différence → `report.html` affiche "IDENTIQUES"
- **T18** : `--quiet` sur `compare` — stdout vide, fichiers produits
- **T19** : lien symbolique dans le dossier source — comportement documenté (ignoré ou suivi ?)
- **T20** : `verify` avec `[dossier]` inexistant → exit 1 (T14 couvre déjà mais pas exactement ce cas)

### Niveau 3 — Tests de non-régression du format `.b3`

Fixture figée : créer `tests/fixtures/reference.b3` contenant les hashes attendus pour `tests/fixtures/data/`. À chaque run, `core_compute` doit produire un fichier identique octet par octet. Détecte toute régression dans le format de sortie, le tri, les séparateurs.

```bash
test_compute_stable() {
    bash "$INTEGRITY" compute ./fixtures/data /tmp/output.b3
    diff tests/fixtures/reference.b3 /tmp/output.b3 || fail "régression format .b3"
    pass "format .b3 stable"
}
```

### Niveau 4 — CI GitHub Actions

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]

jobs:
  tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: sudo apt-get install -y b3sum jq shellcheck
      - run: cd tests && ./run_tests.sh
      - run: cd tests && ./run_tests_pipeline.sh
      - run: cd tests && ./run_tests_core.sh          # nouveau
      - run: shellcheck src/integrity.sh runner.sh src/lib/*.sh docker/entrypoint.sh
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: /tmp/integrity-test*/

  docker:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t hash_tool .
      - run: docker run --rm hash_tool version
      - run: |
          docker run --rm \
            -v /tmp/testdata:/data:ro \
            -v /tmp/testbases:/bases \
            hash_tool compute /data /bases/test.b3
```

Ajouter une matrice pour tester sur Ubuntu 22.04 et 24.04 (versions différentes de `b3sum`, `bash`, `awk`).

### Niveau 5 — Rapport de test structuré

Modifier `run_tests.sh` pour produire un rapport TAP (Test Anything Protocol) — format standard, consommable par n'importe quel CI :

```bash
echo "TAP version 14"
echo "1..$TOTAL"
pass() { echo "ok $TOTAL - $1"; }
fail() { echo "not ok $TOTAL - $1"; }
```

Ou JSON minimal pour intégration dashboard :

```bash
# En fin de suite
cat > /tmp/test-report.json <<JSON
{
  "suite": "run_tests.sh",
  "timestamp": "$(date -Iseconds)",
  "total": $TOTAL,
  "passed": $PASS,
  "failed": $FAIL
}
JSON
```

---

## Priorisation

| Priorité | Action | Impact | Effort |
|---|---|---|---|
| 1 | CI GitHub Actions (minimal) | Détection régression sur PR | ~2h |
| 2 | `run_tests_core.sh` — tests unitaires | Isolation des bugs | ~4h |
| 3 | Fixtures de non-régression format `.b3` | Détection silencieuse | ~1h |
| 4 | Cas limites HTML escaping (T16) | Bug latent confirmé | ~1h |
| 5 | T15 newlines, T18 `--quiet compare` | Couverture lacunaire | ~1h |
| 6 | Tests `entrypoint.sh` Docker | Couverture Docker nulle | ~3h |
| 7 | Rapport TAP / JSON | Intégration dashboard | ~1h |

Le delta le plus impactant à court terme : **CI + tests unitaires `core.sh`**. La suite actuelle fonctionne mais ne détecte les régressions que si quelqu'un pense à lancer les tests manuellement.