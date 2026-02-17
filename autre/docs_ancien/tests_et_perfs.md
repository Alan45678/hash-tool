




# Rapports de Performance et Protocoles de Test

Ce document compile les résultats des tests de performance et décrit la procédure pour valider le bon fonctionnement de l'outil dans l'environnement de simulation.

## 📊 Benchmarks de Performance

L'utilisation de **BLAKE3** via `b3sum` permet d'atteindre des vitesses de traitement exceptionnelles, souvent limitées uniquement par le matériel.

### Résultats sur un dossier de 200 Go (Photos/Vidéos) :
* **Support SSD (SATA/NVMe)** : Temps de calcul ~5 à 12 minutes.
* **Support HDD (USB 3.0)** : Temps de calcul ~45 minutes à 1h15 (limité par la vitesse de lecture mécanique).
* **Comparaison SQLite** : La mise à jour de la base de données après le calcul des hash prend moins de 10 secondes pour 50 000 fichiers.

## 🧪 Protocole de Test Manuel

Le projet inclut un environnement de simulation dans le dossier `test/` pour vérifier que l'outil détecte correctement les erreurs sans risquer vos données réelles.

### 1. Préparation de l'environnement
Vérifiez que vos dossiers de simulation existent :
* `test/source/` : Contient les fichiers originaux.
* `test/destination/` : Contient une copie (potentiellement altérée).

### 2. Étape de Baseline (Référence)
Générez l'empreinte de référence du dossier source :
```bash
# Via le script de collecte
./src/collect.sh "ref_source"

```

Ceci créera le fichier `test/hashdb/ref_source.db`.

### 3. Simulation d'une corruption (Bit Rot)

Pour tester la détection, modifiez manuellement un fichier dans le dossier source :

```bash
echo "donnée corrompue" >> test/source/fichier\ \(1\).txt

```

### 4. Vérification de l'intégrité

Lancez la vérification par rapport à la base SQLite :

```bash
./src/main.sh

```

**Résultat attendu :** Le script doit signaler que `fichier (1).txt` a été modifié et générer un rapport d'alerte dans `test/reports/`.

## 📂 Structure des sorties de test

Tous les fichiers de test sont isolés pour garantir la propreté de la racine :

* **Bases de données** : Localisées dans `test/hashdb/`.
* **Journal de hachage** : Les fichiers intermédiaires `.b3` sont stockés dans `test/hash/hashbase/`.
* **Rapports d'audit** : Les fichiers HTML sont générés dans `test/reports/`.

---

*Dernière mise à jour : Février 2026*



