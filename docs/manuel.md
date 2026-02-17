# Manuel technique - Vérification d'intégrité de données

**Périmètre :** détection d'erreurs de transfert et de corruption silencieuse sur disque, sans adversaire.  
**Outils couverts :** b3sum (BLAKE3) · xxHash3 · find · diff · bash

---

## Table des matières

1. [Algorithmes de hachage](#1-algorithmes-de-hachage)
2. [Structure du fichier .b3](#2-structure-du-fichier-b3)
3. [Workflow : calcul, stockage, comparaison](#3-workflow--calcul-stockage-comparaison)
4. [Explication du script integrity.sh](#4-explication-du-script-integritysh)
5. [Performances et optimisation disque](#5-performances-et-optimisation-disque)
6. [Limites et angles morts](#6-limites-et-angles-morts)
7. [Référence rapide](#7-référence-rapide)
8. [Annexe - Alternatives et extensions](#8-annexe--alternatives-et-extensions)

---

## 1. Algorithmes de hachage

### Taxonomie

Deux familles distinctes, usages mutuellement exclusifs :

| Propriété | Cryptographique (BLAKE3) | Non-cryptographique (xxHash3) |
|---|---|---|
| Résistance collision intentionnelle | Oui - infaisable calculatoirement | Non - collisions construisibles |
| Résistance préimage | Oui | Non |
| Débit CPU (1 cœur) | ~1 Go/s | ~50 Go/s |
| Débit sur HDD (150 Mo/s) | Identique - disque impose le rythme | Identique |
| Débit sur SATA SSD (500 Mo/s) | Identique | Identique |
| Détection corruption accidentelle | Oui | Oui |
| Utilisable en sécurité | Oui | Non |

### Pourquoi BLAKE3 plutôt que xxHash3

xxHash3 est techniquement suffisant pour détecter des erreurs accidentelles. BLAKE3 est recommandé pour une seule raison : **le coût marginal sur disque est nul** - les deux sont limités par l'I/O. BLAKE3 reste utilisable si le besoin évolue vers un contexte de sécurité. Headroom gratuit.

```bash
# Si xxHash3 est préféré - workflow identique à b3sum
find ./dossier -type f -print0 | sort -z | xargs -0 xxh128sum > base.xxh
```

### Limitations spécifiques à ce workflow

- Ne hache pas les métadonnées (mtime, permissions) - comportement voulu ici, mais à connaître.
- Ne hache pas les dossiers vides : `find -type f` ne remonte que les fichiers réguliers.
- Sensible aux chemins : le fichier `.b3` encode les chemins tels qu'ils ont été passés à `b3sum`. Chemin absolu vs relatif → deux bases incompatibles pour la même donnée.

---

## 2. Structure du fichier .b3

b3sum produit un format texte simple, une ligne par fichier :

```
# Format : <hash>  <chemin>
# Deux espaces séparent le hash du chemin (convention b3sum/sha256sum)

a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2  ./dossier/fichier.txt
e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6  ./dossier/sous/autre.bin
```

**Taille du fichier .b3 :** chaque ligne fait ~130–200 octets selon la longueur des chemins.

| Nombre de fichiers | Taille approximative |
|---|---|
| 10 000 | ~2 Mo |
| 100 000 | ~20 Mo |
| 1 000 000 | ~200 Mo |

> **Règle absolue : chemins relatifs.** Toujours utiliser `find ./dossier` et non `find /chemin/absolu/dossier`. Un chemin absolu rend la base inutilisable après déplacement, remontage à un point différent, ou copie sur une autre machine.

---

## 3. Workflow : calcul, stockage, comparaison

### Calcul et enregistrement de la base

```bash
# Calcul de base - commande de référence
find ./mon_dossier -type f -print0 \
  | sort -z \
  | xargs -0 b3sum \
  > hashes_2024-01-15.b3

# Vérification immédiate : nombre de fichiers indexés
wc -l hashes_2024-01-15.b3
```

**Pourquoi `sort -z` :** `find` ne garantit pas un ordre déterministe - il dépend de l'ordre de parcours du filesystem (inode order sur ext4). Sans tri, deux exécutions consécutives peuvent produire des fichiers `.b3` dans des ordres différents, rendant la comparaison par `diff` bruyante et inutilisable.

**Pourquoi `-print0` / `-0` :** les noms de fichiers peuvent contenir des espaces, des retours à la ligne, ou des caractères spéciaux. `-print0` utilise le caractère nul comme séparateur, et `-0` dans `xargs` l'interprète. C'est la seule approche robuste.

### Vérification directe

`b3sum --check` relit les fichiers sur disque et compare leurs hashes à la base enregistrée.

```bash
# Lancer depuis le même répertoire de travail qu'au calcul
b3sum --check hashes_2024-01-15.b3

# Sortie en cas de succès :
# ./mon_dossier/fichier.txt: OK
# ./mon_dossier/sous/autre.bin: OK

# Sortie en cas d'échec :
# ./mon_dossier/sous/corrompu.bin: FAILED
# b3sum: WARNING: 1 computed checksum did NOT match

# Filtrer uniquement les échecs
b3sum --check hashes_2024-01-15.b3 2>&1 | grep FAILED
```

> **Contrainte critique : répertoire de travail.** `b3sum --check` résout les chemins relatifs depuis `pwd`. Si la base a été créée depuis `/data` et que la vérification est lancée depuis `/home`, tous les fichiers apparaissent manquants. Toujours exécuter depuis le répertoire parent du dossier à vérifier.

### Comparaison de deux bases .b3

Utile pour comparer deux états historiques sans avoir accès aux fichiers originaux (archive froide, backup distant).

```bash
# Diff brut - suffisant si les bases sont triées
diff <(sort hashes_2024-01-15.b3) <(sort hashes_2024-02-01.b3)

# Comparaison propre par fichier
sort -k2 hashes_2024-01-15.b3 > /tmp/_old.b3
sort -k2 hashes_2024-02-01.b3 > /tmp/_new.b3

# Fichiers dont le hash a changé
join -1 2 -2 2 /tmp/_old.b3 /tmp/_new.b3 \
  | awk '$2 != $3 {print $1, "\n  ancien:", $3, "\n  nouveau:", $2}'

# Fichiers disparus
comm -23 <(awk '{print $2}' /tmp/_old.b3) \
         <(awk '{print $2}' /tmp/_new.b3)

# Fichiers nouveaux
comm -13 <(awk '{print $2}' /tmp/_old.b3) \
         <(awk '{print $2}' /tmp/_new.b3)
```

**`join -1 2 -2 2` :** joint les deux fichiers sur la colonne 2 (nom de fichier), puis compare les colonnes 1 (hash). Les lignes où `$2 != $3` sont les fichiers dont le contenu a changé.

**`comm` :** compare deux flux triés ligne par ligne. `-23` retient les lignes exclusives au premier flux (disparus). `-13` retient les lignes exclusives au second (nouveaux).

---

## 4. Explication du script integrity.sh

### En-tête et mode strict

```bash
#!/usr/bin/env bash
set -euo pipefail
```

`set -euo pipefail` est le mode strict Bash :

- `-e` : le script s'arrête si une commande échoue.
- `-u` : erreur si une variable non initialisée est utilisée.
- `-o pipefail` : si une commande dans un pipeline échoue, le pipeline entier échoue.

### Lecture des arguments

```bash
MODE=${1:-}
ARG2=${2:-}
ARG3=${3:-}
```

Récupère les 3 arguments positionnels. `:-` donne une valeur vide par défaut si l'argument n'est pas fourni - évite une erreur en mode `-u`.

### Mode `compute`

Le mode `compute` délègue à `compute_with_progress`, fonction dédiée à l'indexation fichier par fichier avec affichage de la progression.

```bash
TARGET=$ARG2
HASHFILE=$ARG3
compute_with_progress "$TARGET" "$HASHFILE"
echo "Base enregistrée : $HASHFILE ($(wc -l < "$HASHFILE") fichiers)"
```

**Pourquoi une fonction séparée :** la logique de progression représente ~20 lignes. Les inliner dans le `case` dégraderait la lisibilité du dispatch sans apport. La fonction est nommée explicitement - son rôle est lisible sans lire son corps.

**Corps de `compute_with_progress` :**

```bash
compute_with_progress() {
  local target="$1"
  local hashfile="$2"

  local -a files
  mapfile -d '' files < <(find "$target" -type f -print0 | sort -z)

  local total_files=${#files[@]}
  local total_bytes
  total_bytes=$(du -sb "$target" | awk '{print $1}')

  local bytes_done=0
  local t_start
  t_start=$(date +%s)

  local i=0
  for file in "${files[@]}"; do
    b3sum "$file" >> "$hashfile"

    bytes_done=$(( bytes_done + $(stat -c%s "$file") ))
    i=$(( i + 1 ))

    local t_now elapsed
    t_now=$(date +%s)
    elapsed=$(( t_now - t_start ))

    if (( bytes_done > 0 && elapsed > 0 )); then
      local speed remaining
      speed=$(( bytes_done / elapsed ))
      remaining=$(( (total_bytes - bytes_done) / speed ))
      printf "\r[%d/%d] ETA : %dm %02ds   " \
        "$i" "$total_files" $(( remaining / 60 )) $(( remaining % 60 ))
    fi
  done

  printf "\r%*s\r" 40 ""  # effacer la ligne de progression
}
```

Points clés :

- `mapfile -d ''` charge les chemins dans un tableau en respectant le séparateur nul - gère les noms de fichiers avec espaces ou caractères spéciaux.
- `>> "$hashfile"` en append : chaque `b3sum "$file"` ajoute une ligne. Le fichier est créé vide implicitement à la première écriture.
- `stat -c%s` lit la taille en octets du fichier traité - opération metadata uniquement, sans relecture du contenu.
- `printf "\r..."` écrase la ligne courante sans sauter de ligne - la progression ne pollue pas stdout.
- `printf "\r%*s\r" 40 ""` efface proprement la ligne de progression avant le message final.

### Mode `verify`

```bash
HASHFILE=$ARG3
b3sum --check "$HASHFILE"
```

Délègue directement à `b3sum --check`. Simple, sans surcharge.

### Mode `compare`

Trie les deux bases sur le nom de fichier (colonne 2), puis produit trois sections : fichiers modifiés (hash différent), fichiers disparus (présents dans l'ancienne base, absents dans la nouvelle), fichiers nouveaux (absent dans l'ancienne, présents dans la nouvelle). Le rapport est à la fois affiché en terminal et sauvegardé via `tee`.

---

## 5. Performances et optimisation disque

### Le goulot est le disque, pas l'algorithme

Sur toute configuration réaliste, l'I/O disque est le facteur limitant. BLAKE3 (~1 Go/s/cœur) ne sera jamais le goulot sur HDD ou SATA SSD.

| Support | Débit typique | Temps lecture 2 To | BLAKE3 est goulot ? |
|---|---|---|---|
| HDD 7200 rpm | 100–150 Mo/s | 4–6 heures | Non |
| SATA SSD | 500 Mo/s | ~1 heure | Non |
| NVMe Gen3 | 2–3 Go/s | 12–17 min | Non (1 Go/s/cœur) |
| NVMe Gen4+ | 5–7 Go/s | 5–7 min | Possible |

**RAM :** b3sum + find + xargs consomment quelques mégaoctets. BLAKE3 traite les fichiers en streaming par chunks de 1 Ko - la taille des fichiers n'influence pas la consommation mémoire. 1 Go de RAM est largement suffisant.

### Stratégie HDD - séquentiel obligatoire

Un HDD est optimisé pour les accès séquentiels. Les accès concurrents cassent la séquentialité de lecture et imposent des déplacements mécaniques de tête coûteux. `xargs -P 4` sur HDD dégrade typiquement les performances de 30 à 50 %. La boucle fichier par fichier de `compute_with_progress` est séquentielle par construction - comportement optimal sur HDD.

Le disque est systématiquement le goulot. BLAKE3 (~1 Go/s/cœur) ne limite jamais sur HDD (100–150 Mo/s) ni sur SATA SSD (500 Mo/s). Sur NVMe Gen4+ (5–7 Go/s), BLAKE3 monothread peut devenir limitant - cas hors périmètre de ce workflow.

### Estimations de durée par volume

| Volume | HDD (150 Mo/s) | SATA SSD (500 Mo/s) | NVMe (3 Go/s) |
|---|---|---|---|
| 100 Go | ~11 min | ~3 min | ~34 sec |
| 500 Go | ~56 min | ~17 min | ~3 min |
| 1 To | ~1h 51min | ~34 min | ~6 min |
| 2 To | ~3h 42min | ~1h 8min | ~11 min |
| 10 To | ~18h 30min | ~5h 40min | ~57 min |

Durées indicatives, pipeline monothread. Sur SSD avec `-P 4`, diviser par 2–3.

---

## 6. Limites et angles morts

### Ce que ce workflow ne couvre pas

| Scénario | Détecté ? | Explication |
|---|---|---|
| Fichier corrompu (contenu modifié) | **Oui** | Hash différent → FAILED ou divergence dans compare |
| Fichier manquant | **Oui** | Absent de la nouvelle base ou FAILED (No such file) |
| Fichier ajouté | **Oui** (compare) | Section NOUVEAUX |
| Dossier vide ajouté/supprimé | **Non** | `find -type f` ignore les dossiers vides |
| Modification de permissions/timestamps | **Non** | b3sum ne hache que le contenu binaire |
| Fichier remplacé par un clone identique | **Non** | Hash identique - indétectable par définition |
| Corruption de la base .b3 elle-même | **Non** | La base n'est pas auto-protégée |
| Corruption pendant la lecture pour hachage | **Non** | Le hash reflète la donnée lue, corrompue ou non |

### Protéger la base de hash

La base `.b3` est le référentiel de confiance. Si elle est corrompue ou altérée, toute comparaison ultérieure est sans valeur.

- Stocker la base sur un support distinct des données à vérifier.
- Hacher la base elle-même et stocker ce méta-hash sur un troisième support (email, cloud, papier imprimé).
- Horodater les bases avec un schéma de nommage explicite : `hashes_2024-01-15.b3`, jamais `hashes_latest.b3`.
- En contexte critique, signer la base avec GPG.

```bash
# Protéger la base par son propre hash
b3sum hashes_2024-01-15.b3 > hashes_2024-01-15.b3.check

# Vérification ultérieure de l'intégrité de la base elle-même
b3sum --check hashes_2024-01-15.b3.check
```

### Le problème des renommages et changements de chemin

`b3sum --check` compare les chemins littéralement. Tout renommage de dossier ou changement de structure rompt la correspondance, même si les données sont intactes.

```bash
# Situation : dossier renommé entre compute et verify
# Calcul depuis :  ./mon_projet/
# Vérification :   ./projet_final/

b3sum --check base.b3
# Résultat : FAILED (No such file or directory) sur TOUS les fichiers
# Le hash est correct - c'est le chemin qui a changé.

# Solution : corriger les chemins dans la base avant vérification
sed 's|./mon_projet/|./projet_final/|g' base.b3 > base_corrigee.b3
b3sum --check base_corrigee.b3
```

---

## 7. Référence rapide

### Commandes essentielles

```bash
# Calcul de base (universel, HDD/SSD)
find ./dossier -type f -print0 | sort -z | xargs -0 b3sum > base.b3

# Vérification directe (état actuel vs base)
b3sum --check base.b3

# Filtrer uniquement les échecs
b3sum --check base.b3 2>&1 | grep FAILED

# Comparaison deux bases (script externe)
./integrity.sh compare ancienne.b3 nouvelle.b3

# Compter les fichiers indexés
wc -l base.b3

# Hacher un fichier unique
b3sum fichier.bin

# Protéger la base elle-même
b3sum base.b3 > base.b3.check
```

### Arbre de décision

| Situation | Mode | Commande |
|---|---|---|
| Première indexation | compute | `find \| sort \| xargs b3sum > base.b3` |
| Vérifier après transfert/stockage | verify | `b3sum --check base.b3` |
| Comparer deux archives | compare | `./integrity.sh compare old.b3 new.b3` |
| Contrôle rapide d'un seul fichier | ad hoc | `b3sum fichier.bin` |
| Rapport horodaté persistant | compare+log | `./integrity.sh compare old.b3 new.b3` |

---

## 8. Annexe - Alternatives et extensions

### A.1 Outils FIM si le besoin évolue vers la sécurité

Si le périmètre évolue vers une surveillance continue ou un contexte de sécurité active, les outils FIM dédiés remplacent ce workflow artisanal.

| Outil | Usage | Complexité | Pertinent si… |
|---|---|---|---|
| Tripwire | Audit système local, détection compromissions post-intrusion | Moyenne | Serveur Linux, conformité PCI-DSS/HIPAA |
| Samhain | FIM distribué, parc multi-hôtes, alertes SIEM | Élevée | Infrastructure d'entreprise |
| AIDE | Alternative open source à Tripwire | Moyenne | Remplacement direct de Tripwire |
| ZFS | Filesystem avec checksum natif sur chaque bloc | Faible (si migration possible) | Protection transparente sans workflow explicite |

La ligne de démarcation structurante : b3sum/xxHash3 sont des **primitives** - ils font ce qu'on leur demande, sans contexte. Tripwire et Samhain sont des **systèmes** - ils maintiennent un état de référence et détectent les dérives.

### A.2 Intégration dans un pipeline automatisé

```bash
# Crontab - vérification hebdomadaire automatique
0 2 * * 0 /opt/integrity.sh verify ./donnees /var/lib/integrity/base.b3 >> /var/log/integrity.log 2>&1

# Post-transfert rsync - vérification immédiate après copie
rsync -av source/ dest/ && b3sum --check base.b3

# Alerte email si des fichiers ont échoué
b3sum --check base.b3 2>&1 | grep FAILED | mail -s 'Alerte intégrité' admin@example.com
```
