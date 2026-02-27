# Troubleshooting

## Comment utiliser ce guide
Démarche diagnostique systématique : lancer `hash-tool check-env` en premier.
La sortie identifie immédiatement les composants manquants ou défaillants.
Convention utilisée dans toutes les pages : **Symptôme** -> **Cause probable**
-> **Diagnostic** (commande à lancer) -> **Solution**.

## Tableau symptôme -> page

| Symptôme | Page |
|----------|------|
| `b3sum` introuvable, `hash-tool` non exécutable | [Installation](installation.md) |
| `verify` échoue sur tous les fichiers | [Exécution](execution.md) |
| `.b3` vide, compare retourne des résultats aberrants | [Exécution](execution.md) |
| Erreurs de volumes, permission denied Docker | [Docker](docker.md) |
| Pipeline JSON : erreur jq, `op` non reconnu | [Pipeline](pipeline.md) |
| `report.html` vide, `RESULTATS_DIR` ignoré | [Résultats](results.md) |

## Diagnostic de premier niveau
Commandes à lancer systématiquement avant d'ouvrir une issue :
1. `hash-tool version` — confirme que le script est accessible et exécutable
2. `hash-tool check-env` — état de toutes les dépendances
3. `head -3 <fichier.b3>` — inspecte le préfixe des chemins dans la base
