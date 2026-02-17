


Pour Linux, ce type de fichier est un **script Shell** et porte généralement l'extension **`.sh`**.

Cependant, contrairement à Windows où l'extension détermine le type de fichier, sous Linux, c'est le contenu (la première ligne `#!/bin/bash`) et les permissions qui comptent.

### Comment l'utiliser concrètement :

1. 
**Nommez le fichier :** `verif_hash.sh`.


2. **Rendez-le exécutable :**
```bash
chmod +x verif_hash.sh

```



(Cette commande est indispensable pour que Linux accepte de lancer le script ).


3. **Lancez-le :**
```bash
./verif_hash.sh

```



### Pourquoi cette extension ?

* 
**Identification :** Cela permet de savoir immédiatement qu'il s'agit d'un script Bash.


* 
**Organisation :** Dans votre arborescence `/test`, cela permet de bien distinguer le script des fichiers de données comme `source.b3` ou `differences.txt`.




**Rappel important :** Comme vous travaillez dans un dossier avec des espaces et des accents (`/vérification_hash/test/`), l'utilisation de l'extension `.sh` avec les guillemets lors de l'appel de vos commandes vous évitera bien des erreurs de syntaxe.




