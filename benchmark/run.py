#!/usr/bin/env python3
"""Bounded real-data benchmark. Fresh directory; no production file edits."""
import argparse, csv, hashlib, json, os, pathlib, platform, shutil, signal, subprocess, time
p=argparse.ArgumentParser(); p.add_argument('--data',required=True); p.add_argument('--out',required=True)
p.add_argument('--pairs',type=int,default=32,choices=[32,279]); p.add_argument('--task-memory-gb',type=int,default=3,choices=[3,6]); p.add_argument('--units',default='1,2,3')
p.add_argument('--image',default='sha256:03b0acaee28353f7d803158ee45e36b4846bfe86946570a5694d4d490edfe86d')
p.add_argument('--nextflow',default=shutil.which('nextflow') or 'nextflow'); a=p.parse_args()
root=pathlib.Path(__file__).resolve().parent.parent; out=pathlib.Path(a.out).resolve(); data=pathlib.Path(a.data).resolve()
if out.exists(): raise SystemExit('Refusing to overwrite existing output directory')
units=[int(x) for x in a.units.split(',')]
if not units or any(x not in (1,2,3) for x in units) or len(set(units))!=len(units): raise SystemExit('Use unique bounded units 1,2,3')
out.mkdir(parents=True); raw=out/'raw'; raw.mkdir(); receipts=[]
def production_hashes():
    files=[root/'main.nf',root/'nextflow.config',root/'nextflow_schema.json']
    for pattern in ('bin/*.R','conf/*.config','modules/**/*.nf','subworkflows/**/*.nf'): files += list(root.glob(pattern))
    return {str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(set(files))}
source_start=production_hashes()
(out/'source-at-start.json').write_text(json.dumps(source_start,indent=2)+'\n')
config_text=(root/'benchmark/bounded.config').read_text().replace("'3 GB'", f"'{a.task_memory_gb} GB'").replace('--memory-swap=3g', f'--memory-swap={a.task_memory_gb}g')
(out/'bounded.config').write_text(config_text.replace('${projectDir}',str(root)))
def streamed_hash(path,algorithm):
    digest=hashlib.new(algorithm)
    with path.open('rb') as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b''): digest.update(chunk)
    return digest.hexdigest()
for name in ['grna_matrix_aligned.rds','response_matrix.rds','grna_target_data_frame.csv']:
    source=data/name; target=raw/name; shutil.copyfile(source,target)
    receipts.append({'file':name,'source':str(source),'bytes':target.stat().st_size,'md5':streamed_hash(target,'md5'),'sha256':streamed_hash(target,'sha256')})
(out/'inputs.json').write_text(json.dumps(receipts,indent=2)+'\n')
commands=[]
def run(cmd,name,timeout=900,cwd=root):
    start=time.monotonic(); log=out/(name+'.log')
    with log.open('w') as f:
        proc=subprocess.Popen([str(x) for x in cmd],cwd=cwd,stdout=f,stderr=subprocess.STDOUT,start_new_session=True)
        try: status=proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid,signal.SIGTERM)
            try: proc.wait(timeout=15)
            except subprocess.TimeoutExpired: os.killpg(proc.pid,signal.SIGKILL); proc.wait()
            status=124
    record={'name':name,'command':[str(x) for x in cmd],'wall_seconds':time.monotonic()-start,'status':status,'timeout_seconds':timeout}
    commands.append(record); (out/'commands.json').write_text(json.dumps(commands,indent=2)+'\n')
    if status: raise SystemExit(f'{name} failed ({status}); inspect {log}')
def docker(script_args,name,metrics=True):
    cmd=['docker','run','--rm','--cpus=1','--memory=8g','--memory-swap=8g','-e','OMP_NUM_THREADS=1','-e','OPENBLAS_NUM_THREADS=1','-v',f'{root}:{root}','-v',f'{out}:{out}','-w',root,a.image,'timeout','--kill-after=10s','900s','Rscript','--vanilla']
    if metrics: cmd += ['benchmark/timed.R',script_args[0],out/(name+'-resources.json'),*script_args[1:]]
    else: cmd += script_args
    run(cmd,name,timeout=930)
