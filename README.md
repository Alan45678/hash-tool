# hash_tool

Outil CLI de vérification d'intégrité de fichiers par hachage BLAKE3.

## Présentation

hash_tool permet de calculer, vérifier et comparer des empreintes cryptographiques (BLAKE3) sur des dossiers de fichiers. Il détecte les fichiers modifiés, disparus ou ajoutés entre deux états d'un même dossier.

Fonctionne en mode natif (b3sum + bash) ou via Docker en fallback automatique.

## Cas d'usage typiques

- Audit d'intégrité avant archivage
- Vérification après migration ou copie de données
- Contrôle périodique de volumes chiffrés (VeraCrypt)
- Automatisation via pipeline JSON

## Prérequis

- bash >= 4, b3sum, jq (mode natif)
- Docker (mode conteneur)

## Installation rapide

```bash
git clone https://github.com/hash_tool/hash_tool
cd hash_tool
chmod +x hash-tool runner.sh src/integrity.sh
./hash-tool check-env
```

## Utilisation

```bash
hash-tool compute  -data ./donnees -save ./bases -meta "Snapshot initial"
hash-tool verify   -base ./bases/hashes_donnees.b3 -data ./donnees
hash-tool compare  -old ancien.b3 -new nouveau.b3 -save ./rapports
hash-tool runner   -pipeline ./pipelines/pipeline.json
```

## Documentation complète

-> [ReadTheDocs](https://hash-tool.readthedocs.io)

## Licence

Voir [LICENSE](LICENSE).
