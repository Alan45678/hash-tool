# Changelog — hash_tool / integrity.sh

## [0.7] — Robustesse compare : chemins avec espaces

### Corrigé
- `integrity.sh`
  - Bug critique dans `run_compare()` : `sort -k2,2`, `join -1 2 -2 2` et `awk '{print $2}'` utilisent le blanc comme séparateur de champ. Un chemin contenant des espaces est fragmenté en plusieurs champs, ce qui corrompt le tri, le join et l'extraction — produisant des faux positifs massifs (ex. 26569 modifiés pour 163 fichiers dont 1 seul a changé).
  - Correction : conversion préalable de chaque ligne en `chemin\thash` via `awk '{ print substr($0,67) "\t" substr($0,1,64) }'` — le hash b3sum étant toujours exactement 64 caractères, l'offset 67 est garanti par le format. Toutes les opérations suivantes utilisent `-t $'\t'` comme séparateur explicite : `sort -t $'\t' -k1,1`, `join -t $'\t' -1 1 -2 1`, `cut -f1`.
  - `modifies.b3` : format de sortie préservé (`hash  chemin`) via `awk -F $'\t' '$2 != $3 { print $3 "  " $1 }'`.

## [0.6] — Robustesse et mode silencieux

### Ajouté
- `integrity.sh`
  - Flag `--quiet` : supprime toute sortie terminal, écrit uniquement dans les fichiers de résultats (`recap.txt`, `failed.txt`). Exit code propagé pour usage CI/cron.
  - Fonction `say()` : point d'entrée unique pour toute sortie terminal, désactivée si `--quiet`.
  - Fonction `file_size()` : abstraction portable `stat -c%s` (GNU/Linux) / `stat -f%z` (BSD/macOS).
  - Vérification version bash en tête de script : `bash >= 4` requis, exit explicite avec message si non respecté.
  - `make_result_dir()` : horodatage automatique des dossiers de résultats en cas de collision (`_YYYYMMDD-HHMMSS`), plus d'écrasement silencieux.
  - `trap EXIT` dans `run_compare()` : nettoyage garanti des fichiers temporaires même en cas d'erreur intermédiaire.
  - Redirection ETA sur `/dev/tty` dans `compute_with_progress()` : garantit que la progression n'est jamais écrite dans le fichier `.b3`.
- `tests/run_tests.sh`
  - `set -euo pipefail` : mode strict complet activé (ajout de `-e`).
  - Fonction `assert_file_absent()` : helper dédié pour les assertions d'absence de fichier.
  - T00 : ShellCheck sur `integrity.sh` et `run_tests.sh` (SKIP propre si non installé).
  - T12 : couverture exhaustive du mode `--quiet` (stdout vide, fichiers produits, exit code propagé).
  - T13 : vérifie l'horodatage automatique des dossiers de résultats sur collision.
  - T14 : détection d'un argument `[dossier]` invalide pour `verify`.
- `README.md`
  - Section `--quiet` avec exemples CI/cron.
  - Section Tests avec instructions d'exécution et comptage des cas (14 tests).
  - Mention horodatage automatique dans l'arborescence des résultats.

### Modifié
- `integrity.sh`
  - `assert_target_valid()` : `find -print0 | grep -zc ''` au lieu de `find | wc -l` — robuste aux noms de fichiers contenant des newlines.
  - `run_verify()` : comptage de lignes via `grep -c '^'` au lieu de `grep -c '.'` — correction du bug de comptage sur flux vide.
  - `run_compare()` : `sort -k2,2` au lieu de `sort -k2` — clé de tri limitée strictement au champ chemin, sans déborder sur le hash.
  - `run_verify()` : propagation de l'exit code de `b3sum --check` via `return $exit_code` — utilisable en scripting avec `|| alert`.
  - `failed.txt` : suppression explicite via `rm -f` si `nb_failed == 0` après une vérification OK suivant un échec précédent.
