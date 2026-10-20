# nf-core engineering principles

This repository applies nf-core engineering principles to its existing SCEPTRE
workflow. It is not an nf-core community pipeline or a claim of full template
lint compliance. The scientific owner remains the schema-3 SCEPTRE package;
Nextflow owns scheduling, serialized artifacts and execution provenance.

## Implementation and checks

| Principle | Implementation | Evidence / check |
| --- | --- | --- |
| Modular DSL2 | `SCEPTRE_VALIDATE`, `SCEPTRE_STAGE` and `SCEPTRE_EXPORT`, composed by the `SCEPTRE` subworkflow | `meta.yml` contracts; real module and pipeline nf-test cases |
| Explicit channel contracts | `(meta, state directory)` plus value channels for config, runtime lock and backing directory; stage and seed are separate inputs | Module metadata; preparation dependency and branch tests |
| Validate early | Pinned nf-schema 2.6.1 validates parameters; R validates configuration, schema, manifest checksums, prerequisites and actual runtime | nf-core schema lint; invalid-stage/duplicate-family nf-test; direct artifact failures |
| Reproducible environments | Exact package archive and source SHA, pinned base-image digest, dependency snapshot, ondisc commit; immutable runtime image digest | `container/prepare-context.py`, Dockerfile, environment lock; same-runtime direct comparison |
| Resource/profile separation | `process_single`/`process_medium` resource labels in config; local test, Docker and Apptainer profiles | Config review and real local test profile; unrun profiles require separate qualification |
| Deliberate errors and retries | Scientific errors terminate with zero automatic retries; successful bundle publication is atomic | Real package failure tests verify no finalized output artifact |
| Resume correctness | Runtime validation always reruns; a published run signature binds session, input, config, runtime, production workflow/helper source bytes, literal-local external configuration include closure and execution options; successful validation gates the original input path | `tests/run-nextflow.sh` asserts six cached scientific stages, cached export and one fresh validation on resume |
| Provenance | Versioned artifact manifests, exact installed dependency identity, per-stage versions, Nextflow trace/report/timeline/DAG | Direct comparison asserts frozen plans and complete-family results |
| Useful tests | Real fixtures exercise public R stages, actual branches and native algorithms; no touch-only stubs | `tests/direct-comparison.R`, `tests/run-nextflow.sh`, `tests/main.nf.test` |
| Maintainable CI | Automatic schema/shell/Python checks; explicit exact-package dispatch builds a container and runs scientific checks | `.github/workflows/ci.yml`; configuration alone does not establish hosted success |

Scientific scope is held in package components, not pipeline metadata. The default reference executes each result
family in one package call. The opt-in distributed mode freezes a certified
package execution plan, scatters whole-key units into raw unfinalized proposals,
and validates exact coverage before a collector commits a complete family.
Workers prepare native and backed resources locally; serialized execution
artifacts contain no live contexts or cached draws. Integration and multiplicity
remain whole-family collector operations. The first stage sets the requested seed; subsequent stages restore the exact
serialized R RNG kind and state from the artifact, preserving the continuous
public workflow stream. Native sampler seeds remain package-owned. This
correctness reference does not establish
large-screen distributed scatter performance. The distributed branch requires
the matching certified package work-unit and collector APIs, with exact-package
qualification recorded separately. Adding an arbitrary seed per partition is
not an equivalent statistical contract.

## Scheduler arrays

