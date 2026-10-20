> Publication scope: historical validation below refers to the explicitly named original source/runtime. Detailed local evidence and raster previews are not distributed in this review branch. This publication commit has its own pending qualification; see the publication scope document.

# Scientific qualification

## Current combined feature and cleaned-runtime checks

The combined schema-3 feature branch at operational checkpoint
`c44c34fc604fc85004d93f1bdca21c87cb325065` passed the local scientific and
integration checks below. The runtime contains SCEPTRE source
`01bb39ccf8373ae8965a2679ee4813a63ea2d85d`, exact R CMD build archive SHA256
`606363fce32238354fc0d126d79f515973da7c8287ca43b14ce53ce2d00df4b7`.
The immutable local Linux ARM64 image is
`sha256:c0fea87023e95a1b6a8d5004baa8e73cdab3678531b9bd53ed1e283c9f1783a5`,
with R 4.5.1 and mandatory ondisc 1.3.1. Later documentation/evidence edits do
not change the frozen validation inputs.

- All **38 real nf-test cases passed**, with every required case present exactly
  once, no skips and an executed distributed branch. The suite includes actual
  concurrency, reordered completion and retry after a completed proposal.
- Both complete R suites passed nine memory and two backed cases each, without
  backend skips. Eight one/multiple/uneven/excess partition scenarios also passed.
  Comparisons check full public tables, failed-QC rows, plans/budgets, fits,
  assignments, ordered cells, design/pair-QC/metrics and RNG in the same runtime.
- Both actual Nextflow reference and distributed integration harnesses passed
  numerical comparison, fully cached scientific resume, nested-config identity,
  publication collision and changed seed/source/array-setting rejection. An
  actual failed worker prevented collection and completed-family publication.
  A checksum-consistent artifact missing an expected family was rejected.
- Report value/nonmutation/failure-isolation checks, the 100,000-row bounded HTML
  regression and a complete real eight-task synthetic demo passed. Full CSV/RDS
  scientific data remain complete; bounded HTML is a presentation limit.

The current CI receipt (historical evidence retained locally) retains
terminal statuses, TAP/JUnit, numerical summaries, runtime identity, raw logs,
source hashes and compact task traces. The independent integration review (historical evidence retained locally)
records its separate code/guard/receipt scope; its
terminal readback addendum (historical evidence retained locally)
checks the completed current run independently. Historical source-169c16e receipts
below and in older evidence directories retain their original identities.

## Scheduler, platform and scale boundaries

The [Betty array smoke test](array-validation.md) passed real batching, a
singleton remainder, collection, cached resume, a site override and failed-child
gating using the production scheduler configuration. It ran shell workers;
scientific calculations on Slurm/AMD64/Apptainer remain pending.
The cleaned runtime also has a successful local AMD64 image build and offline identity check (historical evidence retained locally),
with no image transfer, SIF conversion or scientific workflow in that image.
Native SIF checksum/profile admission guards are implemented and tested locally;
positive scientific SIF execution needs its own [site qualification](hpc.md).

The automatic hosted workflow has not been pushed or dispatched. No hosted green
run, cross-architecture numerical equality, full-screen performance or public
release is established by these local checks. The separate
[DC-TAP benchmark](benchmark.md) uses its original frozen checkpoint; the
[Gasperini/Replogle scale inventory](scale-boundaries.md) is metadata and policy
evidence for a proposed bounded next step, not a completed full-screen run.

## Historical compatibility baseline

This records the schema-3 compatibility baseline qualified on 2026-10-19,
using small deterministic screens and the exact runtimes below. At that
checkpoint, hosted CI, large-screen performance, cluster/cloud schedulers,
Apptainer, Linux AMD64 science and cross-platform numerical equality were outside
its scope.

Subsequent work has separate records for [automatic CI and numerical comparisons](ci.md), [test coverage](coverage.md),
[scheduler arrays](array-validation.md), [real-screen benchmarks](benchmark.md),
[Slurm and Apptainer](hpc.md), and [the scientific report](report.md).
Each record names its executed source/runtime/workload and remaining gaps; adding
a configuration or a harness does not establish a successful execution.

### Exact artifacts

- Package source: `169c16e4ba00c687c1f03fe37e9d79a11d01cd8f`.
- Owner's exact `R CMD build` archive:
  `/private/tmp/sceptre-hardening-qualified-check/sceptre_0.99.0.tar.gz`;
  SHA256 `fb6c3ad20da63c2d2595e08b54a8916e8eed9002e50fa62e877867718afa11b4`.
