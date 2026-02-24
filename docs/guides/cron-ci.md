# Guide - CI / Cron

Intégration de hash_tool dans des pipelines automatisés : cron Linux, CI/CD, hooks Git.

---

## Mode `--quiet`

Toutes les commandes acceptent `--quiet` en premier argument. Ce flag :

- Supprime **toute** sortie terminal (stdout et stderr de `integrity.sh`)
- Conserve l'**exit code** : `0` = OK, `1` = ECHEC ou ERREUR
- Continue d'écrire les fichiers de résultats (`recap.txt`, `failed.txt`, `report.html`)

C'est le mode à utiliser systématiquement en automatisation - le script parent ou le système de notification gère la sortie.

```bash
./src/integrity.sh --quiet verify hashes.b3
echo "Exit code : $?"
```

---

## Cron Linux

### Vérification nocturne simple

```cron
# /etc/cron.d/hash-integrity
# Vérification à 03h00 chaque nuit
0 3 * * * user /opt/hash_tool/src/integrity.sh --quiet verify \
    /opt/bases/hashes.b3 /srv/data \
    >> /var/log/hash-integrity.log 2>&1 \
    || echo "$(date) - ALERTE intégrité" | mail -s "Alerte $(hostname)" admin@example.com
```

### Avec pipeline complet

```cron
# Recalcul hebdomadaire + comparaison (dimanche 02h00)
0 2 * * 0 user /opt/hash_tool/runner.sh /opt/hash_tool/pipelines/pipeline-weekly.json \
    >> /var/log/hash-integrity-weekly.log 2>&1 \
    || mail -s "ECHEC pipeline intégrité $(hostname)" admin@example.com
```

### Rotation des logs

```bash
# /etc/logrotate.d/hash-integrity
/var/log/hash-integrity.log {
    weekly
    rotate 52
    compress
    missingok
    notifempty
}
```

---

## Cron via Docker

```cron
0 3 * * * root \
    docker run --rm \
      -v /srv/data:/data:ro \
      -v /srv/bases:/bases:ro \
      -v /srv/resultats:/resultats \
      hash_tool --quiet verify /bases/hashes.b3 /data \
    >> /var/log/hash-integrity.log 2>&1 \
    || mail -s "ALERTE intégrité $(hostname)" admin@example.com
```

---

## Intégration CI/CD

### GitHub Actions

```yaml
# .github/workflows/integrity-check.yml
name: Vérification intégrité

on:
  schedule:
    - cron: '0 3 * * *'   # 03h00 UTC chaque nuit
  workflow_dispatch:        # déclenchement manuel possible

jobs:
  verify:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Installer b3sum
        run: sudo apt-get install -y b3sum

      - name: Vérifier l'intégrité
        run: |
          ./src/integrity.sh --quiet verify bases/hashes.b3
        env:
          RESULTATS_DIR: /tmp/integrity-results

      - name: Uploader les résultats
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: integrity-results
          path: /tmp/integrity-results/
          retention-days: 30
```

### GitLab CI

```yaml
# .gitlab-ci.yml
integrity-verify:
  stage: verify
  image: alpine:3.19
  before_script:
    - apk add --no-cache bash b3sum
  script:
    - ./src/integrity.sh --quiet verify bases/hashes.b3
  artifacts:
    when: always
    paths:
      - integrity-results/
    expire_in: 30 days
  variables:
    RESULTATS_DIR: integrity-results
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
```

### Hook Git pre-commit

Vérifier l'intégrité d'un dossier avant chaque commit :

```bash
#!/usr/bin/env bash
# .git/hooks/pre-commit
set -euo pipefail

BASES_DIR="$(git rev-parse --show-toplevel)/bases"
DATA_DIR="$(git rev-parse --show-toplevel)/data"

if [ -f "$BASES_DIR/hashes.b3" ]; then
    echo "Vérification intégrité..."
    ./src/integrity.sh --quiet verify "$BASES_DIR/hashes.b3" "$DATA_DIR" || {
        echo "ERREUR : corruption détectée. Commit annulé."
        echo "Consulter : $BASES_DIR/resultats/"
        exit 1
    }
    echo "Intégrité OK."
fi
```

```bash
chmod +x .git/hooks/pre-commit
```

---

## Patterns de notification

### Email via `mail`

```bash
./src/integrity.sh --quiet verify hashes.b3 || \
    mail -s "ALERTE intégrité $(hostname)" admin@example.com < \
    "$(ls -d ~/integrity_resultats/resultats_hashes* | tail -1)/recap.txt"
```

### Slack webhook

```bash
#!/usr/bin/env bash
WEBHOOK_URL="https://hooks.slack.com/services/..."

./src/integrity.sh --quiet verify hashes.b3
EXIT=$?

if [ $EXIT -ne 0 ]; then
    RECAP=$(cat "$(ls -d ~/integrity_resultats/resultats_hashes* | tail -1)/recap.txt")
    curl -s -X POST "$WEBHOOK_URL" \
        -H 'Content-type: application/json' \
        --data "{\"text\":\"🚨 *Alerte intégrité* sur \`$(hostname)\`\n\`\`\`${RECAP}\`\`\`\"}"
fi

exit $EXIT
```

### Fichier de statut pour monitoring

```bash
#!/usr/bin/env bash
STATUS_FILE=/var/lib/hash-integrity/last-status

./src/integrity.sh --quiet verify hashes.b3
EXIT=$?

mkdir -p "$(dirname "$STATUS_FILE")"
{
    echo "date=$(date -Iseconds)"
    echo "status=$([ $EXIT -eq 0 ] && echo OK || echo FAILED)"
    echo "exit_code=$EXIT"
} > "$STATUS_FILE"

exit $EXIT
```

Le fichier `last-status` peut être lu par Zabbix, Nagios, Prometheus node_exporter (textfile collector), etc.

---

## Gestion des résultats en CI

Les résultats (`recap.txt`, `failed.txt`, `report.html`) s'accumulent dans `RESULTATS_DIR`. En CI, pointer vers un dossier temporaire :

```bash
export RESULTATS_DIR=/tmp/integrity-$(date +%Y%m%d-%H%M%S)
./src/integrity.sh verify hashes.b3
# Uploader $RESULTATS_DIR comme artefact CI
```

Ou utiliser le champ `resultats` dans `pipeline.json` pour un chemin explicite par run.

---

## Récupérer le résumé en script

```bash
# Vérifier et récupérer le recap
./src/integrity.sh --quiet verify hashes.b3
EXIT=$?

OUTDIR=$(ls -d "${RESULTATS_DIR:-$HOME/integrity_resultats}/resultats_hashes"* 2>/dev/null | tail -1)

if [ $EXIT -ne 0 ] && [ -f "$OUTDIR/failed.txt" ]; then
    NB_FAILED=$(grep -c ': FAILED' "$OUTDIR/failed.txt" || echo 0)
    echo "ECHEC : $NB_FAILED fichier(s) corrompu(s)"
    cat "$OUTDIR/failed.txt"
fi

exit $EXIT
```
