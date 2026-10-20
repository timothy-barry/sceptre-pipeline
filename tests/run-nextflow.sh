#!/usr/bin/env bash
set -euo pipefail
# Run from repository root with exact isolated R_LIBS (or inside qualified image).
root=$(pwd)
run_dir=${1:?Usage: tests/run-nextflow.sh NEW_RUN_DIRECTORY}
mkdir -p "$run_dir"
run_dir=$(cd "$run_dir" && pwd)
run_r() {
  if [[ -n "${SCEPTRE_CONTAINER_IMAGE:-}" ]]; then
    docker run --rm -v "$root:$root" -v "$run_dir:$run_dir" -w "$root" "$SCEPTRE_CONTAINER_IMAGE" Rscript --vanilla "$@"
  else
    Rscript --vanilla "$@"
  fi
}
run_r tests/make-input.R "$run_dir/fixture" "${SCEPTRE_TEST_CASE:-high_crt}"
profile=test
if [[ -n "${SCEPTRE_CONTAINER_IMAGE:-}" ]]; then profile=test,docker; fi
# A top-level site config includes a second local file. Both are run identity.
mkdir -p "$run_dir/site"
printf "includeConfig 'nested.config'\n" > "$run_dir/site/site.config"
printf 'process.cpus = 1\n' > "$run_dir/site/nested.config"
args=(run "$root/main.nf" -c "$run_dir/site/site.config" -profile "$profile" -ansi-log false -work-dir "$run_dir/work"
  --input_bundle "$run_dir/fixture/input" --analysis_config "$run_dir/fixture/config.rds"
  --environment_lock "$run_dir/fixture/lock.rds" --outdir "$run_dir/results"
  --execution_mode "${SCEPTRE_EXECUTION_MODE:-reference}" --n_work_units 3)
if [[ -n "${SCEPTRE_CONTAINER_IMAGE:-}" ]]; then
  args+=( --container_image "$SCEPTRE_CONTAINER_IMAGE" )
fi
(cd "$run_dir" && nextflow "${args[@]}")
run_r tests/compare-nextflow.R "$run_dir/fixture" "$run_dir/results" 271828
resume_id=$(run_r -e 'cat(readRDS(commandArgs(TRUE)[1])$options$session_id)' "$run_dir/results/run_signature.rds")
(cd "$run_dir" && nextflow "${args[@]}" -resume "$resume_id")
# Validation reruns, scientific tasks must be reused (not silently recomputed).
python3 - "$run_dir/results/pipeline_info/trace.tsv" <<'PY'
import csv,sys
rows=list(csv.DictReader(open(sys.argv[1]), delimiter='\t'))
assert len(rows)>=8,rows
assert sum(r['status']=='CACHED' for r in rows)==len(rows)-1,rows
assert sum(r['status']=='COMPLETED' for r in rows)==1,rows
import shutil
shutil.copyfile(sys.argv[1], sys.argv[1].split('/results/')[0]+'/resume-trace.tsv')
print('PASS resume: runtime validation reran, all scientific tasks and export cached')
PY
# The nested include must be bound even though workflow.configFiles omits it.
printf 'process.cpus = 2\n' > "$run_dir/site/nested.config"
if (cd "$run_dir" && nextflow "${args[@]}" -resume "$resume_id") > "$run_dir/nested-config-change.log" 2>&1; then
  echo 'Nested includeConfig change reused old publication paths' >&2; exit 1
fi
grep -q 'Output directory belongs to a different run' "$run_dir/nested-config-change.log"
printf 'process.cpus = 1\n' > "$run_dir/site/nested.config"
echo 'PASS nested configuration change rejected; unchanged nested configuration resumed with cached science'
# Interpolated includes cannot be statically certified and must fail early.
printf 'includeConfig "${projectDir}/conf/base.config"\n' > "$run_dir/site/site.config"
if (cd "$run_dir" && nextflow "${args[@]}" -resume "$resume_id") > "$run_dir/dynamic-config.log" 2>&1; then
  echo 'Dynamic includeConfig unexpectedly accepted' >&2; exit 1
fi
grep -q 'Configuration identity supports only' "$run_dir/dynamic-config.log"
printf "includeConfig 'nested.config'\n" > "$run_dir/site/site.config"
echo 'PASS unsupported dynamic configuration include rejected before tasks'
# Nextflow itself parses missing/cyclic includes before workflow startup.
printf "includeConfig 'absent.config'\n" > "$run_dir/site/missing.config"
printf "includeConfig 'cycle-b.config'\n" > "$run_dir/site/cycle-a.config"
printf "includeConfig 'cycle-a.config'\n" > "$run_dir/site/cycle-b.config"
for kind in missing cycle-a; do
  if (cd "$run_dir" && nextflow run "$root/main.nf" -c "$run_dir/site/$kind.config" -ansi-log false) > "$run_dir/$kind-config.log" 2>&1; then
    echo "Invalid $kind config unexpectedly accepted" >&2; exit 1
  fi
  grep -q 'ERROR' "$run_dir/$kind-config.log"
  if grep -q 'Submitted process' "$run_dir/$kind-config.log"; then
    echo "Invalid $kind config launched tasks" >&2; exit 1
  fi
