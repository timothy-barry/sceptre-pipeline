# Worker-array scheduler smoke test

This lightweight fixture reuses `conf/base.config` and `conf/slurm.config`, the
production worker/collector names and resource labels. It uses shell-only tasks,
not substitute scientific calculations. Each task requests one CPU, 128 MB and
two minutes. Five workers and array size two exercise two full batches and a
partial final batch, followed by one individual collector. Nextflow 25.10.4
submits the singleton remainder as an individual job, with `none` in the array-ID
columns. Site overrides may increase the fixture memory request; Betty requires
5632 MB per CPU in the tested partition.

Run from an initialized cluster login environment with the pinned Nextflow
25.10.4 launcher. All paths must be on shared storage. Supply institutional
account/partition/QoS in an external literal site config:

```bash
nextflow -log /shared/smoke/success.log run tests/array-smoke/main.nf \
  -profile slurm -c /shared/site.config -work-dir /shared/smoke/work \
  --array_size 2 --n_items 5 --outdir /shared/smoke/results
```

`collected.tsv` records item, `SLURM_ARRAY_JOB_ID` and `SLURM_ARRAY_TASK_ID`.
Verify items 1 through 5 appear once and inspect `trace.tsv`, Slurm `sacct`, and
worker `.command.run` files for actual array submission. A collector must have
no `#SBATCH --array` directive. Retain the Nextflow session ID and rerun the same
command with `-resume SESSION`; all five workers and the collector must be cached.

Use a fresh output/work directory and add `--fail_item 3` to test failure. Expect
exit 42 from that child, a failed workflow, and no `collected.tsv`. The default
production policy has zero retries. Keep failure logs and cancelled/completed
sibling accounting rather than interpreting workflow failure as every child
having failed. These runs are tiny but use the real scheduler and allocation.

Without `-profile slurm`, the same fixture runs locally with `none` in the Slurm
columns. Local execution verifies wiring, not array submission. Production
profile isolation is checked with `bash tests/check-array-config.sh`.

See [array qualification](../../docs/array-validation.md) for the exact tested
source, runtime, account, job IDs, outcomes and limits.