The Slurm profile adapts the prior `feat/nf-core-template` array-size setting to
certified `SCEPTRE_WORKER` processes. Arrays are absent from the default local
profile; collectors and preparation remain individual jobs. Resource and site
configuration are separate, scientific unit boundaries are unchanged, and array
size is part of run identity. See [usage](usage.md#slurm-worker-arrays) and
[bounded scheduler qualification](array-validation.md). This adds a deployment
option without asserting formal nf-core template/community acceptance.

## Local checks

Use an isolated installation of the exact package candidate. Do not use a stale
ordinary user-library package. Run commands from the repository root:

```bash
export R_LIBS=/absolute/path/to/isolated/library
Rscript tests/direct-comparison.R /absolute/path/to/fresh/direct-results
bash tests/run-nextflow.sh /absolute/path/to/fresh/nextflow-results
export SCEPTRE_TEST_FIXTURE=/absolute/path/to/fresh/nftest-fixture
Rscript tests/make-input.R "$SCEPTRE_TEST_FIXTURE"
SCEPTRE_NFTEST_WORKDIR=/absolute/path/to/fresh/nftest-work nf-test test
nf-core pipelines schema lint --dir .
```

`nf-test` is pinned to 0.9.5 for qualification and CI, Nextflow to 25.10.4, and
nf-core/tools to 4.1.0. Install nf-test from the official tagged release and run
its jar from an isolated tools directory if a global installation is unwanted.
`SCEPTRE_NFTEST_WORKDIR` selects fresh disposable test work directories when
qualifying a new runtime; previous published outputs are protected by run
signatures. `nf-test.config` selects the local `test` profile by default. Override with
`--profile test,docker` and set `SCEPTRE_CONTAINER_IMAGE` to the built immutable
image digest for container tests. Generate the fixture and environment lock in
that same image. Host and Linux container numerical equality is not presumed.

The direct comparison suite checks low/high MOI, NT/complement controls,
CRT/permutation, union/Bonferroni/singleton integration, failed-QC requests,
full result tables, frozen budgets and preparation alignment. Backed count tests
are optional locally with an explicit skip reason; `REQUIRE_ONDISC=true` makes
missing supported capabilities a failure. They check closed serialization,
reopening/relocation and unchanged backing files. The shell suite compares real
Nextflow results to direct calls in the same runtime, then tests resume and
unknown legacy flags. nf-test independently checks all families, QC stopping,
discovery without calibration, early failures and both module interfaces.

The distributed nf-test case is explicitly opt-in until its exact package seam
is qualified. With that candidate installed and a fresh fixture, use:

```bash
SCEPTRE_TEST_DISTRIBUTED=true nf-test test --tag distributed
```

It asserts actual worker fan-out, three collectors and published complete-family
artifacts. The reference branch remains the default. Reusing an output directory requires
an identical run signature and the original Nextflow session resumed explicitly;
a new run or changed options must use a fresh output directory. Real scientific comparison
and malformed-proposal rejection require the R integration suite; task counts
alone do not establish statistical equality. Worker fault injection belongs in a
test harness or proposal-validation fixture, not production failure parameters.

## CI and intentional exceptions

The schema job runs on pushes and pull requests. The scientific job is an
explicit `workflow_dispatch` requiring a full 40-character package commit that
is available from the package repository. Until the hardened local package is
published, there is no valid remote revision to substitute. Dispatch checks out
that exact source, creates a narrow build context, builds a local image, runs
direct comparisons with required ondisc support, then real Nextflow and nf-test.
It uploads source identity and diagnostics; it does not push a registry image.

Full nf-core template lint is not the acceptance criterion for this existing
pipeline. We intentionally retain the repository identity and a small local
module set; no community submission, branding, MultiQC, unused reports, Conda
profile or cloud test infrastructure is implied. Local module metadata documents
interfaces without inventing maintainers. Docker/Apptainer profile configuration
is distinct from qualification on those engines. Cluster and cloud schedulers,
large screens and hosted CI require actual runs before being described as
supported. Exact local qualification results belong in the validation evidence.

## Named engineering authorities

Guidance consulted on 2026-10-19 (tool versions above are pinned because these
interfaces evolve):

- [nf-core pipeline guidelines](https://nf-co.re/docs/guidelines/pipelines/overview)
- [nf-core module structure and contracts](https://nf-co.re/docs/tutorials/nf-core_training/writing-nf-core-modules/chapter-3-what-is-a-nf-core-module)
- [nf-core/tools](https://nf-co.re/docs/nf-core-tools) and [module lint](https://nf-co.re/docs/nf-core-tools/cli/modules/lint)
- [nf-test pipeline assertions](https://www.nf-test.com/docs/testcases/nextflow_pipeline/), [configuration](https://www.nf-test.com/docs/configuration/), and [installation](https://www.nf-test.com/installation/)
- [Nextflow process directives](https://www.nextflow.io/docs/stable/reference/process.html) and [configuration](https://www.nextflow.io/docs/stable/config.html)

## External site configuration identity

`workflow.configFiles` omits nested includes. The adapter recursively hashes the
closure of standalone literal local `includeConfig` paths in external site files,
relative to each including file. Unchanged nested configuration must resume with
cached science; modifying a child file rejects publication reuse. Dynamic,
interpolated, remote and conditional include expressions reject explicitly before
scientific tasks. Select separate literal site files/profiles instead. Production
configs remain covered by the full source manifest and retain their normal profile
syntax. No raw external configuration is staged in workers. Missing includes and
cycles fail in Nextflow's configuration parser before workflow startup; its 25.10.4
cycle diagnostic is `StackOverflowError`. Tests cover these failures as well as
unsupported ambiguity. This constrained site-config interface is not general HPC,
cluster, cloud or Apptainer qualification.
