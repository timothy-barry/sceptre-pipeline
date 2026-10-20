# Usage

## Prepare scientific input

Import the screen with the current schema-3 package. Existing schema-1/2 objects
must first be migrated with the qualified package and their scientific state
checked. Old Nextflow work directories and partial result files cannot be
resumed. Input files and backing count files are immutable during a run.

Create a trusted RDS configuration containing named argument lists:

```r
config <- list(
  analysis = list(
    discovery_pairs = discovery_pairs,
    positive_control_pairs = positive_control_pairs,
    formula_object = ~ response_n_umis,
    resampling_mechanism = "permutations",
    multiple_testing_method = "BH"
  ),
  assignment = list(method = "thresholding", threshold = 5),
  qc = list(n_nonzero_trt_thresh = 7L, n_nonzero_cntrl_thresh = 7L),
  calibration = list(n_calibration_pairs = 100L, calibration_group_size = 2L),
  execution = list(output_amount = 1L)
)
saveRDS(config, "analysis_config.rds")
```

Arguments omitted from a section use the public function's defaults. In
particular, supplying `analysis = list(...)` invokes `set_analysis_parameters()`;
it does not overlay settings on a previous specification. Omit the entire
`analysis` section to preserve an already configured object's specification.
An unconfigured object requires that section. Config files are executable R
serialization from trusted local authors, not an untrusted interchange format.

For an object prepared with `sceptre::set_grna_assignments()`, omit both the
`analysis` and `assignment` sections to preserve its configured external calls.
The assignment stage verifies current data/design/membership/provenance identity
through the package getter; saved completion flags alone are insufficient.
Stale or design-invalidated external calls fail before QC. Supplying an explicit
`assignment = list(...)` requests ordinary package reassignment instead. Changing
the analysis configuration invalidates existing assignments, so configure and
reapply external calls in R before creating the bundle if they should be retained.
Raw response/guide counts and full-library covariates remain in the immutable
object. SingleCellExperiment import and results export are documented in the
package's `single-cell-interoperability` vignette; optional SCE is needed only
in the importing/exporting processes, not in pipeline execution processes.

Assignment arguments are validated by method by the package. Irrelevant method
arguments should be removed rather than relying on legacy pipeline filtering.
Unknown sections/arguments and pipeline CLI flags fail early. Formulae and pair
tables belong in this RDS configuration, not shell expressions. RDS is used here
because public R arguments include formulae and typed pair tables.

```bash
Rscript bin/lock_environment.R environment_lock.rds
Rscript bin/prepare_input.R imported_object.rds analysis_config.rds input_bundle environment_lock.rds
nextflow run . -profile test \
  --input_bundle /absolute/path/input_bundle \
  --analysis_config /absolute/path/analysis_config.rds \
  --environment_lock /absolute/path/environment_lock.rds \
  --outdir /absolute/path/new_results
```

`-profile test` supplies small fixture resource limits; omit it for real screens.
The default workflow executes calibration, power and discovery in that order.
Use `--analyses discovery` or `--analyses power,discovery` to omit calibration.
`--stop_after parameters`, `assignment`, or `qc` stops before association tests.
`--analyses ''` performs preparation only. A selected empty scientific family
raises the package's useful error; it is not silently represented as completed.

The initial analysis R seed defaults to 271828. It is set once at the parameters
boundary, after the immutable screen has been imported. Each subsequent process
restores the certified R RNG kind and state from the preceding manifest and saves
the resulting state. Native samplers retain their package-owned seeds.
The reference executor preserves full-family draw sharing and traversal. Changing
a seed or resampling budget is a scientific run change.

## Count storage

Sparse in-memory objects need no count-file arguments. For backed objects,
construct the input bundle with the public package writer (the pipeline helper
uses it automatically) and pass `--backing_directory /absolute/path/counts`.
This directory must contain files named `response.odm` and `grna.odm`. Rename/copy
the original backing files once if necessary; never reimport them independently
and assume their import identity matches. Both files are staged to every process,
and the package reader verifies identity and reopens process-local handles.
If the saved input's original backing paths have moved, supply the new directory
as the fifth argument to `prepare_input.R`; it opens the closed saved object through
the public reader with explicit verified paths. Active serialized handles reject.
The output RDS contains closed descriptors. Keep the original count files and
use the public reader with explicit new paths when reopening/relocating outputs.

The certified distributed work-unit API supports backed permutation resampling
and rejects backed CRT during `prepare_execution()` and execution-manifest
validation. Direct/reference analysis follows a separate CRT path; reaching that
path does not establish backed-CRT support, memory bounds or numerical
qualification. Use the [qualification record](validation.md) for the exact tested
storage/mode/runtime combination. Do not change resampling methods merely to
bypass a backend guard.

In-memory high MOI resolves to complement controls, even if `nt_cells` is
requested. Inspect the resolved manifest/settings rather than inferring the
branch from a configuration label.

## Environments and executors

Use [container build instructions](../container/README.md) to build from the
exact local package source. Supply an immutable image ID/digest:

```bash
nextflow run . -profile docker --container_image sha256:IMAGE_ID ...
```

Create input/config/lock files in the same image that will execute tasks. A host
lock is intentionally incompatible with Linux container package binaries and R.
A docker/apptainer profile requires an explicit image; no moving default image
is supplied. Docker and Apptainer are separate qualification targets.

