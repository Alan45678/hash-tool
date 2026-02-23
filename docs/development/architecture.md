# Architecture

Décisions techniques, choix d'implémentation et rationale.

---

## Vue d'ensemble

hash_tool est composé de trois couches :

```
runner.sh               ← orchestration pipeline
    └── src/integrity.sh        ← logique métier (compute / verify / compare)
            └── src/lib/report.sh   ← génération des rapports HTML
```

Chaque couche a une responsabilité unique et des dépendances strictement unidirectionnelles.

---

## Choix algorithmique — BLAKE3 vs alternatives

### Pourquoi BLAKE3 et non xxHash3

xxHash3 est techniquement suffisant pour détecter des erreurs accidentelles — pas d'adversaire dans ce cas d'usage. BLAKE3 est retenu pour une seule raison : **coût marginal nul**. Sur HDD (150 Mo/s) ou SATA SSD (500 Mo/s), le disque est systématiquement le goulot. BLAKE3 à ~1 Go/s (1 cœur) ne sera jamais le facteur limitant. Le headroom cryptographique est gratuit.

Si le besoin évolue vers un contexte avec adversaire (signature, authentification), BLAKE3 reste utilisable sans changer de workflow ni de format de base.

### Pourquoi ne pas utiliser SHA-256 ou SHA-512

- BLAKE3 est ~3–5× plus rapide que SHA-256 sur les mêmes données
- Format de sortie `b3sum` identique à `sha256sum` — interopérabilité outil/format conservée
- Pas de dépendance supplémentaire : `b3sum` est disponible dans Alpine, Debian, Ubuntu, Homebrew

---

## Format du fichier `.b3`

Le format est directement celui produit par `b3sum` :

```
<hash_64_chars>  <chemin>
```

Deux espaces — convention `b3sum`/`sha256sum`. Ce choix délibéré permet :

- **Interopérabilité directe** : `b3sum --check base.b3` fonctionne sans aucun post-traitement
- **Lisibilité humaine** : `grep`, `awk`, `sort` opèrent directement sur le fichier
- **Zéro format propriétaire** : pas de serialisation, pas de parser dédié

L'offset fixe du hash (64 chars + 2 espaces = position 67) est exploité dans `run_compare()` pour parser les lignes sans ambiguïté même avec des chemins contenant des espaces :

```bash
awk '{ print substr($0,67) "\t" substr($0,1,64) }' base.b3
```

---

## Chemins relatifs — décision fondamentale

Les bases `.b3` stockent des **chemins relatifs**. C'est une contrainte non négociable :

- Un chemin absolu `/mnt/veracrypt1/photos/img.jpg` devient invalide si la partition est remontée sur `/mnt/veracrypt2/` ou un point de montage différent
- Un chemin relatif `./photos/img.jpg` reste valide quel que soit le point de montage, dès lors qu'on lance `verify` depuis le bon répertoire de travail

`runner.sh` encapsule cette contrainte via `cd "$source"` + `integrity.sh compute . ...` — l'utilisateur n'a pas à y penser.

---

## Gestion du répertoire de travail dans runner.sh

Chaque opération `compute` et `verify` est exécutée dans un sous-shell :

```bash
( cd "$source" && "$INTEGRITY" compute . "$bases_abs/$nom" )
```

Le `cd` est isolé dans `( )` — il ne fuite pas vers les blocs suivants du pipeline. Sans cette isolation, un `cd` dans un bloc `compute` affecterait le répertoire de travail de tous les blocs suivants.

De même pour `RESULTATS_DIR` sur les blocs `compare` avec champ `resultats` :

```bash
RESULTATS_DIR="$resultats_abs" "$INTEGRITY" compare "$base_a" "$base_b"
```

`RESULTATS_DIR` est passé comme variable d'environnement préfixée à la commande — scope limité à cet appel, sans `export`, sans modification du processus parent.

---

## Robustesse aux noms de fichiers avec espaces

Trois points critiques :

**1. `find -print0` + `sort -z` + `mapfile -d ''`**

```bash
mapfile -d '' files < <(find "$target" -type f -print0 | sort -z)
```

