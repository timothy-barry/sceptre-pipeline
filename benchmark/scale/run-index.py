#!/usr/bin/env python3
"""Capped before/after kernel curve; use the shared resource wrapper for admission."""
import argparse, csv, datetime, hashlib, json, os, pathlib, re, signal, subprocess, time
p = argparse.ArgumentParser(description=__doc__)
p.add_argument("--base", required=True); p.add_argument("--candidate", required=True)
p.add_argument("--out", required=True)
a = p.parse_args(); out = pathlib.Path(a.out); out.mkdir(parents=True, exist_ok=False)
rows = []
try:
    frozen = {}
    for mode, path in (("before", a.base), ("after", a.candidate)):
        dest = out / (mode + "-distributed_execution.R")
        dest.write_bytes(pathlib.Path(path).read_bytes()); frozen[mode] = dest.resolve()
    script = pathlib.Path(__file__).with_name("unit-index.R").resolve()
    (out / "unit-index.R").write_bytes(script.read_bytes()); script = (out / "unit-index.R").resolve()
    for H, U in ((100000,10),(100000,1000),(1000000,10),(1000000,100),(1000000,1000),(1000000,5000),(2000000,5000)):
        pair = []
        for mode in ("before", "after"):
            label = "%s-H%d-U%d" % (mode,H,U); result = out / (label + ".json")
            cmd = ["/usr/bin/time", "-l", "Rscript", str(script), str(frozen[mode]), str(H), str(U), str(result.resolve())]
            env = dict(os.environ, OMP_NUM_THREADS="1", OPENBLAS_NUM_THREADS="1", VECLIB_MAXIMUM_THREADS="1", R_MAX_VSIZE="2G")
            started = time.monotonic()
            with (out / (label + ".log")).open("w") as log:
                proc = subprocess.Popen(cmd, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                sampled_peak = 0
                while proc.poll() is None:
                    if time.monotonic()-started > 60:
                        os.killpg(proc.pid, signal.SIGKILL); proc.wait(); raise RuntimeError(label + " wall cap")
                    # macOS time process + its R descendant, sampled by process group.
                    ps = subprocess.check_output(["ps","-axo","pgid=,rss="],text=True)
                    rss = sum(int(line.split()[1])*1024 for line in ps.splitlines() if line.split() and int(line.split()[0]) == proc.pid)
                    sampled_peak = max(sampled_peak,rss)
                    if rss > 1536*1024**2:
                        os.killpg(proc.pid, signal.SIGKILL); proc.wait(); raise RuntimeError(label + " sampled RSS cap")
                    time.sleep(.1)
            if proc.returncode: raise RuntimeError(label + " exit=" + str(proc.returncode))
            record = json.loads(result.read_text()); record.update(mode=mode, wall_seconds=time.monotonic()-started, sampled_tree_peak_bytes=sampled_peak)
            match = re.search(r"(\d+)\s+maximum resident set size", (out / (label+".log")).read_text())
            record["kernel_highwater_rss_bytes"] = int(match[1]) if match else None
            rows.append(record); pair.append(record)
            print(label,record["kernel_seconds"],record["kernel_highwater_rss_bytes"],flush=True)
        if pair[0]["units_sha256"] != pair[1]["units_sha256"]: raise RuntimeError("Exact unit identity changed")
    (out / "measurements.json").write_text(json.dumps(rows,indent=2)+"\n")
    with (out / "measurements.csv").open("w") as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0])); w.writeheader();w.writerows(rows)
finally:
    pass  # Shared run-heavy.py owns token-checked lease cleanup.
