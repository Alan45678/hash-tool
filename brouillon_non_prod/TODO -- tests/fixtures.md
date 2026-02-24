# Fixtures — Spécification de `tests/fixtures/`

---

## Définition

Une fixture est un ensemble de données figées dans un état connu, commitées dans le dépôt git, utilisées comme entrée reproductible pour les tests. Contrairement aux données créées dynamiquement dans `setup()`, les fixtures sont stables entre les runs et entre les machines.

---

## Arborescence cible

```
tests/fixtures/
│
├── data/                              ← jeu de données standard (4 fichiers)
│   ├── alpha.txt
│   ├── beta.txt
│   ├── gamma.txt
│   └── sub/
│       └── delta.txt
│
├── data-edge/                         ← jeu de données avec cas limites
│   ├── fichier avec espaces.txt
│   ├── fichier&special.txt
│   ├── <html>chars.txt
│   ├── .fichier_cache
│   └── zero_bytes.bin
│
├── bases/                             ← bases .b3 de référence
│   ├── reference.b3                   ← hash de data/ — non-régression format
│   └── reference-edge.b3             ← hash de data-edge/ — non-régression edge cases
│
└── reports/                           ← structures HTML de référence
    ├── reference-identiques.html      ← rapport compare sans différences
    └── reference-diff.html            ← rapport compare avec 1 modifié
```

---

## Contenu des fichiers de données

### `data/` — Jeu standard

Ces fichiers sont figés. Ne jamais les modifier sans régénérer `bases/reference.b3`.

**`data/alpha.txt`**
```
contenu alpha
```
(terminé par `\n`, encodage UTF-8, pas de BOM)

**`data/beta.txt`**
```
contenu beta
```

**`data/gamma.txt`**
```
contenu gamma
```

**`data/sub/delta.txt`**
```
contenu delta
```

**Propriétés du jeu standard :**
- 4 fichiers dans 2 niveaux d'arborescence
- Noms ASCII simples, pas de caractères spéciaux
- Contenu textuel court et déterministe
- Suffisant pour tester compute, verify, compare sans ambiguïté

---

### `data-edge/` — Jeu de cas limites

Ces fichiers couvrent les noms et contenus pathologiques.

**`data-edge/fichier avec espaces.txt`**
```
contenu avec espaces dans le nom
```
Utilisé par : T15 (intégration), CU42 (unitaire)

**`data-edge/fichier&special.txt`**
```
contenu avec esperluette dans le nom
```
Utilisé par : T16 (HTML escaping), CU43 (unitaire)

**`data-edge/<html>chars.txt`**
```
contenu avec chevrons dans le nom
```
Utilisé par : T16 (injection HTML dans report.html)

**`data-edge/.fichier_cache`**
```
contenu fichier cache
```
Utilisé par : vérification que `find -type f` indexe les fichiers cachés

**`data-edge/zero_bytes.bin`**
Fichier vide — 0 octet. Créé avec `touch`.

Utilisé par : T18 (ETA sur fichier vide), CU23 (unitaire)

---

### `bases/reference.b3`

Hash BLAKE3 de `data/`, produit par `core_compute` depuis `tests/fixtures/`.

**Procédure de génération :**
```bash
cd tests/fixtures
../../src/integrity.sh compute ./data bases/reference.b3
```

**Contenu attendu (hashes exacts à remplir lors de la génération initiale) :**
```
<hash_alpha>  ./data/alpha.txt
<hash_delta>  ./data/sub/delta.txt
<hash_beta>   ./data/beta.txt
<hash_gamma>  ./data/gamma.txt
```

**Invariants vérifiables sans connaître les hashes :**
- 4 lignes
- Triées lexicographiquement : `alpha` < `sub/delta` < `beta` < `gamma`

  **Attention :** l'ordre lexicographique binaire (LC_ALL=C) donne :
  `./data/alpha.txt` < `./data/beta.txt` < `./data/gamma.txt` < `./data/sub/delta.txt`
  
  Le tri est sur le chemin complet, pas juste le nom du fichier. `sub/delta` vient après `gamma` car `s` > `g`.

- Tous les chemins commencent par `./data/`
- Pas de ligne vide, pas de `\r`

---

### `bases/reference-edge.b3`

Hash BLAKE3 de `data-edge/`.

**Procédure de génération :**
```bash
cd tests/fixtures
../../src/integrity.sh compute ./data-edge bases/reference-edge.b3
```

**Usage :** test de non-régression sur les cas limites — vérifie que les noms de fichiers avec espaces, `&`, `<>` sont correctement traités et indexés.

---

### `reports/reference-identiques.html`

