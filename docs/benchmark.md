> Publication scope: historical validation below refers to the explicitly named original source/runtime. Detailed local evidence and raster previews are not distributed in this review branch. This publication commit has its own pending qualification; see the publication scope document.

# Bounded real-data benchmark

This harness compares an independent public-R workflow with the actual Nextflow
pipeline in one pinned Linux runtime. It is a reproducible release qualification
experiment, not a claim of general screen-scale performance or biological truth.
See [real-screen scale boundaries](scale-boundaries.md) for the verified
Gasperini/Replogle inventory, storage and budget limits, and the next proposed
bounded qualification gate.
The recorded runs use one repetition and discovery immediately after QC;
calibration/power are outside this benchmark's scope. All recorded science is
local ARM64 Docker; Betty scientific execution still awaits container transfer,
SIF conversion and its own terminal qualification. The newer
local AMD64 build (historical evidence retained locally) is build/identity
evidence only.


## Recorded local results: 2026-10-19 pre-SIF checkpoint

The frozen production source (historical evidence retained locally)
and original validation certificates identify this checkpoint, before the later
native-Apptainer frontend change. These are actual DC-TAP counts and experiments,
not the synthetic CI/demo fixtures. Both families retained all 10,932 cells and
all original count features for depth covariates. Eligible p-values were finite
and between zero and one.

All six actual Nextflow comparisons passed **exactly, tolerance zero** against
the independent public-R reference: full result tables including failed-QC rows,
original plans/identities, all compact fits, preparation/spec/import identity and
continuous stage RNG states. The kernel peaks below are the maximum individual
container's charged memory, not a measured simultaneous whole-job peak.

### 32-pair pilot

32 requested; 32 eligible; 0 failed QC. Realized global plan: B1=499, B2=0, B3=3,200 (3,699 total).

| Execution | Command wall (s) | Container CPU work (s) | Max task peak (GiB) | Observed concurrent workers |
|---|---:|---:|---:|---:|
| Independent public R | 12.65 | 12.08 | 0.691 | 1 |
| Nextflow, 1 unit(s) | 44.58 | 30.85 | 0.567 | 1 |
| Nextflow, 2 unit(s) | 34.94 | 30.74 | 0.505 | 2 |
| Nextflow, 3 unit(s) | 38.75 | 33.83 | 0.460 | 2 |

Complete measurements and interpretation (historical evidence retained locally), full result CSV (historical evidence retained locally), realized original plan (historical evidence retained locally).

### 279-pair complete targeted-screen family

279 requested; 264 eligible; 15 failed QC. Realized global plan: B1=499, B2=0, B3=26,400 (26,899 total).

| Execution | Command wall (s) | Container CPU work (s) | Max task peak (GiB) | Observed concurrent workers |
|---|---:|---:|---:|---:|
| Independent public R | 158.02 | 156.27 | 2.470 | 1 |
| Nextflow, 1 unit(s) | 191.80 | 179.94 | 2.472 | 1 |
| Nextflow, 2 unit(s) | 203.29 | 191.84 | 1.608 | 1 |
| Nextflow, 3 unit(s) | 226.09 | 214.97 | 1.607 | 1 |

Complete measurements and interpretation (historical evidence retained locally), full result CSV (historical evidence retained locally), realized original plan (historical evidence retained locally).

The pilot used three-GiB task caps, allowing two workers to overlap. The full
family used six-GiB task caps under a seven-GiB executor envelope, so its units
ran serially. The latter comparisons measure partition/orchestration overhead;
they are not a strong-scaling experiment. The direct full-family public discovery
call itself took 152.24 seconds; its complete R harness took 157.67 seconds,
including stage snapshots. One repetition, warm OS/image caches, and extra
pipeline validation/export/report work prevent stable speedup conclusions.

The 32-pair family had 17 stage-1 and 15 stage-3 results. The full family had
161 stage-1 and 103 stage-3 results, plus 15 failed-QC rows. The larger family
therefore uses a different empirical budget; its timing is not a fixed-budget
cell-scaling comparison. Raw counters/task scripts, source/config verification,
original scientific payloads, runtime lock and data checksums are retained in
those evidence folders with `SHA256SUMS.txt`. Large raw counts and stage objects
remain in the original run directories recorded in their READMEs. The initial
benchmark-only instrumentation failure (historical evidence retained locally)
is preserved and excluded from the primary one-repetition table.

