# Tests d'intégration — Extensions des suites existantes

---

## Périmètre

Ce document spécifie les cas à ajouter aux suites d'intégration existantes :
- `run_tests.sh` : cas T15 à T20 (extensions de la suite integrity.sh)
- `run_tests_pipeline.sh` : cas TP13 à TP15 (extensions de la suite runner.sh)

Les cas existants T00–T14 et TP01–TP12b ne sont pas modifiés.

---

## Extensions de `run_tests.sh`

### T15 — Fichier avec newline dans le nom

**Motivation :** les noms de fichiers Linux peuvent légalement contenir des newlines. `find | wc -l` ou `xargs` sans `-0` cassent sur ce cas. `mapfile -d ''` et `find -print0` sont censés tenir — ce test le vérifie.

**Précondition :**
```bash
printf "contenu\n" > "$WORKDIR/data/$'nom\navec\nnewline.txt'"
bash "$INTEGRITY" compute ./data base_t15.b3
```

**Assertions :**
- `base_t15.b3` contient exactement autant de lignes que de fichiers dans `./data` (le fichier avec newline compte pour 1)
- `bash "$INTEGRITY" verify base_t15.b3` → exit 0, aucun FAILED

**Oracle :** si le test échoue, `mapfile -d ''` ou `sort -z` ne gèrent pas correctement les newlines dans les noms — le fichier est compté plusieurs fois ou ignoré.

---

### T16 — Caractères HTML dans les noms de fichiers

**Motivation :** `report.html` est généré via `generate_compare_html`. La fonction `html_escape` est censée protéger contre l'injection HTML. Ce test vérifie que les caractères `<`, `>`, `&` dans les noms de fichiers sont bien échappés dans le rapport.

**Précondition :**
```bash
echo "v1" > "$WORKDIR/data_old/<script>alert.txt"
echo "v1" > "$WORKDIR/data_old/a&b.txt"
echo "v2" > "$WORKDIR/data_new/<script>alert.txt"   # modifié
echo "v1" > "$WORKDIR/data_new/a&b.txt"             # inchangé
bash "$INTEGRITY" compute ./data_old base_t16_old.b3
bash "$INTEGRITY" compute ./data_new base_t16_new.b3
bash "$INTEGRITY" compare base_t16_old.b3 base_t16_new.b3
```

**Assertions sur `report.html` :**
- Ne contient PAS la chaîne `<script>` littérale (serait une injection)
- Contient `&lt;script&gt;` (échappement correct)
- Contient `&amp;` pour le `&` de `a&b.txt`
- Est un HTML valide (balises ouvertes = balises fermées, au minimum)

**Oracle :** si `<script>` apparaît littéralement dans le HTML, `html_escape` ne fonctionne pas et le rapport est vulnérable à l'injection.

```bash
# Assertions spécifiques
local html_content
html_content=$(cat "$outdir/report.html")
assert_not_contains "T16 pas de <script> brut"   "<script>"      "$html_content"
assert_contains     "T16 échappement lt/gt"       "&lt;script&gt;" "$html_content"
assert_contains     "T16 échappement esperluette" "&amp;"          "$html_content"
```

---

### T17 — `--quiet` sur `compare`

**Motivation :** T12 couvre `--quiet` sur `verify` et `compute` mais pas sur `compare`. Le mode `--quiet` doit aussi supprimer la sortie de `compare`.

**Précondition :**
```bash
bash "$INTEGRITY" compute ./data base_t17a.b3
echo "contenu modifié" > data/alpha.txt
bash "$INTEGRITY" compute ./data base_t17b.b3
```

