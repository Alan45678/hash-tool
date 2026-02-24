# Tests Docker — Spécification `run_tests_docker.sh`

---

## Périmètre

`run_tests_docker.sh` couvre trois niveaux :

1. **Build** — l'image se construit sans erreur, pour les architectures cibles
2. **Environnement** — les outils attendus sont présents dans l'image avec les bonnes versions
3. **Entrypoint** — chaque commande de `docker/entrypoint.sh` produit le résultat attendu

Cette suite est **indépendante** des autres : elle ne source aucun module bash, elle ne dépend pas de `b3sum` sur l'hôte. Elle nécessite uniquement Docker.

---

## Prérequis et skip automatique

```bash
#!/usr/bin/env bash
# run_tests_docker.sh
set -euo pipefail

# Skip si Docker n'est pas disponible
command -v docker &>/dev/null || {
    echo "SKIP - Docker non disponible sur cet hôte"
    exit 0
}

# Skip si l'image n'est pas buildée (sauf si --build passé en argument)
if [ "${1:-}" = "--build" ]; then
    echo "=== Build de l'image ==="
    docker build -t hash_tool . || { echo "ERREUR : build échoué"; exit 1; }
fi

docker image inspect hash_tool &>/dev/null || {
    echo "SKIP - image hash_tool non trouvée. Lancer avec --build ou 'docker build -t hash_tool .'"
    exit 0
}
```

---

## Tests de build (TB)

Ces tests sont séparés des tests d'entrypoint — le build est lent (~2-3 min) et ne doit pas bloquer les tests fonctionnels.

### TB01 — Build amd64 réussi

```bash
docker build --platform linux/amd64 -t hash_tool:test-amd64 .
[ $? -eq 0 ] && pass "TB01 build amd64" || fail "TB01 build amd64 échoué"
docker rmi hash_tool:test-amd64 >/dev/null 2>&1 || true
```

### TB02 — Build arm64 réussi

```bash
# Requiert Docker Buildx ou QEMU
docker build --platform linux/arm64 -t hash_tool:test-arm64 .
[ $? -eq 0 ] && pass "TB02 build arm64" || fail "TB02 build arm64 échoué"
docker rmi hash_tool:test-arm64 >/dev/null 2>&1 || true
```

**Note CI :** TB02 nécessite `docker buildx` avec `--platform linux/arm64` et l'émulation QEMU. Dans GitHub Actions, utiliser `docker/setup-qemu-action` et `docker/setup-buildx-action`.

### TB03 — Taille de l'image finale

```bash
local size
size=$(docker image inspect hash_tool --format='{{.Size}}')
local size_mb=$(( size / 1024 / 1024 ))
# Seuil : < 30 Mo (image actuelle ~14 Mo, marge pour éviter les faux positifs)
[ "$size_mb" -lt 30 ] \
    && pass "TB03 taille image OK : ${size_mb} Mo" \
    || fail "TB03 image trop lourde : ${size_mb} Mo (seuil 30 Mo)"
```

**Rationale du seuil :** l'image actuelle fait ~14 Mo. Un seuil à 30 Mo détecte une régression significative (ajout accidentel d'un package lourd) sans être trop strict.

### TB04 — Pas de données utilisateur dans l'image

```bash
# Vérifier que mon_dossier/ et les .b3 ne sont pas dans l'image (respecte .dockerignore)
local found
found=$(docker run --rm hash_tool find / -name "*.b3" -o -name "hashes_*" 2>/dev/null | grep -v "^/proc" || true)
[ -z "$found" ] \
    && pass "TB04 pas de données utilisateur dans l'image" \
    || fail "TB04 données trouvées dans l'image : $found"
```

---

## Tests d'environnement (TE)

Ces tests vérifient que les outils présents dans l'image sont les bons, aux bonnes versions.

### TE01 — `b3sum` présent et fonctionnel

```bash
local out
out=$(docker run --rm hash_tool b3sum --version 2>&1)
echo "$out" | grep -qi "b3sum" \
    && pass "TE01 b3sum présent" \
    || fail "TE01 b3sum absent ou non fonctionnel : $out"
```

