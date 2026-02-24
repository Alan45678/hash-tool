

## Plan de migration vers production-ready

### Jalon 1 — Assainissement immédiat 

Objectif : supprimer la dette visible, versionner, licencier

Délivrables :
- Ajout du fichier `LICENSE` (choix à faire : MIT ou GPL selon objectif)
- Variable `VERSION="0.14"` déclarée dans `integrity.sh` et `runner.sh`, exposée via `--version`
- Tag git `v0.14` sur le commit courant
- `CONTRIBUTING.md` autonome avec processus de release : tag → changelog → artefact

---

### Jalon 2 — Robustesse du code 

Objectif : corriger les défauts identifiés dans le code

Délivrables :
- Fix `run_compare()` : `trap - EXIT` déplacé dans un bloc `finally` simulé ou restructuration pour garantir l'exécution sur tout chemin de sortie
- Fix `assert_b3_valid()` : vérification d'au moins N lignes au bon format (pas seulement la première), rejection si taux d'erreur > seuil configurable
- Fix `compute_with_progress()` : gestion explicite du cas `file_size = 0` (skip de la mise à jour de `bytes_done`, ou log en mode debug)
- Définition et documentation du comportement sur liens symboliques (ignorer, suivre, ou erreur explicite) — choix à documenter dans `architecture.md`
- Gestion explicite du cas `RESULTATS_DIR` non accessible en écriture : message d'erreur propre au lieu d'un crash `mkdir` opaque

---

### Jalon 3 — Couverture de tests 

Objectif : couvrir les cas limites non testés

Délivrables :
- T15 : lien symbolique dans le dossier à hacher (comportement selon choix du Jalon 2)
- T16 : nom de fichier avec caractères non UTF-8 (octets arbitraires)
- T17 : base `.b3` avec une ligne corrompue au milieu de lignes valides → `assert_b3_valid()` doit rejeter ou signaler
- T18 : `RESULTATS_DIR` non accessible en écriture → erreur propre
- T19 : fichier de taille zéro dans le dossier à hacher
- TP13 : pipeline avec `resultats` pointant vers un chemin non créable → erreur propre
- Rapport de couverture : script `coverage.sh` qui liste les fonctions de `integrity.sh` et les cas de tests associés (tableau statique, pas `bashcov`)

---

### Jalon 4 — CI/CD 

Objectif : automatiser ce qui est déjà en place

Délivrables :
- `.github/workflows/ci.yml` : déclenchement sur push et PR
  - `shellcheck` sur tous les scripts (zéro warning requis, pas de skip conditionnel)
  - `run_tests.sh` sur Ubuntu latest
  - `run_tests_pipeline.sh` sur Ubuntu latest
  - Build Docker (sans push, validation seule)
- `.github/workflows/release.yml` : déclenchement sur tag `v*`
  - Exécution des tests
  - Création d'une GitHub Release avec `CHANGELOG.md` du tag
  - Checksum SHA-256 et BLAKE3 des scripts `integrity.sh` et `runner.sh` attachés à la release
- Badge CI dans `README.md`

---

### Jalon 5 — Documentation et gouvernance

Objectif : formaliser ce qui est implicite

Délivrables :
- `SECURITY.md` : modèle de menace explicite (périmètre : erreurs accidentelles uniquement), propriétés BLAKE3 utilisées, surface d'attaque auditée (injection de chemins dans `pipeline.json`, comportement sur chemins avec `..`), procédure de signalement
- `docs/architecture.md` : section "Limites de conception" ajoutée (liens symboliques, fichiers 0 octet, non UTF-8, comportement en écriture concurrente)
- `docs/development/contributing.md` : convention Conventional Commits, processus de release en 5 étapes (branch → test → tag → release → changelog), format attendu des PRs
- `ROADMAP.md` : fonctionnalités prévues, limites connues non corrigeables (clone bit-à-bit, métadonnées), axes d'évolution potentiels (notifications natives, export JSON des résultats, `--verify-base` pour auto-protéger le `.b3`)