done
echo 'PASS missing and cyclic includes fail during native config parsing before tasks'

# A misspelled legacy flag must fail before launching tasks.
if (cd "$run_dir" && nextflow "${args[@]}" --pair_pod_size 10) > "$run_dir/invalid.log" 2>&1; then
  echo 'Unknown parameter unexpectedly accepted' >&2; exit 1
fi
grep -qi 'pair_pod_size' "$run_dir/invalid.log"
echo 'PASS unknown/legacy parameter rejected'

# Reusing publication paths must not silently retain stale scientific outputs.
if (cd "$run_dir" && nextflow "${args[@]}") > "$run_dir/output-collision.log" 2>&1; then
  echo 'Fresh run reused an occupied output directory' >&2; exit 1
fi
grep -q 'Output directory belongs to a different run' "$run_dir/output-collision.log"
if (cd "$run_dir" && nextflow "${args[@]}" -resume "$resume_id" --seed 271829) > "$run_dir/changed-seed.log" 2>&1; then
  echo 'Changed-seed resume reused old publication paths' >&2; exit 1
fi
grep -q 'Output directory belongs to a different run' "$run_dir/changed-seed.log"
echo 'PASS fresh-run collision and changed-seed resume rejected before scientific tasks'
if (cd "$run_dir" && nextflow "${args[@]}" -resume "$resume_id" --array_size 17) > "$run_dir/changed-array-size.log" 2>&1; then
  echo 'Changed-array-size resume reused old publication paths' >&2; exit 1
fi
grep -q 'Output directory belongs to a different run' "$run_dir/changed-array-size.log"
echo 'PASS changed array batching cannot reuse prior publication paths'

# A different .nf implementation must not inherit old published state on resume.
python3 - "$root" "$run_dir/altered-source" <<'PY_SOURCE'
import pathlib,shutil,sys,hashlib,json
src,dst=map(pathlib.Path,sys.argv[1:]); dst.mkdir()
for folder in ('bin','conf','modules','subworkflows','resources'):
    shutil.copytree(src/folder,dst/folder)
for name in ('main.nf','nextflow.config','nextflow_schema.json'):
    shutil.copyfile(src/name,dst/name)
before=hashlib.sha256((dst/'main.nf').read_bytes()).hexdigest()
with (dst/'main.nf').open('a') as f: f.write('\n// altered-source resume rejection fixture\n')
after=hashlib.sha256((dst/'main.nf').read_bytes()).hexdigest()
assert before!=after
(dst/'source-change.json').write_text(json.dumps({'before':before,'after':after})+'\n')
PY_SOURCE
altered_args=("${args[@]}")
altered_args[1]="$run_dir/altered-source/main.nf"
if (cd "$run_dir" && nextflow "${altered_args[@]}" -resume "$resume_id") > "$run_dir/altered-source.log" 2>&1; then
  echo 'Altered workflow source resumed into stale publication paths' >&2; exit 1
fi
grep -q 'Output directory belongs to a different run' "$run_dir/altered-source.log"
echo 'PASS altered .nf source resume rejected; original source identical resume passed'

if [[ "${SCEPTRE_EXECUTION_MODE:-reference}" == distributed ]]; then
  failure_args=(run "$root/main.nf" -c "$root/tests/conf/worker-failure.config"
    -profile "$profile" -ansi-log false -work-dir "$run_dir/failure-work"
    --input_bundle "$run_dir/fixture/input" --analysis_config "$run_dir/fixture/config.rds"
    --environment_lock "$run_dir/fixture/lock.rds" --outdir "$run_dir/failure-results"
    --execution_mode distributed --n_work_units 3 --analyses discovery)
  if [[ -n "${SCEPTRE_CONTAINER_IMAGE:-}" ]]; then
    failure_args+=(--container_image "$SCEPTRE_CONTAINER_IMAGE")
  fi
  if (cd "$run_dir" && nextflow "${failure_args[@]}") > "$run_dir/worker-failure.log" 2>&1; then
    echo 'Worker failure unexpectedly succeeded' >&2; exit 1
  fi
  grep -q CERTIFIED_WORKER_FAILURE_TEST "$run_dir/worker-failure.log"
  test ! -d "$run_dir/failure-results/discovery/state"
  if grep -q 'Submitted process.*SCEPTRE_COLLECT' "$run_dir/worker-failure.log"; then
    echo 'Collector launched after a worker failure' >&2; exit 1
  fi
  echo 'PASS actual failed worker prevents collection and completed family publication'
fi
