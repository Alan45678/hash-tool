# Architecture

Décisions techniques, choix d'implémentation, flux de données et rationale.

---

## Vue d'ensemble

hash_tool est organisé en quatre couches avec séparation stricte des responsabilités :

```
runner.sh                      ← orchestration pipeline (entrée utilisateur)
    └== src/integrity.sh       ← dispatcher CLI (parsing args, orchestration)
            ├== src/lib/core.sh      ← logique métier pure
            ├== src/lib/ui.sh        ← interface terminal (affichage, ETA)
            ├== src/lib/results.sh   ← écriture fichiers de résultats
            └== src/lib/report.sh    ← génération rapports HTML
```

Les dépendances sont **strictement unidirectionnelles** : `integrity.sh` orchestre les modules, les modules ne se connaissent pas entre eux.

### Rationale de la séparation

La séparation n'est pas un exercice de style. Elle résout des problèmes concrets :

- **Testabilité** : `core_compute()`, `core_verify()`, `core_compare()` peuvent être testés sans terminal, sans affichage, sans effets de bord UI.
- **Mode `--quiet`** : activé dans `ui.sh` uniquement. Le code métier n'a pas à savoir si on est en mode silencieux.
- **Réutilisabilité** : `src/lib/core.sh` peut être sourcé par un script tiers pour utiliser les fonctions métier sans l'interface CLI.
- **Maintenance** : modifier le format d'affichage de l'ETA ne touche pas à la logique de hachage, et vice versa.

---

## Flux de données

### Mode `compute`

```
integrity.sh
    │
    ├= core_assert_target_valid(target)
    │      ↓ exit 1 si invalide
    │
    ├= core_compute(target, hashfile, callback=ui_progress_callback)
    │      │
    │      ├= find -type f -print0 | sort -z → liste fichiers
    │      ├= pour chaque fichier :
    │      │       b3sum fichier >> hashfile
    │      │       callback(i, total, bytes_done, total_bytes, eta)
    │      │           └= ui_progress_callback → printf > /dev/tty
    │      └= retour : hashfile contient N lignes "<hash>  <chemin>"
    │
    ├= ui_progress_clear()     → efface ligne ETA du terminal
    └= say("Base enregistrée") → stdout
```

### Mode `verify`

```
integrity.sh
    │
    ├= core_assert_b3_valid(b3file)
    ├= résolution chemin absolu (avant cd)
    ├= cd workdir (si ARG3 fourni)
    ├= core_make_result_dir → outdir
    │
    ├= core_verify(hashfile_abs)
    │      │
    │      ├= b3sum --check hashfile → raw output
    │      ├= parsing raw → CORE_VERIFY_LINES_OK/FAIL/ERR
    │      └= positionne CORE_VERIFY_STATUS, NB_OK, NB_FAIL
    │
    ├= results_write_verify(outdir, ...) → outdir/recap.txt, outdir/failed.txt
    └= ui_show_verify_result(...)        → stdout
```

### Mode `compare`

```
integrity.sh
    │
    ├= core_assert_b3_valid(old), core_assert_b3_valid(new)
    ├= core_make_result_dir → outdir
    │
    ├= core_compare(old, new, outdir)
    │      │
    │      ├= _b3_to_path_hash(old) → tmp_old : "chemin\thash"
    │      ├= _b3_to_path_hash(new) → tmp_new : "chemin\thash"
    │      ├= join inner → modifies.b3
    │      ├= comm -23   → disparus.txt
    │      ├= comm -13   → nouveaux.txt
    │      └= positionne CORE_COMPARE_NB_MOD/DIS/NOU
    │
    ├= results_write_compare(outdir, ...) → outdir/recap.txt
    ├= generate_compare_html(...)         → outdir/report.html
    └= ui_show_compare_result(...)        → stdout
```

---

## Choix algorithmique - BLAKE3

### Comparaison MD5 / SHA-256 / BLAKE3

| Critère | MD5 | SHA-256 | BLAKE3 |
|---|---|---|---|
| Vitesse sur fichiers volumineux | Rapide | Lent | Très rapide (~3× SHA-256) |
| Sécurité cryptographique | Cassé | Solide | Solide |
| Parallélisation | Non | Non | Oui (SIMD, multi-thread) |
| Adapté à l'intégrité de fichiers | Oui* | Oui | Oui (référence actuelle) |