- Package evidence HEAD: `a3433c71fd339932e4c2d366e5413e13ad8299c9`.
  This is distinct from the packaged source revision. All 126 committed
  R/src/man/inst/data/NAMESPACE files match the archive byte-for-byte; committed
  DESCRIPTION fields match after DCF whitespace normalization. The additional
  fields are standard build metadata. Later evidence changes do not change those
  packaged source paths.
- Final immutable local Linux ARM64 image:
  `sha256:9d150dbba87ba7d4944b55399859ac1ce7244ec9c8ac5dd18d4afeb5ddaa1623`.
  Local tag: `sceptre-pipeline:qualified-169c16e`.
  R 4.5.1, SCEPTRE 0.99.0, ondisc 1.3.1. This is a local image ID, not a
  pullable registry digest. No image or branch was pushed.
- Host: macOS ARM64, R 4.6.0, isolated exact-archive package installation at
  `/private/tmp/sceptre-pipeline-final-lib`, optional ondisc 1.3.5 in a separate
  library. The ordinary user library was untouched. Host SCEPTRE installed-file
  SHA256: `54eca363e6d118bb45be3245c15ab4c64990fdce77aaee0f64dc61543f7dd397`.
- Nextflow 25.10.4, Java 17.0.10, nf-schema 2.6.1, nf-test 0.9.5,
  nf-core/tools 4.1.0. Docker Desktop 4.74.0 / engine 29.4.3.

Pipeline implementation checkpoint: `cb6349a`; subsequent qualification commits
record container tooling, metadata and evidence. Earlier baseline/provisional
runs in container history are superseded by this exact-archive qualification.

### Scientific matrix

Both reference and certified distributed comparisons use all nine memory cases:

| Case | MOI / control | Mechanism | Integration / assignment |
| --- | --- | --- | --- |
| low_nt_permutation | low / NT | permutation, skew-normal | union / maximum |
| low_complement_permutation | low / complement | permutation, skew-normal | union / maximum |
| low_nt_crt | low / NT | CRT, skew-normal | union / maximum |
| low_complement_crt | low / complement | CRT, skew-normal | Bonferroni / maximum |
| high_crt | high / complement | CRT, skew-normal | union / thresholding |
| high_mixture_crt | high / complement | CRT, skew-normal | union / mixture |
| high_permutation | high / complement | permutation, skew-normal | singleton / thresholding |
| low_nt_empirical_permutation | low / NT | permutation, no approximation | union / maximum |
| high_empirical_crt | high / complement | CRT, no approximation | union / thresholding |

Each fixture has noncontiguous retained cells, ordered covariate/design checks,
multiple guides per target and failed-QC requests. Empirical cases deliberately
use three calibration pairs and four eligible discovery pairs: calibration B3 is
300 and later power/discovery B3 is 400. Standalone power/discovery after QC has
the same effective budgets. This guards against calibration-budget leakage.

Comparisons check complete tables, realized plans/settings, compact fits, public
current-result status, assignments, ordered cells/design and R RNG state against
an uninterrupted direct public workflow initialized once at the analysis boundary.
No task-specific reseeding replaces the continuous stream; native samplers retain
their package-owned seeds. A controlled RNG-state advance proves restoration.

Both actual backed cases (low NT permutation and high complement singleton
permutation) require ondisc, with no backend skips. They check closed serialization,
process-local reopening, relocation, unchanged count-file hashes and input CLI
reopening after original paths disappear. Raw active serialized handles and backed
CRT reject. In-memory high MOI resolves to complement controls.

Distributed tests reverse unit execution and proposal arrival, compare complete
families and fitted state, reject missing/duplicate/wrong/corrupt proposals,
conflicting fits and unknown units, and exercise the actual collector subprocess
on proposal files. Workers return raw rows; integration and correction occur once
in the validated collector. Failure cases leave input bytes unchanged and publish
no completed family.

### Final execution evidence

Host reference and distributed suites exited 0 with `REQUIRE_ONDISC=true`, each
passing nine memory and two backed cases. Logs and serialized reports:

- `/private/tmp/pipeline-final169c-direct{.log,/direct-comparison.rds}`
- `/private/tmp/pipeline-final169c-distributed{.log,/distributed-comparison.rds}`

The exact final image passed both full R suites with `REQUIRE_ONDISC=true`, nine
memory and two backed cases each. Logs are `container/qualified-{direct,distributed}.build.log`;
reports are under `container/.build/qualified-169c16e-{direct,distributed}/`.

Actual Docker-profile Nextflow runs exited 0 and matched direct public R in that
same image for every full table and realized plan:

- Distributed high-MOI CRT: `/private/tmp/pipeline-final169c-docker-high-crt.log`.
- Reference low-NT empirical permutations:
  `/private/tmp/pipeline-final169c-docker-low-permutation.log`.

