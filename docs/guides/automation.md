# Guide — Automatisation et planification

## Vérification planifiée en cron Linux
Exemple de crontab pour lancer `hash-tool verify` chaque nuit à 3h.
Redirection stdout/stderr vers un fichier log. Exploitation du code de
sortie non-zéro pour envoyer une alerte (mail, notification).
```
0 3 * * * /chemin/hash-tool verify -base /bases/hashes.b3 -data /donnees -quiet >> /var/log/hash_tool.log 2>&1
```

## Service Docker cron
Activation du profil `cron` dans `docker-compose.yml` :
`docker compose --profile cron up -d cron`. Configuration via variables
d'environnement `CRON_SCHEDULE` et `CRON_BASE`. Note : le service `cron`
utilise l'image standard — crond doit être ajouté (Dockerfile étendu
ou image dérivée). Instructions de build de l'image étendue.

## Intégration CI/CD
Utilisation de hash_tool dans un pipeline GitHub Actions : build de
l'image Docker, smoke tests (version, help, check-env, compute via volume,
verify). Référence au workflow `.github/workflows/ci.yml` livré avec le projet.
Extension possible : ajouter un job de vérification d'intégrité sur les
artefacts de build.

## Alertes et monitoring
Exploitation du code de sortie `1` pour déclencher une alerte :
script wrapper avec envoi d'email, intégration Slack webhook, notification
système. Exemple de script wrapper minimaliste.
