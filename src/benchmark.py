# Compares one query on three paths and writes informe\mediciones.csv with the timings.

from __future__ import annotations

import csv
import os
import sys
import time

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql import types as T

from rdd_lab import CURATED_DIR, RATINGS_PATH, TITLES_PATH, parse_rating, parse_title, read_body

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INFORME_DIR = os.path.join(ROOT, "informe")
MEASUREMENTS_PATH = os.path.join(INFORME_DIR, "mediciones.csv")

QUERY = "nota_ponderada_por_decada"
SHUFFLE_PARTITIONS = 8
REPEATS = 2
TOLERANCE = 0.01

TITLES_SCHEMA = T.StructType([
    T.StructField("tconst", T.StringType(), False),
    T.StructField("titleType", T.StringType(), False),
    T.StructField("primaryTitle", T.StringType(), False),
    T.StructField("originalTitle", T.StringType(), True),
    T.StructField("isAdult", T.IntegerType(), False),
    T.StructField("startYear", T.IntegerType(), False),
    T.StructField("endYear", T.IntegerType(), True),
    T.StructField("runtimeMinutes", T.IntegerType(), True),
    T.StructField("decade", T.IntegerType(), False),
    T.StructField("genres", T.StringType(), True),
])

RATINGS_SCHEMA = T.StructType([
    T.StructField("tconst", T.StringType(), False),
    T.StructField("averageRating", T.DoubleType(), False),
    T.StructField("numVotes", T.IntegerType(), False),
])


def create_session():
    spark = (
        SparkSession.builder.appName("spark-lab-benchmark")
        .master("local[2]")
        .config("spark.sql.shuffle.partitions", str(SHUFFLE_PARTITIONS))
        .config("spark.driver.host", "127.0.0.1")
        .getOrCreate()
    )
    spark.sparkContext.setLogLevel("ERROR")
    return spark


def read_tsv(spark):
    options = {"sep": "\t", "header": True}
    titles = spark.read.options(**options).schema(TITLES_SCHEMA).csv(TITLES_PATH)
    ratings = spark.read.options(**options).schema(RATINGS_SCHEMA).csv(RATINGS_PATH)
    return titles.join(ratings, "tconst")


def read_parquet(spark):
    titles = spark.read.parquet(os.path.join(CURATED_DIR, "titles"))
    ratings = spark.read.parquet(os.path.join(CURATED_DIR, "ratings"))
    return titles.join(ratings, "tconst")


def weighted_by_decade(frame):
    weighted = frame.select(
        "decade",
        (F.col("averageRating") * F.col("numVotes")).alias("weighted"),
        "numVotes",
    )
    return weighted.groupBy("decade").agg(
        F.round(F.sum("weighted") / F.sum("numVotes"), 3).alias("nota_ponderada")
    ).orderBy("decade")


def rows_from_frame(frame):
    return [(row["decade"], row["nota_ponderada"]) for row in weighted_by_decade(frame).collect()]


def rows_from_rdd(sc):
    titles = read_body(sc, TITLES_PATH).map(parse_title).filter(lambda row: row is not None)
    ratings = read_body(sc, RATINGS_PATH).map(parse_rating).filter(lambda row: row is not None)
    joined = titles.map(lambda row: (row[0], row[3])).join(ratings.map(lambda row: (row[0], row[1:])))
    totals = joined.map(lambda item: (item[1][0] // 10 * 10, (item[1][1][0] * item[1][1][1], item[1][1][1])))
    sums = totals.reduceByKey(lambda left, right: (left[0] + right[0], left[1] + right[1]))
    return sorted(sums.mapValues(lambda value: round(value[0] / value[1], 3)).collect())


def measure(build):
    elapsed = 0.0
    rows = []
    for _ in range(REPEATS):
        started = time.perf_counter()
        rows = build()
        elapsed = (time.perf_counter() - started) * 1000
    return elapsed, rows


def same_rows(first, second):
    if len(first) != len(second):
        return False
    for left, right in zip(first, second):
        if left[0] != right[0] or abs(left[1] - right[1]) > TOLERANCE:
            return False
    return True


def write_measurements(measurements):
    if not os.path.isdir(INFORME_DIR):
        os.makedirs(INFORME_DIR)
    with open(MEASUREMENTS_PATH, "w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["consulta", "interfaz", "milisegundos"])
        for interface, milliseconds in measurements:
            writer.writerow([QUERY, interface, "%.0f" % milliseconds])
    print("[benchmark] mediciones en %s" % MEASUREMENTS_PATH)


def main():
    spark = create_session()
    try:
        spark.sparkContext.addPyFile(os.path.join(ROOT, "src", "rdd_lab.py"))
        rdd_ms, rdd_rows = measure(lambda: rows_from_rdd(spark.sparkContext))
        print("[benchmark] rdd sobre tsv deja %d filas en %.0f ms" % (len(rdd_rows), rdd_ms))
        tsv_ms, tsv_rows = measure(lambda: rows_from_frame(read_tsv(spark)))
        print("[benchmark] dataframe sobre tsv deja %d filas en %.0f ms" % (len(tsv_rows), tsv_ms))
        parquet_ms, parquet_rows = measure(lambda: rows_from_frame(read_parquet(spark)))
        print("[benchmark] dataframe sobre parquet deja %d filas en %.0f ms" % (len(parquet_rows), parquet_ms))
        if not same_rows(rdd_rows, tsv_rows) or not same_rows(rdd_rows, parquet_rows):
            print("[benchmark] aviso, las tres rutas no coinciden")
            return 1
        write_measurements([
            ("rdd_tsv", rdd_ms),
            ("dataframe_tsv", tsv_ms),
            ("dataframe_parquet", parquet_ms),
        ])
    finally:
        spark.stop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