\* MD5 est suffisant pour détecter la corruption accidentelle mais ne doit plus être utilisé pour des usages sécuritaires.

### Rationale

xxHash3 est techniquement suffisant pour détecter des erreurs accidentelles - pas d'adversaire dans ce cas d'usage. BLAKE3 est retenu pour une seule raison : **coût marginal nul sur disque**. Sur HDD (150 Mo/s) ou SATA SSD (500 Mo/s), le disque est le goulot. BLAKE3 à ~1 Go/s sur un cœur n'est jamais le facteur limitant. Le headroom cryptographique est gratuit.

Si le besoin évolue vers un contexte adversarial (signature, authentification), BLAKE3 reste utilisable sans changer de workflow ni de format de base. Voir `SECURITY.md` pour le modèle de menace.

### Pourquoi ne pas SHA-256 ou SHA-512

- BLAKE3 est ~3–5× plus rapide que SHA-256 sur les mêmes données
- Format de sortie `b3sum` identique à `sha256sum` - interopérabilité conservée
- `b3sum` disponible dans Alpine, Debian, Ubuntu, Homebrew sans compilation

---

## Format du fichier `.b3`

Voir la spécification normative complète : [`docs/spec/b3-format.md`](../spec/b3-format.md).

Résumé des invariants :
- Format natif `b3sum` : `<hash64>  <chemin>` (deux espaces)
- Chemins **relatifs** obligatoires
- Trié par chemin (ordre binaire, LC_ALL=C)
- Pas de ligne vide, pas de commentaire, format Unix (LF)

### Rationale du format natif b3sum

Le format `b3sum` natif est délibérément conservé plutôt qu'un format propriétaire :

- **Interopérabilité directe** : `b3sum --check base.b3` fonctionne sans post-traitement
- **Lisibilité humaine** : `grep`, `awk`, `sort` opèrent directement
- **Zéro parser dédié** : l'offset fixe hash=64 chars + SEP=2 chars est exploité dans `core_compare()` pour parser les lignes sans ambiguïté même avec des espaces dans les chemins :
  ```bash
  awk '{ print substr($0,67) "\t" substr($0,1,64) }' base.b3
  ```

---

## Chemins relatifs - décision fondamentale

Les bases `.b3` stockent des **chemins relatifs**. C'est une contrainte non négociable.

### Rationale

Un chemin absolu `/mnt/veracrypt1/photos/img.jpg` devient invalide si la partition est remontée sur `/mnt/veracrypt2/`. Un chemin relatif `./photos/img.jpg` reste valide quel que soit le point de montage, dès lors que `verify` est lancé depuis le bon répertoire.

`runner.sh` encapsule cette contrainte via `cd "$source"` + `integrity.sh compute . ...` - l'utilisateur n'a pas à y penser.

### Impact sur `verify`

`b3sum --check` résout les chemins relatifs depuis le `pwd`. Avant tout `cd`, `integrity.sh` résout le chemin absolu du fichier `.b3` :

```bash
hashfile_abs="$(cd "$(dirname "$b3file")" && pwd)/$(basename "$b3file")"
# cd vers le répertoire de travail d'origine
cd "$workdir"
# Utilise l'absolu - le relatif serait invalide après le cd
b3sum --check "$hashfile_abs"
```

---

## Isolation des sous-shells dans `runner.sh`

Chaque opération `compute` et `verify` est exécutée dans un sous-shell :

```bash
( cd "$source" && "$INTEGRITY" compute . "$bases_abs/$nom" )
```

Le `cd` est isolé dans `( )` - il ne fuite pas vers les blocs suivants du pipeline.

Pour `RESULTATS_DIR` sur les blocs `compare` avec champ `resultats` :

```bash
RESULTATS_DIR="$resultats_abs" "$INTEGRITY" compare "$base_a" "$base_b"
```

Variable préfixée à la commande - scope limité à cet appel, sans `export`, sans modification du processus parent.

---

## Robustesse aux noms de fichiers avec espaces

Trois points critiques dans l'implémentation :

**1. `find -print0` + `sort -z` + `mapfile -d ''`**

