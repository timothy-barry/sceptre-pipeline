#!/usr/bin/env python3
"""Hash the actual portable qualification source, including the direct oracle."""
import hashlib
import json
from pathlib import Path
import sys
root = Path(sys.argv[1]).resolve()
paths = [p for folder, pattern in [("bin", "*.R"), ("conf", "*.config"),
    ("modules", "*.nf"), ("subworkflows", "*.nf"), ("hpc", "*")]
    for p in (root / folder).rglob(pattern) if p.is_file() and "__pycache__" not in p.parts]
paths += [root / name for name in ["main.nf", "nextflow.config", "nextflow_schema.json",
    "tests/fixture.R", "tests/ci/compare-workflow.R", "tests/conf/worker-failure.config", "tests/runtime/source.json"]]
value = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}
Path(sys.argv[2]).write_text(json.dumps(value, indent=2) + "\n")
