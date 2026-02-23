# Référence — integrity.sh

Script principal de vérification d'intégrité BLAKE3.

**Emplacement :** `src/integrity.sh`

---

## Synopsis

```
integrity.sh [--quiet] <mode> [arguments...]

Modes :
  compute <dossier> <base.b3>
  verify  <base.b3> [dossier]
  compare <ancienne.b3> <nouvelle.b3>
```

---

## Options globales

### `--quiet`

Supprime toute sortie terminal. Écrit uniquement dans les fichiers de résultats (`recap.txt`, `failed.txt`, `report.html`). L'exit code est conservé.

```bash
./src/integrity.sh --quiet verify base.b3
echo $?   # 0 = OK, 1 = ECHEC ou ERREUR
```

**Usage type :** intégration CI, cron, scripts parents qui gèrent eux-mêmes la sortie.

!!! warning
    En mode `--quiet`, la progression ETA est également supprimée pendant `compute`.

---

## Mode `compute`

Calcule les hashes BLAKE3 de tous les fichiers d'un dossier et les enregistre dans un fichier `.b3`.

### Syntaxe

```bash
./src/integrity.sh compute <dossier> <base.b3>
```

### Arguments

| Argument | Type | Description |
|---|---|---|
| `<dossier>` | chemin | Dossier à indexer. Relatif ou absolu, mais **préférer relatif** (voir avertissement ci-dessous). |
| `<base.b3>` | chemin fichier | Fichier de sortie. Créé ou écrasé. Ne doit pas être un dossier existant. |

### Comportement

1. Valide que `<dossier>` existe et contient au moins un fichier.
2. Parcourt récursivement `<dossier>` avec `find -type f`.
3. Trie les chemins (`sort -z`) pour garantir un ordre déterministe.
4. Calcule le hash BLAKE3 de chaque fichier avec `b3sum`.
5. Affiche la progression et l'ETA sur `/dev/tty` (jamais dans le `.b3`).
6. Enregistre les résultats dans `<base.b3>`.

### Format du fichier `.b3`

```
<hash_64_chars>  <chemin>
```

Deux espaces entre le hash et le chemin — convention `b3sum`/`sha256sum`.

```
a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2  ./dossier/fichier.txt
e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6  ./dossier/sous/autre.bin
```

!!! danger "Règle absolue : chemins relatifs"
    Toujours passer un chemin relatif (`.` ou `./sous-dossier`) comme `<dossier>`. Un chemin absolu rend la base inutilisable si les données sont déplacées ou remontées sur un point de montage différent.

    ```bash
    # Correct — chemin relatif dans la base
    cd /mnt/a/mes_donnees
    ./src/integrity.sh compute . /mnt/c/bases/hashes.b3

    # Incorrect — chemin absolu, base non portable
    ./src/integrity.sh compute /mnt/a/mes_donnees /mnt/c/bases/hashes.b3
    ```

    `runner.sh` gère ce `cd` automatiquement.

### Progression ETA

Affichée sur `/dev/tty` pendant le calcul, **jamais** dans le fichier `.b3` :

```
[47/142] ETA : 2m 34s
```

L'ETA converge après ~10–20 secondes. Instable avant ce seuil — comportement normal, inhérent à l'extrapolation linéaire.

### Exit codes

| Code | Signification |
|---|---|
| `0` | Base calculée avec succès |
| `1` | Erreur (dossier introuvable, dossier vide, argument manquant) |

### Exemples

```bash
# Indexer le répertoire courant
./src/integrity.sh compute . hashes_$(date +%Y-%m-%d).b3

# Indexer un sous-dossier
./src/integrity.sh compute ./archives hashes_archives.b3

# Mode silencieux (pas d'ETA affiché)
./src/integrity.sh --quiet compute . hashes.b3
```

---

## Mode `verify`

Vérifie que les fichiers correspondent aux hashes stockés dans la base `.b3`.

### Syntaxe

```bash
./src/integrity.sh verify <base.b3> [dossier]
```

### Arguments

| Argument | Type | Description |
|---|---|---|
| `<base.b3>` | chemin fichier | Base de hashes à utiliser pour la vérification. |
| `[dossier]` | chemin (optionnel) | Répertoire de travail à utiliser. Si absent, utilise le `pwd` courant. |