### TE02 — `b3sum` produit un hash valide

```bash
local hash
hash=$(docker run --rm hash_tool bash -c 'echo "test" | b3sum')
echo "$hash" | grep -qE '^[0-9a-f]{64}' \
    && pass "TE02 b3sum produit un hash valide" \
    || fail "TE02 hash invalide : $hash"
```

### TE03 — `jq` présent et fonctionnel

```bash
local out
out=$(docker run --rm hash_tool jq --version 2>&1)
echo "$out" | grep -qi "jq" \
    && pass "TE03 jq présent" \
    || fail "TE03 jq absent : $out"
```

### TE04 — `bash` version >= 4

```bash
local version
version=$(docker run --rm hash_tool bash -c 'echo ${BASH_VERSINFO[0]}')
[ "$version" -ge 4 ] \
    && pass "TE04 bash >= 4 (version $version)" \
    || fail "TE04 bash trop ancien : $version"
```

### TE05 — Outils coreutils présents

```bash
for tool in find sort awk comm join stat du mktemp; do
    docker run --rm hash_tool command -v "$tool" >/dev/null 2>&1 \
        && pass "TE05 $tool présent" \
        || fail "TE05 $tool absent"
done
```

### TE06 — `RESULTATS_DIR` défini à `/resultats`

```bash
local val
val=$(docker run --rm hash_tool bash -c 'echo $RESULTATS_DIR')
[ "$val" = "/resultats" ] \
    && pass "TE06 RESULTATS_DIR=/resultats" \
    || fail "TE06 RESULTATS_DIR=$val (attendu /resultats)"
```

### TE07 — Scripts présents et exécutables

```bash
for f in /app/runner.sh /app/src/integrity.sh /app/src/lib/report.sh; do
    docker run --rm hash_tool test -x "$f" \
        && pass "TE07 $f exécutable" \
        || fail "TE07 $f absent ou non exécutable"
done
```

---

## Tests de l'entrypoint (TD)

### TD01 — Commande `help` : exit 0, affiche de l'aide

```bash
local out exit_code=0
out=$(docker run --rm hash_tool help 2>&1) || exit_code=$?
[ "$exit_code" -eq 0 ] && pass "TD01 help exit 0" || fail "TD01 help exit $exit_code"
echo "$out" | grep -qi "compute" && pass "TD01 help contient compute" || fail "TD01 help ne contient pas compute"
echo "$out" | grep -qi "verify"  && pass "TD01 help contient verify"  || fail "TD01 help ne contient pas verify"
```

### TD02 — Commande sans argument : affiche l'aide (CMD défaut)

```bash
local out
out=$(docker run --rm hash_tool 2>&1) || true
echo "$out" | grep -qi "usage\|compute\|verify" \
    && pass "TD02 aide par défaut" \
    || fail "TD02 pas d'aide par défaut"
```

### TD03 — Commande inconnue : exit 1, message d'erreur

```bash
local exit_code=0
local out
out=$(docker run --rm hash_tool commande_inconnue_xyz 2>&1) || exit_code=$?
[ "$exit_code" -ne 0 ] && pass "TD03 commande inconnue → exit non-zéro" || fail "TD03 doit exit 1"
echo "$out" | grep -qi "inconnue\|unknown\|ERREUR" \
    && pass "TD03 message d'erreur explicite" \
    || fail "TD03 message d'erreur absent"
```

### TD04 — Commande `version` : affiche b3sum, jq, bash

```bash
local out
out=$(docker run --rm hash_tool version 2>&1)
echo "$out" | grep -qi "b3sum" && pass "TD04 version contient b3sum" || fail "TD04 version sans b3sum"
echo "$out" | grep -qi "jq"    && pass "TD04 version contient jq"    || fail "TD04 version sans jq"
echo "$out" | grep -qi "bash"  && pass "TD04 version contient bash"   || fail "TD04 version sans bash"
```

### TD05 — Commande `compute` : produit un fichier `.b3`