- `tests/run_tests.sh`
  - Résolution dynamique des `outdir` via `ls -d ... | tail -1` : compatible avec l'horodatage des dossiers de résultats.
  - T02, T03, T05, T06, T07 : assertions adaptées à la résolution dynamique des dossiers.
- `README.md`
  - Dépendances : mention explicite de `bash >= 4`.
  - Usage : exemple `--quiet` ajouté.

### Corrigé
- `integrity.sh`
  - Bug comptage lignes dans `run_verify()` : `grep -c '.'` sur flux vide retournait 0 mais ne capturait pas correctement les lignes non vides. Remplacé par `grep -c '^'`.
  - Bug tri ambigü dans `run_compare()` : `sort -k2` triait du champ 2 à la fin de ligne, incluant potentiellement le hash. `sort -k2,2` limite la clé au seul champ 2.
  - Bug nettoyage tmpfiles : `run_compare()` laissait des fichiers temporaires en cas d'erreur intermédiaire. Ajout de `trap 'rm -f ...' EXIT`.
  - Bug portabilité `stat` : `stat -c%s` est GNU-only. Ajout de `file_size()` avec fallback BSD `stat -f%z`.
  - Bug comptage fichiers avec newlines : `assert_target_valid()` utilisait `find | wc -l`. Corrigé avec `find -print0 | grep -zc ''`.
- `tests/run_tests.sh`
  - T10 : pattern `"^/"` remplacé par `"  /"` — `grep` opérait sur une chaîne, l'ancre `^` ne matchait pas la deuxième colonne.

---

## [0.5] — Documentation

### Modifié
- `README.md` — règle répertoire de travail pour `verify` précisée : l'argument `[dossier]` est le répertoire d'origine du compute, pas le dossier haché. Exemples correct/incorrect ajoutés.
- `docs/manuel.md` — section `verify` mise à jour avec le même avertissement et les exemples.

---

## [0.4] — Gardes-fous et signalisation des erreurs

### Modifié
- `integrity.sh`
  - Ajout de `die()` : point de sortie unique pour toutes les erreurs, message sur stderr.
  - Ajout de `assert_b3_valid()` : vérifie existence, type fichier, non-vide, format b3sum valide.
  - Ajout de `assert_target_valid()` : vérifie existence du dossier cible et présence d'au moins un fichier.
  - Validation explicite des arguments dans chaque branche du `case` avant tout traitement.
  - `verify` accepte un argument optionnel `[dossier]` : fait `cd` avant `b3sum --check`.
  - Résolution du chemin absolu du `.b3` avant `cd` (correction bug : chemin relatif invalide après changement de répertoire).
  - `RESULTATS_DIR` : `${RESULTATS_DIR:-...}` au lieu d'assignation inconditionnelle — respecte la valeur exportée par l'environnement (fix tests).
  - Suppression de `local hashfile_abs` hors fonction (illégal en bash hors contexte fonction).
  - `run_verify()` : refonte de la signalisation.
    - Trois états distincts : `OK`, `ECHEC`, `ERREUR`.
    - Terminal : affichage sobre si OK, bloc `████` visible si échec ou erreur.
    - `recap.txt` : compteur `FAILED` affiché uniquement si > 0 ; section erreurs b3sum séparée.
    - `failed.txt` : créé uniquement si `nb_failed > 0` ou erreurs b3sum présentes. Supprimé si tout est OK.
