#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
receipt=$(mktemp -d)
trap 'rm -rf "$receipt"' EXIT
nextflow -log "$receipt/slurm.log" config "$root" -profile slurm -flat > "$receipt/slurm.txt"
nextflow -log "$receipt/local.log" config "$root" -flat > "$receipt/local.txt"
python3 - "$receipt" "$root" <<'PY_CONFIG'
from pathlib import Path
import sys
root=Path(sys.argv[1])
slurm=(root/'slurm.txt').read_text()
local=(root/'local.txt').read_text()
assert "process.executor = 'slurm'" in slurm
# Array size is a static process declaration evaluated after final params merge;
# Nextflow rejects dynamic array closures and early config reads can freeze defaults.
project=Path(sys.argv[2])
array_modules=[p for p in (project/'modules').rglob('*.nf')
               if any(line.strip().startswith('array ') for line in p.read_text().splitlines())]
assert array_modules==[project/'modules/local/sceptre_worker/main.nf'],array_modules
worker=array_modules[0].read_text()
assert "array (workflow.profile.tokenize(',').contains('slurm') ? params.array_size : null)" in worker
assert not any('.array =' in line for line in local.splitlines())
assert "process.executor = 'local'" in local
print('PASS Slurm arrays apply only to workers; default local execution has no arrays.')
PY_CONFIG
