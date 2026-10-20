#!/usr/bin/env bash
# Small synthetic end-user acceptance. Retain output for review; no publishing.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
run=${1:?Usage: SCEPTRE_DEMO_IMAGE=sha256:... demo/acceptance.sh NEW_DIRECTORY}
: "${SCEPTRE_DEMO_IMAGE:?Build an exact image first; supply its immutable ID}"
export SCEPTRE_DEMO_PROFILE=${SCEPTRE_DEMO_PROFILE:-test,docker}
"$root/demo/demo.sh" "$run"
run=$(cd "$run" && pwd)
image=$(cat "$run/image-id.txt")
run_r() {
  docker run --rm --cpus 2 -v "$root:$root" -v "$run:$run" -w "$root" "$image" Rscript --vanilla "$@"
}
run_r demo/check-output.R "$run" | tee "$run/saved-result-check.log"
# Reopen certified scientific state, not merely the HTML view.
run_r -e 'source("bin/pipeline.R"); a <- commandArgs(TRUE); x <- read_bundle(file.path(a[1], "results/discovery/state"), readRDS(file.path(a[1], "fixture/config.rds")), readRDS(file.path(a[1], "fixture/lock.rds"))); saveRDS(sceptre::get_result(x$object, "run_discovery_analysis"), file.path(a[1], "reopened-discovery.rds")); cat("PASS reopened certified discovery state\n")' "$run" | tee "$run/reopen.log"
cp -R "$run/results/exports/scientific-report" "$run/relocated-report"
(cd "$run/relocated-report" && Rscript --vanilla -e 'source("render.R"); stopifnot(!"sceptre" %in% loadedNamespaces()); scientific_report_html(readRDS("report-data.rds"), "report.html"); stopifnot(!"sceptre" %in% loadedNamespaces())')
# Confirm relocation retains every relative scientific asset/link.
python3 - "$run/relocated-report" <<'PYLINKS'
from html.parser import HTMLParser
from pathlib import Path
import sys
class Links(HTMLParser):
    def handle_starttag(self, tag, attrs):
        for key, value in attrs:
            if key in ('href','src') and value and not value.startswith('#'):
                assert (Path(sys.argv[1])/value).is_file(), value
Links().feed((Path(sys.argv[1])/'report.html').read_text())
print('PASS relocated report relative assets and base-R rerender')
PYLINKS
session=$(run_r -e 'cat(readRDS(file.path(commandArgs(TRUE)[1], "results/run_signature.rds"))$options$session_id)' "$run")
args=(run "$root/main.nf" -profile "$SCEPTRE_DEMO_PROFILE" -ansi-log false -work-dir "$run/work"
  --container_image "$image" --input_bundle "$run/fixture/input" --analysis_config "$run/fixture/config.rds"
  --environment_lock "$run/fixture/lock.rds" --analyses calibration,power,discovery --seed 271828 --outdir "$run/results")
(cd "$run" && nextflow "${args[@]}" -resume "$session") > "$run/resume.log" 2>&1
cp "$run/results/pipeline_info/trace.tsv" "$run/resume-trace.tsv"
# Test-only sentinel and config. Mount the sentinel directory into Docker as well.
python3 - "$run" <<'PYCONFIG'
import json, pathlib, re, sys
run=pathlib.Path(sys.argv[1])
if not re.fullmatch(r'[A-Za-z0-9_/. -]+',str(run)):
    raise SystemExit('Acceptance failure probe requires a path with letters, digits, spaces, _ / . or -')
script='if test -f "'+str(run/'failure.flag')+'"; then echo W09_TRANSIENT_FAILURE >&2; exit 42; fi'
(run/'failure.config').write_text('process {\n  containerOptions = '+json.dumps('-v "'+str(run)+':'+str(run)+'"')+'\n  withName: ".*DISCOVERY:SCEPTRE_STAGE" { beforeScript = '+json.dumps(script)+' }\n}\n')
(run/'failure.flag').touch()
PYCONFIG
failure_args=(run "$root/main.nf" -c "$run/failure.config" -profile "$SCEPTRE_DEMO_PROFILE" -ansi-log false
  -work-dir "$run/failure-work" --container_image "$image" --input_bundle "$run/fixture/input"
  --analysis_config "$run/fixture/config.rds" --environment_lock "$run/fixture/lock.rds"
  --analyses discovery --outdir "$run/failure-results")
if (cd "$run" && nextflow "${failure_args[@]}") > "$run/induced-failure.log" 2>&1; then
  echo 'Expected transient discovery failure did not occur' >&2; exit 1
fi
grep -q W09_TRANSIENT_FAILURE "$run/induced-failure.log"
test ! -d "$run/failure-results/discovery/state"
failed_session=$(run_r -e 'cat(readRDS(file.path(commandArgs(TRUE)[1], "failure-results/run_signature.rds"))$options$session_id)' "$run")
rm "$run/failure.flag"
(cd "$run" && nextflow "${failure_args[@]}" -resume "$failed_session") > "$run/recovery.log" 2>&1
cp "$run/failure-results/pipeline_info/trace.tsv" "$run/recovery-trace.tsv"
python3 - "$run" <<'PYVERIFY'
import csv,json,pathlib,sys
run=pathlib.Path(sys.argv[1])
read=lambda name:list(csv.DictReader((run/name).open(),delimiter='\t'))
rows=read('resume-trace.tsv')
assert len(rows)>=8 and sum(r['status']=='COMPLETED' for r in rows)==1, rows
assert sum(r['status']=='CACHED' for r in rows)==len(rows)-1, rows
rows=read('recovery-trace.tsv')
assert any('DISCOVERY:SCEPTRE_STAGE' in r['name'] and r['status']=='COMPLETED' for r in rows), rows
assert sum(r['status']=='CACHED' for r in rows)>=3, rows
status=json.loads((run/'failure-results/exports/scientific-report/report-status.json').read_text())
assert status['status']=='completed', status
(run/'acceptance.json').write_text(json.dumps({'status':'passed','checks':['public-demo','saved-public-result-equality','saved-state-reopen','relocated-base-R-report','relative-assets','cached-resume','induced-failure-no-published-family','identical-config-recovery'], 'limits':'synthetic reference mode; reused exact image; no fresh install, statistical validation, Slurm or OS OOM claim'},indent=2)+'\n')
print('PASS acceptance: demo, reopen, relocation, cached resume, transient failure and identical-config recovery')
PYVERIFY
