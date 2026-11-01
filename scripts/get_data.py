# Downloads the IMDb files with resume support and records a manifest with their hashes.

import argparse
import os
import shutil
import sys
import time
import urllib.error
import urllib.request

from imdb_common import (
    MANIFEST_PATH,
    RAW_DIR,
    RESOURCES,
    ensure_dir,
    raw_path,
    read_json,
    sha256_file,
    write_json,
)

BLOCK_BYTES = 1024 * 1024
REPORT_BYTES = 64 * 1024 * 1024
MIN_FREE_GB = 1.5


def parse_args():
    parser = argparse.ArgumentParser(description="Descarga los archivos publicos de IMDb.")
    parser.add_argument("--resource", choices=["basics", "ratings", "all"], default="all")
    parser.add_argument("--force", action="store_true", help="descarga aunque el archivo exista")
    parser.add_argument("--offline", action="store_true", help="no descarga, solo usa lo que ya existe")
    parser.add_argument("--timeout", type=int, default=120, help="segundos por lectura de red")
    return parser.parse_args()


def check_space():
    free_gb = shutil.disk_usage(RAW_DIR).free / (1024 ** 3)
    if free_gb < MIN_FREE_GB:
        raise RuntimeError("espacio insuficiente, quedan %.2f GB" % free_gb)


def is_gzip(path):
    with open(path, "rb") as handle:
        return handle.read(2) == b"\x1f\x8b"


def write_stream(response, handle, start, name):
    downloaded = start
    next_report = start + REPORT_BYTES
    while True:
        block = response.read(BLOCK_BYTES)
        if not block:
            break
        handle.write(block)
        downloaded += len(block)
        if downloaded >= next_report:
            print("  %s %.0f MB" % (name, downloaded / (1024 * 1024)))
            next_report += REPORT_BYTES
    return downloaded


def download(url, target, timeout):
    part = target + ".part"
    start = os.path.getsize(part) if os.path.exists(part) else 0
    request = urllib.request.Request(url)
    if start > 0:
        request.add_header("Range", "bytes=%d-" % start)
    with urllib.request.urlopen(request, timeout=timeout) as response:
        if start > 0 and response.status != 206:
            print("  el servidor no acepta reanudacion, se reinicia la descarga")
            start = 0
        with open(part, "ab" if start > 0 else "wb") as handle:
            write_stream(response, handle, start, os.path.basename(target))
    os.replace(part, target)


def record(name, url, target, digest, manifest):
    files = manifest.setdefault("files", {})
    files[name] = {
        "url": url,
        "bytes": os.path.getsize(target),
        "sha256": digest,
        "downloaded_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    write_json(MANIFEST_PATH, manifest)
    return manifest


def fetch(name, args, manifest):
    url, filename = RESOURCES[name]
    target = raw_path(name)
    previous = manifest.get("files", {}).get(name)
    if os.path.exists(target) and is_gzip(target) and not args.force:
        digest = sha256_file(target)
        if previous and previous.get("sha256") == digest:
            print("[get_data] %-7s ya completo" % name)
            return manifest
        print("[get_data] %-7s adopta el archivo existente, sha256 %s" % (name, digest[:12]))
        return record(name, url, target, digest, manifest)
    if args.offline:
        raise RuntimeError("falta %s y se pidio modo sin conexion" % filename)
    print("[get_data] %-7s descarga %s" % (name, filename))
    started = time.time()
    download(url, target, args.timeout)
    if not is_gzip(target):
        os.remove(target)
        raise RuntimeError("%s no es un gzip valido" % filename)
    digest = sha256_file(target)
    manifest = record(name, url, target, digest, manifest)
    size_mb = os.path.getsize(target) / (1024 * 1024)
    print("[get_data] %-7s %.1f MB, %.1f s, sha256 %s" % (name, size_mb, time.time() - started, digest[:12]))
    return manifest


def main():
    args = parse_args()
    ensure_dir(RAW_DIR)
    try:
        check_space()
        manifest = read_json(MANIFEST_PATH, {"files": {}})
        names = sorted(RESOURCES) if args.resource == "all" else [args.resource]
        for name in names:
            manifest = fetch(name, args, manifest)
    except (RuntimeError, OSError, urllib.error.URLError) as error:
        print("[get_data] error %s" % error)
        return 1
    print("[get_data] manifiesto en %s" % MANIFEST_PATH)
    return 0


if __name__ == "__main__":
    sys.exit(main())