Rapport HTML produit par `compare` quand les deux bases sont identiques (aucune différence).

**Procédure de génération :**
```bash
cd tests/fixtures
# Comparer reference.b3 avec lui-même
RESULTATS_DIR=/tmp/fixtures-gen ../../src/integrity.sh compare bases/reference.b3 bases/reference.b3
cp /tmp/fixtures-gen/resultats_reference/report.html reports/reference-identiques.html
```

**Usage :** test de régression HTML — vérifier que le statut "IDENTIQUES" et les compteurs à zéro sont correctement rendus.

**Ce qui est comparé** (pas le fichier entier — la date change) :
```bash
grep -E '(status-badge|stat-value|IDENTIQUES|DIFFÉRENCES)' reports/reference-identiques.html
```

---

### `reports/reference-diff.html`

Rapport HTML produit quand il y a 1 fichier modifié, 1 disparu, 1 nouveau.

**Procédure de génération :**
```bash
cd tests/fixtures

# Créer une base modifiée
cp -r data/ data-modified/
echo "contenu modifié" > data-modified/beta.txt      # modifié
rm data-modified/gamma.txt                           # disparu
echo "contenu nouveau" > data-modified/epsilon.txt   # nouveau

../../src/integrity.sh compute ./data          bases/reference.b3
../../src/integrity.sh compute ./data-modified bases/reference-modified.b3

RESULTATS_DIR=/tmp/fixtures-gen ../../src/integrity.sh compare \
    bases/reference.b3 bases/reference-modified.b3
cp /tmp/fixtures-gen/resultats_reference/report.html reports/reference-diff.html

rm -rf data-modified bases/reference-modified.b3
```

**Usage :** test de régression HTML — vérifier que les listes de fichiers modifiés/disparus/nouveaux sont présentes et correctement formatées.

---

## Règles de nommage

| Règle | Raison |
|---|---|
| Noms de fichiers en minuscules, tirets comme séparateurs | Cohérence, compatibilité cross-platform |
| Pas d'espace dans les noms des fixtures **elles-mêmes** (dossiers, fichiers `.b3`, `.html`) | Les fixtures sont référencées dans les scripts — les espaces cassent les chemins non quotés |
| Les fichiers dans `data-edge/` peuvent avoir des noms avec caractères spéciaux | C'est leur raison d'être |
| Les fichiers `.b3` et `.html` de référence sont commitées dans git | Ils constituent la définition du comportement attendu |

---

## Procédure d'ajout d'une nouvelle fixture

1. **Identifier le besoin** : quel cas limite ou comportement doit être couvert ?
2. **Créer le fichier** dans le sous-dossier approprié (`data/`, `data-edge/`, ou nouveau sous-dossier).
3. **Documenter le fichier** dans ce document : contenu, usage, tests qui s'en servent.
4. **Régénérer les bases `.b3`** si le jeu de données standard ou edge est modifié.
5. **Commiter avec un message explicite** : `test(fixtures): add <nom> for <raison>`

---

## Ce qui ne doit PAS être dans les fixtures

| Type | Raison |
|---|---|
| Données personnelles | Commitées dans git, publiques |
| Fichiers binaires volumineux (> 1 Mo) | Alourdissent le repo sans valeur ajoutée |
| Fichiers `.b3` produits par des versions différentes de b3sum | Invalides sur d'autres machines |
| Résultats de tests (`recap.txt`, `failed.txt`) | Produits dynamiquement, ne doivent pas être fixés |

---

## Vérification de l'intégrité des fixtures elles-mêmes

Les fixtures peuvent être corrompues si un éditeur modifie les fins de ligne (`\r\n` au lieu de `\n`) ou l'encodage. Un meta-test peut vérifier leur intégrité :

```bash
# Vérifier que les fichiers de données sont en format Unix (pas de CRLF)
test_fixtures_unix_format() {
    local has_crlf=0
    while IFS= read -r -d '' f; do
        if file "$f" | grep -q "CRLF"; then
            fail "fixture en CRLF : $f"
            has_crlf=1
        fi
    done < <(find tests/fixtures/data -type f -print0)
    [ "$has_crlf" -eq 0 ] && pass "fixtures au format Unix"
}

# Vérifier que reference.b3 respecte le format b3sum
test_fixtures_reference_format() {
    local invalid
    invalid=$(grep -cvE '^[0-9a-f]{64}  .+' tests/fixtures/bases/reference.b3 || true)
    [ "$invalid" -eq 0 ] \
        && pass "reference.b3 format valide" \
        || fail "reference.b3 : $invalid ligne(s) invalide(s)"
}
```
