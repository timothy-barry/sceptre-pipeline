# Continuous integration

`Pipeline checks` runs on every pull request and push, and also supports manual
`workflow_dispatch`. Both schema and scientific jobs are automatic. No package
ref input, private secret, published image, cluster account, or protected runner
is required. Fork PRs use the ordinary `pull_request` event with read-only content
permission and checkout credentials disabled. Superseded runs for the same ref
are cancelled.

## Checks that execute

1. The schema job installs nf-core tools 4.1.0, lints the production schema,
   checks shell/Python syntax, verifies the bundled source checksum, and proves
   altered source receipts fail before dependency downloads.
2. The scientific job resolves the opt-in Slurm configuration and confirms only
   workers receive `array`, while default local execution has no arrays. Five actual
   Nextflow guards reject unqualified SIF images and mutable OCI tags before task
   submission; these guards do not require an Apptainer binary.
3. Docker builds the exact bundled SCEPTRE source, including native code and
   mandatory ondisc support. Build failure is a failed check. Missing runtimes
   never trigger a skip or a fallback to an older package.
4. `tests/ci/run-nf-test.sh` creates workflow, scientific-matrix and certified
   module fixtures in that same container and runs all thirty-eight nf-test cases
   with `--ci --profile test,docker`. It explicitly enables the distributed case.
   The post-run TAP guard requires every named case exactly once, contiguous unique
   case IDs, and no failed, skipped or TODO cases. Scientific processes execute
   real R/native work; no stub option is used.
   The full reference, selected-family and distributed branches launch actual
   Nextflow and then compare with uninterrupted direct public R in the same image:
   exact family sets, full tables, global plans/budgets, design/pair-QC tables,
   cell metrics/order, assignments, fit caches and RNG. Only data.table's native
   self-reference and compact row-name representation are normalized.
   Two scheduling cases require actual serial versus concurrent execution,
   uneven partitions, reordered completion and successful retry after a worker
   has generated a proposal. The collector must wait for successful attempts.
   Direct module tests exercise preparation, worker admission, complete collection
   and scientific export, including rejected incomplete proposals. Direct tests of
   both subworkflows cover selected stages, canonical family ordering, exact
   discovery results, and empty or multiple-screen channel rejection.
5. Direct-versus-adapter and direct-versus-distributed R comparisons cover all
   nine in-memory fixtures and two backed permutation fixtures, with
   `REQUIRE_ONDISC=true` so backend absence fails rather than skips.
6. A numerical discovery partition matrix runs one/two/three/99 requested units
   on permutation and empirical CRT fixtures. It compares corrected tables,
   global plans, fit caches and RNG exactly with direct execution, observes a
   genuinely uneven partition and verifies excess requests become singleton keys.
7. Real report tests check public values, omitted/unavailable/empty stages,
   renderer failure isolation and immutable base-R rerender. A 100,000-row synthetic
   renderer regression requires bounded HTML/allocation while preserving complete
   CSV/RDS data and late scientific settings and budgets. A complete synthetic
   Nextflow demo then verifies all report tables against saved public results.
8. Actual Nextflow reference and distributed runs compare numeric outputs and
   test cached resume, nested configuration identity, rejected changed inputs or
   publication collisions, and failed-worker rejection before collection. A
   checksum-updated, internally consistent artifact missing an expected result
   family must also fail the shared semantic comparator.

The hosted job uses the local executor with Docker on Ubuntu 24.04/AMD64.
Configuration checks for Slurm are portable; actual submission, scheduler job
arrays, partial batches, failed array children and cluster resume are separately
qualified on Betty as documented in `array-validation.md`. Passing hosted CI
cannot establish cluster behavior.

## Pinned inputs and runtime