Both passed complete cached resume, collision/changed-setting/source guards and
nested external configuration checks. The distributed run also passed actual
worker-failure fault injection with no collector or completed family publication.

All eight nf-test cases passed on the final isolated host installation in 158.45s:
reference all families/export, QC stopping, discovery after QC, schema failure,
duplicate-family failure, distributed fan-out (18 tasks: seven workers and three
collectors), and both real module interfaces. Evidence:
`/private/tmp/sceptre-pipeline-final-nftest.{log,tap}`.

Locally retained compact evidence: scientific reports (historical evidence retained locally),
execution record (historical evidence retained locally), nf-test TAP (historical evidence retained locally)
and package source equivalence (historical evidence retained locally).
Reports summarize saved assertions; complete temporary logs/work directories are
local diagnostic artifacts, not published datasets.

The actual Nextflow harness additionally checks unknown legacy flags, fresh-run
output collisions, changed seed, changed `.nf` source, and a changed nested
external config child. Identical resume reruns validation and caches all scientific
and export tasks. Interpolated includes reject explicitly; missing/cyclic includes
fail during native configuration parsing before tasks. Dynamic external include
forms are deliberately unsupported; see [usage](usage.md). A real injected worker
failure prevents collector launch and completed discovery publication.

The host nested-config regression also passed separately at
`/private/tmp/pipeline-nested-config-guard-v2.log`. External files are hashed on the
host; raw site configs are never staged/mounted in workers. Production sources are
explicit validator inputs, preventing stale publications after helper/module edits.

Final nf-core schema lint passed all 12 parameters without warnings; shell/Python,
YAML parsing and `git diff --check` passed. Scientific CI is configured for an
explicit full package revision dispatch and has not been run on hosted runners.
[Engineering mapping](nf-core.md) distinguishes applied principles from formal
nf-core community/template conformance.

### Reproduce locally

From a fresh pipeline checkout with Docker and the pinned Nextflow/plugin installed:

```bash
container/build.sh /path/to/sceptre 169c16e4ba00c687c1f03fe37e9d79a11d01cd8f sceptre-pipeline:qualified-169c16e \
  --package-archive /path/to/sceptre_0.99.0.tar.gz \
  --package-sha256 fb6c3ad20da63c2d2595e08b54a8916e8eed9002e50fa62e877867718afa11b4
SCEPTRE_CONTAINER_IMAGE=sha256:9d150dbba87ba7d4944b55399859ac1ce7244ec9c8ac5dd18d4afeb5ddaa1623 \
  SCEPTRE_EXECUTION_MODE=distributed SCEPTRE_TEST_CASE=high_crt \
  bash tests/run-nextflow.sh /absolute/path/to/new-qualification-run
```

Use the newly built image ID if rebuilding; byte-identical image rebuilds are not
promised. The harness creates input/lock files and the direct comparison inside
that same image. Select `reference` and `low_nt_empirical_permutation` for the
second scheduler case. The build context refuses overwrite; preserve an existing
context or use a fresh checkout. See [container instructions](../container/README.md)
for required source artifacts and the full direct/distributed R suites.

### Independent review closure

The independent review found no remaining actionable issue within its bounded
scope. It independently executed the exact-final-archive 12-check collector suite,
clean-checkout configuration/publication probes at `cb6349a`, and a network-disabled
image identity readback. It verified terminal scientific/nf-test receipts without
claiming to rerun those broad suites. The nested-config publication finding is
closed under the documented literal-local external-config policy.

Original reviewer bytes and manifests are preserved in
the final report (historical evidence retained locally),
the pipeline recheck (historical evidence retained locally),
exact-archive verification (historical evidence retained locally),
and the copy hash manifest (historical evidence retained locally).
The review identifies the clean evidence checkpoint `d1ff3ac`; the later handoff
commit adds only these review originals and reproduction documentation. Earlier
baseline/provisional findings remain labeled historical in their source reports.

### CRT execution diagnostic

A separate instrumented dispatch receipt (historical evidence retained locally)
checks the qualified Linux ARM64 package on the same high-MOI screen: reference
and distributed-adapter CRT execution called the CRT sampler and native
association wrapper, with zero permutation calls; changing only the requested
mechanism exercised the permutation branch. Complete public tables, realized
plans, fits and RNG states matched exactly between reference and distributed
adapters. The saved harness and scope (historical evidence retained locally)
retain the original paths and runtime/source identity. This is a package/adapter
execution diagnostic; actual Nextflow scheduling equality is recorded separately
in [CI](ci.md). It is not independent statistical calibration validation.
