#!/usr/bin/env python3
"""Check the bundled runtime receipt and ensure corrupt receipts fail before downloads."""
from pathlib import Path
import json
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
print("PASS exact bundled source; altered archive, moving ref and escaped path rejected before downloads")
