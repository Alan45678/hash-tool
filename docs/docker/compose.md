# Docker Compose

## Services définis
Trois services dans `docker-compose.yml` :
`integrity` (commandes unitaires compute/verify/compare),
`pipeline` (exécution runner.sh avec pipeline.json),
`cron` (vérification périodique, désactivé par défaut via profil).

## Configuration des volumes
Section `x-volumes` : les 4 chemins à adapter avant tout usage.
Localisation selon l'environnement : Windows/WSL (`/mnt/c/Users/TonNom/...`),
NAS Synology (`/volume1/...`), serveur Debian (`/srv/...`).
Un seul endroit à modifier pour reconfigurer tous les services.

## Commandes types
Exemples opérationnels :
```
docker compose run --rm integrity compute /data /bases/hashes.b3
docker compose run --rm integrity verify  /bases/hashes.b3 /data
docker compose run --rm integrity compare /bases/old.b3 /bases/new.b3
docker compose run --rm pipeline
```

## Service cron
Activation : `docker compose --profile cron up -d cron`.
Variables de configuration : `CRON_SCHEDULE` (expression cron, défaut `0 3 * * *`)
et `CRON_BASE` (base à vérifier). Nécessite une image étendue avec crond -
lien vers `guides/automation.md` pour le setup complet.
