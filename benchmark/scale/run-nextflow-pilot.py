#!/usr/bin/env python3
"""One admitted local Gasperini pilot, same runtime, actual Nextflow and exact comparison.

Must run after run-real.py's successful 2k pilot and under the shared resource
wrapper. Generates real-derived files locally; never commit those outputs.
"""
import argparse, json, os, pathlib, signal, subprocess, time
p=argparse.ArgumentParser(description=__doc__)
p.add_argument("--case",required=True);p.add_argument("--library",required=True)
p.add_argument("--out",required=True);p.add_argument("--nextflow",default="nextflow")
a=p.parse_args();root=pathlib.Path(__file__).resolve().parents[2]
case=pathlib.Path(a.case).resolve();out=pathlib.Path(a.out).resolve()
if json.loads((case/"comparison.json").read_text())["status"]!="exact_pass":raise SystemExit("Adapter pilot parity is required")
if json.loads((case/"scalar-summary.json").read_text())["invalid_p_values"]:raise SystemExit("Pilot output invariants failed")
out.mkdir(parents=True,exist_ok=False)
config=out/"capped.config"
config.write_text("""executor { queueSize = 1; cpus = 1; memory = '1 GB' }
process {
 executor = 'local'
 withLabel: process_single { cpus = 1; memory = '768 MB'; time = '90s' }
 withLabel: process_medium { cpus = 1; memory = '768 MB'; time = '90s' }
}
""")
env=dict(os.environ,R_LIBS=str(pathlib.Path(a.library).resolve()),R_MAX_VSIZE="2G",NXF_OFFLINE="true",NXF_DISABLE_CHECK_LATEST="true",NXF_OPTS="-Xms64m -Xmx512m -XX:ActiveProcessorCount=1",OMP_NUM_THREADS="1",OPENBLAS_NUM_THREADS="1",VECLIB_MAXIMUM_THREADS="1")
cmd=[a.nextflow,"-log",str(out/"nextflow.log"),"run",str(root/"main.nf"),"-c",str(config),"-ansi-log","false","-work-dir",str(out/"work"),"--input_bundle",str(case/"fixture/input"),"--analysis_config",str(case/"fixture/config.rds"),"--environment_lock",str(case/"fixture/lock.rds"),"--analyses","discovery","--execution_mode","distributed","--n_work_units","3","--seed","20261019","--outdir",str(out/"results")]
start=time.monotonic();peak=0
with (out/"stdout.log").open("w") as log:
 proc=subprocess.Popen(cmd,cwd=out,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
 while proc.poll() is None:
  snapshot=[tuple(map(int,s.split())) for s in subprocess.check_output(["ps","-axo","pid=,ppid=,rss="],text=True).splitlines() if s.split()]
  ids={proc.pid}
  while True:
   found=ids|{pid for pid,parent,rss in snapshot if parent in ids}
   if found==ids:break
   ids=found
  rss=sum(rss*1024 for pid,parent,rss in snapshot if pid in ids);peak=max(peak,rss)
  if rss>1536*1024**2 or time.monotonic()-start>120:
   for pid in sorted(ids,reverse=True):
    try:os.kill(pid,signal.SIGKILL)
    except ProcessLookupError:pass
   proc.wait();raise RuntimeError("Nextflow pilot exceeded tree RSS/wall cap")
  time.sleep(.1)
receipt=dict(command=cmd,status=proc.returncode,wall_seconds=time.monotonic()-start,sampled_tree_peak_bytes=peak,execution="actual native local Nextflow; one task; fixed isolated R runtime",limits=dict(tree_rss_bytes=1536*1024**2,wall_seconds=120,JVM_heap_bytes=512*1024**2),task_memory_note="macOS trace RSS unavailable; sampled whole-process-tree peak includes JVM and task; not individual R task highwater")
(out/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n")
if proc.returncode:raise SystemExit(proc.returncode)
compare=["Rscript",str(root/"benchmark/compare.R"),str(case/"direct"),str(out/"results"),str(out/"comparison.json")]
with (out/"compare.log").open("w") as log:
 result=subprocess.run(compare,cwd=root,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=90)
if result.returncode:raise SystemExit(result.returncode)
