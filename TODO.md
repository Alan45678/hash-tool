

- il faut que la comparaison, les bases de hash aussi vienne avec des métadonnées
  - par exemple un fichier "[nom de la base] - métadonnée.json" avec les métadonnées , un sidecar file 

- améliorer la documentation
  - ajouter le contenu des .docx dans la doc en ligne 
  - ajouter la doc des tests aussi 
  Remarque : qu'est-ce que je dois mettre dans la documentation? est-ce que la façon dont c'est codé doit être dans la doc ?? Typiquement les README, moi j'ai envie de les mettre dans les tests. Une documentation pour l'utilisateur final et une autre pour le dev ??? 



- tester les tests
- bien comprendre l'outil produit
- réorganiser et améliorer
- rendre public et partager 


## Chamins relatifs

"Toujours lancer compute depuis le dossier qui contient les données, pas depuis un dossier parent. Les chemins dans le .b3 sont relatifs au pwd au moment du compute." 

J'aime pas ça, je veux comprendre pourquoi ça fait ça 



Les commit : il faut que claude me dise quel commit faire, je vais améliorer ma gestion git comme ça 






## Docker trop compliqué 

les commandes docker sont trop compliquées
des commandes plus simples 
pareil si j'utilise docker ou non, que ça se fasse de façon invisible 
utilisation du pipeline même avec Docker 
le pipeline.json doit être le point d'entrée 

hash-tool -pipeline <chemin pipeline.json> -save <chemin du dossier d enregistrement> 

hash-tool compute -data <chemin data> -save <chemin du dossier d enregistrement> 

et voilà, rien d'autre à faire 




## Faire une doc simple 

les docx sont vraiment bien rédigés, là la doc est merdique de fou, pas du tout perspicace ... 













