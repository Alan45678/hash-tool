# Tests de non-régression — Format `.b3` et fixtures statiques

---

## Principe

Un test de non-régression capture un comportement connu et correct, le fige comme référence, puis vérifie à chaque modification que ce comportement est inchangé.

Pour `hash_tool`, le comportement le plus critique à figer est le **format du fichier `.b3`** produit par `core_compute`. Toute modification — même accidentelle — du format de sortie invalide toutes les bases existantes des utilisateurs.

---

## Risques couverts

| Modification silencieuse | Impact utilisateur |
|---|---|
| Changement du séparateur (1 espace au lieu de 2) | Toutes les bases existantes invalides pour `b3sum --check` |
| Changement de l'ordre de tri (locale différente) | `compare` produit des faux positifs massifs |
| Ajout d'un préfixe ou suffixe dans les chemins | `verify` échoue sur toutes les bases existantes |
| Ligne vide en fin de fichier | `core_assert_b3_valid` rejette les bases existantes |
| Retour chariot `\r` introduit | `b3sum --check` échoue sur certains OS |
| Mise à jour de `b3sum` changeant le format de sortie | Rupture totale de compatibilité |

---

## Structure des fixtures

```
tests/fixtures/
├── data/
│   ├── alpha.txt          ← "contenu alpha\n"
│   ├── beta.txt           ← "contenu beta\n"
│   ├── gamma.txt          ← "contenu gamma\n"
│   └── sub/
│       └── delta.txt      ← "contenu delta\n"
└── reference.b3           ← produit par core_compute sur ./data, commité dans git
```

Le contenu de chaque fichier est **figé et documenté**. Ne jamais modifier les fichiers dans `tests/fixtures/data/` sans régénérer `reference.b3` et expliquer le changement dans la PR.

---

## Génération initiale de `reference.b3`

À faire une seule fois, sur une machine avec `b3sum` installé :

```bash
cd tests/fixtures

# Créer les fichiers de données
mkdir -p data/sub
printf "contenu alpha\n" > data/alpha.txt
printf "contenu beta\n"  > data/beta.txt
printf "contenu gamma\n" > data/gamma.txt
printf "contenu delta\n" > data/sub/delta.txt

# Générer la référence via core_compute
# (utiliser integrity.sh pour garantir le même chemin de code)
../../src/integrity.sh compute ./data reference.b3

# Vérifier le contenu
cat reference.b3
# Attendu : 4 lignes, chemins commençant par ./data/, triées, format b3sum

# Commiter
git add data/ reference.b3
git commit -m "test(fixtures): add reference.b3 for format regression tests"
```

---

## Test de non-régression — implémentation

Ce test est à ajouter dans `run_tests.sh` comme cas **T_REG01** (ou dans une section dédiée) :

```bash
echo "T_REG - Non-régression format .b3"

FIXTURES_DIR="$SCRIPT_DIR/fixtures"

# Vérifier que les fixtures existent
[ -d "$FIXTURES_DIR/data" ] || { echo "SKIP - fixtures absentes"; return; }
[ -f "$FIXTURES_DIR/reference.b3" ] || { echo "SKIP - reference.b3 absent"; return; }

# Compute sur les fixtures
( cd "$FIXTURES_DIR" && bash "$INTEGRITY" compute ./data "$WORKDIR/output_reg.b3" >/dev/null 2>&1 )

# Comparaison bit-à-bit
if diff "$FIXTURES_DIR/reference.b3" "$WORKDIR/output_reg.b3" >/dev/null 2>&1; then
    pass "T_REG01 format .b3 stable"
else
    fail "T_REG01 régression du format .b3 détectée"
    echo "  Diff :"
    diff "$FIXTURES_DIR/reference.b3" "$WORKDIR/output_reg.b3" | head -20
fi
```

---

## Contenu attendu de `reference.b3`

Exemple de contenu attendu (les hashes réels dépendent du contenu exact des fichiers) :

