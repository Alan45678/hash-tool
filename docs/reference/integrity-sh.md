# Référence - `hash-tool` & `src/integrity.sh`

`hash-tool` est l'interface CLI unique. `src/integrity.sh` est le moteur interne pour `compute`, `verify`, `compare`. Les nouvelles commandes (`list`, `diff`, `stats`, `check-env`, `version`) sont gérées directement par `hash-tool`.

---

## Synopsis

```
hash-tool <commande> [options]
```

**Appel direct `integrity.sh` (non recommandé en usage courant) :**

```
./src/integrity.sh [--quiet] compute <dossier> <base.b3>
./src/integrity.sh [--quiet] verify  <base.b3> [dossier]
./src/integrity.sh [--quiet] compare <ancienne.b3> <nouvelle.b3>
```

---

## Commandes

### `compute`

Calcule les empreintes BLAKE3 de tous les fichiers d'un dossier. Génère un fichier `.b3` et un sidecar `.meta.json`.

```bash
hash-tool compute -data <dossier> [-save <dossier>] [-meta <texte>] [-quiet] [-readonly]
```

| Option | Requis | Description |
|---|---|---|
| `-data <dossier>` | Oui | Dossier à analyser. |
| `-save <dossier>` | Non | Dossier de sortie pour le `.b3` (défaut : répertoire courant). |
| `-meta <texte>` | Non | Commentaire stocké dans le sidecar `.meta.json`. |
| `-quiet` | Non | Supprime toute sortie terminal. |
| `-readonly` | Non | Documenté dans le sidecar (`parameters.readonly: true`). |

**Sortie :**

```
./bases/hashes_donnees.b3           ← empreintes BLAKE3
./bases/hashes_donnees.b3.meta.json ← sidecar métadonnées
Base enregistrée : ./bases/hashes_donnees.b3 (1247 fichiers)
Sidecar : ./bases/hashes_donnees.b3.meta.json
```

**Exit codes :**

| Code | Signification |
|---|---|
| `0` | Base calculée avec succès |
| `1` | Erreur (argument manquant, dossier introuvable, dossier vide) |

---

### `verify`

Vérifie l'intégrité d'un dossier à partir d'une base d'empreintes.

```bash
hash-tool verify -base <fichier.b3> [-data <dossier>] [-save <dossier>] [-quiet]
```

| Option | Requis | Description |
|---|---|---|
| `-base <fichier.b3>` | Oui | Base d'empreintes de référence. |
| `-data <dossier>` | Non | Dossier à vérifier. Défaut : répertoire courant au moment du `compute`. |
| `-save <dossier>` | Non | Dossier de sortie des résultats (surcharge `RESULTATS_DIR`). |
| `-quiet` | Non | Supprime la sortie terminal. Exit code propagé. |

**Fichiers produits :**

```
~/integrity_resultats/resultats_hashes_donnees/
├── recap.txt    ← statut, compteurs OK/FAIL
└── failed.txt   ← chemins FAILED (uniquement si echec)
```

**Exit codes :**

| Code | Signification |
|---|---|
| `0` | Tous les fichiers intègres |
| `1` | Au moins un fichier FAILED ou erreur `b3sum` |

!!! warning "Répertoire de travail"
    `verify` doit être lancé depuis le même répertoire qu'au `compute`, ou `-data` doit pointer vers ce répertoire. Les chemins dans `.b3` sont relatifs - un mauvais `pwd` produit des faux positifs massifs.

---

### `compare`

Compare deux bases d'empreintes et produit un rapport HTML.

```bash
hash-tool compare -old <ancienne.b3> -new <nouvelle.b3> [-save <dossier>]
```

| Option | Requis | Description |
|---|---|---|
| `-old <ancienne.b3>` | Oui | Ancienne base (référence). |
| `-new <nouvelle.b3>` | Oui | Nouvelle base (à comparer). |
| `-save <dossier>` | Non | Dossier de sortie des résultats. |

**Fichiers produits :**

```
~/integrity_resultats/resultats_hashes_avant/
├── recap.txt     ← compteurs : modifiés, disparus, nouveaux
├── modifies.b3   ← fichiers présents dans les deux bases avec hashes différents
├── disparus.txt  ← chemins dans ancienne, absents de nouvelle
├── nouveaux.txt  ← chemins dans nouvelle, absents d'ancienne
└── report.html   ← rapport HTML autonome (CSS inline, thème sombre)
```

**Exit codes :**

| Code | Signification |
|---|---|
| `0` | Comparaison effectuée (même si des différences existent) |
| `1` | Erreur technique |

!!! note
    `compare` retourne `0` même si des différences sont détectées. La présence de différences est une information, pas une erreur. Pour détecter des différences en script, vérifier si `modifies.b3`, `disparus.txt` ou `nouveaux.txt` sont non vides.

---

### `runner`

Exécute un pipeline JSON définissant une suite d'opérations.

```bash
hash-tool runner [-pipeline <fichier.json>] [-save <dossier>]
```

Voir [reference/runner-sh.md](runner-sh.md) pour la documentation complète du format pipeline.

---

### `list`

Liste toutes les bases `.b3` disponibles dans un dossier.

```bash
hash-tool list [-data <dossier>]
```

| Option | Description |
|---|---|
| `-data <dossier>` | Dossier à parcourir (défaut : répertoire courant). |

**Sortie (exemple) :**

```
=== Bases d'empreintes dans : ./bases ===

  hashes_donnees.b3                     1247 fichiers   2.1M [+meta]
     → Snapshot initial (2026-02-26T14:30:00Z)
  hashes_donnees_v2.b3                  1253 fichiers   2.2M [+meta]
     → Snapshot après migration (2026-02-27T09:00:00Z)
```

