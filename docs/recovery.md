# Diagnose and recover a run

Keep `.nextflow.log`, `results/pipeline_info/trace.tsv` and the failed task's
`.command.err`, `.command.log`, `.command.sh` and `.exitcode`. Nextflow prints its
work directory. A failed scientific family is incomplete even when earlier
certified stages remain in the output directory. A missing report after such a
failure does not mean the family returned zero associations.

## Check execution before launching science

`--execution_mode distributed` partitions scientific work; it does not select a
cluster executor. The default executor is **local**, including with Docker.
On a cluster login node select the documented `slurm,apptainer` profiles and
site config, then inspect the resolved configuration before running:

```bash
nextflow config . -profile slurm,apptainer -c /absolute/path/site.config -flat
```

Check `process.executor` and every `withName`/`withLabel` executor override, as
well as CPU, memory, queue, container and backing paths. A site selector can
override the global executor. Do not assume that being inside a Slurm allocation
makes Nextflow submit workers to Slurm. The execution log must identify the
expected executor when tasks launch. See [HPC](hpc.md) and [scale boundaries](scale-boundaries.md).

## Scientific and input failures

| Symptom | Inspect and decide |
| --- | --- |
| Calibration needs non-targeting guides, or group size exceeds active guides | Verify guide labels, assignments and **post-QC** active non-targeting guides. Metadata rows alone are insufficient. Check intended control design and calibration group size. Explicitly omit calibration if that is the intended run; this supplies no calibration evidence. |
| No supplied pairs or no pairs pass QC | Inspect requested response/target identifiers and pair-QC results with treatment/control counts. An empty family is not a negative finding. Correct input errors or justify eligibility scientifically; do not relax QC solely to increase discoveries. Omit a stage that was not requested scientifically. |
| Misaligned cells/features/guides | Verify IDs and order across both count matrices, covariate rows, metadata and external assignments. Reorder using verified IDs before import. Renaming columns does not align cells. Preserve full-library depth covariates when subsetting features. |
| Backed storage or unsupported mode | Use closed descriptors, identity-matched `response.odm` and `grna.odm`, and explicit `--backing_directory`. Read [supported storage/modes](usage.md#count-storage); never silently substitute permutations for CRT. |
| Runtime/config/checksum/signature mismatch | Restore the original immutable inputs for an identical resume, or create a new compatible bundle/lock and fresh output directory for the changed run. Never patch hashes or transplant a lock into an old artifact. |

Reference and distributed stage errors append conditional recovery checks for
these known cases while retaining the original error. Input import/validation
errors can occur before a scientific task and should be inspected directly.
Unknown errors retain their original message and task logs; the hints are not a
complete diagnostic classifier. No hint automatically changes QC, controls,
scientific budgets, method or seed.

## Resume versus a new run

A transient infrastructure failure can be resumed with the **same command**,
unchanged source/site config/input/config/lock/image/seed, original working
launch directory and `-resume SESSION_ID`. Retain `.nextflow/`, `work/` and
`run_signature.rds`; inspect `nextflow log` to find the session. Cached science
may be reused while runtime validation runs again. Do not resume a changed
scientific or execution configuration into existing publication paths. For such
a change use a fresh `--outdir` and compatible inputs; the unchanged task cache
can remain for audit. A resource change also changes execution configuration.

The executable [acceptance walkthrough](../demo/acceptance.sh) induces a
reference discovery-task failure using a temporary sentinel. It then removes
only that sentinel and resumes with identical configuration. This simulates a
transient task failure, not OS OOM, scheduler interruption or scientific failure.
It verifies that the failed task did not publish a completed family.

## Report recovery and moving results

Check `exports/scientific-report/report-status.json`. `failed` describes
presentation availability, not a completed analysis failure. Completed science
is still in stage artifacts and exported tables. Fix the renderer/environment
and rerender inside a **copy of the entire report directory**:

```bash
Rscript --vanilla -e 'source("render.R"); scientific_report_html(readRDS("report-data.rds"), "report.html")'
```

Retain `plots/`, `tables/`, and frozen RDS files so relative assets still resolve.
A rerender does not refresh the pipeline's original `report-status.json`; retain
that original failure receipt separately. HTML row/text/settings previews are
bounded. CSV retains all scalar columns; list/matrix columns remain complete in
`report-data.rds`, and column omissions are labelled. A completed empty table,
an omitted stage, unavailable results and a failed pipeline task have different
meanings. Only successfully completed stages supply scientific results.
