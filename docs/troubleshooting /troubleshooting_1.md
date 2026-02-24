
# troubleshooting 1 : titre

## Commande 

bash ./runner.sh ./pipelines/pipeline-debug.json

## Message d'erreur 

=== PIPELINE DÉMARRÉ : mar. 24 févr. 2026 13:22:40 CET ===
=== Config : ./pipelines/pipeline-debug.json (3 opération(s)) ===

=== COMPUTE : ./mon_dossier/source ===
./runner.sh: ligne 70: /media/veracrypt1/partition_laptop/divers/config ordinateur/2 en cours -- 2025-00-00 -- backup/d11 installation/hash_tool/src/integrity.sh: Permission non accordée

## Solution 

chmod +x ./src/integrity.sh ./src/lib/*.sh

## Explication 

à écrire 









