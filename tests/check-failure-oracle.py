#!/usr/bin/env python3
"""Negative probes: incidental source text must not certify a failure."""
import csv
import importlib.util
from pathlib import Path
import tempfile

spec = importlib.util.spec_from_file_location("failure", "demo/check-failure.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with tempfile.TemporaryDirectory() as directory:
    run = Path(directory)
    task = run / "failure-work/ab/1234567890"
    task.mkdir(parents=True)
    (task / ".exitcode").write_text("42")
    (task / ".command.log").write_text("W09_TRANSIENT_FAILURE\n")
    rows = [{"hash":"ab/123456", "name":"SCEPTRE:DISCOVERY:SCEPTRE_STAGE (screen:discovery)", "status":"FAILED", "exit":"42"}]
    def trace(value):
        with (run / "failure-trace.tsv").open("w") as stream:
            writer=csv.DictWriter(stream, fieldnames=["hash","name","status","exit"], delimiter="\t")
            writer.writeheader(); writer.writerows(value)
    trace(rows)
    assert module.verify(run)["exit"] == 42
    probes = []
    def rejects():
        try: module.verify(run)
        except (ValueError, FileNotFoundError):
            probes.append(True)
            return
        raise AssertionError("Invalid evidence incorrectly certified")
    for field,value in [("status","COMPLETED"),("name","SCEPTRE:QC (screen:qc)"),("name","SCEPTRE:NOT_DISCOVERY:SCEPTRE_STAGE (screen:discovery)"),("exit","1")]:
        changed=[dict(rows[0], **{field:value})]; trace(changed); rejects()
    trace(rows)
    (task / ".command.log").write_text('echo W09_TRANSIENT_FAILURE >&2\n')
    (task / ".command.run").write_text("W09_TRANSIENT_FAILURE\n")
    rejects() # Echoed-only and source-only markers are not emitted evidence.
    (task / ".command.log").unlink(); rejects()
    (task / ".command.run").unlink(); rejects()
    (task / ".command.log").write_text("W09_TRANSIENT_FAILURE\n")
    (task / ".exitcode").write_text("1"); rejects()
    (task / ".exitcode").write_text("42")
    for name in ("SCEPTRE:SCEPTRE_COLLECT (screen:discovery)", "SCEPTRE:SCEPTRE_EXPORT (screen:export)"):
        trace(rows + [dict(rows[0],name=name,status="COMPLETED",exit="0")]); rejects()
    trace(rows)
    published=run/"failure-results/discovery/state"; published.mkdir(parents=True); rejects(); published.rmdir()
    exported=run/"failure-results/exports"; exported.mkdir(); rejects(); exported.rmdir()
    (run/"failure-work/ab/123456ffff").mkdir(); rejects()
print(f"PASS failure oracle positive fixture and {len(probes)} negative probes")
