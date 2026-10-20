# Bounded scale engineering

This lane uses realistic CRISPR screens and the existing [scale inventory](../../docs/scale-boundaries.md).
It does not qualify a full screen, infer a scientific family from a Cartesian
product, or extrapolate to 100 million cells.

## Demonstrated scheduling improvement

Package branch `codex/w06-unit-preindex`, base
`840f33436a6811a45d712b78bc587d8a0bb8a25b`, replaces one eligible-index scan
per key with a single row index. First-occurrence keys, chunk boundaries,
within-key global row order and IDs remain identical. The change applies when
constructing and validating canonical work units. It does not stream the
family, collector, certificates, or resampling banks.

The actual old and new helpers produced identical SHA256s at all seven points
in [raw measurements](evidence/index/measurements.csv). At H=1,000,000 and
U=5,000, kernel elapsed was 6.039 versus .017 seconds and whole-process peak RSS
was 150,159,360 versus 133,726,208 bytes. At H=2,000,000/U=5,000 elapsed was
11.584 versus .029 seconds. These are single warm observations on synthetic
indexes with failed QC rows, not end-to-end scientific speedups or confidence
intervals. The retained output is still O(H). The package implementation fingerprint changes;
rebuild package archives/runtime locks and start fresh manifests rather than
resuming across old and new package artifacts. All workers must load the same
qualified artifact.

The curve can be regenerated locally using the script below.

Reproduce with an exact base file and candidate file:

```sh
git -C /path/to/sceptre show 840f334:R/distributed_execution.R > /tmp/before.R
python3 benchmark/scale/run-index.py --base /tmp/before.R \
  --candidate /path/to/candidate/R/distributed_execution.R --out /tmp/new-index-curve
Rscript benchmark/scale/plot-index.R /tmp/new-index-curve/measurements.csv /tmp/curve.png
```

During the overnight program, run heavy commands **only** after W10's explicit
slot notice and through `resources/run-heavy.py W06 COMMAND...`; do not launch
autonomous lease waiters. The curve runner freezes both function files and its
R harness, stops each case above sampled 1.5-GiB process-tree RSS or 60 seconds,
and uses a 2-GiB R vector heap. RSS sampling can overshoot between observations;
macOS `/usr/bin/time -l` supplies completed-process high-water RSS separately.

W11 independently compared the exact candidate helper against the base on
200 irregular random families, both key modes and four unit counts (1,600
comparisons): units and caller RNG matched. That review covers scheduling
identity only; the [independent receipt](evidence/index/independent-unit-index.json) and
[script](evidence/index/independent-unit-index.R) retain source hashes and scope.

## Scalar admission

`python3 bin/resource_admission.py SPEC.json NEW_RECEIPT.json` checks metadata
without allocating counts, pairs or draws. All dimensions, resolved B1/B2/B3 (or explicitly labelled conservative
pre-QC upper bounds),
maximum treatment size, backend, method, execution mode, family/covariate identity, per-process
memory, disk allowance and concurrent workers must be explicit. Exit 2 is a
rejection; exit 0 means **pilot only**. A pass is a necessary check, not a RAM
prediction or a full-run permit. It neither alters scientific settings nor
substitutes permutations for CRT. It is a standalone tool, not an automatic
Nextflow launch gate.

The component payloads exclude object headers, copies, fits, scores, allocator
overhead and most output storage. CRT banks need probability-dependent
measurements; the checker includes only the known 12-byte-per-draw working
arrays from `sample_crt_indices` (`double[B]` and `int[B]`), independently of
unknown draw payloads and C++ vector headers. `workers` reports aggregate
design payload only, not total concurrent RAM. The public parameter-setting path rejects backed CRT before either standard
reference or distributed workflow can run. The distributed executor adds its
own guard; reaching its internal kernel from source alone does not establish
that public setup accepts the method. Backed storage does not waive
native budget limits. The illustrative full-screen upper families are not adopted requests; both
were rejected without materialization. Detailed local inventory receipts are
excluded from this publication branch. Metadata checks preserve the earlier distinction between
stored entries and biological nonzeros.

## Bounded real-data gate

`prepare-gasperini.R` reads only eight raw CSR response rows and the six guides
for the first three original targets. It selects evenly spaced original cell
indices at C=2,000/8,000/16,000 and carries the original four full-library depth
covariates plus `prep_batch` from the closed initial state. It never recomputes
those model covariates from the selected features. Counts and selected-cell,
family and covariate identities are recorded. This is a systems fixture; it is
not a representative biological effect analysis or the missing computational
benchmark's original post-QC family.

`run-real.py --raw GASPERINI_ROOT --library ISOLATED_R_LIBRARY --out NEW_DIR`
executes the 2k pilot before admitting larger subsets. Each phase has a
90-second/1.5-GiB sampled RSS cap, 2-GiB R heap and 512-MiB retained-output cap
per subset; the pilot must use less than half the time/RSS allowance. Pre-QC admission uses the 24-request budget upper bound and labels it; the
actual post-QC budgets remain package-owned and are checked by parity. Science
uses declared high-MOI threshold-5, complement controls, CRT, no approximation,
complete-family BH and its naturally resolved budgets. No budget is capped.

Public `benchmark/direct.R` runs independently. `pipeline-adapter.R` executes
the actual pipeline stage/prepare/worker/collector adapters in reverse worker
completion order, serially with one runtime. `benchmark/compare.R` checks full
tables, complete records/plans, spec, preparation, fit caches and each stage's
RNG state with zero tolerance. These adapter runs do **not** invoke Nextflow or
qualify scheduler/container execution. Existing DC-TAP Nextflow evidence is
historical and is not relabeled for this package revision. A separate
`run-nextflow-pilot.py --case PASSED_2K_CASE --library ISOLATED_LIBRARY --out NEW_DIR`
gate runs actual native local Nextflow on the passed 2k fixture: explicit local
executor, one task, 512-MiB JVM heap, 120-second wall and sampled 1.5-GiB process-tree
RSS caps. Its exact comparison is distinct from adapter-only evidence; its
whole-tree peak includes the JVM and is not a per-task high-water measurement.
All real-derived outputs, including reports, remain local.

## Backed CRT investigation

`probe-backed-crt.R` is deliberately a separate synthetic experiment, never a
production fallback. The attempted run on the guarded package stopped in
`check_set_analysis_parameters`: backed objects require permutations at public
parameter setup. The requested method remained CRT; it was not substituted.
No internal-kernel parity, public-direct backed result or distributed backed
result was produced. The prototype remains deferred at that explicit gate.

Source reachability in `analysis.R` had initially suggested a direct/kernel
experiment, but this was too narrow: the earlier public setup guard is part of
the actual contract. The scalar checker rejects backed CRT in both explicit
execution modes. Before enabling any prototype, preserve raw-count semantics,
cell order, full-library covariates, fit and draw identities, and establish
certificate/save-reopen/relocation/corruption behavior, realistic resource
bounds and independent statistical validation. No support change is made here.