```bash
local tmpdata tmpbases
tmpdata=$(mktemp -d)
tmpbases=$(mktemp -d)
echo "contenu test" > "$tmpdata/fichier.txt"

docker run --rm \
    -v "$tmpdata:/data:ro" \
    -v "$tmpbases:/bases" \
    hash_tool compute /data /bases/test.b3

[ -f "$tmpbases/test.b3" ] \
    && pass "TD05 test.b3 produit" \
    || fail "TD05 test.b3 absent"

grep -qE '^[0-9a-f]{64}  ./fichier.txt' "$tmpbases/test.b3" \
    && pass "TD05 format b3sum correct" \
    || fail "TD05 format b3sum incorrect : $(cat "$tmpbases/test.b3")"

rm -rf "$tmpdata" "$tmpbases"
```

### TD06 — Commande `verify` : OK sur base fraîche

```bash
local tmpdata tmpbases tmpres
tmpdata=$(mktemp -d); tmpbases=$(mktemp -d); tmpres=$(mktemp -d)
echo "contenu test" > "$tmpdata/fichier.txt"

docker run --rm -v "$tmpdata:/data:ro" -v "$tmpbases:/bases" \
    hash_tool compute /data /bases/test.b3 >/dev/null

local out exit_code=0
out=$(docker run --rm \
    -v "$tmpdata:/data:ro" \
    -v "$tmpbases:/bases:ro" \
    -v "$tmpres:/resultats" \
    hash_tool verify /bases/test.b3 /data 2>&1) || exit_code=$?

[ "$exit_code" -eq 0 ] && pass "TD06 verify exit 0" || fail "TD06 verify exit $exit_code"
echo "$out" | grep -qi "OK" && pass "TD06 verify affiche OK" || fail "TD06 verify n'affiche pas OK"

rm -rf "$tmpdata" "$tmpbases" "$tmpres"
```

### TD07 — Commande `verify` : détecte une corruption

```bash
local tmpdata tmpbases tmpres
tmpdata=$(mktemp -d); tmpbases=$(mktemp -d); tmpres=$(mktemp -d)
echo "contenu original" > "$tmpdata/fichier.txt"

docker run --rm -v "$tmpdata:/data:ro" -v "$tmpbases:/bases" \
    hash_tool compute /data /bases/test.b3 >/dev/null

echo "contenu corrompu" > "$tmpdata/fichier.txt"

local exit_code=0
docker run --rm \
    -v "$tmpdata:/data:ro" \
    -v "$tmpbases:/bases:ro" \
    -v "$tmpres:/resultats" \
    hash_tool verify /bases/test.b3 /data >/dev/null 2>&1 || exit_code=$?

[ "$exit_code" -ne 0 ] \
    && pass "TD07 verify détecte corruption → exit non-zéro" \
    || fail "TD07 verify aurait dû échouer"

rm -rf "$tmpdata" "$tmpbases" "$tmpres"
```

### TD08 — Commande `compare` : produit `report.html`

```bash
local tmpbases tmpres
tmpbases=$(mktemp -d); tmpres=$(mktemp -d)

# Créer deux bases différentes
local tmpdata_a tmpdata_b
tmpdata_a=$(mktemp -d); tmpdata_b=$(mktemp -d)
echo "v1" > "$tmpdata_a/f.txt"
echo "v2" > "$tmpdata_b/f.txt"

docker run --rm -v "$tmpdata_a:/data:ro" -v "$tmpbases:/bases" \
    hash_tool compute /data /bases/a.b3 >/dev/null
docker run --rm -v "$tmpdata_b:/data:ro" -v "$tmpbases:/bases" \
    hash_tool compute /data /bases/b.b3 >/dev/null

docker run --rm \
    -v "$tmpbases:/bases:ro" \
    -v "$tmpres:/resultats" \
    hash_tool compare /bases/a.b3 /bases/b.b3 >/dev/null

local report
report=$(ls "$tmpres"/resultats_a*/report.html 2>/dev/null | head -1)
[ -f "$report" ] \
    && pass "TD08 report.html produit" \
    || fail "TD08 report.html absent"

rm -rf "$tmpdata_a" "$tmpdata_b" "$tmpbases" "$tmpres"
```

