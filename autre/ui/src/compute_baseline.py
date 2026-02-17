#!/usr/bin/env python3

import argparse
import sys
from pathlib import Path

# Ajouter le dossier parent (hash_tool) à sys.path
script_dir = Path(__file__).resolve().parent
project_root = script_dir.parent
sys.path.insert(0, str(project_root))

from src.hashing.database import build_database
from src.hashing.compute import list_files

def main():
    parser = argparse.ArgumentParser(
        description="Génération d'une base de hash SQLite (BLAKE3)"
    )
    parser.add_argument("folder", help="Dossier à analyser")
    parser.add_argument("output", help="Fichier de sortie .db")
    args = parser.parse_args()

    folder = Path(args.folder)
    output = Path(args.output)

    if not folder.exists() or not folder.is_dir():
        print(f"Erreur : dossier invalide -> {folder}")
        sys.exit(1)

    files = list_files(folder)
    print("CALCUL DE LA BASE DE HASH (BLAKE3)")
    print("=" * 60)
    print(f"Dossier analysé : {folder}")
    print(f"Nombre de fichiers : {len(files)}\n")

    build_database(folder, output)

    print(f"\nBase de hash générée : {output}")
    print("TERMINE")

if __name__ == "__main__":
    main()