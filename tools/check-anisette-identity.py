#!/usr/bin/env python3
"""Compare stable anisette identity fields without printing their values."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import urllib.request

parser = argparse.ArgumentParser()
parser.add_argument("action", choices=["capture", "compare"])
parser.add_argument("--baseline", type=Path, required=True)
parser.add_argument("--url", default="http://127.0.0.1:6969/")
args = parser.parse_args()
with urllib.request.urlopen(args.url, timeout=10) as response:
    data = json.loads(response.read(1024 * 1024))
keys = ("X-Mme-Device-Id", "X-Apple-I-MD-LU", "X-Apple-I-MD-M")
identity = {}
for key in keys:
    value = data.get(key)
    if not isinstance(value, str) or not value:
        raise SystemExit("Missing stable anisette identity field")
    identity[key] = hashlib.sha256(value.encode()).hexdigest()
if args.action == "capture":
    with os.fdopen(os.open(args.baseline, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "w") as stream:
        json.dump(identity, stream)
    print("Identity baseline captured (hashes only)")
else:
    if json.loads(args.baseline.read_text()) != identity:
        raise SystemExit("FAIL: anisette identity changed")
    print("PASS: all stable anisette identity fields unchanged")
