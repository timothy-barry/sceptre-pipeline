#!/usr/bin/env python3
"""Archive compact, auditable evidence; leave raw counts/work objects in run dir."""
import argparse,hashlib,json,pathlib,shutil
p=argparse.ArgumentParser(); p.add_argument('run');p.add_argument('new_evidence_directory');a=p.parse_args()
run=pathlib.Path(a.run).resolve(); out=pathlib.Path(a.new_evidence_directory).resolve()
if out.exists(): raise SystemExit('Evidence directory must be new')
out.mkdir(parents=True)
def copy(path,relative=None):
    if not path.is_file(): return
    dest=out/(relative if relative is not None else path.relative_to(run));dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,dest)
for name in ['commands.json','receipt.json','inputs.json','direct-resources.json','prepare-resources.json','bounded.config','summary.json','summary.csv','source-at-start.json','source-at-end.json','source-immutability.json','executed-source-verification.json']:
    copy(run/name)
for path in run.glob('*.log'): copy(path)
for name in ['result.csv','realized-plan.json','timings.json']:copy(run/'direct'/name)
for name in ['dataset.json','requested-family.csv']:copy(run/'fixture'/name)
for path in (run/'scientific-evidence').glob('*'):copy(path)
for directory in sorted(run.glob('pipeline-units-*')):
    for name in ['comparison.json','task-kernel-resources.csv','.nextflow.log']:copy(directory/name)
    for name in ['trace.tsv','timeline.html']:copy(directory/'results/pipeline_info'/name)
    copy(directory/'results/discovery/state/manifest.rds')
    copy(directory/'results/exports/scientific-report/report-status.json')
    for marker in sorted((directory/'work').glob('*/*/.benchmark-memory.peak')):
        task=marker.parent
        for artifact in ['execution/execution.rds','execution/manifest.rds','execution/unit_ids.txt']:
            copy(task/artifact, pathlib.Path(directory.name)/'tasks'/task.parent.name/task.name/artifact)
        for proposal in task.glob('proposal_*.rds'):
            if proposal.stat().st_size <= 5*1024**2: copy(proposal,pathlib.Path(directory.name)/'tasks'/task.parent.name/task.name/proposal.name)
        for name in ['.benchmark-start','.benchmark-end','.benchmark-memory.peak','.benchmark-memory.max','.benchmark-cpu.stat','.command.sh','.command.run','.command.out','.command.err','.exitcode','versions.yml']:
            copy(task/name, pathlib.Path(directory.name)/'tasks'/task.parent.name/task.name/name)
(out/'README.md').write_text('# Recorded bounded real-data run\n\nOriginal full run directory: `'+str(run)+'`.\n\nOne qualifying repetition. Raw counts and large stage objects remain outside this compact evidence archive; input byte hashes, complete result CSV, original scientific certificates/fits/RNG payload, exact-comparison hashes, runtime lock, task scripts/raw counters, trace and console logs are retained.\n\nKernel peaks are per container, not the simultaneous whole-job peak. See `summary.json` and the benchmark protocol for scope, source, cache and resource limits.\n')
files=sorted(f for f in out.rglob('*') if f.is_file())
(out/'SHA256SUMS.txt').write_text(''.join(hashlib.sha256(f.read_bytes()).hexdigest()+'  '+str(f.relative_to(out))+'\n' for f in files))
print(out)
