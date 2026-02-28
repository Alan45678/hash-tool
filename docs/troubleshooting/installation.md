# Troubleshooting - Installation

## `b3sum` introuvable en natif

**Symptôme** : `check-env` retourne `[KO] b3sum introuvable`.
**Cause** : absent des dépôts par défaut sur certaines distributions.
**Solution par OS** :
- Alpine : `apk add --no-cache b3sum` (activer le dépôt community)
- Debian/Ubuntu : installer via cargo (`cargo install b3sum`) ou télécharger
  le binaire depuis les releases GitHub de BLAKE3
- macOS : `brew install b3sum`
**Vérification** : `b3sum --version`

## `bash` version insuffisante (< 4)

**Symptôme** : erreurs de syntaxe bash au lancement, `check-env` signale la version.
**Cause fréquente** : macOS - bash système = 3.x (Apple distribue bash 3.2 pour
des raisons de licence GPLv2).
**Diagnostic** : `bash --version`
**Solution** : `brew install bash`, puis utiliser `/opt/homebrew/bin/bash`.
Ne pas remplacer `/bin/bash` système sur macOS.

## `hash-tool` non exécutable

**Symptôme** : `Permission denied` ou `command not found`.
**Cause** : `chmod +x` non appliqué, ou fichiers sur un système de fichiers
FAT32/NTFS (ignorent les bits de permission Unix).
**Solution** : `chmod +x hash-tool runner.sh src/integrity.sh src/lib/*.sh`
**Cas FAT/NTFS** : cloner le dépôt sur un système de fichiers natif Linux/ext4.

## Image Docker absente

**Symptôme** : `[--] Image Docker 'hash_tool' absente` dans `check-env`.
**Cause** : image non buildée - elle n'est pas publiée sur Docker Hub.
**Solution** : `docker build -t hash_tool .` depuis la racine du dépôt.
Erreur fréquente : lancer le build depuis un sous-dossier (Dockerfile introuvable).
