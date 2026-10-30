# Smoke test that exercises a real Spark job and prints SMOKE_OK and UI_OK.

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
import traceback
import urllib.request

from pyspark.sql import SparkSession
from pyspark.sql import functions as F

ROW_COUNT = 200
PUBLISHERS = 4
PRICE_CYCLE = 9


def build_frame(spark: SparkSession, directory: str):
    csv_path = os.path.join(directory, "apps.csv")
    with open(csv_path, "w", encoding="utf-8", newline="") as handle:
        handle.write("appid,publisher,price\n")
        for index in range(ROW_COUNT):
            handle.write(
                "%d,publisher-%d,%.1f\n"
                % (index, index % PUBLISHERS, (index % PRICE_CYCLE) + 0.5)
            )
    return spark.read.csv(csv_path, header=True, inferSchema=True)


def check_ui(spark: SparkSession) -> None:
    ui_url = spark.sparkContext.uiWebUrl
    if not ui_url:
        print("UI_WARN the Spark UI is disabled")
        return
    try:
        request = urllib.request.Request(ui_url.rstrip("/") + "/api/v1/applications")
        with urllib.request.urlopen(request, timeout=10) as response:
            payload = json.load(response)
        if isinstance(payload, dict):
            applications = payload.get("applications") or []
        else:
            applications = payload or []
        if applications:
            print("UI_OK")
        else:
            print("UI_WARN the Spark UI returned no applications")
    except Exception as exc:  # pragma: no cover - depends on the local port
        print("UI_WARN %s" % exc)


def run() -> int:
    spark = (
        SparkSession.builder.appName("spark-lab-smoke")
        .master("local[2]")
        .config("spark.ui.enabled", "true")
        .config("spark.sql.shuffle.partitions", "4")
        .config("spark.driver.host", "127.0.0.1")
        .getOrCreate()
    )
    spark.sparkContext.setLogLevel("ERROR")
    directory = tempfile.mkdtemp(prefix="spark-lab-smoke-")
    try:
        frame = build_frame(spark, directory)
        loaded = frame.count()
        if loaded != ROW_COUNT:
            raise AssertionError("read %d rows instead of %d" % (loaded, ROW_COUNT))

        grouped = frame.groupBy("publisher").count().orderBy("publisher").collect()
        if len(grouped) != PUBLISHERS:
            raise AssertionError("groupBy returned %d publishers" % len(grouped))

        parquet_path = os.path.join(directory, "apps.parquet")
        frame.write.mode("overwrite").parquet(parquet_path)
        restored = spark.read.parquet(parquet_path)
        summary = restored.agg(
            F.count("*").alias("rows"), F.sum("price").alias("total")
        ).collect()[0]
        if summary["rows"] != ROW_COUNT:
            raise AssertionError("Parquet round trip lost rows")

        expected = sum((index % PRICE_CYCLE) + 0.5 for index in range(ROW_COUNT))
        if abs(float(summary["total"]) - expected) > 0.001:
            raise AssertionError("Parquet round trip changed the price total")

        print("SMOKE_ROWS %d" % summary["rows"])
        print("SMOKE_PUBLISHERS %d" % len(grouped))
        print("SMOKE_TOTAL %.1f" % summary["total"])
        check_ui(spark)
        print("SMOKE_OK")
        return 0
    except Exception:
        traceback.print_exc()
        return 1
    finally:
        spark.stop()
        shutil.rmtree(directory, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(run())
