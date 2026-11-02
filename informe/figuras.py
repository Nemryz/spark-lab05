# Builds the four figures of the report from the curated Parquet and the measurements file.

from __future__ import annotations

import csv
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import pandas as pd
from matplotlib.colors import LogNorm

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CURATED_DIR = os.path.join(ROOT, "data", "curated", "imdb")
MEASUREMENTS_PATH = os.path.join(HERE, "mediciones.csv")
FIGURES_DIR = os.path.join(HERE, "figuras")

DPI = 200
WIDTH = 6.4
FIRST_DECADE = 1920
GREEN = "#1f6f4a"
ORANGE = "#c1651b"
GREY = "#8a8f98"


def load_joined():
    titles = pd.read_parquet(os.path.join(CURATED_DIR, "titles"))
    ratings = pd.read_parquet(os.path.join(CURATED_DIR, "ratings"))
    return titles.merge(ratings, on="tconst", how="inner")


def save(figure, name):
    if not os.path.isdir(FIGURES_DIR):
        os.makedirs(FIGURES_DIR)
    path = os.path.join(FIGURES_DIR, name)
    figure.tight_layout()
    figure.savefig(path, dpi=DPI, bbox_inches="tight")
    plt.close(figure)
    print("[figuras] %s" % path)


def read_measurements():
    rows = []
    with open(MEASUREMENTS_PATH, "r", encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            rows.append((row["interfaz"], int(row["milisegundos"])))
    return rows


def clean_axes(axes, grid_axis="x"):
    axes.grid(axis=grid_axis, color="#dddddd", linewidth=0.6)
    axes.set_axisbelow(True)
    for side in ("top", "right"):
        axes.spines[side].set_visible(False)


def figure_paths(rows):
    labels = ["RDD\nsobre TSV", "DataFrame\nsobre TSV", "DataFrame\nsobre Parquet"]
    values = [value for _, value in rows]
    figure, (left, right) = plt.subplots(1, 2, figsize=(WIDTH, 2.7),
                                         gridspec_kw={"width_ratios": [2.4, 1]})
    left.barh(labels, values, color=[ORANGE, GREEN, GREEN], height=0.6)
    left.invert_yaxis()
    left.set_xlabel("milisegundos")
    left.tick_params(axis="y", labelsize=8)
    for position, value in enumerate(values):
        left.text(value * 1.02, position, ("%d" % value), va="center", fontsize=8)
    left.set_xlim(0, max(values) * 1.18)
    clean_axes(left)

    right.barh(labels[1:], values[1:], color=GREEN, height=0.5)
    right.invert_yaxis()
    right.set_xlabel("milisegundos")
    right.tick_params(axis="y", labelsize=8)
    for position, value in enumerate(values[1:]):
        right.text(value * 1.03, position, ("%d" % value), va="center", fontsize=8)
    right.set_xlim(0, max(values[1:]) * 1.35)
    clean_axes(right)
    save(figure, "rutas.png")


def figure_decades(frame):
    sample = frame[frame.decade >= FIRST_DECADE]
    weighted = (sample.averageRating * sample.numVotes).groupby(sample.decade).sum()
    votes = sample.groupby("decade").numVotes.sum()
    means = weighted / votes
    counts = sample.groupby("decade").size()
    overall = (frame.averageRating * frame.numVotes).sum() / frame.numVotes.sum()

    figure, (upper, lower) = plt.subplots(2, 1, figsize=(WIDTH, 4.0), sharex=True,
                                          gridspec_kw={"height_ratios": [2, 1]})
    upper.plot(means.index, means.values, color=GREEN, linewidth=1.8, marker="o", markersize=4)
    upper.set_ylabel("nota ponderada")
    upper.set_ylim(6.4, 7.9)
    upper.axhline(overall, color=GREY, linestyle="--", linewidth=1)
    upper.text(means.index.min() + 1, overall + 0.05, "media global %.3f" % overall,
               fontsize=8, color=GREY)
    lower.bar(counts.index, counts.values, width=7, color=GREY, alpha=0.8)
    lower.set_ylabel("títulos")
    lower.set_xlabel("década de estreno")
    lower.yaxis.set_major_formatter(ticker.FuncFormatter(lambda value, _: "%d" % value))
    for axes in (upper, lower):
        clean_axes(axes, "y")
    save(figure, "decadas.png")


def figure_votes_rating(frame):
    pairs = frame[["numVotes", "averageRating"]].dropna()
    buckets = (pairs.numVotes.map(lambda value: int(value).bit_length()) // 1).astype(int)
    median = pairs.groupby(buckets).agg(votos=("numVotes", "median"), nota=("averageRating", "median"))
    figure, axes = plt.subplots(figsize=(WIDTH, 3.4))
    grid = axes.hexbin(pairs.numVotes, pairs.averageRating, gridsize=45, xscale="log",
                       cmap="Greens", norm=LogNorm(), mincnt=1, linewidths=0)
    axes.plot(median.votos, median.nota, color=ORANGE, linewidth=2, label="mediana por tramo de votos")
    axes.set_xlabel("votos por título, escala logarítmica")
    axes.set_ylabel("nota media")
    axes.set_xlim(900, 4000000)
    axes.set_ylim(0.5, 10)
    axes.legend(loc="lower right", fontsize=8, frameon=False)
    bar = figure.colorbar(grid, ax=axes, pad=0.01)
    bar.set_label("títulos por celda", fontsize=8)
    clean_axes(axes, "y")
    save(figure, "votos_nota.png")


def figure_top(frame):
    best = frame.nlargest(10, "numVotes").iloc[::-1]
    figure, axes = plt.subplots(figsize=(WIDTH, 3.2))
    axes.barh(best.primaryTitle, best.numVotes / 1000000.0, color=ORANGE, height=0.62)
    axes.set_xlabel("millones de votos")
    axes.set_xlim(0, best.numVotes.max() / 1000000.0 * 1.22)
    axes.tick_params(axis="y", labelsize=8)
    for position, (_, row) in enumerate(best.iterrows()):
        text = ("%.1f" % row.averageRating).replace(".", ",")
        axes.text(row.numVotes / 1000000.0 * 1.01, position, "nota " + text, va="center", fontsize=8)
    clean_axes(axes)
    save(figure, "top_votos.png")


def main():
    rows = read_measurements()
    frame = load_joined()
    print("[figuras] %d títulos cruzados" % len(frame))
    figure_paths(rows)
    figure_decades(frame)
    figure_votes_rating(frame)
    figure_top(frame)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
