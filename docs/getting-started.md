# Démarrage rapide

Installation et premier usage en moins de 5 minutes.

## Prérequis

### Linux / WSL

```bash
# Debian / Ubuntu
sudo apt install b3sum jq

# Vérifier
b3sum --version
jq --version
bash --version   # doit être >= 4
```

### macOS

```bash
brew install b3sum jq bash

# Ajouter bash 5 à /etc/shells si nécessaire
echo "$(brew --prefix)/bin/bash" | sudo tee -a /etc/shells
```

### Windows

Utiliser WSL (Windows Subsystem for Linux) avec une distribution Debian ou Ubuntu, puis procéder comme sous Linux.

```bat
REM Lancement depuis Windows via WSL
wsl bash /mnt/c/Users/TonNom/Desktop/hash_tool/runner.sh
```

### Docker (aucune dépendance sur l'hôte)

```bash
docker build -t hash_tool .
```

Voir la [référence Docker](reference/docker.md) pour l'usage complet.

---

## Installation

Aucune installation système requise. Cloner ou copier le dossier `hash_tool/` où vous le souhaitez.

```bash
git clone https://github.com/hash_tool/hash_tool.git
cd hash_tool
chmod +x src/integrity.sh runner.sh
```

---

## Premier usage

### Étape 1 — Indexer un dossier

```bash
cd hash_tool
./src/integrity.sh compute ./mon_dossier hashes_2024-01-15.b3
```

Sortie attendue :

```
Base enregistrée : hashes_2024-01-15.b3 (142 fichiers)
```

Le fichier `hashes_2024-01-15.b3` contient une ligne par fichier :

```
a1b2c3d4...f0a1b2  ./mon_dossier/document.pdf
e5f6a7b8...e5f6a7  ./mon_dossier/sous-dossier/image.jpg
```

!!! warning "Répertoire de travail"
    Toujours lancer `compute` depuis le dossier qui contient les données, **pas** depuis un dossier parent. Les chemins dans le `.b3` sont relatifs au `pwd` au moment du compute.

    ```bash
    # Correct
    cd /mnt/a/mes_donnees
    /opt/hash_tool/src/integrity.sh compute . /opt/bases/hashes.b3

    # Incorrect — chemins absolus dans la base, non portables
    /opt/hash_tool/src/integrity.sh compute /mnt/a/mes_donnees /opt/bases/hashes.b3
    ```

### Étape 2 — Vérifier l'intégrité

```bash
# Depuis le même répertoire qu'au compute
./src/integrity.sh verify hashes_2024-01-15.b3
```

Sortie si tout est intact :

```
Vérification OK — 142 fichiers intègres.
Résultats dans : /home/user/integrity_resultats/resultats_hashes_2024-01-15
  recap.txt
```

Sortie si corruption détectée :

```
████████████████████████████████████████
  ECHEC : 2 fichier(s) corrompu(s) ou manquant(s)
████████████████████████████████████████

./mon_dossier/document.pdf: FAILED
./mon_dossier/archive.zip: FAILED

Résultats dans : /home/user/integrity_resultats/resultats_hashes_2024-01-15
  recap.txt
  failed.txt
```

### Étape 3 — Comparer deux snapshots

```bash
# Après avoir recalculé une nouvelle base
./src/integrity.sh compute ./mon_dossier hashes_2024-02-01.b3

# Comparer
./src/integrity.sh compare hashes_2024-01-15.b3 hashes_2024-02-01.b3
```

Produit dans `~/integrity_resultats/resultats_hashes_2024-01-15/` :

```
recap.txt       — résumé texte (modifiés / disparus / nouveaux)
modifies.b3     — fichiers avec hash différent
disparus.txt    — fichiers présents dans l'ancienne base, absents de la nouvelle
nouveaux.txt    — fichiers absents de l'ancienne base, présents dans la nouvelle
report.html     — rapport visuel interactif
```

---

## Usage avec le pipeline

Pour plusieurs dossiers ou une routine régulière, `runner.sh` + `pipeline.json` est plus robuste que les appels manuels.

```bash
# Éditer pipelines/pipeline.json avec vos chemins
./runner.sh

# Ou avec un fichier de config explicite
./runner.sh /chemin/vers/mon-pipeline.json
```

Voir la [référence runner.sh](reference/runner-sh.md) pour le format complet du pipeline.

---

## Où sont les résultats ?

Par défaut dans `~/integrity_resultats/`. Configurable via la variable d'environnement `RESULTATS_DIR` :

```bash
export RESULTATS_DIR=/srv/rapports/integrity
./src/integrity.sh verify hashes.b3
```

Ou directement dans le pipeline via le champ `resultats` sur les blocs `compare`.

---

## Prochaines étapes

- [Référence complète integrity.sh](reference/integrity-sh.md) — toutes les options, variables, exit codes
- [Référence runner.sh](reference/runner-sh.md) — format pipeline.json
- [Guide VeraCrypt](guides/veracrypt.md) — workflow multi-disques
- [Guide CI/Cron](guides/cron-ci.md) — automatisation
