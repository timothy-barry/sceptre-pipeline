> Publication scope: historical validation below refers to the explicitly named original source/runtime. Detailed local evidence and raster previews are not distributed in this review branch. This publication commit has its own pending qualification; see the publication scope document.

# Slurm array qualification

Qualified on 2026-10-19 using the existing Kerberos-authenticated Betty session.
The worker declaration resolves array size after the final configuration merge,
with null disabling arrays outside the Slurm profile. Nextflow rejects dynamic
closures for this directive; early config assignment can freeze a default before
a later site override. The final implementation avoids both.

The opt-in Slurm profile adapts the prior `feat/nf-core-template` setting from
commit `3192fbd` to the certified `SCEPTRE_WORKER` process. It changes scheduler
batching only; no R-package source, scientific work-unit partition, draw budget,
seed or collector calculation changes.

## Implemented behavior

- `-profile slurm` schedules pipeline processes through Slurm. Only distributed
  `SCEPTRE_WORKER` tasks enable a non-null `array` directive. Preparation, validation,
  collection and export are individual jobs.
- `--array_size` is a positive integer, default 100. It is independent of
  `--n_work_units` and bound to the published run signature. The default local
  profile enables no arrays; reference mode has no workers to batch.
- Resources remain uniform for each worker process; account, partition, QoS and
  site-specific resources stay in external configuration. The existing
  terminate-on-error policy and zero automatic retries are retained.
- Nextflow 25.10.4 submits a singleton remainder as an individual job.

See [usage](usage.md#slurm-worker-arrays) and the
[scheduler fixture](../tests/array-smoke/README.md). The official
[Nextflow array contract](https://docs.seqera.io/nextflow/reference/process/directives/array)
requires a supported executor and uniform resource directives across array tasks.

## Actual Betty run

Runtime: Linux x86_64 Betty compute nodes, Nextflow25.10.4, Java21.0.12 and
Slurm24.11.7. The test used account `ekatsevi-wharton`, QoS `wharton-genoa`,
partition `genoa-std-mem`, one CPU and two-minute walltime per task. Site policy
requires exactly **5632 MB per CPU**, supplied through external label overrides.
The shell fixture's portable 128-MB defaults were not the accepted Betty request.
No GPU resources were requested.

The source and runtime were staged in a new isolated shared directory:
`<LOCAL_QUALIFICATION_ROOT>/process-expression`.
The test imported the **actual production base/Slurm configs**, used the actual
worker/collector names and labels, and ran five shell workers with array size two.

| Submission | Actual Slurm IDs | Result |
|---|---|---|
| First full two-task array | `9167717_0`, `9167717_1` | Both completed, exit0 |
| Second full two-task array | `9167718_0`, `9167718_1` | Both completed, exit0 |
| Singleton remainder | `9167719` | Completed individually, exit0 |
| Collector | `9167722` | Completed individually, exit0; items1–5 appear exactly once |
| Identical `-resume` | Same six task outputs | All five workers and collector cached; no new jobs |
| Controlled child failure | `9167747_1` | Actual child exit42; workflow exit1; no collector launched and no `collected.tsv` published |

A separate site-config override changes the fixture default from size2 to3: all
three workers execute in one real array (`9167760_0` through
`9167760_2`), proving the final resolved value is used.

In the failure run, the other four worker tasks completed successfully, including
its singleton `9167748`; this does not mean all array children failed. The final
accounting readback records the actual compute-node names, memory and exit codes.
All jobs belonging to these runs have left the active queue.

Two setup attempts failed **before any job was accepted**: a non-login shell
lacked Slurm's controller configuration, then the cluster CLI filter rejected
128 MB on its fixed-memory-per-CPU partition. The accepted run used the initialized
login/module environment and external 5632-MB overrides. Those original logs are
preserved instead of being counted as successful scheduler runs.

## Initial local scientific and configuration regressions

At the initial array-addition checkpoint, the qualified package archive was SHA256
`fb6c3ad20da63c2d2595e08b54a8916e8eed9002e50fa62e877867718afa11b4`, source
`169c16e4ba00c687c1f03fe37e9d79a11d01cd8f`. The array addition and integration checks include:

- **All nine real nf-test cases at the initial addition checkpoint**, nf-test0.9.5 / Nextflow25.10.4 / macOS arm64
  R4.6.0, isolated exact-archive installation. This includes the existing
  reference/distributed scientific branches and module interfaces plus the new
  nonpositive-array-size rejection before scientific work. No stub-only tests or
  conditional distributed-test skips substitute for this execution.
- The production profile-isolation guard: only the worker declares the profile-
  conditional array size; the local default enables none. The shell fixture also passes
  locally, with no Slurm array variables.
- Actual scientific workflow run-identity rejection: changing array size2 →3 on
  resume fails with the existing incompatible-publication error.
- nf-core/tools4.1.0 schema lint: all **13 parameters** pass with defaults matched;
  generated parameter help exposes the array setting. Shell syntax and Git
  whitespace checks pass.

Machine-readable qualification (historical evidence retained locally),
Slurm verification (historical evidence retained locally),
accounting (historical evidence retained locally),
nf-test TAP (historical evidence retained locally), original terminal logs,
source/archive/runtime hashes and a
file hash manifest (historical evidence retained locally) are retained locally.
The complete shared work/cache directory remains available for inspection.
Earlier static-setting receipts remain labeled by their original staging/source
hashes; the `slurm-final/` receipts qualify the final process-level expression.
The expanded integrated scientific suite is recorded separately in [coverage](coverage.md).

## Limits

Betty qualification here is a **scheduler-only shell smoke test**. It proves
real job-array grouping, individual collection, singleton handling, cached resume
and child-failure gating using the production scheduler config. It does not run
SCEPTRE scientific calculations on AMD64, validate Apptainer, qualify a full-size
screen, establish performance gains, or qualify any other site's resource policy.
The scientific branch regressions run on the already qualified local ARM64
package runtime. Earlier full host/container scientific comparisons and their
exact revisions remain separately recorded in [package/pipeline validation](validation.md).

Automatic hosted nf-test CI is documented separately in [CI](ci.md); configured
workflows are not evidence of a successful hosted run. No branch, image or site
was pushed, deployed or published by this local qualification.
