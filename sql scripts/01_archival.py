import re
from datetime import datetime

# ── CONFIG ──────────────────────────────────────────────────
BUCKET         = "s3://sales-dwh-bucket-charith-977574653589-us-east-2-an"
SFTP_ZONE      = f"{BUCKET}/sftp-landing/"
BRONZE_ZONE    = f"{BUCKET}/bronze/"
SILVER_ZONE    = f"{BUCKET}/silver/"
ARCHIVE_SFTP   = f"{BUCKET}/archive/sftp/"
ARCHIVE_BRONZE = f"{BUCKET}/archive/bronze/"
ARCHIVE_SILVER = f"{BUCKET}/archive/silver/"

SOURCES = {
    "customers" : "customers_src",
    "products"  : "products_src",
    "stores"    : "stores_src",
    "sales"     : "sales_transactions_src"
}

# ── HELPERS ─────────────────────────────────────────────────

def list_files(path):
    try:
        return [f.path for f in dbutils.fs.ls(path) if not f.path.endswith("/")]
    except Exception:
        return []

def parse_timestamp(filepath, source_prefix):
    name    = filepath.split("/")[-1]
    pattern = rf"{source_prefix}_(\d{{2}})(\d{{2}})(\d{{4}})(\d{{2}})(\d{{2}})(\d{{2}})\.csv"
    match   = re.search(pattern, name)
    if not match:
        print(f"WARNING: Cannot parse timestamp from '{name}'")
        return None
    dd, mm, yyyy, hh, mi, ss = match.groups()
    try:
        return datetime(int(yyyy), int(mm), int(dd), int(hh), int(mi), int(ss))
    except ValueError as e:
        print(f"WARNING: Invalid date in '{name}': {e}")
        return None

def move_file(src, dst):
    dbutils.fs.cp(src, dst)
    dbutils.fs.rm(src)
    print(f"Archived: {src.split('/')[-1]} -> {dst}")

def archive_zone(zone_path, archive_path, source_name, source_prefix):
    all_files = list_files(zone_path)
    matching  = [f for f in all_files if source_prefix in f.split("/")[-1]]

    if len(matching) <= 1:
        return "OK"

    timestamped = []
    for fp in matching:
        ts = parse_timestamp(fp, source_prefix)
        if ts:
            timestamped.append((ts, fp))

    if not timestamped:
        print(f"ERROR: No valid timestamps found for {source_name} in {zone_path}")
        return "ERROR"

    timestamped.sort(key=lambda x: x[0], reverse=True)
    latest_file            = timestamped[0][1]
    older_files            = timestamped[1:]

    print(f"Keeping : {latest_file.split('/')[-1]}")

    for _, old_fp in older_files:
        filename = old_fp.split("/")[-1]
        move_file(old_fp, f"{archive_path}{source_name}/{filename}")

    return "OK"

# ── MAIN ────────────────────────────────────────────────────

print("Archival started")

for source_name, source_prefix in SOURCES.items():
    for zone_path, archive_path in [
        (SFTP_ZONE,   ARCHIVE_SFTP),
        (BRONZE_ZONE, ARCHIVE_BRONZE),
        (SILVER_ZONE, ARCHIVE_SILVER)
    ]:
        archive_zone(zone_path, archive_path, source_name, source_prefix)

# ── VALIDATION ──────────────────────────────────────────────

print("\nPost-archival file counts:")

failed = False

for source_name, source_prefix in SOURCES.items():
    for zone_path, zone_label in [
        (SFTP_ZONE,   "sftp"),
        (BRONZE_ZONE, "bronze"),
        (SILVER_ZONE, "silver")
    ]:
        files = [f for f in list_files(zone_path) if source_prefix in f.split("/")[-1]]
        count = len(files)
        status = "OK" if count <= 1 else "FAIL"
        if count > 1:
            failed = True
        print(f"  {zone_label:<8} {source_name:<12} {count} file(s)  [{status}]")

print("Archival complete")

if failed:
    raise Exception("Multiple files detected in active zones. Pipeline stopped.")