
**Rapport — Helps spécifiques des sous-commandes de `hash-tool`**

---

### 1. Help global

```bash
hash-tool help
````

**Usage :**
`hash-tool <commande> [options]`

**Commandes principales :**

* `compute`        Calcule les empreintes d’un dossier.
* `verify`         Vérifie l’intégrité d’un dossier à partir d’une base.
* `compare`        Compare deux bases d’empreintes.
* `runner`         Exécute un pipeline JSON.
* `list`           Liste les bases d’empreintes disponibles.
* `diff`           Affiche les différences entre une base et un dossier.
* `stats`          Affiche des statistiques sur une base.
* `check-env`      Analyse l’environnement d’exécution.
* `version`        Affiche la version.
* `help`           Affiche cette aide.

**Options générales :**

* `-data <chemin>`        Dossier à analyser.
* `-base <chemin>`        Fichier base d’empreintes (.b3).
* `-old <chemin>`         Ancienne base (pour `compare`).
* `-new <chemin>`         Nouvelle base (pour `compare`).
* `-pipeline <chemin>`    Fichier pipeline JSON.
* `-save <chemin>`        Dossier de sortie pour les résultats.
* `-readonly`             Lecture seule.
* `-verbose`              Mode verbeux.
* `-quiet`                Mode silencieux.
* `-help`                 Affiche le help spécifique.
* `-version`              Affiche la version.
* `-meta <texte>`         Commentaire à inclure dans le sidecar JSON.

---

### 2. Helps spécifiques par sous-commande

#### 2.1 Compute

```bash
hash-tool compute -help
```

**Usage :**
`hash-tool compute -data <chemin dossier> -save <chemin sortie> [options]`

**Options :**

* `-data <chemin>`      Dossier contenant les fichiers à hacher.
* `-save <chemin>`      Dossier où enregistrer la base d’empreintes.
* `-verbose`            Mode verbeux.
* `-readonly`           Analyse en lecture seule.
* `-quiet`              Mode silencieux.
* `-meta <texte>`       Commentaire à inclure dans le sidecar JSON.

**Exemple :**
`hash-tool compute -data ./donnees -save ./bases -meta "Snapshot initial"`

---

#### 2.2 Verify

```bash
hash-tool verify -help
```

**Usage :**
`hash-tool verify -data <chemin dossier> -base <chemin base.b3> -save <chemin sortie> [options]`

**Options :**

* `-data <chemin>`      Dossier à vérifier.
* `-base <chemin>`      Base d’empreintes de référence.
* `-save <chemin>`      Dossier de sortie pour le rapport de vérification.
* `-verbose`            Mode verbeux.
* `-quiet`              Mode silencieux.

**Exemple :**
`hash-tool verify -data ./donnees -base ./bases/hashes.b3 -save ./resultats`

---

#### 2.3 Compare

```bash
hash-tool compare -help
```

**Usage :**
`hash-tool compare -old <chemin ancien.b3> -new <chemin nouveau.b3> -save <chemin sortie> [options]`

**Options :**

* `-old <chemin>`       Ancienne base d’empreintes.
* `-new <chemin>`       Nouvelle base d’empreintes.
* `-save <chemin>`      Dossier de sortie pour le rapport de comparaison.
* `-verbose`            Mode verbeux.
* `-quiet`              Mode silencieux.

**Exemple :**
`hash-tool compare -old ancien.b3 -new nouveau.b3 -save ./resultats`

---

#### 2.4 Runner (pipeline JSON)

```bash
hash-tool runner -help
```

**Usage :**
`hash-tool runner -pipeline <chemin pipeline.json> -save <chemin sortie> [options]`

**Options :**

* `-pipeline <chemin>`  Fichier JSON définissant le pipeline.
* `-save <chemin>`      Dossier de sortie pour les résultats du pipeline.
* `-verbose`            Mode verbeux.
* `-quiet`              Mode silencieux.

**Exemple :**
`hash-tool runner -pipeline ./pipeline.json -save ./resultats`

---

#### 2.5 List

```bash
hash-tool list -help
```

**Usage :**
`hash-tool list -base <chemin dossier> [options]`

**Options :**

* `-base <chemin>`      Dossier contenant les snapshots à lister.
* `-verbose`            Mode verbeux.

**Exemple :**
`hash-tool list -base ./bases`

---

#### 2.6 Diff

```bash
hash-tool diff -help
```

**Usage :**
`hash-tool diff -base <chemin base.b3> -data <chemin dossier> [options]`

**Options :**

* `-base <chemin>`      Base d’empreintes de référence.
* `-data <chemin>`      Dossier à comparer.
* `-verbose`            Mode verbeux.

**Exemple :**
`hash-tool diff -base ./bases/hashes.b3 -data ./donnees`

---

#### 2.7 Stats

```bash
hash-tool stats -help
```

**Usage :**
`hash-tool stats -base <chemin base.b3> [options]`

**Options :**

* `-base <chemin>`      Base d’empreintes pour calculer les statistiques.
* `-verbose`            Mode verbeux.

**Exemple :**
`hash-tool stats -base ./bases/hashes.b3`

---

#### 2.8 Check-env

```bash
hash-tool check-env -help
```

**Usage :**
`hash-tool check-env`

**Description :**
Analyse l’environnement d’exécution et indique si le programme peut s’exécuter nativement ou doit utiliser Docker.

---

#### 2.9 Version

```bash
hash-tool version -help
```

**Usage :**
`hash-tool version`

**Description :**
Affiche la version du logiciel.

---

**3. Conclusion**

* Chaque sous-commande dispose d’un help dédié pour détailler ses options et arguments.
* Le help global résume les commandes principales et sert de point d’entrée.
* La structure prend en charge la génération et l’exploitation de sidecar files pour les métadonnées.