`find -print0` sépare les chemins par des octets nuls (pas des newlines). `sort -z` trie sur le même séparateur. `mapfile -d ''` charge le tableau avec le même séparateur. Aucune confusion possible avec des espaces ou des newlines dans les noms.

**2. Séparateur tab dans `run_compare()`**

Après conversion `hash  chemin` → `chemin\thash`, toutes les opérations (`sort`, `join`, `comm`, `cut`) utilisent `-t $'\t'`. Un chemin contenant des espaces ne fragmente pas les champs.

**3. `"$@"` et guillemets systématiques**

Tous les arguments sont propagés entre guillemets doubles. `shellcheck` enforce ce point (T00 dans la suite de tests).

---

## Progression ETA — pourquoi casser le pipeline xargs

Le pipeline naturel `find | sort | xargs b3sum` est une boîte noire : `b3sum` ne remonte aucune progression.

Intercaler `pv` est invalide : mesurer le débit sur le flux concaténé `cat | pv | b3sum` produit un hash unique du flux, pas une ligne par fichier — le `.b3` résultant est inutilisable pour `--check`.

La boucle bash fichier par fichier est la seule approche compatible. Le coût en performance est nul sur HDD (disque = goulot). Sur SSD NVMe avec `-P 4`, la parallélisation `xargs` offrirait +20–40% — mais l'ETA est incompatible avec le parallélisme sans complexité majeure.

La progression est écrite sur `/dev/tty` directement :

```bash
printf "\r[%d/%d] ETA : %dm %02ds   " ... > /dev/tty
```

`/dev/tty` est le terminal courant, indépendamment des redirections. Cela garantit que la progression n'est **jamais** capturée dans le fichier `.b3` ni dans un pipe parent.

---

## Rapport HTML — CSS inline

`report.html` est autonome : tout le CSS est inline, aucune dépendance externe. Raison : le rapport doit être lisible hors ligne, sur un NAS sans accès internet, dans un gestionnaire de fichiers local. Un CDN externe (`fonts.googleapis.com`, etc.) serait inaccessible dans ces contextes.

L'import Google Fonts dans le CSS est donc purement décoratif — le fallback `system-ui, sans-serif` et `monospace` fonctionne parfaitement sans réseau.

---

## Horodatage anti-écrasement

`make_result_dir()` vérifie l'existence du dossier cible et ajoute un suffixe `_YYYYMMDD-HHMMSS` en cas de collision :

```bash
if [ -d "$outdir" ]; then
    outdir="${outdir}_$(date +%Y%m%d-%H%M%S)"
fi
```

Aucun résultat n'est jamais écrasé silencieusement. Cette décision est volontairement conservative : conserver l'historique complet des vérifications a plus de valeur que d'économiser de l'espace disque.

---

## Structure src/ vs racine

La séparation `src/integrity.sh` + `src/lib/report.sh` vs `runner.sh` à la racine suit une convention explicite :

- **`runner.sh` à la racine** : point d'entrée utilisateur, documentation visible, lancement direct
- **`src/`** : code interne, pas destiné à être appelé directement par l'utilisateur dans le cas général
- **`src/lib/`** : modules internes, sourcés par `integrity.sh`, préparent l'extension future (`notify.sh`, `export.sh`)

---

## Validation JSON dans runner.sh

```bash
jq empty "$CONFIG" 2>/dev/null || { echo "ERREUR : JSON invalide : $CONFIG" >&2; exit 1; }
```

`jq empty` parse le JSON sans produire de sortie — uniquement un exit code. L'erreur de `jq` est redirigée vers `/dev/null` ; le message d'erreur est celui de `runner.sh`, pas une stacktrace `jq` brute. Ce pattern évite d'exposer les détails internes de `jq` à l'utilisateur.

---

## Dépendances externes — décisions

| Outil | Alternatif envisagé | Raison du choix |
|---|---|---|
| `b3sum` | `sha256sum`, `xxhash` | BLAKE3, performance, format compatible |
| `jq` | parser bash custom | Validation JSON native, robustesse, maintenabilité |
| Alpine 3.19 (Docker) | Ubuntu, Debian slim | ~14 Mo vs ~80 Mo, `b3sum` disponible dans community |
| `bash >= 4` | `sh`, `dash` | `mapfile`, tableaux associatifs, `BASH_VERSINFO` |
