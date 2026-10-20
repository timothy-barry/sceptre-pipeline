#!/usr/bin/env bash
# Exercise pre-submission identity validation with actual Nextflow, without Apptainer.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
receipt=${1:-$(mktemp -d)}
mkdir -p "$receipt"
receipt=$(cd "$receipt" && pwd)
mkdir -p "$receipt/input"
printf 'synthetic pre-submission fixture\n' > "$receipt/input/manifest.rds"
printf 'not read before identity rejection\n' > "$receipt/config.rds"
printf 'not read before identity rejection\n' > "$receipt/lock.rds"
printf 'small fake SIF for checksum guard only\n' > "$receipt/runtime.sif"
sha=$(python3 - "$receipt/runtime.sif" <<'PY_SHA'
import hashlib,sys
print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())
PY_SHA
)
reject() {
    local name=$1 profile=$2 image=$3 expected=$4
    shift 4
    if (cd "$receipt" && nextflow -log "$receipt/$name.nextflow.log" run "$root/main.nf" \
        -profile "$profile" -ansi-log false -work-dir "$receipt/work-$name" \
        --input_bundle "$receipt/input" --analysis_config "$receipt/config.rds" \
        --environment_lock "$receipt/lock.rds" --outdir "$receipt/out-$name" \
        --container_image "$image" "$@") > "$receipt/$name.log" 2>&1; then
        echo "Invalid container identity unexpectedly accepted: $name" >&2; exit 1
    fi
    if ! grep -Fq "$expected" "$receipt/$name.log"; then
        echo "Wrong rejection reason for $name; expected: $expected" >&2
        cat "$receipt/$name.log" >&2; exit 1
    fi
    if grep -Eq 'Submitted process|Cached process|\[.*\] process >' "$receipt/$name.log" ||
       grep -Eq 'Submitted process|Cached process' "$receipt/$name.nextflow.log"; then
        echo "Container identity rejection launched or reused a task: $name" >&2; exit 1
    fi
    test ! -d "$receipt/out-$name/parameters"
    echo "PASS pre-submission container identity: $name"
}
reject missing-sha apptainer "$receipt/runtime.sif" 'container_image_sha256 is required'
reject wrong-sha apptainer "$receipt/runtime.sif" 'SIF SHA256 mismatch' \
    --container_image_sha256 ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
reject relative-sif apptainer runtime.sif 'SIF path must be absolute' --container_image_sha256 "$sha"
reject docker-sif docker "$receipt/runtime.sif" 'SIF images require the apptainer profile' --container_image_sha256 "$sha"
reject mutable-oci docker example.invalid/sceptre:latest 'immutable image digest'
