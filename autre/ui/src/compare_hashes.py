#!/usr/bin/env python3

import argparse
import io
import contextlib
import sys
from pathlib import Path

# Ajouter le dossier parent (hash_tool) à sys.path
script_dir = Path(__file__).resolve().parent
project_root = script_dir.parent
sys.path.insert(0, str(project_root))

from src.comparison.compare import compare_databases
from src.comparison.report import generate_html_report
from src.hashing.database import load_database

def main():
    parser = argparse.ArgumentParser(description="Comparaison de bases SQLite")
    parser.add_argument("--base1", required=True, help="Fichier de base de référence (.db)")
    parser.add_argument("--base2", required=True, help="Fichier de base à comparer (.db)")
    parser.add_argument("--output", required=True, help="Fichier de sortie HTML")
    args = parser.parse_args()

    log_buffer = io.StringIO()

    with contextlib.redirect_stdout(log_buffer):
        db1_path = Path(args.base1)
        db2_path = Path(args.base2)
        output_path = Path(args.output)

        print("COMPARAISON DE BASES DE HASH")
        print("=" * 60)
        print(f"Base #1: {db1_path.name}")
        print(f"Base #2: {db2_path.name}\n")

        print("Chargement de la base #1...")
        base1 = load_database(db1_path)
        print(f"  > {len(base1)} fichiers")

        print("Chargement de la base #2...")
        base2 = load_database(db2_path)
        print(f"  > {len(base2)} fichiers\n")

        print("Comparaison en cours...")
        results = compare_databases(base1, base2)

        print("Génération du rapport HTML...")
        generate_html_report(results, db1_path.name, db2_path.name, output_path, log_buffer.getvalue())

        print("COMPARAISON TERMINEE")

    print(log_buffer.getvalue())

if __name__ == "__main__":
    main()