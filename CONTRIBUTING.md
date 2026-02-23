# Contribuer à hash_tool

La documentation de contribution complète est dans [`docs/development/contributing.md`](docs/development/contributing.md).

## Démarrage rapide

```bash
# Prérequis
sudo apt install bash b3sum jq shellcheck

# Tests
cd tests && ./run_tests.sh
cd tests && ./run_tests_pipeline.sh

# Lint
shellcheck src/integrity.sh runner.sh src/lib/report.sh docker/entrypoint.sh
```

Zéro warning ShellCheck requis. Tous les tests doivent passer avant soumission.
