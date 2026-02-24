# Contribuer à hash_tool

---

## Prérequis

```bash
sudo apt install bash b3sum jq shellcheck
```

---

## Tests

```bash
cd tests && ./run_tests.sh
cd tests && ./run_tests_pipeline.sh
```

Zéro warning ShellCheck requis (T00). Tous les tests doivent passer avant soumission.

---

## Conventions de code

### Séparation des responsabilités

Le code est organisé en modules avec des responsabilités strictement séparées. Avant d'écrire du code, identifier dans quel module il appartient :

- **Logique métier** (hachage, vérification, comparaison) → `src/lib/core.sh`
- **Affichage terminal, progression** → `src/lib/ui.sh`
- **Écriture fichiers de résultats** → `src/lib/results.sh`
- **Génération HTML** → `src/lib/report.sh`
- **Orchestration CLI** → `src/integrity.sh`

Ne jamais écrire de sortie terminal dans `core.sh`. Ne jamais écrire de logique métier dans `ui.sh`.

### Contrats de fonction

Toute fonction non triviale doit documenter :
- Les entrées (`$1`, `$2`...)
- Les sorties (exit code, variables positionnées, fichiers créés)
- Les effets de bord
- Les invariants supposés et garantis

Voir `src/lib/core.sh` comme référence de format.

### Conventions bash

- `set -euo pipefail` dans tout script exécutable
- `"$@"` et guillemets systématiques - ShellCheck enforce ce point
- `local` pour toutes les variables de fonction
- `mktemp` pour les fichiers temporaires, nettoyés via `trap EXIT`
- Pas de `ls` dans les scripts - utiliser `find` ou glob

---

## Format des commits

Convention : [Conventional Commits](https://www.conventionalcommits.org/)

```
<type>(<scope>): <description courte>

[corps optionnel]

[footer optionnel]
```

Types :

| Type | Usage |
|---|---|
| `feat` | Nouvelle fonctionnalité |
| `fix` | Correction de bug |
| `refactor` | Refactoring sans changement de comportement |
| `test` | Ajout ou modification de tests |
| `docs` | Documentation uniquement |
| `chore` | Tâches de maintenance (CI, dépendances, etc.) |
| `perf` | Amélioration de performance |

Exemples :

```
feat(core): ajouter support des liens symboliques dans core_compute
fix(ui): corriger l'effacement de la ligne ETA sur terminal étroit
docs(spec): documenter le cas des fichiers de taille zéro dans b3-format.md
test(core): ajouter T15 - vérification comportement sur lien symbolique
```

## Philosophie de test

- Chaque test crée son propre répertoire temporaire isolé dans `/tmp` - pas d'effet de bord entre cas
- Les tests de corruption introduisent volontairement une modification puis vérifient la détection
- Les tests pipeline vérifient l'isolation des sous-shells (pas de fuite de répertoire courant entre blocs)
- Résultat coloré `PASS` / `FAIL` avec compteur final

## Contributions prioritaires

Par ordre de valeur décroissante :

- **GitHub Actions** - CI automatique sur push : `run_tests.sh` + `run_tests_pipeline.sh` + ShellCheck
- **`install.sh`** - script d'installation one-liner avec vérification des dépendances (`b3sum`, `jq`, `bash >= 4`)
- **`--format json`** - sortie machine-readable pour `verify` et `compare` (aujourd'hui : texte uniquement)
- **Rapport HTML** - enrichissement du contenu et de la mise en page

---

## Processus de release

1. **Vérifier que tous les tests passent** sur une machine propre
   ```bash
   cd tests && ./run_tests.sh && ./run_tests_pipeline.sh
   shellcheck src/integrity.sh runner.sh src/lib/*.sh docker/entrypoint.sh
   ```

2. **Mettre à jour `CHANGELOG.md`** avec la nouvelle version et les changements

3. **Mettre à jour la variable `VERSION`** dans `src/integrity.sh` et `runner.sh`

4. **Créer le tag git**
   ```bash
   git tag -a v0.15 -m "Release v0.15 - <description courte>"
   git push origin v0.15
   ```

5. **Créer la GitHub Release** avec le contenu du CHANGELOG correspondant et les checksums :
   ```bash
   b3sum src/integrity.sh runner.sh src/lib/*.sh
   ```

---

## Structure des tests

Les tests sont dans `tests/`. Deux suites indépendantes :

| Suite | Scope | Cas |
|---|---|---|
| `run_tests.sh` | `integrity.sh` | T00–T14 |
| `run_tests_pipeline.sh` | `runner.sh` + `pipeline.json` | TP01–TP12b |

### Ajouter un test

1. Identifier la suite concernée
2. Nommer le cas (T15, T16... ou TP13, TP14...)
3. Documenter : précondition, oracle de test (résultat attendu), postcondition
4. Le test doit être reproductible sur n'importe quelle machine disposant des prérequis
5. Le test ne doit pas dépendre de l'état du système hôte (pas de `/home/user/...`, pas de fichiers extérieurs au `WORKDIR`)

Voir `tests/run_tests.sh` pour la structure standard d'un cas de test.
