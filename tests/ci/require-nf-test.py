#!/usr/bin/env python3
"""Fail closed when a successful nf-test run omits required acceptance cases."""
from pathlib import Path
import re
import sys

# Explicit case identities keep an omitted branch from being replaced by an
# unrelated passing test. Additions can execute without weakening this contract.
required = (
    'Runs every requested complete family',
    'QC stop does not launch result families',
    'Discovery runs directly after QC without calibration',
    'Schema rejects invalid stage before scientific work',
    'Duplicate families fail before scientific work',
    'Schema rejects nonpositive array sizes before scientific work',
    'Certified distributed units finalize complete families',
    'Parameters stop executes no assignment, QC or families',
    'Assignment stop preserves exact assignments and RNG',
    'Empty analysis selection stops after QC without family tasks',
    'Calibration alone matches direct full-family tables and plans',
    'Power alone matches direct full-family tables and plans',
    'One-unit permutations preserve complete tables, fits and RNG',
    'Excess-unit empirical CRT preserves whole-family budgets and RNG',
    'Backed permutation workers match direct saved-state semantics',
    'Native HDF5 CRT workers match direct saved-state semantics',
    'Wrong runtime lock fails before parameters execute',
    'Corrupt input object fails checksum before parameters execute',
    'Nonpositive work-unit request fails schema before tasks',
    'Two uneven units execute serially with exact public R results',
    'Concurrent reordered workers retry discarded proposals with exact public R results',
    'Collects all proposals into the exact public reference family',
    'Rejects incomplete proposals without publishing a completed family',
    'Exports exact certified discovery tables and marks other families omitted',
    'Exports QC-only report without inventing analysis result tables',
    'Prepares the certified target-group units within the requested limit',
    'Rejects input that has not completed QC before publishing a plan',
    'Writes a real object, manifest and version identity',
    'Checks real serialized input and emits a readiness gate',
    'Executes a real certified unit and emits its named proposal',
    'Rejects a unit outside the certified execution plan',
    'Parameters boundary emits state without export or downstream tasks',
    'Empty selected families preserve the QC state and export',
    'Unordered family selection executes canonical power then discovery',
    'Reference analysis preserves discovery-only semantics and RNG',
    'Distributed analysis joins certified proposals into one exact family',
    'Analysis rejects multiple screen states before scientific tasks',
    'Analysis rejects an empty screen channel before scientific tasks',
)
report = Path(sys.argv[1]).read_text()
lines = report.splitlines()
plans = [int(match[1]) for line in lines
         if (match := re.fullmatch(r"1\.\.(\d+)", line.strip()))]
cases = [match for line in lines
         if (match := re.fullmatch(r"((?:not )?ok) (\d+) (.+)", line))]
if len(plans) != 1 or plans[0] < len(required) or len(cases) != plans[0]:
    raise SystemExit(f"nf-test must report at least all {len(required)} expected cases: " + report)
if [int(case[2]) for case in cases] != list(range(1, plans[0] + 1)):
    raise SystemExit("nf-test case IDs must occur once in contiguous report order")
if any(case[1] != "ok" or re.search(r"#\s*(?:SKIP|TODO)", case[3], re.I) for case in cases):
    raise SystemExit("Failed, skipped or TODO nf-test cases cannot qualify scientific CI")
for name in required:
    if sum(case[3].endswith(": " + name) for case in cases) != 1:
        raise SystemExit("Required nf-test case must pass exactly once: " + name)
print(f"PASS all {len(cases)} real nf-test cases; every required case present exactly once; no skips")