The host was an Apple M5 Pro with Docker Desktop 29.4.3, Linuxkit 6.12.76,
ARM64 R 4.5.1 and Nextflow 25.10.4/Temurin Java 17.0.10; the daemon exposed
18 CPUs and 8,319,410,176 bytes total memory, while task CPU/memory remained
explicitly capped. Host/runtime facts (historical evidence retained locally)
record this context. No ordinary user R library was modified. No Betty
scientific run or atlas-scale qualification is established by these results.

## Real input and scientific scope

The input is the existing DC-TAP K562 high-MOI targeted screen, GSE303901:
`grna_matrix_aligned.rds`, `response_matrix.rds`, and
`grna_target_data_frame.csv`. The source directory is recorded in `inputs.json`;
MD5, SHA-256, and byte lengths bind the original files to their staged copies.
Reproduction requires those checksum-identical aligned project files; the
harness does not independently download or rederive their preprocessing from GEO.
There are 10,932 cells, 110 guides (12 targeting guides across three targets and
98 non-targeting guides), and 93 measured response features. All count rows and
cells remain in import and in the full-library depth covariates. This is a small
real targeted screen; it does not represent a genome-wide perturbation screen.

`prepare.R` constructs the target-by-response family in original target and
response row order, cycling targets fastest. The 32-pair pilot is a separate
complete *requested* family, not a subset of p-values adjusted over 279 pairs.
`--pairs 279` requests the complete 3×93 targeted-screen family. The two family
sizes have different realized empirical budgets and must not be pooled.

Fixed computational settings: high MOI, threshold assignment at five UMIs,
complement controls, union guide integration, two-sided CRT, empirical
`no_approximation` resampling, BH at 0.1, output level 2, and seed 271828 once at
the beginning of the R workflow. Four depth covariates use
`log(response_n_nonzero_full+1)`, `log(response_n_umis_full+1)`,
`log(grna_n_nonzero_full+1)`, and `log(grna_n_umis_full+1)`, computed before
choosing a requested family. QC retains the declared full depth quantile ranges
and mitochondrial threshold one, with at least seven nonzero treatment and
control cells. Actual retained cells, eligible rows, and B1/B2/B3 are read from
the public completed object/RunPlan. No private budget hooks or seed mechanics
are changed. These are valid fixed computational comparison settings, not an
assessment of guide-assignment precision or biological mechanisms.

## Reproduce

From the repository root, with Docker and Nextflow 25.10.4 available:

```bash
export NXF_JAVA_HOME=/path/to/java17
python3 benchmark/run.py \
  --data /path/to/dctap_k562_highmoi_GSE303901/sceptre \
  --out /absolute/new/pilot32 \
  --pairs 32 --units 1,2,3
```

The default image is the immutable qualified ARM64 image
`sha256:03b0acaee28353f7d803158ee45e36b4846bfe86946570a5694d4d490edfe86d`.
It carries package source commit `169c16e4ba00c687c1f03fe37e9d79a11d01cd8f`,
archive SHA-256
`fb6c3ad20da63c2d2595e08b54a8916e8eed9002e50fa62e877867718afa11b4`,
and R 4.5.1. `tests/runtime/source.json` is checked against the image's own
receipt before work. A lock is built **inside that image**, and all bind mounts
retain identical absolute paths. Host R locks deliberately do not qualify the
Linux runtime. The default local image ID is not a pullable registry URL. On another machine,
[build the pinned source context](../container/README.md) using
`tests/runtime/source.json`, or provide an already compatible immutable image
with `--image`. The script verifies its package source receipt.
A different CPU architecture needs its own qualified image;
changing an image tag is not sufficient.

A measured pilot must establish a resource bound before the full targeted family:

```bash
python3 benchmark/run.py \
  --data /path/to/dctap_k562_highmoi_GSE303901/sceptre \
  --out /absolute/new/full279 \
  --pairs 279 --units 1,2,3 --task-memory-gb 6
```

Every output directory must be new. No `-resume` is used in a timed cold run.
No production source, containers, CI workflows, or website files are changed by
this harness. The source matrices are copied byte-for-byte, not altered in place.

## Limits, measurements and equality

