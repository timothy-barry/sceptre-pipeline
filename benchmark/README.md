# Real targeted-screen benchmark harness

See [the protocol and interpretation limits](../docs/benchmark.md).

- `run.py`: checked image/input staging, one independent direct workflow, then
  actual Nextflow runs with bounded unit counts and hard resource limits.
- `prepare.R`: actual DC-TAP raw counts and fixed declared pilot/full-family scope.
- `direct.R`: public R reference, independent of pipeline scientific helpers.
- `compare.R`: tolerance-zero scientific, plan, fit, preparation and RNG comparison.
- `timed.R`, `container-entrypoint.sh`: Linux kernel high-water resource records.
- `bounded.config`: benchmark-only limits; no production configuration edits.
- `summarize.py`: keep wall latency, CPU work and individual-container peak distinct.

Run directories contain raw inputs/objects and may be large; the checked-in
`evidence/` contains compact receipts, raw logs/counters, comparisons and complete
result CSVs instead. No sensitive credentials or machine-wide configuration are
needed, copied, or changed.