### TD09 — Flag `--quiet` transmis correctement

```bash
local tmpdata tmpbases tmpres
tmpdata=$(mktemp -d); tmpbases=$(mktemp -d); tmpres=$(mktemp -d)
echo "contenu" > "$tmpdata/f.txt"

docker run --rm -v "$tmpdata:/data:ro" -v "$tmpbases:/bases" \
    hash_tool compute /data /bases/test.b3 >/dev/null

local out
out=$(docker run --rm \
    -v "$tmpdata:/data:ro" \
    -v "$tmpbases:/bases:ro" \
    -v "$tmpres:/resultats" \
    hash_tool --quiet verify /bases/test.b3 /data 2>&1)

[ -z "$out" ] \
    && pass "TD09 --quiet : stdout vide" \
    || fail "TD09 --quiet : stdout non vide : $out"

rm -rf "$tmpdata" "$tmpbases" "$tmpres"
```

### TD10 — Commande `runner` avec pipeline JSON

```bash
local tmpdata tmpbases tmpres tmppipelines
tmpdata=$(mktemp -d); tmpbases=$(mktemp -d)
tmpres=$(mktemp -d); tmppipelines=$(mktemp -d)
echo "contenu" > "$tmpdata/f.txt"

cat > "$tmppipelines/pipeline.json" <<EOF
{
    "pipeline": [
        { "op": "compute", "source": "/data", "bases": "/bases", "nom": "test.b3" }
    ]
}
EOF

docker run --rm \
    -v "$tmpdata:/data:ro" \
    -v "$tmpbases:/bases" \
    -v "$tmpres:/resultats" \
    -v "$tmppipelines/pipeline.json:/pipelines/pipeline.json:ro" \
    hash_tool runner /pipelines/pipeline.json >/dev/null

[ -f "$tmpbases/test.b3" ] \
    && pass "TD10 runner pipeline : test.b3 produit" \
    || fail "TD10 runner pipeline : test.b3 absent"

rm -rf "$tmpdata" "$tmpbases" "$tmpres" "$tmppipelines"
```

### TD11 — Commande `runner` sans pipeline.json monté : erreur explicite

```bash
local out exit_code=0
out=$(docker run --rm hash_tool runner 2>&1) || exit_code=$?
[ "$exit_code" -ne 0 ] && pass "TD11 runner sans pipeline → exit non-zéro" || fail "TD11 doit exit 1"
echo "$out" | grep -qi "introuvable\|ERREUR\|not found" \
    && pass "TD11 message d'erreur sur pipeline absent" \
    || fail "TD11 message d'erreur absent : $out"
```

---

## Structure du fichier `run_tests_docker.sh`

```bash
#!/usr/bin/env bash
# run_tests_docker.sh - Tests de l'image Docker hash_tool
# Usage : ./run_tests_docker.sh [--build]
# Prérequis : Docker

set -euo pipefail

# ... helpers pass/fail/assert identiques aux autres suites ...

echo "=== BUILD ==="
# TB01–TB04

echo "=== ENVIRONNEMENT ==="
# TE01–TE07

echo "=== ENTRYPOINT ==="
# TD01–TD11

echo "========================================"
[ "$FAIL" -eq 0 ] \
    && echo "  $PASS/$TOTAL tests passés" \
    || echo "  $PASS/$TOTAL passés - $FAIL échec(s)"
echo "========================================"
[ "$FAIL" -eq 0 ]
```

---

## Durée estimée

| Section | Durée approx. |
|---|---|
| Tests d'environnement (TE) | ~10 secondes |
| Tests entrypoint (TD) | ~60 secondes |
| Tests de build (TB01 amd64) | ~2-3 minutes |
| Tests de build (TB02 arm64 avec QEMU) | ~5-10 minutes |

**Recommandation CI :** séparer les tests de build (job `docker-build`) des tests d'entrypoint (job `docker-test`). Les tests d'entrypoint peuvent tourner sur une image pré-buildée en cache. Les tests de build ne tournent que sur les PRs modifiant `Dockerfile`, `.dockerignore` ou `docker/`.
