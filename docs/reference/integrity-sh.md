# Référence - integrity.sh

Script principal de vérification d'intégrité BLAKE3.

**Emplacement :** `src/integrity.sh`  
**Architecture :** dispatcher CLI - orchestre `src/lib/core.sh`, `src/lib/ui.sh`, `src/lib/results.sh`, `src/lib/report.sh`

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
| `<dossier>` | chemin | Dossier à indexer. Relatif ou absolu, mais **préférer relatif** (voir ci-dessous). |
| `<base.b3>` | chemin fichier | Fichier de sortie. Créé ou écrasé. Ne doit pas être un dossier existant. |

### Comportement

1. Valide que `<dossier>` existe et contient au moins un fichier régulier (`core_assert_target_valid`)
2. Parcourt récursivement avec `find -type f -print0 | sort -z`
3. Calcule le hash BLAKE3 de chaque fichier avec `b3sum` (via `core_compute`)
4. Affiche la progression et l'ETA sur `/dev/tty` via callback `ui_progress_callback`
5. Enregistre les résultats dans `<base.b3>`

### Format du fichier `.b3`

Voir la [spécification complète](../spec/b3-format.md). Format synthétique :

```
<hash_64_chars>  <chemin>
```

!!! danger "Règle absolue : chemins relatifs"
    Toujours passer un chemin relatif (`.` ou `./sous-dossier`) comme `<dossier>`.

    ```bash
    # Correct - chemin relatif dans la base
    cd /mnt/a/mes_donnees
    ./src/integrity.sh compute . /mnt/c/bases/hashes.b3

    # Incorrect - chemin absolu, base non portable
    ./src/integrity.sh compute /mnt/a/mes_donnees /mnt/c/bases/hashes.b3
    ```

    `runner.sh` gère ce `cd` automatiquement.

### Exit codes

| Code | Signification |
|---|---|
| `0` | Base calculée avec succès |
| `1` | Erreur (dossier introuvable, dossier vide, argument manquant) |

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

1. Valide le fichier `.b3` (`core_assert_b3_valid`) - toutes les lignes doivent être au format b3sum
2. Résout le chemin absolu de `<base.b3>` **avant** le `cd`
3. Si `[dossier]` est fourni, fait `cd` dans ce dossier
4. Lance `b3sum --check` via `core_verify()`
5. Écrit les résultats dans `$RESULTATS_DIR/resultats_<nom_base>/`

!!! warning "Répertoire de travail"
    `b3sum --check` résout les chemins relatifs depuis le `pwd`. Lancer `verify` depuis le même répertoire qu'au `compute` - ou passer ce répertoire en second argument.

    ```bash
    # Cas 1 : on est dans le bon répertoire
    cd /mnt/a/mes_donnees
    ./src/integrity.sh verify /mnt/c/bases/hashes.b3

    # Cas 2 : on est ailleurs
    ./src/integrity.sh verify /mnt/c/bases/hashes.b3 /mnt/a/mes_donnees
    ```

### Fichiers produits

Créés dans `$RESULTATS_DIR/resultats_<nom_base>/` (horodaté si le dossier existe déjà) :

| Fichier | Présence | Contenu |
|---|---|---|
| `recap.txt` | Toujours | Statut global, compteurs OK/FAILED, erreurs b3sum |
| `failed.txt` | Si échec seulement | Liste des fichiers FAILED ou en erreur |

### Exit codes

| Code | Signification |
|---|---|
| `0` | Tous les fichiers intègres |
| `1` | Au moins un FAILED ou erreur b3sum |

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

### Fichiers produits

Créés dans `$RESULTATS_DIR/resultats_<nom_ancienne_base>/` :

| Fichier | Contenu |
|---|---|
| `recap.txt` | Commande, date, bases, compteurs |
| `modifies.b3` | Fichiers présents dans les deux bases avec hashes différents. Format : `nouveau_hash  chemin` |
| `disparus.txt` | Chemins présents dans `<ancienne.b3>` et absents de `<nouvelle.b3>` |
| `nouveaux.txt` | Chemins absents de `<ancienne.b3>` et présents dans `<nouvelle.b3>` |
| `report.html` | Rapport visuel autonome (CSS inline) |

### Exit codes

| Code | Signification |
|---|---|
| `0` | Comparaison effectuée (qu'il y ait des différences ou non) |
| `1` | Erreur (fichier introuvable, format invalide) |

!!! note
    `compare` retourne `0` même si des différences sont détectées. La présence de différences est une information, pas une erreur. Pour détecter des différences en script, vérifier si `modifies.b3`, `disparus.txt` ou `nouveaux.txt` sont non vides.

---

## Variable d'environnement

### `RESULTATS_DIR`

| | |
|---|---|
| **Défaut** | `~/integrity_resultats` |
| **Scope** | `verify` et `compare` |

```bash
export RESULTATS_DIR=/srv/rapports/integrity
./src/integrity.sh verify hashes.b3
```

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
b3sum hashes.b3 > hashes.b3.check
b3sum --check hashes.b3.check
```

---

## Dépendances techniques

| Outil | Usage |
|---|---|
| `b3sum` | Calcul et vérification des hashes BLAKE3 |
| `find` | Parcours récursif du dossier |
| `sort` | Tri déterministe des chemins |
| `awk` | Conversion format `hash chemin` ↔ `chemin\thash` |
| `join` | Identification des fichiers modifiés |
| `comm` | Identification des disparus et nouveaux |
| `stat` | Taille de fichier pour le calcul ETA |
| `du` | Taille totale du dossier pour le calcul ETA |
| `mktemp` | Fichiers temporaires isolés dans `compare` |
