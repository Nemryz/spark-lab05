# Shared constants and small helpers for the IMDb ingestion scripts.

import hashlib
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(ROOT, "data")
RAW_DIR = os.path.join(DATA_DIR, "raw", "imdb")
CURATED_DIR = os.path.join(DATA_DIR, "curated", "imdb")
SAMPLE_DIR = os.path.join(DATA_DIR, "sample")
MANIFEST_PATH = os.path.join(RAW_DIR, "manifest.json")

RESOURCES = {
    "basics": ("https://datasets.imdbws.com/title.basics.tsv.gz", "title.basics.tsv.gz"),
    "ratings": ("https://datasets.imdbws.com/title.ratings.tsv.gz", "title.ratings.tsv.gz"),
}

MIN_VOTES = 1000
EXCLUDED_TYPES = ("tvEpisode",)
CHUNK_ROWS = 50000


def raw_path(name):
    return os.path.join(RAW_DIR, RESOURCES[name][1])


def curated_dir(name):
    return os.path.join(CURATED_DIR, name)


def sample_path():
    return os.path.join(SAMPLE_DIR, "imdb_sample.csv")


def ensure_dir(path):
    os.makedirs(path, exist_ok=True)


def read_json(path, default):
    if not os.path.exists(path):
        return default
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path, data):
    parent = os.path.dirname(path)
    if parent:
        ensure_dir(parent)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        while True:
            block = handle.read(1024 * 1024)
            if not block:
                break
            digest.update(block)
    return digest.hexdigest()


def to_int(text):
    if text in ("\\N", ""):
        return None
    try:
        return int(text)
    except ValueError:
        return None


def to_float(text):
    if text in ("\\N", ""):
        return None
    try:
        return float(text)
    except ValueError:
        return None


def null_text(text):
    if text == "\\N":
        return None
    return text