External site configuration supports standalone literal local includes, for example
`includeConfig 'resources.config'` (relative to the including file). All such
nested files are hashed on the host and bound to the run signature; their contents
are never staged into tasks. Paths with interpolation, remote URLs, computed or
conditional include expressions, and other ambiguous include forms are unsupported
and reject before scientific tasks. Put conditional choices in separate literal
site files selected with `-c`, or use ordinary profile settings without dynamic
includes. This restriction applies to external site files; production configs are
already bound by the complete source manifest. It can require simplifying existing
institutional/HPC configurations and does not qualify any scheduler. Missing files
and include cycles fail during Nextflow configuration parsing before this workflow
starts (Nextflow 25.10.4 reports a cycle as `StackOverflowError`). Avoid cycles.

Resource labels are in `conf/base.config`. Institutional executor/cloud settings
belong in an external `-c site.config`; credentials never belong in this repo.
`process_medium` defaults to one CPU, 8 GB, 12 h. Tasks terminate on error with no
automatic retry; deterministic scientific errors are not retried. Override
resources per process for your screen. A distributed backend is a distinct
execution policy requiring the package's certified work-unit interface.

## Slurm worker arrays

The opt-in `slurm` profile schedules all pipeline processes through Slurm and
batches **only `SCEPTRE_WORKER`** tasks into Nextflow job arrays. Preparation,
validation, collection and export stay individual jobs. Reference mode has no
workers to batch; select distributed mode explicitly. The default local profile
has no array directive.

```bash
nextflow run . -profile slurm,apptainer -c /path/to/site.config \
  --execution_mode distributed --n_work_units 64 --array_size 16 \
  --container_image registry/name@sha256:EXACT_DIGEST \
  --input_bundle /shared/input --analysis_config /shared/config.rds \
  --environment_lock /shared/lock.rds --outdir /shared/new-results
```

This is a deployment example, not qualification of a particular container or
cluster. Build an exact runtime for the compute-node architecture, create the
input bundle and runtime lock inside that runtime, and use shared paths visible
on every node. The locally qualified ARM64 Docker image does not establish
AMD64/Apptainer scientific compatibility. See [validation](validation.md) for
what was actually tested.

An external literal site config supplies institutional settings, for example:

```groovy
process.queue = 'YOUR_CPU_PARTITION'
process.clusterOptions = '--account=YOUR_ACCOUNT --qos=YOUR_QOS'
```

Load the site's Slurm environment before launching Nextflow; adding `sbatch` to
PATH alone may omit required controller/configuration settings. Sites can also
enforce fixed memory per CPU; override the resource labels to satisfy that policy
(Betty's tested CPU partition requires 5632 MB per CPU). Keep account,
partition, QoS and credentials out of portable defaults.

`--n_work_units` determines how the package partitions whole scientific keys;
`--array_size` (positive integer, default 100) controls how many ready workers
Nextflow groups in one scheduler submission. It does not split a certified unit
or change family correction, seeds or draw budgets. A smaller final batch is
submitted when fewer tasks remain; Nextflow 25.10.4 submits a lone remainder as
an individual job. An array size of one requests one task per
batch. Keep resource requests uniform across each worker process; override CPU,
memory and walltime through the existing resource labels/site configuration.

Array support retains the default terminate-on-error policy and zero automatic
retries. Failed workers cannot produce a completed collected family. Array size
is bound to the published run signature, so changing it requires a fresh output
directory under the same strict execution-configuration policy as other options.

For a scheduler-only test without R or screen data, use
[`tests/array-smoke`](../tests/array-smoke/README.md). This reuses the production
Slurm profile and worker array policy and tests actual array children, partial batches, collection,
cached resume and controlled child failure. It does not replace a scientific
pipeline comparison in the target runtime.

## Resume

Use `-resume` with the same immutable input/config/runtime lock, backing files and
retained Nextflow cache/work directories. Runtime validation always runs, even
when scientific tasks are cached. Deep task caching hashes declared state,
configuration and lock inputs. Rebuild the lock and create a fresh input bundle
when the package/runtime/config changes, then start a new output directory.
Do not transplant a new lock into an old bundle. Do not resume legacy pod work.
A published run signature binds the Nextflow session, source state, configuration,
runtime, helper implementation and run options. A fresh run or changed-seed/config
resume cannot reuse old publication paths. Retain the signature for identical
`-resume`. Concurrent runs must use distinct output directories.
Use a distinct output directory for each scientific run; inspect stage manifests
if a run fails, since completed earlier stages can still be present.

## Certified distributed analyses

The package candidate adds a narrow protocol-1 work-unit API. Select it with
`--execution_mode distributed --n_work_units 16`. The requested unit count is
capped by eligible response keys for permutations, or whole guide groups for CRT.
`reference` remains the default and the numerical fallback. Both modes use the
same package-owned global family/budgets, including failed-QC requests.

Preparation samples calibration pseudogroups once and freezes the global plan.
Workers reopen counts and reconstruct full-dimension native resources locally;
they emit raw certified proposals without integration or significance labels.
Only the package collector, after validating every expected unit and row exactly
once, integrates guides and commits a complete-family result. A worker failure
terminates the workflow and prevents collection. `n_work_units` is scheduler
metadata; it does not alter scientific scope or use a new task seed.

See [distributed protocol](distributed-interface.md) for the input/resource/RNG
contract and [validation](validation.md) for actual qualified branches. Installing
a package with the same version number is insufficient: every process must use
the exact locked implementation/runtime.

For error interpretation, scheduler checks, failure recovery and report relocation,
see [diagnose and recover a run](recovery.md).
