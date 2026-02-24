# Cas limites — Catalogue exhaustif

---

## Introduction

Un cas limite est une entrée qui se situe aux frontières du comportement normal. C'est là que les bugs se cachent — le code est typiquement développé et testé sur des cas "standards", et les hypothèses implicites sur les entrées ne sont jamais vérifiées.

Ce catalogue recense tous les cas limites identifiés pour `hash_tool`, classés par catégorie. Pour chaque cas : l'input, le comportement attendu, et le risque si le cas n'est pas testé.

---

## Catégorie 1 — Noms de fichiers

### 1.1 Espace dans le nom

| | |
|---|---|
| **Input** | `"fichier avec espaces.txt"` |
| **Comportement attendu** | Indexé correctement, 1 ligne dans `.b3`, verify OK |
| **Risque** | `awk '{print $2}'` fragmente le chemin — faux positif massif dans `compare` (bug historique v0.7) |
| **Testé par** | T08 (existant), CU42 (unitaire à créer) |

### 1.2 Plusieurs espaces consécutifs

| | |
|---|---|
| **Input** | `"fichier  avec  doubles  espaces.txt"` |
| **Comportement attendu** | Indexé correctement, 1 ligne, verify OK |
| **Risque** | Parsing par champ fragmente encore plus — potentiellement confondu avec le séparateur `  ` du format b3sum |
| **Testé par** | Non testé — à ajouter en T15b |

### 1.3 Newline dans le nom

| | |
|---|---|
| **Input** | `$'nom\navec\nnewline.txt'` |
| **Comportement attendu** | Indexé correctement (1 fichier = 1 ligne dans `.b3`) |
| **Risque** | `find | wc -l` compte 3 fichiers ; `xargs` sans `-0` éclate le nom ; seuls `find -print0` + `mapfile -d ''` tiennent |
| **Testé par** | T15 (à créer) |
| **Note** | Cas légal sur Linux, illégal sur Windows/macOS |

### 1.4 Tabulation dans le nom

| | |
|---|---|
| **Input** | `$'nom\tavec\ttab.txt'` |
| **Comportement attendu** | Indexé correctement |
| **Risque** | `_b3_to_path_hash` utilise `\t` comme séparateur — une tabulation dans le chemin peut corrompre le parsing |
| **Testé par** | Non testé — **cas critique à ajouter** |
| **Note** | `awk '{ print substr($0,67) "\t" substr($0,1,64) }'` — l'offset fixe 67 protège le hash, mais le chemin est copié tel quel avec sa tabulation |

### 1.5 Caractères HTML dans le nom