run(['docker','image','inspect',a.image],'image-inspect',60)
docker(['-e','expected <- jsonlite::fromJSON(commandArgs(TRUE)[1]); actual <- jsonlite::fromJSON("/opt/sceptre/source.json"); stopifnot(identical(actual$sceptre_commit, expected$source_commit), identical(actual$sceptre_archive_sha256, expected$archive_sha256))',root/'tests/runtime/source.json'],'verify-image',False)
docker(['benchmark/prepare.R',raw,out/'fixture',str(a.pairs)],'prepare')
docker(['benchmark/direct.R',out/'fixture',out/'direct','271828'],'direct')
receipt={'kind':'bounded-real-targeted-screen-benchmark','repetitions':1,'pairs':a.pairs,'units':units,'image':a.image,'source':json.loads((root/'tests/runtime/source.json').read_text()),'pipeline_revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'data':receipts,'limits':{'global_cpus':2,'pipeline_per_task_memory_bytes':a.task_memory_gb*1024**3,'standalone_memory_bytes':8*1024**3,'task_seconds':900},'cache_policy':'fresh input/no fits; no Nextflow resume; warm OS/image cache not flushed; one repetition'}
production=[root/'main.nf',root/'nextflow.config',root/'nextflow_schema.json']
for pattern in ('bin/*.R','conf/*.config','modules/**/*.nf','subworkflows/**/*.nf'): production += list(root.glob(pattern))
receipt['actual_pipeline_files_sha256']=source_start
receipt['actual_benchmark_files_sha256']={str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted((root/'benchmark').iterdir()) if f.suffix in ('.R','.py','.sh','.config')}
receipt['host']={'platform':platform.platform(),'machine':platform.machine(),'logical_cpus':os.cpu_count(),'nextflow':shutil.which(a.nextflow) or a.nextflow,'NXF_JAVA_HOME':os.environ.get('NXF_JAVA_HOME')}
receipt['pipeline_worktree_dirty']=bool(subprocess.check_output(['git','status','--porcelain'],cwd=root,text=True))
(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
for n in units:
    target=out/f'pipeline-units-{n}'; target.mkdir()
    cmd=[a.nextflow,'run',root/'main.nf','-profile','docker','-c',out/'bounded.config','-ansi-log','false','-work-dir',target/'work','--container_image',a.image,'--input_bundle',out/'fixture/input','--analysis_config',out/'fixture/config.rds','--environment_lock',out/'fixture/lock.rds','--analyses','discovery','--execution_mode','distributed','--n_work_units',str(n),'--seed','271828','--outdir',target/'results']
    run(cmd,f'nextflow-units-{n}',timeout=1800,cwd=target)
    docker(['benchmark/compare.R',out/'direct',target/'results',target/'comparison.json'],f'compare-units-{n}')
    rows=[]
    for marker in sorted((target/'work').glob('*/*/.benchmark-memory.peak')):
        task=marker.parent
        stat=dict(line.split() for line in (task/'.benchmark-cpu.stat').read_text().splitlines())
        rows.append({'work_directory':str(task),'elapsed_shell_seconds':float((task/'.benchmark-end').read_text())-float((task/'.benchmark-start').read_text()),'kernel_cgroup_memory_peak_bytes':int(marker.read_text()),'kernel_cgroup_memory_max_bytes':int((task/'.benchmark-memory.max').read_text()),'cgroup_cpu_usage_seconds':int(stat['usage_usec'])/1e6,'cgroup_cpu_user_seconds':int(stat['user_usec'])/1e6,'cgroup_cpu_system_seconds':int(stat['system_usec'])/1e6})
    with (target/'task-kernel-resources.csv').open('w') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]) if rows else ['work_directory']); w.writeheader(); w.writerows(rows)
source_end=production_hashes()
(out/'source-at-end.json').write_text(json.dumps(source_end,indent=2)+'\n')
if source_end != source_start: raise SystemExit('Production pipeline source changed during benchmark; results cannot qualify a frozen source.')
(out/'source-immutability.json').write_text(json.dumps({'status':'exact_pass','files':len(source_start),'algorithm':'sha256','checkpoints':'before preparation and after all Nextflow/scientific comparisons'},indent=2)+'\n')
run(['python3',root/'benchmark/summarize.py',out],'summarize',60)
print(out)
