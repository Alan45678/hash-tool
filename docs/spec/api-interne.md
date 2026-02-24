# API interne - Contrats des modules

**Scope :** développeurs contribuant au code de hash_tool  
**Référence d'implémentation :** `src/lib/core.sh`, `src/lib/ui.sh`, `src/lib/results.sh`, `src/lib/report.sh`

---

## Architecture des modules

```
integrity.sh  (dispatcher CLI)
    │
    ├== src/lib/core.sh      Logique métier pure
    │   Entrées : chemins, fichiers .b3
    │   Sorties : fichiers .b3, variables CORE_*, fichiers de résultats partiels
    │   Aucune sortie terminal directe
    │
    ├== src/lib/ui.sh        Interface terminal
    │   Entrées : données structurées issues de core.*
    │   Sorties : stdout / /dev/tty
    │   Aucune logique métier
    │
    ├== src/lib/results.sh   Écriture fichiers de résultats
    │   Entrées : données structurées + chemin outdir
    │   Sorties : recap.txt, failed.txt sur disque
    │   Aucune sortie terminal directe
    │
    └== src/lib/report.sh    Génération HTML
        Entrées : données structurées + fichiers de listes + chemin output
        Sorties : report.html sur disque
        Aucune sortie terminal directe
```

**Principe de séparation strict :** `core.sh` ne connaît pas `ui.sh`. `ui.sh` ne connaît pas `results.sh`. `integrity.sh` est le seul module qui orchestre l'ensemble.

---

## Module `core.sh`

### `core_assert_b3_valid(file, [label])`

| | |
|---|---|
| **Entrée** | `$1` chemin fichier .b3 ; `$2` label optionnel pour les messages |
| **Sortie** | exit 0 si valide ; exit 1 + message stderr sinon |
| **Effets** | aucun |
| **Invariants vérifiés** | existence, type fichier régulier, non vide, toutes les lignes au format `[0-9a-f]{64}  .+` |

### `core_assert_target_valid(dir)`

| | |
|---|---|
| **Entrée** | `$1` chemin dossier |
| **Sortie** | exit 0 si valide ; exit 1 + message stderr sinon |
| **Effets** | aucun |
| **Invariants vérifiés** | existence, type dossier, contient au moins un fichier régulier |

### `core_compute(target, hashfile, [callback])`

| | |
|---|---|
| **Entrée** | `$1` dossier cible ; `$2` fichier .b3 de sortie ; `$3` nom de fonction callback (optionnel) |
| **Sortie** | exit 0/1 ; `$2` contient le fichier .b3 |
| **Effets** | crée/écrase `$2` ; appelle `$3` après chaque fichier |
| **Signature callback** | `callback(i, total_files, bytes_done, total_bytes, eta_seconds)` |
| **Garantie** | aucune ligne de progression ne peut polluer `$2` |

### `core_verify(hashfile)`

| | |
|---|---|
| **Entrée** | `$1` chemin absolu du fichier .b3 ; répertoire courant = répertoire d'origine du compute |
| **Sortie** | exit 0 si OK ; exit 1 si FAILED/ERREUR |
| **Variables positionnées** | `CORE_VERIFY_RAW`, `CORE_VERIFY_LINES_OK`, `CORE_VERIFY_LINES_FAIL`, `CORE_VERIFY_LINES_ERR`, `CORE_VERIFY_NB_OK`, `CORE_VERIFY_NB_FAIL`, `CORE_VERIFY_STATUS` |
| **Effets** | aucun (pas d'écriture disque) |

### `core_compare(old, new, outdir)`

| | |
|---|---|
| **Entrée** | `$1` ancienne base .b3 ; `$2` nouvelle base .b3 ; `$3` dossier de sortie (doit exister) |
| **Sortie** | exit 0/1 |
| **Fichiers produits** | `$3/modifies.b3`, `$3/disparus.txt`, `$3/nouveaux.txt` |
| **Variables positionnées** | `CORE_COMPARE_NB_MOD`, `CORE_COMPARE_NB_DIS`, `CORE_COMPARE_NB_NOU` |
| **Effets** | écrit 3 fichiers dans `$3` ; utilise mktemp nettoyé via trap |

### `core_make_result_dir(b3file, resultats_dir)`

| | |
|---|---|
| **Entrée** | `$1` chemin .b3 (pour nommer le dossier) ; `$2` dossier racine des résultats |
| **Sortie** | stdout = chemin absolu du dossier créé |
| **Effets** | crée le dossier via mkdir -p |
| **Invariant anti-écrasement** | si le dossier existe, ajoute `_YYYYMMDD-HHMMSS` |

---

## Module `ui.sh`

### Prérequis

La variable `QUIET` doit être définie avant de sourcer `ui.sh` :
- `QUIET=0` - affichage normal
- `QUIET=1` - suppression totale de la sortie terminal

### `die(message)`

| | |
|---|---|
| **Entrée** | `$@` message |
| **Sortie** | exit 1 toujours ; stderr = "ERREUR : <message>" |
| **Note** | fonction globale utilisable depuis tous les modules |

### `say(message)`

| | |
|---|---|
| **Entrée** | `$@` message |
| **Sortie** | stdout si QUIET==0 ; rien si QUIET==1 |

### `ui_progress_callback(i, total_files, bytes_done, total_bytes, eta_seconds)`

| | |
|---|---|
| **Sortie** | `/dev/tty` si QUIET==0 ; rien si QUIET==1 |
| **Note** | écriture sur `/dev/tty` et non stdout - ne peut pas polluer les pipes |

### `ui_progress_clear()`

| | |
|---|---|
| **Sortie** | `/dev/tty` - efface la ligne de progression |

### `ui_show_verify_result(statut, nb_ok, nb_fail, lines_fail, lines_err, outdir)`

| | |
|---|---|
| **Sortie** | stdout si QUIET==0 |

### `ui_show_compare_result(nb_mod, nb_dis, nb_nou, outdir)`

| | |
|---|---|
| **Sortie** | stdout si QUIET==0 |

---

## Module `results.sh`

### `results_write_verify(outdir, hashfile, statut, nb_ok, nb_fail, lines_fail, lines_err)`

| | |
|---|---|
| **Sortie** | `outdir/recap.txt` toujours ; `outdir/failed.txt` si erreurs ; supprime `failed.txt` si OK |

### `results_write_compare(outdir, old, new, nb_mod, nb_dis, nb_nou)`

| | |
|---|---|
| **Sortie** | `outdir/recap.txt` |
| **Prérequis** | `outdir` contient déjà `modifies.b3`, `disparus.txt`, `nouveaux.txt` produits par `core_compare` |

---

## Règles de contribution au code

1. **Aucune sortie terminal dans `core.sh`** - toute communication utilisateur passe par les variables de sortie et les codes de retour
2. **Aucune logique métier dans `ui.sh`** - `ui.sh` formate et affiche, il ne calcule rien
3. **Tout chemin dans un .b3 est relatif** - `core_compute` ne vérifie pas cet invariant (responsabilité de l'appelant via `runner.sh` ou appel direct avec `cd`)
4. **Variables `CORE_*` déclarées `local` dans les appelants** si isolation requise entre appels successifs
5. **`die()` est disponible globalement** - sourcé via `ui.sh` qui est chargé en premier dans `integrity.sh`
