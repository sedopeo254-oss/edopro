#!/usr/bin/env python3
# -*- coding: utf-8 -*-
from __future__ import annotations

import base64
import gzip
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENCODED = ROOT / ".github" / "patches" / "4way-live-ec2d962.patch.gz.b64"
PATCH = ROOT / ".github" / "patches" / "4way-live-ec2d962.patch"

raw = gzip.decompress(base64.b64decode(ENCODED.read_text(encoding="ascii")))
PATCH.write_bytes(raw)
subprocess.run(["git", "apply", "--check", str(PATCH)], cwd=ROOT, check=True)
subprocess.run(["git", "apply", str(PATCH)], cwd=ROOT, check=True)
print("Applied live Battle Royale ec2d962 compatibility patch")