### Comportement

1. Valide que `<base.b3>` est un fichier non vide au format b3sum valide.
2. Si `[dossier]` est fourni, fait `cd` dans ce dossier avant vérification.
3. Résout le chemin absolu de `<base.b3>` **avant** le `cd` (évite l'invalidation du chemin relatif après changement de répertoire).
4. Lance `b3sum --check <base.b3>`.
5. Écrit les résultats dans `$RESULTATS_DIR/resultats_<nom_base>/`.

!!! warning "Répertoire de travail"
    `b3sum --check` résout les chemins relatifs depuis le `pwd`. Il faut impérativement lancer `verify` depuis le même répertoire qu'au `compute` — ou passer ce répertoire en second argument.

    ```bash
    # Cas 1 : on est dans le bon répertoire
    cd /mnt/a/mes_donnees
    ./src/integrity.sh verify /mnt/c/bases/hashes.b3

    # Cas 2 : on est ailleurs, on passe le répertoire d'origine
    ./src/integrity.sh verify /mnt/c/bases/hashes.b3 /mnt/a/mes_donnees
    ```

### Fichiers produits

Créés dans `$RESULTATS_DIR/resultats_<nom_base>/` (horodaté si le dossier existe déjà) :

| Fichier | Présence | Contenu |
|---|---|---|
| `recap.txt` | Toujours | Statut global, compteurs OK/FAILED, erreurs b3sum |
| `failed.txt` | Si échec seulement | Liste des fichiers FAILED ou en erreur |

### Statuts de sortie terminal

| Statut | Condition | Affichage |
|---|---|---|
| `OK` | Zéro FAILED, zéro erreur | Message sobre une ligne |
| `ECHEC` | Au moins un FAILED | Bloc `████` visible, liste des fichiers |
| `ERREUR` | Erreur b3sum non liée aux hashes | Bloc `████` visible, détail erreur |

### Exit codes

| Code | Signification |
|---|---|
| `0` | Tous les fichiers intègres |
| `1` | Au moins un FAILED ou erreur b3sum |

### Exemples

```bash
# Vérification depuis le bon répertoire
cd /mnt/a/mes_donnees
./src/integrity.sh verify /mnt/c/bases/hashes.b3

# Vérification depuis n'importe où avec dossier explicite
./src/integrity.sh verify /mnt/c/bases/hashes.b3 /mnt/a/mes_donnees

# En CI — arrêt immédiat sur échec
./src/integrity.sh --quiet verify hashes.b3 || exit 1
```

---

## Mode `compare`

Compare deux bases `.b3` et identifie les fichiers modifiés, disparus et nouveaux.

### Syntaxe

```bash
./src/integrity.sh compare <ancienne.b3> <nouvelle.b3>
```

### Arguments

| Argument | Type | Description |
|---|---|---|
| `<ancienne.b3>` | chemin fichier | Base de référence (snapshot antérieur). |
| `<nouvelle.b3>` | chemin fichier | Base à comparer (snapshot récent). |

### Comportement

1. Valide les deux fichiers `.b3`.
2. Convertit chaque ligne `hash  chemin` en `chemin\thash` (séparateur tab) via `awk` avec offset fixe 64 chars — robuste aux chemins avec espaces.
3. Trie par chemin.
4. `join` sur le chemin : identifie les fichiers présents dans les deux bases → les modifiés (hashes différents).
5. `comm` sur les chemins : identifie les disparus (dans A, pas dans B) et les nouveaux (dans B, pas dans A).
6. Génère les fichiers de résultats et le rapport HTML.

### Fichiers produits

Créés dans `$RESULTATS_DIR/resultats_<nom_ancienne_base>/` :

| Fichier | Contenu |
|---|---|
| `recap.txt` | Commande, date, bases, compteurs modifiés/disparus/nouveaux |
| `modifies.b3` | Fichiers présents dans les deux bases avec hashes différents. Format : `nouveau_hash  chemin` |
| `disparus.txt` | Chemins présents dans `<ancienne.b3>` et absents de `<nouvelle.b3>` |
| `nouveaux.txt` | Chemins absents de `<ancienne.b3>` et présents dans `<nouvelle.b3>` |
| `report.html` | Rapport visuel autonome (CSS inline, sans dépendance externe) |

### Rapport HTML

Thème sombre, lisible hors ligne. Contient :

- Badge statut : `IDENTIQUES` (vert) ou `DIFFÉRENCES DÉTECTÉES` (orange)
- Compteurs par catégorie
- Listes détaillées des fichiers affectés

### Exit codes

| Code | Signification |
|---|---|
| `0` | Comparaison effectuée (qu'il y ait des différences ou non) |
| `1` | Erreur (fichier introuvable, format invalide) |

!!! note
    `compare` retourne `0` même si des différences sont détectées. C'est voulu : la présence de différences n'est pas une erreur, c'est une information. Pour détecter des différences en script, lire `recap.txt` ou vérifier si `modifies.b3`, `disparus.txt` ou `nouveaux.txt` sont non vides.

### Exemples

```bash
# Comparaison de deux snapshots
./src/integrity.sh compare hashes_2024-01.b3 hashes_2024-02.b3

# Avec destination personnalisée (via variable d'env)
RESULTATS_DIR=/srv/rapports ./src/integrity.sh compare old.b3 new.b3
```

---

## Variable d'environnement

### `RESULTATS_DIR`

Dossier racine où sont créés les sous-dossiers de résultats.

| | |
|---|---|
| **Défaut** | `~/integrity_resultats` |
| **Scope** | `verify` et `compare` |
| **Priorité** | Variable d'environnement > valeur par défaut dans le script |

```bash
# Export global
export RESULTATS_DIR=/srv/rapports/integrity
./src/integrity.sh verify hashes.b3

# Surcharge ponctuelle
RESULTATS_DIR=/tmp/test ./src/integrity.sh compare a.b3 b.b3
```

`runner.sh` peut surcharger `RESULTATS_DIR` pour un bloc `compare` spécifique via le champ `resultats` du pipeline — sans affecter les autres blocs.

---

## Horodatage automatique des résultats

Si `$RESULTATS_DIR/resultats_<nom_base>` existe déjà lors d'un nouvel appel, un suffixe horodaté est ajouté automatiquement :

```
~/integrity_resultats/
├── resultats_hashes_2024-01/
├── resultats_hashes_2024-01_20240215-143022/
└── resultats_hashes_2024-01_20240301-091547/
```

Aucun résultat n'est jamais écrasé silencieusement.

---

## Limites connues

| Scénario | Détecté ? | Remarque |
|---|---|---|
| Contenu de fichier modifié | **Oui** | Hash différent |
| Fichier supprimé | **Oui** | FAILED (verify) ou DISPARUS (compare) |
| Fichier ajouté | **Oui** (compare) | Section NOUVEAUX |
| Dossier vide | **Non** | `find -type f` ignore les dossiers vides |
| Permissions / timestamps | **Non** | Seul le contenu binaire est haché |
| Fichier renommé | **Non** | Vu comme suppression + ajout |
| Clone bit-à-bit | **Non** | Hash identique par définition |
| Corruption de la base `.b3` | **Non** | La base n'est pas auto-protégée |

### Protéger la base `.b3`

```bash
# Calculer le hash de la base elle-même
b3sum hashes.b3 > hashes.b3.check

# Vérifier la base avant usage
b3sum --check hashes.b3.check
```

### Gérer les renommages

```bash
# Mettre à jour les chemins dans la base après renommage
sed 's|./ancien_nom/|./nouveau_nom/|g' hashes.b3 > hashes_corrige.b3
b3sum --check hashes_corrige.b3
```

---

## Dépendances techniques

| Outil | Usage |
|---|---|
| `b3sum` | Calcul et vérification des hashes BLAKE3 |
| `find` | Parcours récursif du dossier |
| `sort` | Tri déterministe des chemins |
| `awk` | Conversion format `hash chemin` ↔ `chemin\thash` |
| `join` | Identification des fichiers modifiés (inner join sur le chemin) |
| `comm` | Identification des disparus et nouveaux (set difference) |
| `stat` | Taille de fichier pour le calcul ETA |
| `du` | Taille totale du dossier pour le calcul ETA |
| `mktemp` | Fichiers temporaires isolés dans `compare` |