**Assertions :**
- `bash "$INTEGRITY" --quiet compare base_t17a.b3 base_t17b.b3` → stdout vide
- Les fichiers de résultats sont quand même produits (`recap.txt`, `modifies.b3`, `report.html`)
- Exit code = 0 (compare ne lève pas d'erreur sur les différences)

```bash
local out_quiet
out_quiet=$(bash "$INTEGRITY" --quiet compare base_t17a.b3 base_t17b.b3 2>&1)
assert_not_contains "T17 stdout vide en quiet"      "Résultats"  "$out_quiet"
assert_not_contains "T17 stdout vide en quiet"      "modifiés"   "$out_quiet"
local outdir
outdir=$(ls -d "${RESULTATS_DIR}/resultats_base_t17a"* 2>/dev/null | tail -1)
assert_file_exists  "T17 recap.txt produit"         "${outdir}/recap.txt"
assert_file_exists  "T17 report.html produit"       "${outdir}/report.html"
```

---

### T18 — Fichier de taille zéro dans compute

**Motivation :** dans `core_compute`, la branche `if (( fsize > 0 ))` protège le calcul ETA quand `fsize == 0`. Ce test vérifie que la présence d'un fichier vide ne plante pas le calcul et que le fichier est quand même indexé.

**Précondition :**
```bash
echo "contenu" > data/normal.txt
touch data/zero.bin    # taille zéro
bash "$INTEGRITY" compute ./data base_t18.b3
```

**Assertions :**
- `base_t18.b3` contient exactement 2 lignes
- La ligne pour `zero.bin` est au format b3sum valide (hash de contenu vide)
- `bash "$INTEGRITY" verify base_t18.b3` → exit 0

**Note :** le hash BLAKE3 d'un fichier vide est déterministe et connu — il peut être utilisé comme assertion dure si nécessaire.

---

### T19 — Lien symbolique dans le dossier source

**Motivation :** le comportement de `find -type f` sur les liens symboliques dépend de la version de `find` et des flags. Par défaut, `find -type f` ne suit pas les liens symboliques — ils sont ignorés. Ce comportement doit être documenté et vérifié.

**Précondition :**
```bash
echo "contenu cible" > data/cible.txt
ln -s data/cible.txt data/lien.txt    # lien symbolique
bash "$INTEGRITY" compute ./data base_t19.b3
```

**Assertions :**
- `base_t19.b3` contient exactement 1 ligne (le lien symbolique est ignoré par `find -type f`)
- La ligne présente correspond à `cible.txt`, pas à `lien.txt`

**Si le comportement attendu change** (décision de suivre les liens) : adapter ce test et documenter la décision dans `architecture.md`.

---

### T20 — Horodatage : deux compare successifs sur la même base

**Motivation :** T13 vérifie l'anti-écrasement pour `verify`. Ce test vérifie le même comportement pour `compare`.

**Précondition :**
```bash
bash "$INTEGRITY" compute ./data base_t20.b3
bash "$INTEGRITY" compare base_t20.b3 base_t20.b3   # compare une base avec elle-même
sleep 1
bash "$INTEGRITY" compare base_t20.b3 base_t20.b3
```

**Assertions :**
- Deux dossiers distincts existent sous `$RESULTATS_DIR` : `resultats_base_t20` et `resultats_base_t20_YYYYMMDD-HHMMSS`

```bash
local nb
nb=$(ls -d "${RESULTATS_DIR}/resultats_base_t20"* 2>/dev/null | wc -l)
[ "$nb" -ge 2 ] && pass "T20 deux dossiers distincts" || fail "T20 écrasement détecté ($nb dossier(s))"
```

---

## Extensions de `run_tests_pipeline.sh`

### TP13 — Pipeline avec verify qui échoue : les blocs suivants ne s'exécutent pas

**Motivation :** `runner.sh` utilise `set -euo pipefail`. Un `verify` qui échoue doit stopper le pipeline immédiatement. Ce comportement n'est pas explicitement testé.

**Précondition :**
```json
{
    "pipeline": [
        { "op": "compute", "source": "$WORKDIR/src_a", "bases": "$WORKDIR/bases", "nom": "tp13.b3" },
        { "op": "verify",  "source": "$WORKDIR/src_a_corrupt", "base": "$WORKDIR/bases/tp13.b3" },
        { "op": "compute", "source": "$WORKDIR/src_b", "bases": "$WORKDIR/bases", "nom": "tp13_b.b3" }
    ]
}
```

Avec `src_a_corrupt` contenant un fichier modifié par rapport à la base.

**Assertions :**
- Exit code du runner ≠ 0
- `tp13_b.b3` n'existe pas (le troisième bloc ne s'est pas exécuté)

---

### TP14 — Champ `nom` avec sous-dossier dans `bases`

**Motivation :** le champ `nom` est concaténé à `bases` via `"$bases_abs/$nom"`. Si `nom` contient un `/`, le comportement doit être défini.

**Cas testé :** `"nom": "sous/hashes.b3"`

**Assertions :**
- Le dossier `$WORKDIR/bases/sous/` est créé automatiquement (via le `mkdir -p` dans `run_compute`)
- `hashes.b3` est créé dans ce sous-dossier
- OU : erreur explicite si les sous-dossiers dans `nom` ne sont pas supportés (dans ce cas, documenter la limite)

---

### TP15 — Pipeline vide (tableau pipeline avec zéro opérations)

**Motivation :** le cas `"pipeline": []` doit être rejeté proprement.

```json
{ "pipeline": [] }
```

**Assertions :**
- Exit code ≠ 0
- Message d'erreur contient "vide" ou "absent"
- Aucun effet de bord (aucun fichier créé)

---

## Tableau de synthèse

| ID | Suite | Motivation principale | Risque si absent |
|---|---|---|---|
| T15 | run_tests.sh | Newlines dans noms | Crash silencieux sur fichiers exotiques |
| T16 | run_tests.sh | Injection HTML dans report.html | Rapport corrompu ou vulnérable |
| T17 | run_tests.sh | `--quiet` sur compare | Mode silencieux partiellement cassé |
| T18 | run_tests.sh | Fichier taille zéro | Crash ETA ou fichier non indexé |
| T19 | run_tests.sh | Liens symboliques | Comportement non documenté et non garanti |
| T20 | run_tests.sh | Anti-écrasement sur compare | Résultats précédents écrasés silencieusement |
| TP13 | run_tests_pipeline.sh | Arrêt sur verify échoué | Pipeline continue après corruption détectée |
| TP14 | run_tests_pipeline.sh | `nom` avec sous-dossier | Comportement indéfini, potentiel crash |
| TP15 | run_tests_pipeline.sh | Pipeline vide | Message d'erreur absent ou cryptique |
