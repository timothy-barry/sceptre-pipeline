#!/usr/bin/env bash
# One selected actual Slurm/Apptainer scientific case, with a same-SIF public R oracle.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
image= expected= site= run=
case_name=low_nt_permutation
mode=distributed
units=2
analyses=calibration,power,discovery
resume=false
failure=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) image=$2; shift 2;;
    --sha256) expected=$2; shift 2;;
    --site-config) site=$2; shift 2;;
    --run-dir) run=$2; shift 2;;
    --case) case_name=$2; shift 2;;
    --mode) mode=$2; shift 2;;
    --n-work-units) units=$2; shift 2;;
    --analyses) analyses=$2; shift 2;;
    --resume) resume=true; shift;;
    --worker-failure) failure=true; shift;;
    *) echo "Unknown option: $1" >&2; exit 1;;
  esac
done
[[ -n "$image" && -n "$expected" && -n "$site" && -n "$run" ]] || {
  echo 'Required: --image ABS.sif --sha256 SHA --site-config ABS.config --run-dir NEW_SHARED_DIRECTORY' >&2; exit 1;
}
[[ "$run" = /* && ! -e "$run" && "$site" = /* && -f "$site" ]] || { echo 'Use a new absolute shared run directory and existing absolute site config.' >&2; exit 1; }
[[ "$mode" == reference || "$mode" == distributed ]]
[[ "$units" =~ ^[1-9][0-9]*$ ]]
[[ "$case_name" == low_nt_permutation || "$case_name" == high_empirical_crt || "$case_name" == low_nt_permutation_backed ]]
[[ "$analyses" == discovery || "$analyses" == calibration,power,discovery ]]
mkdir -p "$run"
run=$(cd "$run" && pwd)
python3 "$root/hpc/source-manifest.py" "$root" "$run/source-before.json"
bash "$root/hpc/preflight.sh" "$image" "$expected" "$run/preflight" > "$run/preflight.log" 2>&1
# Refuse a site policy that leaks host R_LIBS into Nextflow's SIF execution.
nextflow -c "$site" config "$root" -profile slurm,apptainer -flat | python3 -c '
import sys
lines=[line for line in sys.stdin if line.strip().startswith("apptainer.runOptions =")]
assert len(lines)==1 and "--cleanenv" in lines[0], "Site config must set apptainer.runOptions containing --cleanenv"
' > "$run/runtime-options-check.log" 2>&1
# Absolute identical bind paths preserve descriptors and public identity certificates.
inside() { apptainer exec --cleanenv --bind "$root:$root" --bind "$run:$run" --pwd "$root" "$image" Rscript --vanilla "$@"; }
inside "$root/hpc/make-input.R" "$run/fixture" "$case_name" > "$run/make-input.log" 2>&1
backing="$root/resources/empty_backing"
compare_backing=none
if [[ "$case_name" == *_backed ]]; then backing="$run/fixture/backing"; compare_backing="$backing"; fi
args=(run "$root/main.nf" -profile slurm,apptainer -c "$site" -ansi-log false -work-dir "$run/work"
  --container_image "$image" --container_image_sha256 "$expected"
  --input_bundle "$run/fixture/input" --analysis_config "$run/fixture/config.rds"
  --environment_lock "$run/fixture/lock.rds" --backing_directory "$backing"
  --execution_mode "$mode" --n_work_units "$units" --array_size 2
  --analyses "$analyses" --seed 271828 --outdir "$run/results")
(cd "$run" && nextflow -log "$run/nextflow.log" "${args[@]}") > "$run/launch.log" 2>&1
inside "$root/tests/ci/compare-workflow.R" "$run/fixture" "$run/results" 271828 analysis "$analyses" "$compare_backing" > "$run/direct-comparison.log" 2>&1
cp "$run/results/pipeline_info/trace.tsv" "$run/success-trace.tsv"
if [[ "$resume" == true ]]; then
  session=$(inside -e 'cat(readRDS(commandArgs(TRUE)[1])$options$session_id)' "$run/results/run_signature.rds")
  (cd "$run" && nextflow -log "$run/resume-nextflow.log" "${args[@]}" -resume "$session") > "$run/resume.log" 2>&1
  cp "$run/results/pipeline_info/trace.tsv" "$run/resume-trace.tsv"
  python3 - "$run/resume-trace.tsv" <<'PY_RESUME'
import csv,sys
rows=list(csv.DictReader(open(sys.argv[1]),delimiter='\t'))
assert rows and sum(r['status']=='COMPLETED' for r in rows)==1,rows
assert sum(r['status']=='CACHED' for r in rows)==len(rows)-1,rows
assert next(r for r in rows if r['status']=='COMPLETED')['name'].endswith('SCEPTRE_VALIDATE (screen:validate)'),rows
print('PASS identical resume: validation reran, all scientific tasks and export cached')
PY_RESUME
  inside "$root/tests/ci/compare-workflow.R" "$run/fixture" "$run/results" 271828 analysis "$analyses" "$compare_backing" > "$run/resume-direct-comparison.log" 2>&1
fi
if [[ "$failure" == true ]]; then
  failure_args=(run "$root/main.nf" -profile slurm,apptainer -c "$site" -c "$root/tests/conf/worker-failure.config"
    -ansi-log false -work-dir "$run/failure-work" --container_image "$image" --container_image_sha256 "$expected"
    --input_bundle "$run/fixture/input" --analysis_config "$run/fixture/config.rds"
    --environment_lock "$run/fixture/lock.rds" --backing_directory "$backing"
    --execution_mode distributed --n_work_units "$units" --array_size 2 --analyses discovery --seed 271828 --outdir "$run/failure-results")
  if (cd "$run" && nextflow -log "$run/failure-nextflow.log" "${failure_args[@]}") > "$run/failure.log" 2>&1; then
    echo 'Controlled worker failure unexpectedly succeeded.' >&2; exit 1
  fi
  # Slurm arrays can write beforeScript stderr to the array launcher's output,
  # rather than the failed child's console stream. Require an actual emitted
  # marker, failed worker exit42, and no collector; source text is not evidence.
  python3 - "$run" <<'PY_FAILURE_ASSERTIONS'
import csv,json,pathlib,sys
run=pathlib.Path(sys.argv[1])
rows=list(csv.DictReader((run/'failure-results/pipeline_info/trace.tsv').open(),delimiter='\t'))
failed=[r for r in rows if r['status']=='FAILED']
assert failed and all('SCEPTRE_WORKER ' in r['name'] and r['exit']=='42' for r in failed), failed
assert not any('SCEPTRE_COLLECT ' in r['name'] for r in rows), rows
logs=[run/'failure.log']
for name in ('.command.log','.command.err','.command.out'):
    logs.extend((run/'failure-work').glob('??/*/'+name))
markers=[str(p.relative_to(run)) for p in logs if p.is_file()
    and any(line.strip()=='CERTIFIED_WORKER_FAILURE_TEST' for line in p.read_text(errors='replace').splitlines())]
assert markers, 'No emitted controlled-worker-failure marker in console/task/array logs'
assert not (run/'failure-results/discovery/state').exists(), 'Completed discovery was published after worker failure'
receipt={'status':'passed','failed_workers':[{'name':r['name'],'native_id':r['native_id'],'exit':int(r['exit'])} for r in failed],
 'emitted_marker_logs':markers,'collector_launched':False,'completed_discovery_published':False}
(run/'failure-verification.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('PASS controlled worker exit42, emitted array/task marker, no collector or completed family')
PY_FAILURE_ASSERTIONS
  [[ ! -e "$run/failure-results/discovery/state" ]]
  if grep -q 'Submitted process.*SCEPTRE_COLLECT' "$run/failure.log"; then
    echo 'Collector launched after controlled failure.' >&2; exit 1
  fi
fi
[[ "$(sha256sum "$image" | cut -d ' ' -f 1)" == "$expected" ]]
python3 "$root/hpc/source-manifest.py" "$root" "$run/source-after.json"
python3 - "$root" "$run" "$image" "$expected" "$site" "$case_name" "$mode" "$units" "$analyses" "$resume" "$failure" <<'PY_RECEIPT'
import hashlib,json,pathlib,subprocess,sys
root,run=map(pathlib.Path,sys.argv[1:3])
before=json.loads((run/'source-before.json').read_text())
after=json.loads((run/'source-after.json').read_text())
assert before == after, 'Qualification source changed during execution; this run is not certified.'
try:
    revision=subprocess.run(['git','-C',str(root),'rev-parse','HEAD'],text=True,capture_output=True)
    revision_value=revision.stdout.strip() if revision.returncode == 0 else None
except FileNotFoundError:
    revision_value=None
receipt={'status':'passed','case':sys.argv[6],'execution_mode':sys.argv[7],'n_work_units':int(sys.argv[8]),'analyses':sys.argv[9],
 'identical_resume_checked':sys.argv[10]=='true','controlled_worker_failure_checked':sys.argv[11]=='true',
 'image':sys.argv[3],'sif_sha256':sys.argv[4],'image_use':'preconverted local SIF; not a Nextflow registry conversion',
 'site_config_sha256':hashlib.sha256(pathlib.Path(sys.argv[5]).read_bytes()).hexdigest(),
 'pipeline_revision':revision_value or 'unavailable; see exact source hashes',
 'source_before_sha256':before,'source_after_sha256':after,'source_unchanged':True}
(run/'qualification.json').write_text(json.dumps(receipt,indent=2)+'\n')
PY_RECEIPT
echo "PASS actual HPC scientific comparison: $run/qualification.json"
