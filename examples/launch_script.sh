#!/usr/bin/env bash
set -euo pipefail
# Prepare these artifacts with the qualified package/runtime; see docs/usage.md.
: "${SCEPTRE_INPUT_BUNDLE:?Set an absolute input bundle directory}"
: "${SCEPTRE_ANALYSIS_CONFIG:?Set an absolute analysis_config.rds path}"
: "${SCEPTRE_ENVIRONMENT_LOCK:?Set an absolute environment_lock.rds path}"
: "${SCEPTRE_OUTPUT_DIRECTORY:?Set a fresh absolute output directory}"
pipeline_directory=$(cd "$(dirname "$0")/.." && pwd)
args=(run "$pipeline_directory/main.nf"
  --input_bundle "$SCEPTRE_INPUT_BUNDLE"
  --analysis_config "$SCEPTRE_ANALYSIS_CONFIG"
  --environment_lock "$SCEPTRE_ENVIRONMENT_LOCK"
  --outdir "$SCEPTRE_OUTPUT_DIRECTORY"
  --analyses "${SCEPTRE_ANALYSES:-calibration,power,discovery}")
if [[ -n "${SCEPTRE_BACKING_DIRECTORY:-}" ]]; then
  args+=(--backing_directory "$SCEPTRE_BACKING_DIRECTORY")
fi
if [[ -n "${SCEPTRE_CONTAINER_IMAGE:-}" ]]; then
  args+=(-profile docker --container_image "$SCEPTRE_CONTAINER_IMAGE")
fi
nextflow "${args[@]}" "$@"
