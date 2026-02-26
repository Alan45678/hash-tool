
**Rapport — Commandes prévues de `hash-tool`**

---

**1. Principe général**

Toutes les commandes suivent le schéma unique :

````

hash-tool <commande> [options]

````

L’utilisateur n’a pas besoin de connaître le mode d’exécution (natif ou Docker), qui est détecté automatiquement.

---

**2. Commandes principales et usage rapide**

| Commande    | Description courte                                                 |
| ----------- | ------------------------------------------------------------------ |
| `compute`   | Calcule les empreintes des fichiers d’un dossier.                  |
| `verify`    | Vérifie l’intégrité d’un dossier à partir d’une base d’empreintes. |
| `compare`   | Compare deux bases d’empreintes (snapshots).                       |
| `runner`    | Exécute un pipeline défini dans un fichier JSON.                   |
| `list`      | Liste les bases d’empreintes disponibles dans un dossier.          |
| `diff`      | Affiche les différences entre une base et un dossier courant.      |
| `stats`     | Affiche des statistiques sur une base d’empreintes.                |
| `check-env` | Analyse l’environnement d’exécution (natif ou conteneur).          |
| `version`   | Affiche la version du logiciel.                                    |
| `help`      | Affiche le help global ou spécifique à une commande.               |

---

**3. Options génériques principales**

| Option               | Description                                                            |
| -------------------- | ---------------------------------------------------------------------- |
| `-data <chemin>`     | Chemin vers le dossier de données à analyser.                          |
| `-base <chemin>`     | Chemin vers un fichier base d’empreintes (.b3) ou un dossier de bases. |
| `-old <chemin>`      | Chemin vers l’ancienne base (pour `compare`).                          |
| `-new <chemin>`      | Chemin vers la nouvelle base (pour `compare`).                         |
| `-pipeline <chemin>` | Chemin vers un fichier pipeline JSON.                                  |
| `-save <chemin>`     | Dossier de sortie pour les résultats.                                  |
| `-readonly`          | Force l’ouverture des données en lecture seule.                        |
| `-verbose`           | Mode verbeux.                                                          |
| `-quiet`             | Mode silencieux.                                                       |
| `-help`              | Affiche le help spécifique.                                            |
| `-version`           | Affiche la version.                                                    |
| `-meta <texte>`      | Commentaire ou note à inclure dans le sidecar JSON associé au `.b3`.   |

---

**4. Exemples d’utilisation rapide**

```bash
# Calculer les empreintes d’un dossier
hash-tool compute -data ./donnees -save ./bases -meta "Snapshot initial"

# Vérifier l’intégrité d’un dossier à partir d’une base
hash-tool verify -data ./donnees -base ./bases/hashes.b3 -save ./resultats

# Comparer deux bases
hash-tool compare -old ancien.b3 -new nouveau.b3 -save ./resultats

# Exécuter un pipeline JSON
hash-tool runner -pipeline ./pipeline.json -save ./resultats

# Vérifier l’environnement
hash-tool check-env
````

---

**5. Objectif de ce fichier**

* Fournir un **référentiel rapide et clair** des commandes disponibles.
* Permettre à l’utilisateur de comprendre la syntaxe générale sans consulter tous les helps détaillés.
* Complémentaire à `helpers_commandes.md` pour les détails par sous-commande et la gestion des métadonnées via sidecar file.


