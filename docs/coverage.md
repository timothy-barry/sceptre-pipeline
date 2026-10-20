# Scientific test coverage

Coverage is organized by behavior and evidence. Test declarations, executed cases,
numerical comparisons, hosted CI results and scheduler qualification are separate
claims. The suite is designed around scientific boundaries and failures rather
than matching another pipeline's test count. The matrix is intentionally targeted,
not the Cartesian product of all parameters.

## Automatic pull-request and push tier

`.github/workflows/ci.yml` runs all checks below, with mandatory Docker native R
execution and ondisc. Missing distributed/backend capabilities fail the job.
`tests/ci/run-nf-test.sh` always enables distributed discovery and its TAP guard
rejects omitted, skipped, TODO or failed required cases. No stub option is used.

| Behavior | Executable cases/assertions | Tier and evidence |
| --- | --- | --- |
| Complete-family orchestration and public module boundaries | `tests/main.nf.test`; `tests/modules/*.nf.test`: all requested families, direct discovery after QC, real validation/stage/preparation/worker/collection/export modules | Automatic nf-test; TAP/JUnit + Nextflow trace |
| Direct subworkflow contracts | `tests/subworkflows/*.nf.test`: parameters-only boundary, empty family selection, canonical power/discovery order; reference/distributed discovery; empty or multiple screen rejection | Automatic native nf-test; exact selected public results/plans/fits/RNG and task-boundary assertions |
| All preparation stops | Existing QC stop plus `tests/ci/matrix.nf.test` parameters and assignment stops | Automatic nf-test; task counts, absence of excluded stages, exact saved assignments/spec/cells/fits/RNG |
| Analysis selections | Calibration only, power only, discovery only, empty selection, all families | Automatic nf-test; semantic public-table/global-plan checks and excluded-stage absence |
| Low/high MOI; NT/complement controls; permutation/CRT; integration; mixture assignment | `tests/direct-comparison.R` and `tests/distributed-comparison.R` execute the nine fixture cases below | Automatic same-image R comparisons; corrected full tables, realized plans, assignments, ordered cells, fits and uninterrupted RNG |
| Empirical budgets | Low permutation and high CRT empirical fixtures (calibration size three versus four eligible discovery pairs) | Automatic R comparisons, empirical CRT nf-test; verifies realized B1/B2/B3 from public plans |
| Reference versus actual distributed scheduling | Main distributed nf-test plus one-unit permutation, excess-unit empirical CRT and backed-permutation cases | Automatic nf-test runs real prep/workers/collection, then compares saved tables/plans/fits/assignments/RNG with direct public execution |
| Actual scheduling invariance | `tests/ci/scheduling.nf.test`: two uneven units serialized with queue/maxForks one; three singleton units with concurrency two and controlled post-proposal retry | Automatic actual nf-test; trace proves no overlap versus overlap, reordered first attempts, exactly one failed exit42 after a proposal exists, successful attempt2 and collector after all successful workers; exact direct-R equality |
| Partition boundaries | `tests/ci/unit-partition-matrix.R`: permutation and empirical CRT each request 1, 2, 3 and 99 units | Eight exact numerical scenarios; actual uneven partition required; excess requests become singleton keys; reversed execution/arrival order |
| Backed storage | Both R suites run low/high permutation fixtures with mandatory ondisc; nf-test runs backed permutation through actual Nextflow | Automatic; closed-state save/reopen, relocated backing, immutable backing hashes, public numerical parity |
| Unsupported backed CRT | Real backed-CRT nf-test | Automatic expected rejection; no completed analysis-family artifact |
| Invalid selections and scalar parameters | Unknown stage, duplicate families, nonpositive array size and nonpositive unit count | Automatic nf-test; rejection before scientific task publication |
| Runtime and input integrity | Wrong package lock and corrupted serialized input in real nf-test; R adapter suite also changes config/runtime/schema/checksums | Automatic; useful error and no completed downstream state |
| Collector admission and transactional failure | R distributed suite: missing/duplicate/wrong/corrupt proposals, invalid global rows, unknown worker, empty CLI proposals | Automatic; rejected publication, unchanged input state, exact successful CLI result/fit/RNG |
| Resume and publication identity | `tests/run-nextflow.sh` in reference and distributed modes | Automatic actual Nextflow runs: cached science on identical resume; changed seed/array size/source/nested config and stale-output collisions rejected |
| Config closure | Integration harness tests literal nested includes, missing/cyclic and unsupported dynamic includes | Automatic; meaningful config identity and failure before tasks |
| Failed worker | Real process failure injected by `tests/conf/worker-failure.config` | Automatic distributed integration; no collector launch or completed family publication |
| Scientific report | `report/check.R` | Automatic real discovery, public values/seed/budgets; omitted/unavailable/empty labels; renderer failure isolation before/after science; immutable base-R rerender |
| Bounded report rendering | `report/check-memory.R` with 100,000 synthetic rows | Automatic same-image presentation regression; bounded HTML and maximum allocation, late budgets/seed/source/correction visible, full CSV/RDS retained unchanged; no scientific inference |
| Complete reproducible demo | `demo/demo.sh` and `demo/check-output.R` in the same pinned runtime | Automatic actual Nextflow run; complete report tables equal saved public results, QC/seed/source bundle and execution report checked |
| Slurm isolation | `tests/check-array-config.sh` | Automatic portable config guard; only worker process has opt-in array behavior |
| Container identity before submission | `tests/ci/check-sif-identity.sh`: missing/wrong SIF SHA, relative SIF, Docker/SIF mismatch, mutable OCI tag | Automatic actual Nextflow negative guards; intended reason and no submitted/cached task; no Apptainer binary required |
| Missing-family false positive | `tests/ci/check-missing-family.R`: self-consistent saved artifact with discovery omitted and checksum updated | Automatic; shared expected-family comparator must reject, rather than iterating only existing records |
| Source and runtime provenance | `tests/ci/check-runtime-source.py`; checksummed source/archive/JARs; Docker build | Automatic; exact qualified archive, moving-ref/corrupt/path-escape rejection, image ID/R session/package versions retained |