| | |
|---|---|
| **Input** | `"<script>alert.txt"`, `"a&b.txt"`, `"page>2.txt"` |
| **Comportement attendu** | Indexé correctement dans `.b3` (pas d'échappement dans le fichier texte) ; échappé dans `report.html` |
| **Risque** | `report.html` affiche `<script>` littéralement → injection HTML dans le rapport |
| **Testé par** | T16 (à créer) |

### 1.6 Fichier commençant par un tiret

| | |
|---|---|
| **Input** | `"-fichier.txt"` |
| **Comportement attendu** | Indexé correctement |
| **Risque** | Certains outils interprètent `-` comme un flag CLI |
| **Testé par** | Non testé — risque faible car `find` et `b3sum` reçoivent le chemin complet |

### 1.7 Nom très long (255 chars, limite ext4)

| | |
|---|---|
| **Input** | Nom de 254 caractères |
| **Comportement attendu** | Indexé correctement |
| **Risque** | Troncature silencieuse dans certains buffers |
| **Testé par** | Non testé — risque faible, `b3sum` gère les noms longs |

### 1.8 Fichier caché (commençant par `.`)

| | |
|---|---|
| **Input** | `".fichier_cache"` |
| **Comportement attendu** | Indexé par `find -type f` (find suit les fichiers cachés par défaut) |
| **Risque** | `ls` ne les montre pas — confusion si on vérifie manuellement le count |
| **Testé par** | Non testé — à ajouter dans fixtures |

---

## Catégorie 2 — Contenu de fichiers

### 2.1 Fichier de taille zéro

| | |
|---|---|
| **Input** | `touch zero.bin` |
| **Comportement attendu** | Indexé (le hash BLAKE3 d'un fichier vide est défini), `bytes_done` non modifié (branche `fsize > 0` protège le calcul ETA) |
| **Risque** | Division par zéro dans le calcul ETA si `bytes_done == total_bytes == 0` |
| **Testé par** | T18 (à créer), CU23 (unitaire) |

### 2.2 Fichier très volumineux (> 4 Go)

| | |
|---|---|
| **Input** | Fichier de 5 Go (nécessite un disque disponible) |
| **Comportement attendu** | Indexé correctement, ETA affichée |
| **Risque** | Overflow integer dans `bytes_done` si bash utilise des entiers 32 bits (bash 4+ utilise 64 bits — OK) |
| **Testé par** | Non testé — difficile en CI (espace disque, temps) |
| **Décision** | Exclus des tests automatiques. Documenté comme supporté (bash 64-bit integers) |

### 2.3 Fichier binaire avec tous les octets possibles

| | |
|---|---|
| **Input** | `printf '%b' '\x00\x01...\xff' > binary.bin` |
| **Comportement attendu** | Indexé correctement, hash stable |
| **Risque** | Traitements texte naïfs sur le contenu du fichier (aucun dans `hash_tool` — `b3sum` opère sur des octets bruts) |
| **Testé par** | Non testé — risque faible |

---

## Catégorie 3 — Structure du dossier

### 3.1 Dossier vide

| | |
|---|---|
| **Input** | `mkdir dossier_vide` sans fichiers |
| **Comportement attendu** | `core_assert_target_valid` lève une erreur "aucun fichier régulier" |
| **Risque** | Base `.b3` vide produite silencieusement, puis `core_assert_b3_valid` rejette la base vide |
| **Testé par** | T09 (existant, partiellement), CU14 (unitaire) |

### 3.2 Dossier avec uniquement des sous-dossiers vides

| | |
|---|---|
| **Input** | `mkdir -p dossier/sub1 dossier/sub2` |
| **Comportement attendu** | Même qu'un dossier vide — erreur "aucun fichier régulier" |
| **Risque** | `find -type f` retourne 0 résultat, `total_files=0`, division par zéro potentielle dans ETA |
| **Testé par** | CU16 (unitaire) |

### 3.3 Arborescence profonde

| | |
|---|---|
| **Input** | `a/b/c/d/e/f/g/h/i/j/fichier.txt` (10 niveaux) |
| **Comportement attendu** | Indexé correctement, chemin complet dans `.b3` |
| **Risque** | Limites de longueur de chemin sur certains OS (PATH_MAX = 4096 sur Linux) |
| **Testé par** | Non testé — risque faible |

### 3.4 Lien symbolique

| | |
|---|---|
| **Input** | `ln -s cible.txt lien.txt` |
| **Comportement attendu** | `find -type f` ignore le lien symbolique par défaut — lien non indexé |
| **Risque** | Comportement non documenté, surprenant pour l'utilisateur qui s'attend à voir le lien indexé |
| **Testé par** | T19 (à créer) |
| **Action** | Documenter le comportement dans `reference/integrity-sh.md` |

### 3.5 Dossier avec un seul fichier

| | |
|---|---|
| **Input** | Un seul fichier dans le dossier |
| **Comportement attendu** | Base de 1 ligne, verify OK |
| **Risque** | Comportement des algorithmes de tri et de comparaison sur des ensembles minimaux |
| **Testé par** | Partiellement par T01 — à vérifier explicitement |

---

## Catégorie 4 — Fichiers `.b3`

### 4.1 Base avec une seule ligne

| | |
|---|---|
| **Input** | `.b3` contenant exactement 1 ligne valide |
| **Comportement attendu** | `core_assert_b3_valid` accepte, `verify` fonctionne |
| **Risque** | `comm`, `join` se comportent différemment sur des fichiers à 1 ligne |
| **Testé par** | Non testé explicitement |

### 4.2 Base avec chemins contenant des espaces

| | |
|---|---|
| **Input** | `.b3` dont les chemins contiennent des espaces |
| **Comportement attendu** | `core_compare` gère correctement (offset fixe 67 dans `awk`) |
| **Risque** | Parsing par champ espace-séparé casse le join — bug historique v0.7 |
| **Testé par** | T08 (existant) + CU42/CU43 (unitaires) |

### 4.3 Base avec caractère tabulation dans un chemin

| | |
|---|---|
| **Input** | Chemin contenant `\t` dans le `.b3` |
| **Comportement attendu** | Comportement à définir — `_b3_to_path_hash` utilise `\t` comme séparateur de conversion |
| **Risque** | Corruption du parsing `chemin\thash` si le chemin contient lui-même un `\t` |
| **Testé par** | Non testé — **bug potentiel non investigué** |
| **Action** | Investiguer, documenter le comportement, ajouter un test ou une contrainte explicite |

### 4.4 Deux bases avec des ordres de tri différents

| | |
|---|---|
| **Input** | `old.b3` trié selon `LC_ALL=fr_FR`, `new.b3` trié selon `LC_ALL=C` |
| **Comportement attendu** | `comm` nécessite que les deux fichiers soient triés selon le même ordre |
| **Risque** | Faux positifs ou faux négatifs dans `compare` si les bases ont été produites avec des locales différentes |
| **Testé par** | Non testé |
| **Décision** | Documenter que `compute` doit être exécuté avec `LC_ALL=C` ou équivalent pour garantir la reproductibilité |

---

## Catégorie 5 — Environnement et configuration

### 5.1 `RESULTATS_DIR` avec espaces dans le chemin

| | |
|---|---|
| **Input** | `export RESULTATS_DIR="/tmp/mon dossier/resultats"` |
| **Comportement attendu** | Dossier créé correctement, résultats écrits |
| **Risque** | `mkdir -p` avec un chemin non quoté |
| **Testé par** | Non testé |

### 5.2 `RESULTATS_DIR` non accessible (permissions)

| | |
|---|---|
| **Input** | `RESULTATS_DIR="/root/resultats"` depuis un utilisateur non-root |
| **Comportement attendu** | `core_make_result_dir` lève une erreur explicite via `die()` |
| **Risque** | Erreur cryptique de `mkdir` sans message d'erreur lisible |
| **Testé par** | Non testé |

### 5.3 Appel depuis un répertoire différent du compute

| | |
|---|---|
| **Input** | `compute` lancé depuis `/mnt/data`, `verify` lancé depuis `/home/user` sans argument `[dossier]` |
| **Comportement attendu** | `b3sum --check` échoue (chemins relatifs résolus depuis mauvais répertoire) |
| **Risque** | Confusion utilisateur — tous les fichiers semblent manquants |
| **Testé par** | T14 (partiellement) |
| **Action** | Ajouter un message d'erreur plus explicite dans ce cas de figure |

---

## Tableau de priorité

| Cas | Priorité | Risque réel | Action |
|---|---|---|---|
| Tabulation dans le nom (1.4) | **Haute** | Bug potentiel confirmé dans `_b3_to_path_hash` | Investiguer + tester |
| Fichier taille zéro (2.1) | Haute | Division par zéro ETA | T18 + CU23 |
| Caractères HTML (1.5) | Haute | Injection dans rapport | T16 |
| Newline dans le nom (1.3) | Haute | Comptage incorrect | T15 |
| Espaces multiples (1.2) | Moyenne | Faux positifs dans compare | T15b |
| Lien symbolique (3.4) | Moyenne | Comportement surprenant non documenté | T19 + doc |
| `RESULTATS_DIR` avec espaces (5.1) | Moyenne | Crash silencieux | Test à créer |
| Fichier très volumineux (2.2) | Faible | Couvert par bash 64-bit integers | Documenté, non testé |