| Input | Pin |
| --- | --- |
| Java | Temurin 17.0.10+7 |
| Nextflow | 25.10.4 |
| nf-test | 0.9.5; release archive and JAR SHA256 checked before execution |
| nf-schema | 2.6.1 in the pipeline config |
| Python/schema tooling | Python 3.12.8; nf-core 4.1.0 |
| R | Rocker R 4.5.1 multi-architecture image index digest |
| R dependencies | Posit CRAN source snapshot 2025-07-01 |
| ondisc | 1.3.1 at exact source commit and archive SHA256 |
| Rhdf5lib/zlib | Versioned source archives and SHA256 checks |
| SCEPTRE | Complete source archive in `tests/runtime`, SHA256-pinned receipt |
| GitHub actions | Exact commit SHAs, with major-version comments |

The SCEPTRE source is commit `01bb39ccf8373ae8965a2679ee4813a63ea2d85d`;
archive SHA256 is
`606363fce32238354fc0d126d79f515973da7c8287ca43b14ce53ce2d00df4b7`.
The source remains available as a complete GPL-3 source archive with original
notices and a license copy. See `tests/runtime/README.md` for replacement rules.

`container/prepare-context.py --source-manifest tests/runtime/source.json`
verifies this receipt without needing a local package Git repository. It records
`source_resolution: qualified_archive_receipt`; this is an owner-qualified
archive/commit pairing, not a claim that the unpublished commit is remotely
fetchable. The existing repository/revision interface still resolves an exact
local Git commit.

Public network access is required to obtain the pinned GitHub actions, Java,
Nextflow, nf-test, nf-schema plugin, Rocker image and public dependency archives.
Source/version/checksum pins bind inputs but do not guarantee bit-for-bit image
builds or cross-architecture numerical equivalence. The resulting Docker image
ID, platform, R session and installed package table are retained with each run.
There is no dependence on the developer's host R libraries or Docker image cache.

## Reports and failure diagnostics

The `scientific-validation-RUN_ID-ATTEMPT` artifact is uploaded even when a prior
step fails and retained for 14 days. It includes TAP and JUnit reports, the
nf-test console/application logs, Nextflow logs, task `.command` stdout/stderr,
resume traces, pipeline reports, build logs, source/dependency checksums, image
inspection and R/package provenance. Hidden task log files are explicitly
included. Failure before a report exists still preserves diagnostics produced
so far. No job publishes an image, pushes source, or submits cluster work.

## Reproduce locally

From the repository root, with Docker, the pinned Java/Nextflow versions and
the nf-test 0.9.5 JAR installed:

```bash
python3 tests/ci/check-runtime-source.py
python3 container/prepare-context.py --source-manifest tests/runtime/source.json \
  --output /absolute/new/context
# Choose a fresh context directory; preparation never overwrites one.
docker build --iidfile /absolute/new/image-id /absolute/new/context
export SCEPTRE_CONTAINER_IMAGE=$(cat /absolute/new/image-id)
bash tests/check-array-config.sh
bash tests/ci/run-nf-test.sh /absolute/path/nf-test.jar /absolute/new/nf-test
```

Run the direct/distributed comparisons and both `tests/run-nextflow.sh` modes
using the same image, as in `.github/workflows/ci.yml`. Fixtures and environment
locks must be generated inside that image, never with a different host R.

## Qualification status

Local qualification and hosted Actions execution are distinct. The automatic
workflow has not been pushed or dispatched, so no hosted green result is claimed.
Exact local terminal outcomes, executed-case reports and source hashes are
recorded in `docs/evidence/ci-cleaned-runtime-20261019/README.md` for the current
cleaned package and combined feature branch. The earlier
`docs/evidence/ci-20261019/README.md` remains a historical source-169c16e receipt.
Each receipt separates scientific runs from schema/lint and source-integrity
checks. Local ARM64 Docker results do not establish Ubuntu/AMD64 execution;
the first authorized hosted run remains that platform qualification.

The [nf-test runner documentation](https://www.nf-test.com/docs/running-tests/)
describes TAP reports; its pinned CLI also supplies JUnit and `--ci` mode. The
[Nextflow installation guide](https://docs.seqera.io/nextflow/install) describes
Java requirements. The behavior-to-test map and remaining gaps are in `docs/coverage.md`.
Source pins and the complete recipe are in
`container/README.md` and `container/prepare-context.py`.
