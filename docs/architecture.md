# Architecture and migration

## Legacy mapping

| Former process/script | Current boundary | Reason |
|---|---|---|
| set_analysis_parameters | parameters | Public parameter setter, explicit configuration/preservation semantics |
| prepare_assign_grnas / assignment pods / combine | assignment | Public whole-screen assignment; no `elements_to_analyze` or manual assignment merging |
| run_qc / run_qc_trans | qc | Public QC retaining source/analysis/design alignment and certified eligible families |
| prepare_association_analysis | package-owned plan preparation | Global budgets and calibration pseudogroups belong to transient plans |
| association pods / combine | complete-family run function (reference) | Draw sharing, actual fit identities, full coverage, one integration/correction/commit |
| nuclear/trans branch | explicit `construct_trans_pairs()` scientific scope | No hidden trans mode or suppression of multiplicity |

The original scripts pruned prepared state and wrote removed flat fields. They
have been removed rather than left as runnable unsupported alternate entrypoints.
The public scientific API remains the authority. No pipeline flags or scheduler
partitions are written into `AnalysisSpec` or package object slots.

The reference flow is:

```text
input bundle -> runtime validation -> parameters -> assignment -> QC
  -> [calibration] -> [power] -> [discovery]
```

Each optional analysis can start from QC. Sequential selected families permit
compatible fits to be reused by the package; no draw resource is saved.
For all-versus-all scope, call exported `construct_trans_pairs()` when preparing
`config$analysis$discovery_pairs`; then run ordinary QC and discovery. This has
full-family correction and may require substantially more memory than the legacy
unfinalized trans partitions. Large-screen scalability is a separate target from
bounded correctness fixtures.

## State bundle v1

A `(meta, state_directory)` tuple uses `meta.id = screen` for the existing
one-screen-per-run interface. Each directory contains an RDS object and a
pipeline manifest. The manifest records artifact kind/schema, object schema,
current/completed pipeline stages, parent manifest hash, exact serialized object
hash, configuration hash, imported data identity, requested-scope counts and
order-preserving hashes (the package object owns the actual pair tables),
resolved MOI/control/mechanism/integration, seed policy and runtime identity.
Pipeline metadata certifies handoffs; current scientific result validity remains
owned and checked by the package.

Runtime identity includes hashes of the installed package's files, all recursive
required dependency versions, and exact R platform/version. It deliberately
excludes absolute package installation paths so matching environments can move.
Backing-file paths are process-local; count descriptors are saved closed with the
package's serializer and reopened via the public reader. Count files are immutable
by contract; the pipeline adds no per-gene/tamper scans.

A worker writes a temporary sibling directory, validates results through the
public getter, then renames the complete directory. Errors do not publish a
completed artifact. Nextflow process failure prevents downstream family tasks.
Family results are never finalized by a pipeline concatenation operation.

## RNG and numerical contract

The reference executor invokes exactly one public call per stage with a fixed
initial R seed followed by serialized RNG-state handoff and `parallel = FALSE`. Statistical/native routines
and their full realized budgets remain unchanged. The direct comparison repeats
an uninterrupted direct sequence of these public calls with one initial seed. Calibration's
temporary empirical budget is independent of later analysis budgets.

Exact host comparisons establish bounded same-runtime equality; they do not prove
macOS/Linux bit identity, all screen sizes, or cluster behavior. Both direct and
pipeline tests must run inside the same image for container qualification.

## Deployment compatibility

Existing PR #7 was inspected before implementation. Its goal of publishing a
complete discovery object is retained. Its direct flat-slot retention/merging is
incompatible with schema 7, and its personal image/cloud profile is not adopted.
Use externally supplied executor settings and explicitly qualified images.

## Distributed dataflow

```text
certified QC/current state -> prepare_execution(full family)
                          -> immutable global plan + ordered unit IDs
                          -> execute_work_unit(full state, plan, unit) [parallel]
                          -> raw proposals [collect all]
                          -> collect_execution(full state, plan, proposals)
                          -> one certified complete-family state
```

The analysis subworkflow selects reference or distributed execution without
changing preparation or publication. The pipeline wrapper binds plan bytes to the
parent state, runtime and config hashes, and carries post-preparation R RNG state
through collection. The package validates its own runtime/method/context/plan,
unit/row coverage, fit identities and global canonical ordering. Workers never
save package objects with partial completed result families.

All pipeline helpers are explicit staged `path` inputs with deep task caching;
changing a sourced helper invalidates cached scientific tasks as well as changing
a directly invoked script. Runtime validation emits a readiness value and gates
the original immutable input path, avoiding a new copied path that would
invalidate every downstream resume cache key.
