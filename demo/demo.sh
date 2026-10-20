#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
run=${1:-"$PWD/sceptre-demo"}
image=${SCEPTRE_DEMO_IMAGE:-}
profile=${SCEPTRE_DEMO_PROFILE:-docker}
for tool in docker python3 nextflow; do
  command -v "$tool" >/dev/null || { echo "Required command unavailable: $tool" >&2; exit 1; }
done
if [[ -e "$run" ]]; then echo "Choose a new demo directory; refusing to overwrite: $run" >&2; exit 1; fi
mkdir -p "$run"
run=$(cd "$run" && pwd)
if [[ -z "$image" ]]; then
  python3 "$root/container/prepare-context.py" --source-manifest "$root/tests/runtime/source.json" --output "$run/runtime-context"
  docker build --iidfile "$run/image-id.txt" "$run/runtime-context"
  image=$(cat "$run/image-id.txt")
fi
if [[ ! "$image" =~ ^sha256:[a-f0-9]{64}$ && ! "$image" =~ @sha256:[a-f0-9]{64}$ ]]; then
  echo 'SCEPTRE_DEMO_IMAGE must be an immutable local image ID or registry digest.' >&2; exit 1
fi
docker image inspect "$image" >/dev/null
printf '%s\n' "$image" > "$run/image-id.txt"
# Reused images must carry the same exact qualified package archive receipt.
docker run --rm -v "$root:$root" "$image" Rscript --vanilla -e \
  'expected <- jsonlite::fromJSON(commandArgs(TRUE)[1]); actual <- jsonlite::fromJSON("/opt/sceptre/source.json"); stopifnot(identical(actual$sceptre_commit, expected$source_commit), identical(actual$sceptre_archive_sha256, expected$archive_sha256))' \
  "$root/tests/runtime/source.json"
docker run --rm -v "$root:$root" -v "$run:$run" -w "$root" "$image" \
  Rscript --vanilla demo/make-input.R "$run/fixture"
(cd "$run" && nextflow run "$root/main.nf" -profile "$profile" -ansi-log false -work-dir "$run/work" \
  --container_image "$image" --input_bundle "$run/fixture/input" \
  --analysis_config "$run/fixture/config.rds" --environment_lock "$run/fixture/lock.rds" \
  --analyses calibration,power,discovery --seed 271828 --outdir "$run/results")
python3 - "$run" "$root" "$image" <<'PY'
import hashlib,json,pathlib,subprocess,sys
run,root=map(pathlib.Path,sys.argv[1:3]); image=sys.argv[3]
report=run/'results/exports/scientific-report/report.html'
status=json.loads((report.parent/'report-status.json').read_text())
if status['status']!='completed' or not report.is_file():
    raise SystemExit('Science completed, but report is unavailable; inspect scientific-report/report-status.json.')
receipt={'kind':'synthetic-sceptre-demo','generation_seed':20261019,'analysis_seed':271828,
 'image':image,'pipeline_revision':subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip(),
 'package_source':json.loads((root/'tests/runtime/source.json').read_text()),
 'generator_sha256':hashlib.sha256((root/'demo/make-input.R').read_bytes()).hexdigest()}
(run/'demo-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('Scientific report:',report)
print('Rerenderable source bundle:',report.parent)
print('Nextflow execution report:',run/'results/pipeline_info/report.html')
PY
