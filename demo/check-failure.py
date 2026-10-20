#!/usr/bin/env python3
"""Validate an actual controlled reference failure, never echoed shell source."""
import csv
import json
from pathlib import Path
import sys


def verify(run):
    run = Path(run)
    rows = list(csv.DictReader((run / "failure-trace.tsv").open(), delimiter="\t"))
    failed = [row for row in rows if row["status"] == "FAILED"]
    if len(failed) != 1 or "DISCOVERY:SCEPTRE_STAGE " not in failed[0]["name"] or failed[0]["exit"] != "42":
        raise ValueError("Expected exactly the discovery reference task FAILED with exit 42")
    if any("SCEPTRE_COLLECT" in row["name"] or "SCEPTRE_EXPORT" in row["name"] for row in rows):
        raise ValueError("Collector/export launched despite failed discovery")
    if (run / "failure-results/discovery/state").exists() or (run / "failure-results/exports").exists():
        raise ValueError("Completed discovery/export published despite failed discovery")
    task_hash = failed[0]["hash"]
    # Trace contains the abbreviated work hash; require one exact work directory.
    import re
    if not re.fullmatch(r"[a-f0-9]{2}/[a-f0-9]{6,}", task_hash):
        raise ValueError("Malformed task work hash")
    tasks = list((run / "failure-work" / task_hash[:2]).glob(task_hash[3:] + "*"))
    if len(tasks) != 1 or not tasks[0].is_dir():
        raise ValueError("Missing or ambiguous failed task work directory")
    task = tasks[0]
    if (task / ".exitcode").read_text().strip() != "42":
        raise ValueError("Actual task exit code is not 42")
    # beforeScript may fail before .command.err exists. .command.log is emitted
    # by the task wrapper; .command.sh/.command.run are never marker evidence.
    logs = [task / name for name in (".command.log", ".command.err", ".command.out")]
    emitted = [str(path.relative_to(run)) for path in logs if path.is_file()
               and "W09_TRANSIENT_FAILURE" in path.read_text().splitlines()]
    if not emitted:
        raise ValueError("No emitted exact failure-marker line in failed task logs")
    receipt = {"status": "passed", "failed_task": failed[0]["name"], "exit": 42,
               "work_hash": task_hash, "emitted_marker_logs": emitted,
               "collector_or_export_launched": False, "completed_family_published": False}
    return receipt


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: demo/check-failure.py RUN_DIRECTORY")
    receipt = verify(sys.argv[1])
    (Path(sys.argv[1]) / "failure-verification.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print("PASS actual discovery FAILED/exit42, emitted task marker, no collector/export/publication")
