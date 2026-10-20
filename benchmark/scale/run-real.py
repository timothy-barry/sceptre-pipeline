#!/usr/bin/env python3
"""Admitted capped Gasperini systems subsets using one isolated installed runtime.

Runs public direct R versus actual pipeline adapters; does not invoke Nextflow.
The 2k pilot must pass exact parity and headroom before larger subsets execute.
"""
import argparse, csv, datetime, importlib.util, json, math, os, pathlib, re, shutil, signal, subprocess, time
p=argparse.ArgumentParser(description=__doc__)
p.add_argument("--raw",required=True);p.add_argument("--library",required=True)
p.add_argument("--out",required=True)
a=p.parse_args();root=pathlib.Path(__file__).resolve().parents[2];out=pathlib.Path(a.out).resolve()
rows=[]
try:
    out.mkdir(parents=True,exist_ok=False)
    free_bytes = shutil.disk_usage(out).free
    (out/"storage-admission.json").write_text(json.dumps(dict(free_storage_before_bytes=free_bytes, required_free_bytes=2*1024**3, per_subset_retained_cap_bytes=512*1024**2),indent=2)+"\n")
    if free_bytes < 2*1024**3: raise RuntimeError("Insufficient free storage for three capped subsets plus runtime headroom")
    module_spec=importlib.util.spec_from_file_location("admission",root/"bin/resource_admission.py")
    module=importlib.util.module_from_spec(module_spec);module_spec.loader.exec_module(module)
    env=dict(os.environ,R_LIBS=str(pathlib.Path(a.library).resolve()),R_MAX_VSIZE="2G",OMP_NUM_THREADS="1",OPENBLAS_NUM_THREADS="1",VECLIB_MAXIMUM_THREADS="1")
    sources={}
    import hashlib
    for pattern in ("bin/*.R","bin/*.py","benchmark/scale/*.R","benchmark/scale/*.py","benchmark/direct.R","benchmark/compare.R"):
        for f in root.glob(pattern): sources[str(f.relative_to(root))]=hashlib.sha256(f.read_bytes()).hexdigest()
    (out/"sources.json").write_text(json.dumps(sources,indent=2)+"\n")
    for C in (2000,8000,16000):
        case=out/str(C);case.mkdir()
        receipt=module.admission(dict(cells=C,responses=8,response_entries=8*C,guide_entries=6*C,
            family_rows=24,design_columns=64,max_treated_cells=C,B1=499,B2=0,B3=2400,
            memory_limit_bytes=1536*1024**2,disk_limit_bytes=512*1024**2,backing_bytes=32*1024**2,
            workers=1,backend="memory",resampling="crt",execution_mode="distributed",budget_scope="Conservative requested-family upper bound before QC; actual post-QC budgets are recorded and compared, never replaced",family_identity="first-3-targets-top-8-response-detection-24-request-family",
            full_library_covariates_identity="gasperini-original-closed-initial-state:four-full-depth-covariates-plus-prep_batch"))
        (case/"admission.json").write_text(json.dumps(receipt,indent=2)+"\n")
        if receipt["status"]!="pilot_only":raise RuntimeError("Admission rejected")
        commands=[("prepare",["benchmark/scale/prepare-gasperini.R",a.raw,str(case/"fixture"),str(C)]),
                  ("direct",["benchmark/direct.R",str(case/"fixture"),str(case/"direct"),"20261019"]),
                  ("pipeline-adapters",["benchmark/scale/pipeline-adapter.R",str(case/"fixture"),str(case/"pipeline"),"20261019"]),
                  ("compare",["benchmark/compare.R",str(case/"direct"),str(case/"pipeline"),str(case/"comparison.json")])]
        for phase,args in commands:
            cmd=["/usr/bin/time","-l","Rscript",*args];start=time.monotonic();peak=0
            with (case/(phase+".log")).open("w") as log:
                proc=subprocess.Popen(cmd,cwd=root,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
                while proc.poll() is None:
                    ps=subprocess.check_output(["ps","-axo","pgid=,rss="],text=True)
                    rss=sum(int(s.split()[1])*1024 for s in ps.splitlines() if s.split() and int(s.split()[0])==proc.pid);peak=max(peak,rss)
                    if rss>1536*1024**2 or time.monotonic()-start>90:
                        os.killpg(proc.pid,signal.SIGKILL);proc.wait();raise RuntimeError(phase+" exceeded cap")
                    time.sleep(.1)
            elapsed=time.monotonic()-start
            text=(case/(phase+".log")).read_text();m=re.search(r"(\d+)\s+maximum resident set size",text)
            record=dict(cells=C,phase=phase,wall_seconds=elapsed,peak_process_rss_bytes=int(m[1]) if m else None,sampled_tree_peak_bytes=peak,exit_code=proc.returncode,command=cmd)
            rows.append(record);(out/"measurements.json").write_text(json.dumps(rows,indent=2)+"\n")
            print(C,phase,record,flush=True)
            if proc.returncode:raise RuntimeError(phase+" failed")
            if C==2000 and (elapsed>45 or max(peak,record["peak_process_rss_bytes"] or 0)>768*1024**2):
                raise RuntimeError("Pilot lacks declared 2x headroom; larger cases not admitted")
        plan=json.loads((case/"direct/realized-plan.json").read_text())
        with (case/"direct/result.csv").open() as handle:
            table=list(csv.DictReader(handle))
        values=[float(row["p_value"]) for row in table if row["p_value"] not in ("NA","")]
        finite=sum(math.isfinite(x) for x in values)
        invalid=sum(not math.isfinite(x) or not 0 <= x <= 1 for x in values)
        summary=dict(cells=C,requested=plan["requested"],eligible=plan["eligible"],finite_p_values=finite,
            invalid_p_values=invalid,B1=plan["B1"],B2=plan["B2"],B3=plan["B3"],
            analyzed_cells=plan["analyzed_cells"],design_columns=len(plan["design_columns"]),
            implementation_parity="exact_pass",statistical_calibration="not_assessed")
        (case/"scalar-summary.json").write_text(json.dumps(summary,indent=2)+"\n")
        if invalid or finite != plan["eligible"]: raise RuntimeError("Scientific output invariants failed; parity alone is insufficient")
        size=sum(f.stat().st_size for f in case.rglob("*") if f.is_file())
        if size>512*1024**2:raise RuntimeError("Retained disk cap exceeded")
    for path,digest in sources.items():
        if hashlib.sha256((root/path).read_bytes()).hexdigest()!=digest:raise RuntimeError("Source drift: "+path)
finally:
    pass  # Shared run-heavy.py owns token-checked lease cleanup.
