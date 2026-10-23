#!/usr/bin/env python3
"""Check the bundled runtime receipt and ensure corrupt receipts fail before downloads."""
from pathlib import Path
import json
import hashlib
import io
import tarfile
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
script = root / "container/prepare-context.py"
manifest = root / "tests/runtime/source.json"
command = ["python3", str(script), "--verify-only", "--source-manifest"]
subprocess.run(command + [str(manifest)], check=True)
original = json.loads(manifest.read_text())
with tempfile.TemporaryDirectory() as directory:
    target = Path(directory) / "source.json"
    (target.parent / original["archive"]).write_bytes(b"wrong source archive")
    for field, value, expected in (
        ("archive_sha256", "0" * 64, "source checksum"),
        ("source_commit", "main", "full commit and SHA256"),
        ("archive", "../outside.tar.gz", "filename in its own directory"),
    ):
        altered = dict(original, **{field: value})
        target.write_text(json.dumps(altered))
        result = subprocess.run(command + [str(target)], text=True, capture_output=True)
        assert result.returncode != 0 and expected in result.stderr, result
    # A valid-looking commit must agree with the checksum-bound source receipt.
    (target.parent / original["archive"]).write_bytes((manifest.parent / original["archive"]).read_bytes())
    (target.parent / original["frozen_manifest"]).write_bytes((manifest.parent / original["frozen_manifest"]).read_bytes())
    target.write_text(json.dumps(dict(original, source_commit="0" * 40)))
    result = subprocess.run(command + [str(target)], text=True, capture_output=True)
    assert result.returncode != 0 and "source commit mismatch" in result.stderr, result
    # A checksum-consistent older schema is still incompatible with this runtime.
    archive_path = target.parent / original["archive"]
    with tarfile.open(manifest.parent / original["archive"], "r:gz") as source:
        with tarfile.open(archive_path, "w:gz") as older:
            for member in source.getmembers():
                payload = source.extractfile(member).read() if member.isfile() else None
                if member.name == "sceptre/R/s4_class.R":
                    payload = payload.replace(b"schema_version = 7L", b"schema_version = 6L")
                    member.size = len(payload)
                older.addfile(member, io.BytesIO(payload) if payload is not None else None)
    altered = dict(original, archive_sha256=hashlib.sha256(archive_path.read_bytes()).hexdigest())
    altered.pop("frozen_manifest", None)
    altered.pop("frozen_manifest_sha256", None)
    target.write_text(json.dumps(altered))
    result = subprocess.run(command + [str(target)], text=True, capture_output=True)
    assert result.returncode != 0 and "native object schema 7" in result.stderr, result
print("PASS exact bundled source; corrupt identity, moving ref, escaped path and checksum-consistent older schema rejected")
