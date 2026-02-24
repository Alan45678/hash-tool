# Roadmap - hash_tool

---

## Positionnement

> Outil de snapshot d'intégrité BLAKE3 pour collections de fichiers locales.

hash_tool n'est pas un logiciel de sauvegarde. Il ne copie pas, ne restaure pas, ne compresse pas. Il n'est pas un outil de sécurité au sens cryptographique - BLAKE3 est utilisé pour la détection d'erreurs accidentelles, pas pour l'authentification. Il n'est pas un outil de surveillance temps réel. Il opère par snapshots sur demande.

La clarté du périmètre est une qualité, pas une limite. Les outils qui font une seule chose bien sont plus faciles à auditer, à maintenir, à tester et à intégrer dans un pipeline plus large. hash_tool est conçu pour être **une brique, pas une solution complète**.

---

## Panorama des outils existants

| Outil | Type | Algorithme | Lacunes vis-à-vis du créneau |
|---|---|---|---|
| `md5sum` / `sha256sum` | CLI Unix | MD5 / SHA-256 | Fichier par fichier, pas de dossier, pas de rapport, pas de compare |
| `rclone check` | CLI Go | Variable | Couplé au stockage cloud, pas adapté aux usages locaux/hors-ligne |
| Duplicati | GUI/daemon | SHA-256 | Logiciel de sauvegarde complet, lourd, overkill pour la vérification seule |
| TeraCopy | GUI Windows | Plusieurs | Windows uniquement, propriétaire, pas scriptable |
| `hashdeep` | CLI C | Plusieurs | Pas de BLAKE3, pas de rapport HTML, pas de pipeline, inactif depuis 2015 |
| `fclones` | CLI Rust | BLAKE3 | Orienté déduplication, pas intégrité temporelle, pas de compare snapshots |
| `par2` | CLI C++ | Reed-Solomon | Réparation de données, pas détection de corruption sur dossier existant |

Aucun outil ci-dessus ne combine simultanément : (1) BLAKE3, (2) gestion de dossiers complets avec chemins relatifs, (3) comparaison de deux snapshots à des instants différents, (4) rapport HTML autonome, (5) pipeline JSON déclaratif, (6) image Docker Alpine légère. La conjonction de ces six caractéristiques définit le créneau.

---

## Population cible

| Profil | Cas d'usage principal | Besoin non couvert par les alternatives |
|---|---|---|
| Sysadmin de PME / indépendant | Vérifier l'intégrité de sauvegardes NAS après restauration | Outil léger, sans agent, rapport lisible par le client |
| Photographe / vidéaste professionnel | Garantir l'intégrité d'archives de médias sur disques durs | Interface simple, hors-ligne, pas de dépendance cloud |
| Archiviste numérique / bibliothèque | Détecter le bitrot sur des collections à long terme | Rapport horodaté, comparaison de snapshots, exportable |
| Chercheur / laboratoire | Valider l'intégrité de datasets après transfert | Portabilité, chemins relatifs, pas de compte tiers requis |
| Développeur DevOps | Intégrer une vérification d'intégrité dans un pipeline CI/CD | Mode `--quiet`, exit code propagé, image Docker légère |

---

## Créneaux secondaires

**Post-transfert sur supports chiffrés.** Les utilisateurs de partitions chiffrées (VeraCrypt, LUKS, BitLocker) font face à un problème spécifique : le transfert de fichiers est une opération à risque (coupure d'alimentation, démontage forcé, erreur de transfert). Aucun outil dédié ne propose un workflow `compute → verify → compare` adapté à ce contexte. Le pipeline JSON de hash_tool s'y prête directement.

**Validation de migration de données.** Migrations de serveurs, changements de NAS, restructuration d'arborescences - ces opérations nécessitent de comparer l'état avant et après. Les outils existants (`diff`, `rsync --checksum`) travaillent sur des copies simultanées, pas sur des snapshots temporels. hash_tool compare deux `.b3` produits à n'importe quel intervalle de temps.

**Intégration CI/CD légère.** Les pipelines CI qui vérifient l'intégrité d'artefacts de build ou de datasets de test utilisent généralement des checksums ad hoc (SHA-256 d'un seul fichier). hash_tool propose une approche structurée avec `--quiet`, exit code propre, et image Docker légère - sans introduire une dépendance lourde comme rclone ou un service cloud.

**Archivage numérique long terme.** La communauté de l'archivage numérique (bibliothèques, musées, institutions de recherche) utilise des outils comme BagIt ou PREMIS pour l'intégrité à long terme. Ces outils sont complexes, orientés XML, et inadaptés aux petites structures. hash_tool offre un sous-ensemble fonctionnel utilisable sans formation.

---

## Synthèse des créneaux

| Créneau | Intensité du besoin | Vacance actuelle | Priorité |
|---|---|---|---|
| Intégrité de collections de fichiers locaux à long terme | Élevée | Totale | Primaire |
| Post-transfert sur supports chiffrés | Moyenne | Totale | Secondaire |
| Validation de migration de données | Élevée | Partielle | Secondaire |
| Intégration CI/CD légère (BLAKE3) | Moyenne | Partielle | Tertiaire |
| Archivage numérique petites structures | Faible | Totale | Tertiaire |

---

## Limites connues non corrigeables par conception

| Scénario | Détecté ? | Explication |
|---|---|---|
| Clone bit-à-bit | Non | Hash identique par définition |
| Renommage de fichier | Non | Vu comme suppression + ajout |
| Modification de permissions / timestamps | Non | `b3sum` ne hache que le contenu binaire |
| Dossier vide | Non | `find -type f` ignore les dossiers vides |
| Corruption de la base `.b3` elle-même | Non | La base n'est pas auto-protégée par défaut |

Contournement pour la base `.b3` :

```bash
b3sum hashes.b3 > hashes.b3.check
b3sum --check hashes.b3.check
```

---

## Concurrence future

Le seul risque de désintermédiation sérieux serait qu'un outil comme `rclone` ou `restic` implémente nativement BLAKE3 + comparaison de snapshots + rapport HTML + Docker léger. Leur complexité intrinsèque rend ce scénario peu probable à court terme.

---

## Axes d'évolution envisagés

Ces fonctionnalités ne sont pas planifiées avec une date. Elles sont identifiées comme extensions naturelles du périmètre actuel, par ordre de valeur décroissante.

**`--format json` sur `verify` et `compare`.** `recap.txt` est lisible par un humain, pas par un outil. Un export JSON permettrait l'intégration avec des dashboards ou des outils de monitoring sans parser du texte. Contribution prioritaire.

**CI automatique (GitHub Actions).** `run_tests.sh` + `run_tests_pipeline.sh` déclenchés sur push. Contribution prioritaire.

**`install.sh` one-liner.** Script d'installation avec vérification des dépendances. Contribution prioritaire.

**Notifications natives.** Aujourd'hui la notification est à la charge du script appelant (`mail`, webhook Slack, etc.). Un champ `on_failure` dans `pipeline.json` encapsulerait ce pattern récurrent.

**Auto-protection de la base `.b3`.** Un flag `--sign` sur `compute` qui calcule et stocke le hash de la base dans un fichier `.b3.check` adjacent, et un flag `--verify-base` sur `verify` qui valide ce check avant toute opération.

**Parallélisme configurable.** La boucle séquentielle est optimale sur HDD. Sur SSD NVMe avec de nombreux petits fichiers, `xargs -P N` offrirait +20–40%. À conditionner à un flag explicite `--parallel N` pour ne pas casser les environnements où l'ordre de traitement importe.