- `tests/run_tests.sh`
  - T02 : assertion `failed.txt absent si 0 échec` (logique inversée par rapport à l'ancienne version).
  - T03 : patterns mis à jour (`ECHEC`, `FAILED`) alignés sur le nouveau format de sortie.

---

## [0.3] — Dossiers de résultats (verify et compare)

### Modifié
- `integrity.sh`
  - Ajout de `RESULTATS_DIR` (configurable, défaut `~/integrity_resultats`).
  - Ajout de `make_result_dir()` : crée `resultats_<nom_base>/` sous `RESULTATS_DIR`.
  - `verify` : délègue à `run_verify()` — produit `recap.txt` et `failed.txt`.
  - `compare` : délègue à `run_compare()` — produit `recap.txt`, `modifies.b3`, `disparus.txt`, `nouveaux.txt`.
  - Fichiers temporaires de `compare` passent par `mktemp` (plus de `/tmp/_old.b3` en dur).
  - Signature `verify` simplifiée : `<base.b3>` uniquement (le dossier n'était pas utilisé par `b3sum --check`).
- `README.md` — usage `verify` et `compare` mis à jour ; section Configuration ajoutée avec arbre des fichiers produits.
- `docs/manuel.md` — sections `verify` et `compare` mises à jour ; arbre de décision et référence rapide alignés.
- `tests/run_tests.sh`
  - `RESULTATS_DIR` exporté vers `WORKDIR` pour isoler les résultats des tests.
  - Ajout de `assert_file_exists()`.
  - T02–T07 : assertions sur la présence et le contenu des fichiers de résultats.

---

## [0.2] — Intégration ETA et tests automatisés

### Modifié
- `integrity.sh`
  - Suppression de `detect_parallelism()` et de la logique SSD/parallélisme (hors périmètre HDD gros volumes).
  - Mode `compute` : délègue à `compute_with_progress()`.
  - Ajout de `compute_with_progress()` : boucle fichier par fichier avec affichage progression et ETA.
    - `mapfile -d ''` remplace `FILES=($(find ...))` — gestion correcte des noms avec espaces.
    - `printf "\r%*s\r"` efface proprement la ligne de progression avant le message final.
  - `df` retiré des dépendances.
- `README.md` — dépendances mises à jour (`df` supprimé, `stat` et `du` ajoutés).
- `docs/manuel.md`
  - Section `detect_parallelism` supprimée.
  - Section `compute` réécrite autour de `compute_with_progress`.
  - Section performances : stratégie SSD/NVMe retirée, focus HDD séquentiel.
- `docs/progression-eta.md` — implémentation finale documentée ; note `mapfile -d ''` vs substitution de commande.
- `tests/run_tests.sh` — T11 ajouté : vérifie que la base produite par `compute_with_progress` est bit-à-bit identique à une base de référence, sans artefact ETA ni `\r`.
- `docs/explication-run-tests.md` — comptage corrigé (10 → 11 cas) ; section T11 ajoutée.

### Corrigé
- `tests/run_tests.sh` T10 : pattern `"^/"` remplacé par `"  /"` — `grep` opère sur une chaîne, pas un fichier, l'ancre `^` ne matchait pas la deuxième colonne.

---

## [0.1] — Structure initiale du projet

### Ajouté
- `integrity.sh` — script principal BLAKE3 avec trois modes : `compute`, `verify`, `compare`.
  - `set -euo pipefail` — mode strict.
  - `detect_parallelism()` — détection SSD/HDD via `/sys/block/.../queue/rotational`.
  - Mode `compute` : pipeline `find | sort -z | xargs b3sum`, parallélisme `-P 4` sur SSD.
  - Mode `verify` : délègue à `b3sum --check`.
  - Mode `compare` : tri sur colonne 2, `join` pour les modifiés, `comm` pour disparus/nouveaux, rapport `tee`.
- `README.md` — point d'entrée : dépendances, usage en 3 commandes, arbre de décision, règles critiques.
- `docs/manuel.md` — référence technique complète : algorithmes, structure `.b3`, workflow, explication du script, performances, limites, référence rapide, annexe FIM.
- `docs/progression-eta.md` — analyse du problème ETA sur pipeline `xargs`, deux approches (`pv` invalide, boucle bash), mécanique de l'estimation, tableau de comparaison des performances.
- `docs/explication-run-tests.md` — documentation du code `run_tests.sh` : chemins, compteurs, assertions, setup/teardown, structure d'un cas de test, prérequis, exit code CI.
- `tests/run_tests.sh` — suite de tests automatisée bash pur, 11 cas T01–T11, isolation via `mktemp`, teardown systématique, exit code CI-compatible.
- `tests/validation.md` — protocole de test manuel : 10 cas T01–T10 avec commandes exactes et résultats attendus, critères de qualité globaux.