# DataFrame demonstration with select, filter, groupBy, agg, orderBy, Window, pivot, explode
# and regexp_replace over the curated IMDb Parquet tables.

from __future__ import annotations

import os
import sys
import time

from pyspark.sql import SparkSession
from pyspark.sql import Window
from pyspark.sql import functions as F

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CURATED_DIR = os.path.join(ROOT, "data", "curated", "imdb")
TITLES_DIR = os.path.join(CURATED_DIR, "titles")
RATINGS_DIR = os.path.join(CURATED_DIR, "ratings")

SHUFFLE_PARTITIONS = 8
DISPLAY_ROWS = 8


def create_session():
    spark = (
        SparkSession.builder.appName("spark-lab-dataframe")
        .master("local[2]")
        .config("spark.sql.shuffle.partitions", str(SHUFFLE_PARTITIONS))
        .config("spark.driver.host", "127.0.0.1")
        .getOrCreate()
    )
    spark.sparkContext.setLogLevel("ERROR")
    return spark


def read_tables(spark):
    titles = spark.read.parquet(TITLES_DIR)
    ratings = spark.read.parquet(RATINGS_DIR)
    return titles.join(ratings, "tconst")


def with_genres(movies):
    listed = F.coalesce(F.col("genres"), F.lit("Unknown"))
    return movies.withColumn("genre", F.explode(F.split(listed, ",")))


def show_select(movies):
    columns = ["tconst", "primaryTitle", "startYear", "averageRating", "numVotes"]
    print("[dataframe] select proyecta %d de %d columnas" % (len(columns), len(movies.columns)))
    selected = movies.select(*columns)
    selected.show(5, truncate=30)
    return selected


def show_filter(movies):
    condition = (F.col("startYear") >= 1990) & (F.col("titleType") == "movie") & (F.col("numVotes") >= 10000)
    recent = movies.filter(condition)
    print("[dataframe] filter deja %d peliculas desde 1990 con diez mil votos o mas" % recent.count())
    recent.select("primaryTitle", "startYear", "numVotes").show(DISPLAY_ROWS, truncate=30)
    return recent


def show_group_by(movies):
    grouped = with_genres(movies).groupBy("genre", "decade").count()
    print("[dataframe] groupBy produce %d combinaciones de genero y decada" % grouped.count())
    grouped.orderBy(F.col("count").desc()).show(DISPLAY_ROWS)
    return grouped


def show_agg(movies):
    summary = with_genres(movies).groupBy("genre").agg(
        F.round(F.avg("averageRating"), 3).alias("nota_media"),
        F.sum("numVotes").alias("votos"),
        F.count("*").alias("titulos"),
    )
    print("[dataframe] agg calcula nota media, votos y titulos por genero")
    summary.orderBy(F.col("votos").desc()).show(DISPLAY_ROWS, truncate=False)
    summary.orderBy(F.col("votos").desc()).explain()
    return summary


def show_order_by(movies):
    ranked = movies.orderBy(F.col("averageRating").desc(), F.col("numVotes").desc())
    print("[dataframe] orderBy desempata la nota por cantidad de votos")
    ranked.select("primaryTitle", "startYear", "averageRating", "numVotes").show(DISPLAY_ROWS, truncate=30)
    return ranked


def show_window(movies):
    window = Window.partitionBy("genre").orderBy(F.col("averageRating").desc(), F.col("numVotes").desc())
    topped = with_genres(movies).withColumn("posicion", F.row_number().over(window))
    top = topped.filter(F.col("posicion") <= 3)
    print("[dataframe] Window con row_number deja tres titulos por genero")
    top.select("genre", "posicion", "primaryTitle", "averageRating").orderBy("genre", "posicion").show(12, truncate=25)
    return top


def show_pivot(movies):
    kinds = ["movie", "tvSeries", "tvMovie"]
    pivot = movies.groupBy("decade").pivot("titleType", kinds).agg(F.round(F.avg("averageRating"), 2))
    print("[dataframe] pivot cruza la decada con tres tipos de titulo")
    pivot.orderBy("decade").show(20, truncate=False)
    return pivot


def show_regexp(movies):
    clean = F.lower(F.regexp_replace(F.col("primaryTitle"), "[^A-Za-z0-9 ]", ""))
    normalised = movies.withColumn("titulo_normalizado", clean)
    repeated = normalised.groupBy("titulo_normalizado").count().filter(F.col("count") > 1)
    print("[dataframe] regexp_replace encuentra %d titulos repetidos" % repeated.count())
    repeated.orderBy(F.col("count").desc()).show(DISPLAY_ROWS, truncate=40)
    return normalised


def show_extras(movies):
    naive = movies.stat.corr("runtimeMinutes", "averageRating")
    timed = movies.filter(F.col("runtimeMinutes").isNotNull())
    correlation = timed.stat.corr("runtimeMinutes", "averageRating")
    median = movies.groupBy("titleType").agg(
        F.percentile_approx("numVotes", 0.5).alias("mediana_votos")
    )
    print("[dataframe] corr sin filtrar nulos da %.3f porque Spark los lee como cero" % naive)
    print("[dataframe] corr entre duracion y nota da %.3f sobre %d titulos" % (correlation, timed.count()))
    median.orderBy(F.col("mediana_votos").desc()).show(9, truncate=False)
    return median


def main():
    started = time.perf_counter()
    spark = create_session()
    try:
        movies = read_tables(spark).persist()
        print("[dataframe] leidos %d titulos con nota" % movies.count())

        show_select(movies)
        show_filter(movies)
        show_group_by(movies)
        show_agg(movies)
        show_order_by(movies)
        show_window(movies)
        show_pivot(movies)
        show_regexp(movies)
        show_extras(movies)
    finally:
        spark.stop()
    print("[dataframe] demo terminada en %.1f s" % (time.perf_counter() - started))
    return 0


if __name__ == "__main__":
    sys.exit(main())
