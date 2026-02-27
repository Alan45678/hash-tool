# Guide - Volumes VeraCrypt

## Contexte
Vérification d'intégrité sur des volumes chiffrés VeraCrypt montés sous
Windows/WSL. Les volumes apparaissent comme des lecteurs (`/mnt/a/`, `/mnt/i/`,
`/mnt/h/`). hash_tool fonctionne dessus comme sur n'importe quel dossier.

## Prérequis
Volumes VeraCrypt montés avant d'exécuter hash_tool. Vérification :
`ls /mnt/a/dossier_disque_1` doit retourner les fichiers attendus.
Les bases `.b3` doivent être stockées hors des volumes chiffrés
(ex : `Desktop/bases/`) pour être accessibles sans monter les volumes.

## Workflow
1. Monter les volumes VeraCrypt
2. `compute` sur chaque volume avec base sauvegardée hors volume
3. `verify` pour contrôle immédiat
4. `compare` entre deux volumes pour audit croisé
5. Démonter les volumes

## Pipeline veracrypt.json commenté
Déconstruction de `pipeline-veracrypt.json` étape par étape : 3 `compute`
sur 3 volumes différents, 1 `verify` de contrôle, 1 `compare` entre
les deux premiers volumes. Adaptation des chemins `/mnt/a/`, `/mnt/i/`,
`/mnt/h/`, `/mnt/c/Users/TonNom/Desktop/`.

## Adaptation à votre configuration
Instructions pour modifier les lettres de lecteur et les chemins de bases
selon la configuration VeraCrypt locale. Variables à remplacer dans le JSON.
