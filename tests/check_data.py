# Checks the curated datasets and the published sample without starting Spark.

import csv
import os
import sys

import pyarrow.parquet as pq

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "scripts"))

from imdb_common import curated_dir, sample_path

EXPECTED_COLUMNS = [
    "tconst",
    "titleType",
    "primaryTitle",
    "originalTitle",
    "isAdult",
    "startYear",
    "endYear",
    "runtimeMinutes",
    "decade",
    "genres",
]
MAX_SAMPLE_BYTES = 5 * 1024 * 1024


def report(name, passed, detail):
    print("%s %-8s %s" % ("OK  " if passed else "FALLA", name, detail))
    return 0 if passed else 1


def decades_consistent(titles):
    years = titles.column("startYear").to_pylist()
    decades = titles.column("decade").to_pylist()
    for year, decade in zip(years, decades):
        if decade != (year // 10) * 10:
            return False
    return True


def read_sample(path):
    if not os.path.exists(path):
        return [], 0
    with open(path, "r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    return rows, os.path.getsize(path)


def main():
    try:
        titles = pq.read_table(curated_dir("titles"))
        ratings = pq.read_table(curated_dir("ratings"), columns=["tconst"])
    except OSError as error:
        print("[check_data] error %s" % error)
        print("[check_data] ejecuta build_curated.py primero")
        return 1
    rows, size = read_sample(sample_path())
    keys = set(titles.column("tconst").to_pylist())
    sample_keys = set(row["tconst"] for row in rows)
    kinds = set(titles.column("titleType").to_pylist())

    failures = 0
    failures += report("titulos", titles.num_rows > 0, "%d filas" % titles.num_rows)
    failures += report("notas", ratings.num_rows > titles.num_rows, "%d filas" % ratings.num_rows)
    failures += report("esquema", titles.column_names == EXPECTED_COLUMNS, "%d columnas" % len(titles.column_names))
    failures += report("claves", titles.column("tconst").null_count == 0, "sin nulos")
    failures += report("episodios", "tvEpisode" not in kinds, "%d tipos" % len(kinds))
    failures += report("decadas", decades_consistent(titles), "coherentes con el año")
    sample_ok = len(rows) > 0 and size < MAX_SAMPLE_BYTES and sample_keys <= keys
    failures += report("muestra", sample_ok, "%d filas, %.1f KB" % (len(rows), size / 1024))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
