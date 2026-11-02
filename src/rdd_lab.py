# RDD demonstration with mapPartitionsWithIndex, distinct, partitionBy, join, takeOrdered,
# aggregate, countByValue and foreachPartition over the curated IMDb text files.

from __future__ import annotations

import os
import shutil
import sys
import time

from pyspark import TaskContext
from pyspark.sql import SparkSession

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CURATED_DIR = os.path.join(ROOT, "data", "curated", "imdb")
TITLES_PATH = os.path.join(CURATED_DIR, "titles.tsv")
RATINGS_PATH = os.path.join(CURATED_DIR, "ratings.tsv")
SUMMARY_DIR = os.path.join(CURATED_DIR, "_resumen_rdd")
SUMMARY_PATH = os.path.join(CURATED_DIR, "resumen_particiones.txt")

TITLE_COLUMNS = 10
RATING_COLUMNS = 3
MIN_PARTITIONS = 8
TOP_SIZE = 10


def create_session():
    spark = (
        SparkSession.builder.appName("spark-lab-rdd")
        .master("local[2]")
        .config("spark.sql.shuffle.partitions", str(MIN_PARTITIONS))
        .config("spark.default.parallelism", str(MIN_PARTITIONS))
        .config("spark.driver.host", "127.0.0.1")
        .getOrCreate()
    )
    spark.sparkContext.setLogLevel("ERROR")
    return spark


def read_body(sc, path):
    return sc.textFile(path, minPartitions=MIN_PARTITIONS)


def parse_title(line):
    parts = line.split("\t")
    if len(parts) != TITLE_COLUMNS or parts[0] == "tconst":
        return None
    return parts[0], parts[1], parts[2], int(parts[5])


def parse_rating(line):
    parts = line.split("\t")
    if len(parts) != RATING_COLUMNS or parts[0] == "tconst":
        return None
    return parts[0], float(parts[1]), int(parts[2])


def count_items(index, items):
    total = 0
    for item in items:
        total += 1
    yield index, total


def show_partitions(rdd, label):
    counts = rdd.mapPartitionsWithIndex(count_items).collect()
    counts.sort()
    print("[rdd] %s ocupa %d particiones con %s elementos" % (label, len(counts), [n for _, n in counts]))
    return counts


def show_distinct(title_types):
    unique = sorted(title_types.distinct().collect())
    print("[rdd] distinct deja %d tipos de titulo" % len(unique))
    print("[rdd] tipos %s" % ", ".join(unique))
    return unique


def show_partition_by(titles):
    pairs = titles.map(lambda row: (row[0], (row[2], row[3]))).partitionBy(MIN_PARTITIONS)
    show_partitions(pairs, "partitionBy")
    print("[rdd] partitionBy coloca cada tconst en una sola particion por hash")
    return pairs


def show_join(pairs, ratings):
    started = time.perf_counter()
    joined = pairs.join(ratings.map(lambda row: (row[0], (row[1], row[2]))), MIN_PARTITIONS).persist()
    matched = joined.count()
    elapsed = time.perf_counter() - started
    print("[rdd] join empareja %d pares en %.1f s" % (matched, elapsed))
    return joined


def show_best(flat):
    best = flat.takeOrdered(TOP_SIZE, key=lambda item: -item[2])
    print("[rdd] takeOrdered devuelve los %d titulos con mas votos" % len(best))
    for title, rating, votes in best:
        print("[rdd]   %-38s %4.1f %8d" % (title[:38], rating, votes))
    return best


def add_weighted(total, item):
    return total[0] + item[1] * item[2], total[1] + item[2]


def merge_weighted(left, right):
    return left[0] + right[0], left[1] + right[1]


def show_weighted_mean(flat):
    weighted, votes = flat.aggregate((0.0, 0), add_weighted, merge_weighted)
    mean = weighted / votes
    print("[rdd] aggregate calcula la nota media ponderada %.3f sobre %d votos" % (mean, votes))
    return mean


def show_count_by_value(title_types):
    counts = title_types.countByValue()
    ordered = sorted(counts.items(), key=lambda item: (-item[1], item[0]))
    print("[rdd] countByValue devuelve %d tipos" % len(ordered))
    for kind, total in ordered:
        print("[rdd]   %-12s %6d" % (kind, total))
    return counts


def write_partition(items):
    index = TaskContext.get().partitionId()
    rows = 0
    votes = 0
    for _, _, count in items:
        rows += 1
        votes += count
    path = os.path.join(SUMMARY_DIR, "part-%02d.txt" % index)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("particion %d titulos %d votos %d\n" % (index, rows, votes))


def show_partition_summary(flat):
    if os.path.isdir(SUMMARY_DIR):
        shutil.rmtree(SUMMARY_DIR)
    os.makedirs(SUMMARY_DIR)
    flat.foreachPartition(write_partition)
    lines = []
    for name in sorted(os.listdir(SUMMARY_DIR)):
        with open(os.path.join(SUMMARY_DIR, name), "r", encoding="utf-8") as handle:
            lines.append(handle.read())
    with open(SUMMARY_PATH, "w", encoding="utf-8") as handle:
        handle.writelines(lines)
    shutil.rmtree(SUMMARY_DIR, ignore_errors=True)
    print("[rdd] foreachPartition dejo %d lineas en %s" % (len(lines), SUMMARY_PATH))
    return lines


def main():
    started = time.perf_counter()
    spark = create_session()
    try:
        sc = spark.sparkContext
        titles = read_body(sc, TITLES_PATH).map(parse_title).filter(lambda row: row is not None).persist()
        ratings = read_body(sc, RATINGS_PATH).map(parse_rating).filter(lambda row: row is not None)
        print("[rdd] leidos %d titulos y %d notas" % (titles.count(), ratings.count()))

        show_partitions(titles, "titles")
        title_types = titles.map(lambda row: row[1])
        show_distinct(title_types)
        pairs = show_partition_by(titles)
        joined = show_join(pairs, ratings)
        flat = joined.map(lambda item: (item[1][0][0], item[1][1][0], item[1][1][1])).persist()

        show_best(flat)
        show_weighted_mean(flat)
        show_count_by_value(title_types)
        show_partition_summary(flat)
    finally:
        spark.stop()
    print("[rdd] demo terminada en %.1f s" % (time.perf_counter() - started))
    return 0


if __name__ == "__main__":
    sys.exit(main())
