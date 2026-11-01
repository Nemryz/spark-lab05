# Turns the raw IMDb files into typed Parquet tables filtered by votes and title type.

import argparse
import csv
import gzip
import os
import shutil
import sys
import time

import pyarrow as pa
import pyarrow.parquet as pq

from imdb_common import (
    CHUNK_ROWS,
    CURATED_DIR,
    EXCLUDED_TYPES,
    MIN_VOTES,
    curated_dir,
    null_text,
    raw_path,
    to_float,
    to_int,
    write_json,
)

TITLES_SCHEMA = pa.schema([
    pa.field("tconst", pa.string(), nullable=False),
    pa.field("titleType", pa.string(), nullable=False),
    pa.field("primaryTitle", pa.string(), nullable=False),
    pa.field("originalTitle", pa.string()),
    pa.field("isAdult", pa.int8(), nullable=False),
    pa.field("startYear", pa.int32(), nullable=False),
    pa.field("endYear", pa.int32()),
    pa.field("runtimeMinutes", pa.int32()),
    pa.field("decade", pa.int32(), nullable=False),
    pa.field("genres", pa.string()),
])

RATINGS_SCHEMA = pa.schema([
    pa.field("tconst", pa.string(), nullable=False),
    pa.field("averageRating", pa.float32(), nullable=False),
    pa.field("numVotes", pa.int32(), nullable=False),
])


def parse_args():
    parser = argparse.ArgumentParser(description="Construye las tablas curadas de IMDb.")
    parser.add_argument("--limit", type=int, default=0, help="lee solo N filas por archivo, util para probar")
    return parser.parse_args()


def open_tsv(name):
    handle = gzip.open(raw_path(name), "rt", encoding="utf-8", newline="")
    reader = csv.reader(handle, delimiter="\t", quoting=csv.QUOTE_NONE)
    header = next(reader)
    return handle, reader, header


def make_index(columns):
    index = {}
    for position, name in enumerate(columns):
        index[name] = position
    return index


def prepare_target(path):
    if os.path.isdir(path):
        shutil.rmtree(path)
    os.makedirs(path, exist_ok=True)


def write_chunk(rows, target, schema, part):
    if not rows:
        return part
    table = pa.Table.from_pylist(rows, schema=schema)
    path = os.path.join(target, "part-%05d.parquet" % part)
    pq.write_table(table, path, compression="snappy")
    return part + 1


def rating_record(row, index):
    key = row[index["tconst"]]
    votes = to_int(row[index["numVotes"]])
    rating = to_float(row[index["averageRating"]])
    if not key or votes is None or rating is None:
        return None
    return {"tconst": key, "averageRating": rating, "numVotes": votes}


def title_record(row, index, keys):
    key = row[index["tconst"]]
    if not key or key not in keys:
        return None
    kind = row[index["titleType"]]
    if kind in EXCLUDED_TYPES:
        return None
    year = to_int(row[index["startYear"]])
    if year is None:
        return None
    return {
        "tconst": key,
        "titleType": kind,
        "primaryTitle": row[index["primaryTitle"]],
        "originalTitle": null_text(row[index["originalTitle"]]),
        "isAdult": to_int(row[index["isAdult"]]) or 0,
        "startYear": year,
        "endYear": to_int(row[index["endYear"]]),
        "runtimeMinutes": to_int(row[index["runtimeMinutes"]]),
        "decade": (year // 10) * 10,
        "genres": null_text(row[index["genres"]]),
    }


def build_ratings(limit):
    target = curated_dir("ratings")
    prepare_target(target)
    handle, reader, columns = open_tsv("ratings")
    index = make_index(columns)
    keys = set()
    chunk = []
    part = 0
    total = 0
    try:
        for row in reader:
            record = rating_record(row, index)
            if record is None:
                continue
            chunk.append(record)
            if record["numVotes"] >= MIN_VOTES:
                keys.add(record["tconst"])
            total += 1
            if len(chunk) >= CHUNK_ROWS:
                part = write_chunk(chunk, target, RATINGS_SCHEMA, part)
                chunk = []
            if limit and total >= limit:
                break
        part = write_chunk(chunk, target, RATINGS_SCHEMA, part)
    finally:
        handle.close()
    print("[build_curated] notas %d filas, %d claves con %d votos o mas" % (total, len(keys), MIN_VOTES))
    return keys, total


def build_titles(keys, limit):
    target = curated_dir("titles")
    prepare_target(target)
    handle, reader, columns = open_tsv("basics")
    index = make_index(columns)
    chunk = []
    part = 0
    total = 0
    kept = 0
    try:
        for row in reader:
            total += 1
            record = title_record(row, index, keys)
            if record is not None:
                chunk.append(record)
                kept += 1
            if len(chunk) >= CHUNK_ROWS:
                part = write_chunk(chunk, target, TITLES_SCHEMA, part)
                chunk = []
            if limit and total >= limit:
                break
        part = write_chunk(chunk, target, TITLES_SCHEMA, part)
    finally:
        handle.close()
    print("[build_curated] titulos %d leidos, %d conservados" % (total, kept))
    return kept


def clean_value(value):
    if value is None:
        return ""
    return str(value).replace("\t", " ").replace("\n", " ").replace("\r", " ")


def export_tsv(name, filename):
    directory = curated_dir(name)
    path = os.path.join(CURATED_DIR, filename)
    with open(path, "w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t", quoting=csv.QUOTE_NONE, quotechar=None)
        header = True
        for part in sorted(os.listdir(directory)):
            table = pq.read_table(os.path.join(directory, part))
            if header:
                writer.writerow(table.column_names)
                header = False
            for record in table.to_pylist():
                writer.writerow([clean_value(record[c]) for c in table.column_names])
    return path


def main():
    args = parse_args()
    started = time.time()
    for name in ("basics", "ratings"):
        if not os.path.exists(raw_path(name)):
            print("[build_curated] falta %s, ejecuta get_data.py primero" % raw_path(name))
            return 1
    try:
        keys, rating_rows = build_ratings(args.limit)
        title_rows = build_titles(keys, args.limit)
        export_tsv("titles", "titles.tsv")
        export_tsv("ratings", "ratings.tsv")
        stats = {
            "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "min_votes": MIN_VOTES,
            "excluded_types": list(EXCLUDED_TYPES),
            "ratings_rows": rating_rows,
            "titles_rows": title_rows,
        }
        write_json(os.path.join(CURATED_DIR, "_stats.json"), stats)
    except (OSError, RuntimeError, KeyError) as error:
        print("[build_curated] error %s" % error)
        return 1
    print("[build_curated] listo en %.1f s" % (time.time() - started))
    return 0


if __name__ == "__main__":
    sys.exit(main())