### Nine scientific in-memory fixture cases

| Fixture | Distinct scientific boundary |
| --- | --- |
| `low_nt_permutation` | Low MOI, non-targeting controls, permutations, union |
| `low_complement_permutation` | Low MOI with complement controls |
| `low_nt_crt` | CRT with non-targeting controls |
| `low_complement_crt` | Complement CRT and Bonferroni integration |
| `high_crt` | High MOI, threshold assignment, CRT, union |
| `high_mixture_crt` | Mixture-model assignment under high MOI |
| `high_permutation` | High MOI, permutations, singleton integration |
| `low_nt_empirical_permutation` | Exact empirical permutation budgets |
| `high_empirical_crt` | Exact empirical CRT budgets |

### Actual Nextflow scientific representatives

The automatic nf-test suite has **38 declared cases**, including meaningful
expected failures. The exact local execution receipt distinguishes the fresh
full invocation from earlier checkpoints and bounded reruns; declarations alone
are not execution evidence.

| Actual Nextflow case | Scientific mode and exact public-R oracle |
| --- | --- |
| Full reference, QC stop, discovery alone | High-MOI CRT; full expected tables/plans/fit/QC/assignment/RNG comparator |
| Preparation stops, empty selection, calibration alone, power alone | High-MOI CRT; selected public R path with excluded stages absent |
| One work unit | Low-MOI non-targeting permutation; all three families |
| Three work units | High-MOI CRT; all three families |
| Excess request of 99 units | High-MOI empirical CRT; all three whole-family budgets |
| Backed workers | Low-MOI non-targeting permutation with ondisc; all three families |
| Two units, serial | Low-MOI non-targeting permutation discovery; actual uneven keys `[2,1]` and no overlap |
| Three units, concurrent/retry | Same discovery fixture; three singleton keys, overlap, altered completion order, failed proposal discarded and attempt2 successful |
| Unchanged resume | Actual high-MOI CRT reference and distributed workflows; science cached, then same strict direct-R oracle on saved outputs |

