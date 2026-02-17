



# Solutions concrètes pour vérification d'intégrité



## Solution 0 : Comparaison octet par octet -- freefilesync 

FreeFileSync fait une vérification « en contenu » par comparaison octet par octet. Il n'utilise pas des hash. Mais cette méthdoe garantit l’intégrité.





## Comparaison par fichiers de hash (méthode générique)

Principe :

1.  calculer un hash pour chaque fichier du dossier source,
2.  calculer un hash pour chaque fichier du dossier cible,
3.  comparer les listes.



### Solution 1 : hashdeep (le plus adapté à votre cas)

**Algorithme** : SHA-256 ou SHA-1 (SHA-1 suffisant pour intégrité, 2x plus rapide)
**Performance** : ~400-600 Mo/s sur SSD, ~100-150 Mo/s sur HDD (SHA-1)
**Parallélisation** : Non natif, mais scriptable
**Incrémental** : Oui via comparaison timestamp

**Format stockage** : Texte plat, 1 ligne par fichier (hash, taille, chemin)
**Rapport** : Fichiers manquants, ajoutés, modifiés avec hash différent



### Solution 2 : BLAKE3 (le plus rapide)

**Algorithme** : BLAKE3
**Performance** : ~3-10 Go/s sur SSD (10-20x plus rapide que SHA-256)
**Parallélisation** : Oui, natif multi-thread
**Incrémental** : À scripter manuellement

**Format stockage** : Texte plat compatible GNU coreutils
**Rapport** : Via diff, affiche lignes différentes/manquantes







### Solution 3 : rhash (compromis polyvalence/performance)

**Algorithme** : Configurable (SHA-256, SHA-1, CRC32, BLAKE2)
**Performance** : ~350-500 Mo/s (SHA-256), ~2-3 Go/s (CRC32)
**Parallélisation** : Non natif, scriptable via GNU parallel
**Incrémental** : Via --update

**Format stockage** : SFV/BSD format, compatible md5sum/sha256sum
**Rapport** : OK/FAILED/MISSING par fichier, stderr pour erreurs







### Recommandation directe

**Pour 100 Go - 1 To+ : BLAKE3** (Solution 2)
- Vitesse brute imbattable
- Parallélisation native
- Sécurité cryptographique correcte

**Pour usage production avec historique : hashdeep** (Solution 1)
- Mode audit intégré
- Gestion différences native
- Stable, éprouvé, documenté

**Performance réelle exemple** :
- 500 Go sur SSD NVMe : ~2-3 min (BLAKE3), ~15-20 min (hashdeep SHA-1), ~30-40 min (hashdeep SHA-256)
- 1 To sur HDD 7200rpm : ~15-20 min (BLAKE3), ~2-3h (hashdeep SHA-1), ~4-6h (hashdeep SHA-256)























