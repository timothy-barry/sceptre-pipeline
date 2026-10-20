#!/usr/bin/env bash
# Read-only runtime checks. This script never submits jobs.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
image=${1:?Usage: hpc/preflight.sh IMAGE.sif EXPECTED_SHA256 RECEIPT_DIRECTORY}
expected=${2:?Expected SIF SHA256 required}
receipt=${3:?Receipt directory required}
[[ "$image" = /* && "$image" == *.sif && -f "$image" ]] || { echo 'Use an existing absolute .sif path.' >&2; exit 1; }
[[ "$expected" =~ ^[a-f0-9]{64}$ ]] || { echo 'Expected SHA256 must contain 64 lowercase hex characters.' >&2; exit 1; }
for tool in apptainer nextflow sbatch sacct sha256sum python3; do
  command -v "$tool" >/dev/null || { echo "Required command unavailable: $tool" >&2; exit 1; }
done
actual=$(sha256sum "$image" | cut -d ' ' -f 1)
[[ "$actual" == "$expected" ]] || { echo 'SIF checksum mismatch.' >&2; exit 1; }
mkdir -p "$receipt"
printf '%s  %s\n' "$actual" "$image" > "$receipt/image.sha256"
apptainer --version > "$receipt/apptainer-version.txt"
nextflow -version > "$receipt/nextflow-version.txt"
sbatch --version > "$receipt/slurm-version.txt"
uname -m > "$receipt/host-architecture.txt"
apptainer exec --cleanenv --bind "$root:$root" "$image" Rscript --vanilla -e '
stopifnot(all(c("prepare_execution", "execute_work_unit", "collect_execution") %in% getNamespaceExports("sceptre")))
expected <- jsonlite::fromJSON(commandArgs(TRUE)[1])
actual <- jsonlite::fromJSON("/opt/sceptre/source.json")
stopifnot(identical(actual$sceptre_commit, expected$source_commit),
    identical(actual$sceptre_archive_sha256, expected$archive_sha256))
cat(R.version$arch, "\n"); cat(readLines("/opt/sceptre/source.json"), sep="\n"); print(sessionInfo())
' "$root/tests/runtime/source.json" > "$receipt/runtime.txt"
# Verify the same bytes again after opening the image.
[[ "$(sha256sum "$image" | cut -d ' ' -f 1)" == "$expected" ]]
echo 'PASS immutable preconverted SIF and local launch prerequisites; compute-node science is not yet qualified.'