These representatives cover each acceptance axis with justified combinations.
They do not claim all nine R fixtures were executed through Nextflow, nor every
combination of scientific mode, partition and concurrency.

Each numerical suite also executes the low-NT and high-MOI permutation fixtures
with disk backing. The direct suite has nine memory plus two backed cases. The
distributed suite has those same eleven cases and tests all three analysis
families at three requested work units. The extra eight-case partition matrix is
discovery-focused; it does not claim every unit count was run across every family
and scientific configuration.

## Scheduler and presentation qualification

Actual Betty/Slurm array submission is a separate tier documented in
`array-validation.md`: full and partial batches, individual collector, cached
resume, failed child, and nondefault array-size override. The smoke workload is
five tiny tasks, not a production CRISPR screen. Hosted Docker CI cannot qualify
Kerberos/VPN, lab account/partition policy, cluster filesystem or scheduler arrays.

Report HTML/Quarto visual review and website rendering have their own evidence
in `report.md`, `demo.md` and the website bundle. R/Nextflow checks do not prove
visual layout or remote publishing.

## Evidence and remaining gaps

The exact local evidence receipt is saved under `docs/evidence/ci-20261019`. Earlier nine-case TAP receipts and the first expanded21-case run are historical
checkpoints; an expanded suite's syntax-only `--dry-run` output is never a green
scientific execution result. Use the final TAP/JUnit and source-hash receipt for
the executed suite, and the R reports for numerical scenarios rather than adding
all assertion counts together.

Automatic Actions is implemented but has not been pushed or dispatched, so no
hosted green result is claimed. Local Docker qualification is Linux/ARM64 with
R 4.5.1 and pinned ondisc 1.3.1. Ubuntu/AMD64 hosted execution, other Nextflow/Java
versions, Apptainer, cloud executors and a full scientific Slurm run remain
unqualified. Backed CRT is deliberately unsupported and tested as a rejection.
These small deterministic fixtures establish exact adapter/protocol behavior in
one runtime; they do not establish production-scale memory/time or scientific
calibration across real datasets.

## Measured nf-test file coverage

The README badge is generated from the pinned nf-test 0.9.5 native `coverage`
command. Current measurement: **9 of 10 files (90%)**. All nine production Nextflow
modules/workflows have recognized direct test references. The remaining file is
the standalone `tests/array-smoke/main.nf` scheduler smoke workflow; its actual
Slurm checks are documented separately. Frozen copies under `benchmark/evidence`
are excluded from discovery through `nf-test.config`.
This measures files recognized as having a test dependency, not executed lines,
R/native coverage, passing tests, or the behavioral matrix above. End-to-end
execution can exercise files without giving them a directly recognized test.
The pinned dependency parser recognizes double-quoted `script` declarations;
the test suites use that equivalent spelling so declared tests are recognized.

CI regenerates CSV/HTML reports, uploads them with scientific diagnostics, and
rejects stale committed coverage/version badges. To update after source, test,
or manifest changes, run from the repository root:

```bash
java -jar /path/to/nf-test.jar coverage --csv /tmp/sceptre-coverage.csv
python3 tests/ci/update-badges.py /tmp/sceptre-coverage.csv
```

Commit the generated SVGs with the corresponding change. The coverage and
version badges describe the checkout; they are not manually asserted CI results.
The version comes from `manifest.version` and currently denotes a development
version, not a published release. The CI status badge queries Actions for
`codex/schema3-pipeline`; it becomes live only after that branch/workflow is
published and run. Update its branch selector when integrating into another
branch. No hosted green result is claimed by these local changes.
