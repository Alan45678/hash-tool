# integrity.sh - Vérification d'intégrité BLAKE3

Détection de corruption silencieuse et d'erreurs de transfert sur disque, par hachage BLAKE3.

**Dépendances :** `b3sum`, `bash >= 4`, `find`, `sort`, `awk`, `comm`, `join`, `stat`, `du`

---

## Usage

```bash
# Créer une base de hachage pour un dossier
./integrity.sh compute ./mon_dossier hashes_2024-01-15.b3

# Vérifier l'intégrité actuelle contre une base
./integrity.sh verify  ./mon_dossier hashes_2024-01-15.b3

# Comparer deux bases (états historiques)
./integrity.sh compare hashes_2024-01-15.b3 hashes_2024-02-01.b3
```

---

## Arbre de décision rapide

| Situation | Commande |
|---|---|
| Première indexation | `compute` |
| Vérifier après transfert / stockage | `verify` |
| Comparer deux snapshots | `compare` |
| Contrôle ad hoc d'un fichier unique | `b3sum fichier.bin` |

---

## Structure du projet

```
integrity/
|-- README.md              ← ce fichier
|-- integrity.sh           ← script principal
|-- docs/
│   |-- manuel.md          ← référence technique complète
│   |-- progression-eta.md ← progression temps réel et estimation ETA
|-- tests/
    |-- validation.md      ← protocole de test et critères qualité
```

---

## Règles d'utilisation critiques

- Toujours utiliser des **chemins relatifs** (`find ./dossier`, jamais `/chemin/absolu`). Un chemin absolu rend la base inutilisable après déplacement ou remontage.
- Lancer `b3sum --check` depuis le **même répertoire de travail** qu'au moment du `compute`.
- Stocker la base `.b3` sur un **support distinct** des données à vérifier.
- Nommer les bases avec une **date explicite** : `hashes_2024-01-15.b3`, jamais `hashes_latest.b3`.
