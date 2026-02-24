# Manuel technique — Vérification d'intégrité de données

**Périmètre :** détection d'erreurs de transfert et de corruption silencieuse sur disque, sans adversaire.  
**Outils couverts :** b3sum (BLAKE3) · xxHash3 · find · diff · bash · jq

---

## Table des matières

1. [Algorithmes de hachage](#1-algorithmes-de-hachage)
2. [Structure du fichier .b3](#2-structure-du-fichier-b3)
3. [Workflow : calcul, stockage, comparaison](#3-workflow--calcul-stockage-comparaison)
4. [Explication du script integrity.sh](#4-explication-du-script-integritysh)
5. [Pipeline batch : runner.sh + pipeline.json](#5-pipeline-batch--runnersh--pipelinejson)
6. [Performances et optimisation disque](#6-performances-et-optimisation-disque)
7. [Limites et angles morts](#7-limites-et-angles-morts)
8. [Référence rapide](#8-référence-rapide)
9. [Annexe — Alternatives et extensions](#9-annexe--alternatives-et-extensions)

---

## 1. Algorithmes de hachage

### Taxonomie

Deux familles distinctes, usages mutuellement exclusifs :

| Propriété | Cryptographique (BLAKE3) | Non-cryptographique (xxHash3) |
|---|---|---|
| Résistance collision intentionnelle | Oui — infaisable calculatoirement | Non — collisions construisibles |
| Résistance préimage | Oui | Non |
| Débit CPU (1 cœur) | ~1 Go/s | ~50 Go/s |
| Débit sur HDD (150 Mo/s) | Identique — disque impose le rythme | Identique |
| Débit sur SATA SSD (500 Mo/s) | Identique | Identique |
| Détection corruption accidentelle | Oui | Oui |
| Utilisable en sécurité | Oui | Non |

### Pourquoi BLAKE3 plutôt que xxHash3

xxHash3 est techniquement suffisant pour détecter des erreurs accidentelles. BLAKE3 est recommandé pour une seule raison : **le coût marginal sur disque est nul** — les deux sont limités par l'I/O. BLAKE3 reste utilisable si le besoin évolue vers un contexte de sécurité. Headroom gratuit.

```bash
# Si xxHash3 est préféré — workflow identique à b3sum
find ./dossier -type f -print0 | sort -z | xargs -0 xxh128sum > base.xxh
```

### Limitations spécifiques à ce workflow

- Ne hache pas les métadonnées (mtime, permissions).
- Ne hache pas les dossiers vides : `find -type f` ne remonte que les fichiers réguliers.
- Sensible aux chemins : chemin absolu vs relatif → deux bases incompatibles pour la même donnée.

---

## 2. Structure du fichier .b3

b3sum produit un format texte simple, une ligne par fichier :

```
# Format : <hash>  <chemin>
# Deux espaces séparent le hash du chemin (convention b3sum/sha256sum)

a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2  ./dossier/fichier.txt
e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6  ./dossier/sous/autre.bin
```

| Nombre de fichiers | Taille approximative |
|---|---|
| 10 000 | ~2 Mo |
| 100 000 | ~20 Mo |
| 1 000 000 | ~200 Mo |

> **Règle absolue : chemins relatifs.** Toujours `find ./dossier`, jamais `find /chemin/absolu`. Un chemin absolu rend la base inutilisable après déplacement ou remontage.

---

## 3. Workflow : calcul, stockage, comparaison

### Calcul et enregistrement de la base

```bash
find ./mon_dossier -type f -print0 \
  | sort -z \
  | xargs -0 b3sum \
  > hashes_2024-01-15.b3

wc -l hashes_2024-01-15.b3
```

**`sort -z`** : `find` ne garantit pas un ordre déterministe. Sans tri, `diff` entre deux bases est inutilisable.

**`-print0` / `-0`** : robuste aux noms de fichiers avec espaces ou caractères spéciaux.

### Vérification directe

```bash
b3sum --check hashes_2024-01-15.b3

# Sortie OK :
# ./mon_dossier/fichier.txt: OK

# Sortie ECHEC :
# ./mon_dossier/sous/corrompu.bin: FAILED
# b3sum: WARNING: 1 computed checksum did NOT match

b3sum --check hashes_2024-01-15.b3 2>&1 | grep FAILED
```

> **Contrainte critique : répertoire de travail.** `b3sum --check` résout les chemins relatifs depuis `pwd`. Toujours exécuter depuis le répertoire où `compute` a été lancé.

### Comparaison de deux bases .b3

```bash
diff <(sort hashes_2024-01-15.b3) <(sort hashes_2024-02-01.b3)
```

`run_compare()` dans `integrity.sh` automatise cette comparaison avec `join`, `comm`, et un rapport structuré.

---

## 4. Explication du script integrity.sh

### En-tête et mode strict

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- `-e` : arrêt sur échec de commande.
- `-u` : erreur sur variable non initialisée.
- `-o pipefail` : échec du pipeline si une commande intermédiaire échoue.

### Parsing des arguments

```bash
QUIET=0
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=1 ;;
    *)       ARGS+=("$arg") ;;
  esac
done
MODE="${ARGS[0]:-}"
ARG2="${ARGS[1]:-}"
ARG3="${ARGS[2]:-}"
```

`--quiet` filtré avant la lecture positionnelle. `:-` donne une valeur vide par défaut en mode `-u`.

### Mode compute

```bash
compute_with_progress() {
  local -a files
  mapfile -d '' files < <(find "$target" -type f -print0 | sort -z)

  for file in "${files[@]}"; do
    b3sum "$file" >> "$hashfile"
    # ETA calculé et affiché sur /dev/tty — jamais dans le pipe
    printf "\r[%d/%d] ETA : %dm %02ds   " ... > /dev/tty
  done
}
```

**`mapfile -d ''`** : charge les chemins en tableau depuis flux nul-séparé. Robuste aux espaces et caractères spéciaux.

**`> /dev/tty`** : progression écrite directement sur le terminal, ne peut pas polluer la base `.b3`.

### Mode verify

```bash
hashfile_abs=$(realpath "$ARG2")
[ -n "${ARG3:-}" ] && cd "$ARG3"
run_verify "$hashfile_abs"
```

Le chemin absolu est résolu **avant** le `cd` — un chemin relatif deviendrait invalide après changement de répertoire.

### Mode compare

`run_compare()` convertit `hash  chemin` → `chemin\thash` via `awk` (offset fixe 64 chars pour le hash), puis utilise `sort`, `join`, `comm` avec `-t $'\t'` — robuste aux chemins avec espaces.

---

## 5. Pipeline batch : runner.sh + pipeline.json

### Problème résolu

Lancer `integrity.sh` manuellement sur plusieurs dossiers depuis des partitions différentes (VeraCrypt, disques externes) est error-prone : répertoire de travail incorrect, chemins absolus dans les bases, oubli de `cd`. `runner.sh` automatise et sécurise ces étapes.

**Dépendance supplémentaire :** `jq` (`apt install jq` dans WSL).

### pipeline.json — format

```json
{
    "pipeline": [

        {
            "op":     "compute",
            "source": "/mnt/a/dossier_disque_1",
            "bases":  "/mnt/c/Users/TonNom/Desktop/bases",
            "nom":    "hashes_dossier_1.b3"
        },

        {
            "op":     "compute",
            "source": "/mnt/i/dossier_disque_2",
            "bases":  "/mnt/c/Users/TonNom/Desktop/bases",
            "nom":    "hashes_dossier_2.b3"
        },

        {
            "op":     "verify",
            "source": "/mnt/a/dossier_disque_1",
            "base":   "/mnt/c/Users/TonNom/Desktop/bases/hashes_dossier_1.b3"
        },

        {
            "op":     "compare",
            "base_a": "/mnt/c/Users/TonNom/Desktop/bases/hashes_dossier_1.b3",
            "base_b": "/mnt/c/Users/TonNom/Desktop/bases/hashes_dossier_2.b3"
        }

    ]
}
```

Champs requis par opération :

| `op` | Champs |
|---|---|
| `compute` | `source` — dossier à hacher · `bases` — dossier de destination · `nom` — nom du `.b3` |
| `verify` | `source` — répertoire de travail d'origine · `base` — chemin complet du `.b3` |
| `compare` | `base_a` — ancienne base · `base_b` — nouvelle base |

### runner.sh — comportement

**compute** : `cd "$source"` puis `integrity.sh compute . "$bases/$nom"`. Le `.` garantit des chemins relatifs dans la base.

**verify** : `cd "$source"` puis `integrity.sh verify "$base"`. Le `cd` reproduit le répertoire de travail d'origine du compute.

**compare** : appel direct sans `cd`. `base_a` et `base_b` sont des chemins absolus vers les `.b3`.

**Validation** : `jq empty` vérifie la syntaxe JSON à l'entrée. Champs manquants et opérations inconnues produisent un message `ERREUR` avec numéro de bloc, sans stacktrace `jq`.

### Lancement Windows (double-clic)

```bat
@echo off
wsl bash /mnt/c/Users/TonNom/Desktop/runner.sh
pause
```

### Chemins WSL — partitions VeraCrypt

| Windows | WSL |
|---|---|
| `A:\` | `/mnt/a/` |
| `C:\` | `/mnt/c/` |
| `H:\` | `/mnt/h/` |
| `I:\` | `/mnt/i/` |

Si VeraCrypt remonte une partition sur une lettre différente, seul le champ `source` dans `pipeline.json` est à modifier. La base `.b3` reste valide car ses chemins sont relatifs.

---

## 6. Performances et optimisation disque

Sur HDD (150 Mo/s), SSD SATA (500 Mo/s) ou SSD NVMe séquentiel, le disque est systématiquement le goulot. b3sum à 1 Go/s sur un cœur ne sera jamais le facteur limitant.

La boucle séquentielle de `compute_with_progress` est légèrement moins efficace que `xargs -P 4` sur SSD NVMe avec de nombreux petits fichiers, mais identique sur HDD — cas principal pour gros volumes. Le gain ETA justifie le choix.

Pour SSD NVMe + pas besoin d'ETA :

```bash
find ./dossier -type f -print0 | sort -z | xargs -0 -P 4 b3sum > base.b3
```

---

## 7. Limites et angles morts

| Scénario | Détecté ? | Explication |
|---|---|---|
| Fichier corrompu | **Oui** | Hash différent → FAILED ou divergence compare |
| Fichier manquant | **Oui** | FAILED (No such file) ou section DISPARUS |
| Fichier ajouté | **Oui** (compare) | Section NOUVEAUX |
| Dossier vide | **Non** | `find -type f` ignore les dossiers vides |
| Permissions/timestamps | **Non** | b3sum ne hache que le contenu binaire |
| Clone identique | **Non** | Hash identique — indétectable par définition |
| Corruption de la base .b3 | **Non** | La base n'est pas auto-protégée |

### Protéger la base

```bash
b3sum hashes_2024-01-15.b3 > hashes_2024-01-15.b3.check
b3sum --check hashes_2024-01-15.b3.check
```

Stocker la base sur un support distinct. Sur VeraCrypt : stocker les `.b3` sur `C:`, jamais sur la partition vérifiée.

### Renommages et changements de chemin

`b3sum --check` compare les chemins littéralement. Tout renommage de dossier produit des FAILED sur tous les fichiers, même si le contenu est intact.

```bash
sed 's|./ancien_nom/|./nouveau_nom/|g' base.b3 > base_corrigee.b3
b3sum --check base_corrigee.b3
```

---

## 8. Référence rapide

```bash
# Calcul
find ./dossier -type f -print0 | sort -z | xargs -0 b3sum > base.b3

# Vérification
./integrity.sh verify base.b3

# Comparaison
./integrity.sh compare ancienne.b3 nouvelle.b3

# Pipeline multi-dossiers
./runner.sh                        # lit pipeline.json dans le même dossier
./runner.sh /chemin/pipeline.json  # config explicite

# Compter les fichiers indexés
wc -l base.b3

# Fichier unique
b3sum fichier.bin

# Protéger la base
b3sum base.b3 > base.b3.check
```

| Situation | Mode | Commande |
|---|---|---|
| Première indexation | compute | `./integrity.sh compute ./dossier base.b3` |
| Multi-dossiers / VeraCrypt | runner | `./runner.sh` |
| Vérifier après transfert | verify | `./integrity.sh verify base.b3` |
| Comparer deux archives | compare | `./integrity.sh compare old.b3 new.b3` |
| Fichier unique | ad hoc | `b3sum fichier.bin` |

---

## 9. Annexe — Alternatives et extensions

### A.1 Outils FIM

| Outil | Usage | Complexité | Pertinent si… |
|---|---|---|---|
| Tripwire | Audit système local | Moyenne | Serveur Linux, conformité PCI-DSS/HIPAA |
| Samhain | FIM distribué, alertes SIEM | Élevée | Infrastructure d'entreprise |
| AIDE | Alternative open source à Tripwire | Moyenne | Remplacement direct de Tripwire |
| ZFS | Checksum natif sur chaque bloc | Faible (si migration possible) | Protection transparente |

b3sum/xxHash3 sont des **primitives**. Tripwire et Samhain sont des **systèmes** qui maintiennent un état de référence et détectent les dérives.

### A.2 Intégration automatisée

```bash
# Crontab — vérification hebdomadaire
0 2 * * 0 /opt/integrity.sh --quiet verify /var/lib/integrity/base.b3 >> /var/log/integrity.log 2>&1

# Post-transfert rsync
rsync -av source/ dest/ && b3sum --check base.b3

# Alerte email
b3sum --check base.b3 2>&1 | grep FAILED | mail -s 'Alerte intégrité' admin@example.com
```