`[+meta]` indique la présence d'un sidecar `.meta.json`.

---

### `diff`

Affiche les différences entre une base d'empreintes et l'état actuel d'un dossier en termes de présence/absence de fichiers. Ne recalcule pas les hashes.

```bash
hash-tool diff -base <fichier.b3> [-data <dossier>]
```

| Option | Requis | Description |
|---|---|---|
| `-base <fichier.b3>` | Oui | Base de référence. |
| `-data <dossier>` | Non | Dossier courant à comparer (défaut : `.`). |

**Sortie (exemple) :**

```
=== DIFF : hashes_donnees.b3 vs ./donnees ===

  Fichiers disparus depuis la base : 2
    - ./donnees/archive/rapport-2023.pdf
    - ./donnees/temp/export.csv

  Nouveaux fichiers non indexés : 1
    + ./donnees/2026/rapport-q1.pdf
```

**Différence avec `compare` :** `diff` est instantané (pas de hachage), `compare` détecte aussi les modifications de contenu.

---

### `stats`

Affiche des statistiques sur une base d'empreintes.

```bash
hash-tool stats -base <fichier.b3>
```

**Sortie (exemple) :**

```
=== Statistiques : hashes_donnees.b3 ===

  Fichier base     : /opt/bases/hashes_donnees.b3
  Taille fichier   : 2.1M
  Fichiers indexés : 1247

  Extensions :
    .jpg           843 fichiers
    .pdf           201 fichiers
    .docx           89 fichiers
    .txt            67 fichiers
    (autres)        47 fichiers

--- Métadonnées (sidecar) ---
{
  "created_by": "hash-tool v2.0.0",
  "date": "2026-02-26T14:30:00Z",
  "comment": "Snapshot initial",
  "parameters": { "directory": "./donnees", "hash_algo": "blake3", "nb_files": 1247 }
}
-----------------------------
```

---

### `check-env`

Analyse l'environnement d'exécution et indique le mode sélectionné.

```bash
hash-tool check-env
```

**Sortie (exemple - environnement natif complet) :**

```
=== check-env : Analyse de l'environnement ===

  [OK] b3sum disponible : b3sum 1.5.4
  [OK] jq disponible : jq-1.7
  [OK] bash 5.2.15(1)-release
  [OK] integrity.sh présent et exécutable
  [OK] runner.sh présent et exécutable
  [--] Docker non disponible (optionnel)

  Mode d'exécution sélectionné : native
  → Exécution native active
```

---

### `version`

Affiche la version du logiciel.

```bash
hash-tool version
```

---

### `help`

```bash
hash-tool help              # aide globale
hash-tool help <commande>   # aide détaillée par sous-commande
```

---

## Options générales

| Option | Description |
|---|---|
| `-data <chemin>` | Dossier à analyser. |
| `-base <chemin>` | Fichier base d'empreintes (`.b3`). |
| `-old <chemin>` | Ancienne base (pour `compare`). |
| `-new <chemin>` | Nouvelle base (pour `compare`). |
| `-pipeline <chemin>` | Fichier pipeline JSON (pour `runner`). |
| `-save <chemin>` | Dossier de sortie pour les résultats. |
| `-meta <texte>` | Commentaire pour le sidecar JSON (`compute`). |
| `-quiet` | Mode silencieux - pas de sortie terminal. |
| `-verbose` | Mode verbeux. |
| `-readonly` | Marque le compute comme lecture seule dans le sidecar. |

---

## Variable d'environnement

### `RESULTATS_DIR`

| | |
|---|---|
| **Défaut** | `~/integrity_resultats` |
| **Scope** | `verify` et `compare` |

```bash
export RESULTATS_DIR=/srv/rapports
hash-tool verify -base hashes.b3
```

Peut aussi être surchargé via `-save` pour une commande unique.

### `HASH_TOOL_DOCKER_IMAGE`

| | |
|---|---|
| **Défaut** | `hash_tool` |
| **Scope** | `hash-tool` en mode Docker |

```bash
export HASH_TOOL_DOCKER_IMAGE=mon_registry/hash_tool:latest
hash-tool compute -data ./donnees -save ./bases
```

---

## Limites connues

| Scénario | Détecté ? | Remarque |
|---|---|---|
| Contenu de fichier modifié | **Oui** | Hash différent → `verify` FAILED, `compare` MODIFIÉS |
| Fichier supprimé | **Oui** | FAILED (`verify`) ou DISPARUS (`compare`) |
| Fichier ajouté | **Oui** (`compare`, `diff`) | Section NOUVEAUX |
| Dossier vide | **Non** | `find -type f` ignore les dossiers vides |
| Permissions / timestamps | **Non** | Seul le contenu binaire est haché |
| Fichier renommé | **Non** | Vu comme suppression + ajout |
| Clone bit-à-bit | **Non** | Hash identique par définition |
| Corruption de la base `.b3` | **Non** | La base n'est pas auto-protégée |

### Protéger la base `.b3`

```bash
b3sum hashes.b3 > hashes.b3.check
b3sum --check hashes.b3.check
```

---

## Dépendances techniques

| Outil | Usage |
|---|---|
| `b3sum` | Calcul et vérification des hashes BLAKE3 |
| `jq` | Sidecar JSON, pipelines |
| `find` | Parcours récursif du dossier |
| `sort` | Tri déterministe des chemins |
| `awk` | Conversion format `hash chemin` ↔ `chemin\thash` |
| `join` | Identification des fichiers modifiés |
| `comm` | Identification des disparus et nouveaux |
| `stat` | Taille de fichier pour le calcul ETA |
| `du` | Taille totale du dossier pour le calcul ETA |
| `mktemp` | Fichiers temporaires isolés dans `compare` |