```
<hash_alpha_64chars>  ./data/alpha.txt
<hash_delta_64chars>  ./data/sub/delta.txt
<hash_beta_64chars>   ./data/beta.txt
<hash_gamma_64chars>  ./data/gamma.txt
```

**Invariants vérifiables sans connaître les hashes :**
- 4 lignes exactement
- Chaque ligne : 64 chars hex + `  ` (2 espaces) + chemin
- Chemins triés lexicographiquement (`alpha` < `sub/delta` car `a` < `s`)
- Pas de ligne vide
- Pas de `\r` (format Unix)
- Tous les chemins commencent par `./data/`

Ces invariants peuvent être testés indépendamment du contenu des hashes :

```bash
# Test des invariants structurels (sans dépendre de reference.b3)
local b3="$WORKDIR/output_reg.b3"

# Nombre de lignes
assert_line_count "T_REG02 4 fichiers indexés" 4 "$b3"

# Format de chaque ligne
local invalid_lines
invalid_lines=$(grep -cvE '^[0-9a-f]{64}  .+' "$b3" || true)
[ "$invalid_lines" -eq 0 ] && pass "T_REG03 format b3sum valide" || fail "T_REG03 $invalid_lines ligne(s) invalide(s)"

# Pas de retour chariot
assert_not_contains "T_REG04 pas de CRLF" $'\r' "$(cat "$b3")"

# Chemins relatifs
assert_not_contains "T_REG05 pas de chemin absolu" "$(pwd)" "$(cat "$b3")"

# Tri correct
local sorted_check
sorted_check=$(sort "$b3")
[ "$(cat "$b3")" = "$sorted_check" ] && pass "T_REG06 trié" || fail "T_REG06 non trié"
```

---

## Procédure de mise à jour de `reference.b3`

Quand une modification intentionnelle du comportement change le format de sortie :

### Étape 1 — Vérifier que le changement est délibéré

Le test `T_REG01` échoue. Avant toute mise à jour, répondre aux questions :
- Pourquoi le format a-t-il changé ?
- Est-ce documenté dans `CHANGELOG.md` ?
- Les bases `.b3` existantes des utilisateurs sont-elles impactées ?
- Faut-il fournir un outil de migration ?

### Étape 2 — Régénérer

```bash
cd tests/fixtures
../../src/integrity.sh compute ./data reference.b3
```

### Étape 3 — Valider manuellement

```bash
# Vérifier que le nouveau reference.b3 respecte les invariants
wc -l reference.b3                                  # doit afficher 4
grep -cE '^[0-9a-f]{64}  .+' reference.b3          # doit afficher 4
grep -c $'\r' reference.b3 || true                  # doit afficher 0
```

### Étape 4 — Commiter avec un message explicite

```bash
git add reference.b3
git commit -m "fix(fixtures): update reference.b3 — [raison du changement]"
```

### Étape 5 — Le diff dans la PR est un signal de revue obligatoire

Tout reviewer doit inspecter le diff de `reference.b3`. Un diff non expliqué dans le message de commit est un signal d'alerte.

---

## Fixtures supplémentaires pour les tests de régression HTML

Le rapport `report.html` est aussi sujet à régression. Une fixture statique peut capturer la structure HTML attendue :

```
tests/fixtures/
└── reports/
    └── reference_compare_empty.html    ← rapport quand modifies/disparus/nouveaux sont tous vides
    └── reference_compare_diff.html     ← rapport avec 1 modifié, 1 disparu, 1 nouveau
```

Ces fixtures sont plus difficiles à maintenir (le CSS change, la date change). La solution est de comparer uniquement les **parties structurelles** :

```bash
# Extraire et comparer uniquement le statut et les compteurs, pas le CSS ni la date
grep -E '(status-badge|stat-value|section-count)' report.html > /tmp/report_structure.txt
diff tests/fixtures/reports/reference_structure.txt /tmp/report_structure.txt
```