```bash
mapfile -d '' files < <(find "$target" -type f -print0 | sort -z)
```

`find -print0` sépare les chemins par des octets nuls. `sort -z` trie sur le même séparateur. `mapfile -d ''` charge le tableau sans ambiguïté avec des espaces ou des newlines dans les noms.

**2. Séparateur tab dans `core_compare()`**

Après conversion `hash  chemin` → `chemin\thash`, toutes les opérations (`sort`, `join`, `comm`, `cut`) utilisent `-t $'\t'`. Un chemin contenant des espaces ne fragmente pas les champs.

**3. `"$@"` et guillemets systématiques**

Tous les arguments sont propagés entre guillemets doubles. ShellCheck enforce ce point (T00 dans la suite de tests).

---

## Progression ETA - pourquoi casser le pipeline `xargs`

Le pipeline naturel `find | sort | xargs b3sum` est une boîte noire : `b3sum` ne remonte aucune progression.

Intercaler `pv` est invalide : mesurer le débit sur le flux concaténé `cat | pv | b3sum` produit un hash unique du flux, pas une ligne par fichier.

La boucle bash fichier par fichier est la seule approche compatible avec le format `.b3`. Le coût en performance est nul sur HDD (disque = goulot). Sur SSD NVMe avec `-P 4`, la parallélisation `xargs` offrirait +20–40% - mais l'ETA est incompatible avec le parallélisme sans complexité majeure.

### Rationale de l'écriture sur `/dev/tty`

La progression est écrite sur `/dev/tty` directement :

```bash
printf "\r[%d/%d] ETA : %dm %02ds   " ... > /dev/tty
```

`/dev/tty` est le terminal courant, indépendamment des redirections. Garantit que la progression n'est **jamais** capturée dans le fichier `.b3` ni dans un pipe parent.

### Separation via callback

`core_compute()` reçoit un nom de fonction callback au lieu d'appeler directement `ui_progress_callback()`. Ceci permet :
- Tests unitaires de `core_compute()` avec un callback vide ou mock
- Découplage de la logique métier de la logique d'affichage

---

## Rapport HTML - CSS inline

`report.html` est autonome : tout le CSS est inline, aucune dépendance externe.

### Rationale

Le rapport doit être lisible hors ligne, sur un NAS sans accès internet, dans un gestionnaire de fichiers local. Un CDN externe (`fonts.googleapis.com`) serait inaccessible dans ces contextes.

L'import Google Fonts dans le CSS est donc purement décoratif - le fallback `system-ui, sans-serif` fonctionne parfaitement sans réseau.

---

## Horodatage anti-écrasement

`core_make_result_dir()` vérifie l'existence du dossier cible et ajoute un suffixe `_YYYYMMDD-HHMMSS` en cas de collision.

### Rationale

Conserver l'historique complet des vérifications a plus de valeur que d'économiser de l'espace disque. Un résultat écrasé silencieusement est une donnée perdue.

---

## Structure `src/` vs racine

- **`runner.sh` à la racine** : point d'entrée utilisateur, visible directement
- **`src/`** : code interne non destiné à être appelé directement dans le cas général
- **`src/lib/`** : modules internes sourcés par `integrity.sh`. La structure prépare l'extension : `notify.sh`, `export.sh`, etc.

---

## Validation JSON dans `runner.sh`

```bash
jq empty "$CONFIG" 2>/dev/null || { echo "ERREUR : JSON invalide : $CONFIG" >&2; exit 1; }
```

`jq empty` parse le JSON sans produire de sortie. L'erreur brute de `jq` est redirigée vers `/dev/null` ; le message d'erreur est celui de `runner.sh`, pas une stacktrace interne de `jq`.

---

## Dépendances externes - décisions

| Outil | Alternatif envisagé | Raison du choix |
|---|---|---|
| `b3sum` | `sha256sum`, `xxhash` | BLAKE3, performance, format compatible |
| `jq` | parser bash custom | Validation JSON native, robustesse, maintenabilité |
| Alpine 3.19 (Docker) | Ubuntu, Debian slim | ~14 Mo vs ~80 Mo, `b3sum` disponible dans community |
| `bash >= 4` | `sh`, `dash` | `mapfile`, tableaux, `BASH_VERSINFO` |