The standalone reference is hard-limited to one CPU, 8 GiB and 900 seconds.
Nextflow uses at most two CPU slots and 7 GiB declared aggregate memory. Each
task has one CPU and either 3 GiB (pilot default) or 6 GiB, with a 15-minute
Nextflow limit and a separate GNU `timeout` in the benchmark-only Docker
entrypoint. At 6 GiB, the 7 GiB executor envelope permits one large task at a
time; requesting three units is therefore a partition/overhead measurement, not
a three-way concurrent scaling result. Each complete Nextflow invocation has
an additional 1,800-second controller timeout. Limits are maxima, not measured
use. Container memory includes processes and charged cache. Docker Desktop's
available memory must support the selected envelope; no Docker settings are
changed automatically.

`direct.R` calls `set_analysis_parameters`, `assign_grnas`, `run_qc`, and
`run_discovery_analysis` directly, independently of all pipeline statistical
helpers. Each Nextflow run starts from the same imported object/configuration,
with empty fits. Fresh processes, serialization and no Nextflow cache reuse are
intentional; OS/file-system/image caches are **not** flushed. The R reference
also writes stage snapshots, so its full harness wall time includes that I/O.

`compare.R` requires tolerance-zero identity of the full discovery table, whole
result records (including original frozen plans and certificates), complete
FitCache, full preparation, spec, import identity, and the continuous R RNG state
at every shared stage. Only data.table's process-local self-reference is omitted;
other scientific attributes and compact row-name representation are preserved.
A mismatch fails the run instead of producing a performance claim.

Resource evidence distinguishes:

- command wall latency, including JVM/orchestration for Nextflow;
- direct public-stage R CPU and elapsed time;
- summed task cgroup CPU (work, not elapsed latency);
- kernel `/proc/self/status` VmHWM for the standalone R process (kernel RSS
  accounting has documented approximation limits);
- kernel cgroup `memory.peak` for each individual container, including its cache.

The pipeline does not have a measured simultaneous whole-job memory high-water
mark. Its maximum *individual task-container* peak must not be described as that
quantity, and per-task peaks must not be added and called a measured peak.
The Linux kernel documents [cgroup memory.peak](https://docs.kernel.org/admin-guide/cgroup-v2.html#memory)
and [process RSS/high-water accounting](https://docs.kernel.org/filesystems/proc.html).
Nextflow trace/report/timeline and per-task raw kernel counters are retained.
`summary.json`/`summary.csv` report these distinct quantities. One repetition is
insufficient for stable performance estimates or speedup claims. Computational
agreement does not establish null calibration, FDR control, guide-assignment
precision or biological discoveries.

## Betty and remaining qualification

The source data also exist on Betty under
`<LOCAL_DATA_ROOT>/dctap_k562_highmoi_GSE303901/sceptre`.
The separately validated Slurm shell-array fixture demonstrates scheduling,
resume and child-failure behavior; it is not a scientific benchmark. At this
checkpoint the advertised `aocc/5.0.0` + `r/4.5.2` runtime fails, and the
SBGrid R path requires unavailable licensed module access. The qualified local
image is ARM64; there is no qualified AMD64 image for Betty. No full Betty
scientific run is claimed, no license workaround is attempted, and ordinary user
R libraries remain untouched. A later Betty run requires a supported isolated
scientific runtime, a newly created lock in that runtime, and the same bounded
pilot/equality checks before larger work. The documented Slurm site's minimum
memory is 5,632 MB per CPU; use the site's approved resources rather than blindly
copying local Docker settings.


## Interpretation and source boundary

The CRT execution keys here are only three targeting groups, so this dataset
cannot demonstrate useful concurrency beyond three workers. Each worker retains
the full prepared screen/context, and collection materializes the whole family.
Cold workers can repeat shared response fitting across guide units; completed
fits are reconciled at collection. This benchmark does not qualify permutation
bank scaling, atlas-sized data, or pooled 100-million-cell workflows. Separate
large-object/kernel audits are different evidence and cannot be inferred from
these 279 pairs.

The pipeline baseline revision alone does not identify the uncommitted candidate
changes present during these runs. Runtime/package/image identities, original
per-run validation signatures, external-config digests and verified source-byte
maps identify this checkpoint. `verify-executed-sources.R` compares original
execution-time source certificates with bytes after completion. The finalized
harness also captures a production-source map before preparation and after all
comparisons, refusing source drift. Original commands/configs and task scripts
remain authoritative for the recorded runs, which began before that extra
harness preflight was added. Later production changes require their own
qualification; this evidence is not automatically a claim about a later commit.
