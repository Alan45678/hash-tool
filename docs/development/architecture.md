# Architecture

## Structure du code
```
hash-tool          -> wrapper CLI (point d'entrée utilisateur)
runner.sh          -> exécuteur de pipelines JSON
src/
  integrity.sh     -> moteur principal (compute, verify, compare)
  lib/
    core.sh        -> fonctions de calcul et vérification BLAKE3
    results.sh     -> écriture des fichiers de résultats
    report.sh      -> génération du rapport HTML
    ui.sh          -> affichage terminal (couleurs, formatage, quiet mode)
```

## Rôle de chaque module
`hash-tool` : abstraction de la couche d'exécution (natif/Docker), parsing
des arguments CLI, sidecar, dispatch vers `integrity.sh` ou `runner.sh`.
`integrity.sh` : orchestration des opérations, appel des fonctions de `src/lib/`.
`core.sh` : appels b3sum, lecture/écriture des `.b3`, logique de diff.
`results.sh` : écriture de `recap.txt`, `failed.txt`, `modifies.b3`, etc.
`report.sh` : injection des données dans `reports/template.html`.
`ui.sh` : fonctions `say`, couleurs ANSI, respect du flag `QUIET`.

## Flux d'exécution natif
`hash-tool compute` -> `cmd_compute()` -> `_run_integrity()` -> `bash integrity.sh compute`
-> `core.sh:compute_hashes()` -> b3sum -> écriture `.b3` -> `_sidecar_write()`.

## Flux d'exécution Docker
`hash-tool compute` -> `cmd_compute()` -> `_run_integrity()` -> `_run_docker_integrity()`
-> calcul des volumes à monter -> `docker run hash_tool compute /data /bases/hashes.b3`.

## Conventions de code
Bash strict mode (`set -euo pipefail`) dans tous les scripts. Fonctions internes
préfixées `_`. Commandes CLI préfixées `cmd_`. Contrats d'entrée/sortie
documentés en tête de chaque fonction dans `src/lib/`.
