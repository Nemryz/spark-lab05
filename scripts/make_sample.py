# Builds the versioned sample that ships with the repository from the curated tables.

import argparse
import csv
import os
import sys

import pyarrow.parquet as pq

from imdb_common import curated_dir, ensure_dir, sample_path

MAX_BYTES = 5 * 1024 * 1024


def parse_args():
    parser = argparse.ArgumentParser(description="Genera la muestra versionada de IMDb.")
    parser.add_argument("--rows", type=int, default=5000, help="filas que debe tener la muestra")
    return parser.parse_args()


def build_sample(titles, ratings, rows):
    joined = titles.join(ratings, keys="tconst", join_type="inner")
    ordered = joined.sort_by([("numVotes", "descending"), ("tconst", "ascending")])
    total = ordered.num_rows
    step = max(1, total // rows)
    positions = list(range(0, total, step))[:rows]
    return ordered.take(positions)


def format_value(value):
    if isinstance(value, float):
        return "%.1f" % value
    return value


def write_csv(table, path):
    ensure_dir(os.path.dirname(path))
    columns = table.column_names
    with open(path, "w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(columns)
        for record in table.to_pylist():
            writer.writerow([format_value(record[name]) for name in columns])


def summarize(table, path):
    size_kb = os.path.getsize(path) / 1024
    kinds = len(set(table.column("titleType").to_pylist()))
    ratings = [value for value in table.column("averageRating").to_pylist() if value is not None]
    print("[make_sample] %d filas, %.1f KB, %d tipos" % (table.num_rows, size_kb, kinds))
    if ratings:
        print("[make_sample] nota de %.1f a %.1f" % (min(ratings), max(ratings)))
    if os.path.getsize(path) > MAX_BYTES:
        print("[make_sample] aviso, la muestra supera los 5 MB")


def main():
    args = parse_args()
    titles_dir = curated_dir("titles")
    ratings_dir = curated_dir("ratings")
    for path in (titles_dir, ratings_dir):
        if not os.path.isdir(path):
            print("[make_sample] falta %s, ejecuta build_curated.py primero" % path)
            return 1
    try:
        titles = pq.read_table(titles_dir)
        ratings = pq.read_table(ratings_dir, columns=["tconst", "averageRating", "numVotes"])
        sample = build_sample(titles, ratings, args.rows)
        write_csv(sample, sample_path())
    except (OSError, RuntimeError) as error:
        print("[make_sample] error %s" % error)
        return 1
    summarize(sample, sample_path())
    print("[make_sample] archivo en %s" % sample_path())
    return 0


if __name__ == "__main__":
    sys.exit(main())
