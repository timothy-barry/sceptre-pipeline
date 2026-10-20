> Publication scope: historical validation below refers to the explicitly named original source/runtime. Detailed local evidence and raster previews are not distributed in this review branch. This publication commit has its own pending qualification; see the publication scope document.

# Real-screen scale boundaries

The largest currently verified local candidate by cell count is **Replogle rd7
(616,184 cells)**. Gasperini supplies the complementary high-MOI case. These are
real CRISPR-screen candidates for the next qualification step; neither full
screen has been qualified by this pipeline's DC-TAP benchmark. The intended
target here is a realistic CRISPR screen, not a pooled 100-million-cell atlas.

## Verified inventory

Metadata refreshed on October 19, 2026 (local time), without reading count-array
values. Dimensions describe the current local processed/imported views, not a
claim to include every cell/feature in the original publication.

| Local dataset view | Cells C | Responses G | Guides | Targeting groups P | Cartesian upper bound G × P |
|---|---:|---:|---:|---:|---:|
| Gasperini | 207,324 | 13,135 | 13,077 | 6,105 | 80,189,175 |
| Replogle rd7 | 616,184 | 36,601 | 2,666 | 2,383 | 87,220,183 |

These Cartesian products are **not adopted scientific families**, post-QC
eligible counts, or completed analyses. Response filtering, cell exclusions,
requested pair scope and guide integration must be specified before a benchmark.
Gasperini additionally has 101 non-targeting guides. Replogle additionally has
113 non-targeting guides, 17 `nt_off_target` guides and one `unknown` guide; those
three labels are excluded from its targeting-group count.

The current project policies use high-MOI threshold-at-five assignment,
complement controls and CRT for Gasperini; low-MOI maximum assignment, NT controls
and permutations for Replogle. Both use full-library log1p response/guide UMI and
detected-feature covariates, with `prep_batch` additionally modeled for Gasperini.
These are recorded project policies, not a new scientific choice for a full run.
Historical saved objects can contain older formulas and must not silently define
the new benchmark's settings.

Existing computational grids select 500 or 1,000 responses. Replogle reaches all
2,383 targeting groups, but its builder comments describe approximately 308,000
retained cells rather than the original 616,184-cell universe. Gasperini's comment
mentions all 6,105 targets while its actual parameter table stops at 3,200.
Generated computational inputs and the expected assignment/exclusion metadata
were absent at the checked local paths. Thus the retained dimensions and actual
pair-QC family remain unverified here. Replogle's `rd7` label also does not mean
that all screens/subsets from its publication were included.

## Resource and support boundaries

| Quantity | Gasperini | Replogle rd7 |
|---|---:|---:|
| Response backing stored entries | 698,998,312 | 2,173,292,422 |
| Response backing file bytes | 1,492,808,210 | 4,724,278,888 |
| Conceptual 8-byte values + 4-byte indices | 7.81 GiB | 24.29 GiB |

Stored-entry extents are not a freshly measured biological nonzero count; explicit
zeros were not inspected. Compressed backing-file size is not peak RAM. The
conceptual sparse payload excludes pointers, names, designs, conversions, fits
and transient copies. Replogle's stored-entry count exceeds the signed 32-bit
pointer capacity of a single ordinary Matrix sparse object (2,147,483,647), so
whole-screen conversion into that representation is unsuitable. This does not
establish that the current backed scientific path handles the full screen.

Public parameter setup and the certified distributed executor reject **backed CRT**, affecting Gasperini's established
CRT mode. Switching to permutations merely to fit a storage path would change
the scientific procedure and requires an explicit benchmark choice.

For **two-sided, no-approximation testing at alpha .1**, the current policy sets
B3 to `ceiling(10 × H / alpha)`, in addition to B1=499 and B2=0. At the illustrative
upper families above this gives B3=8,018,917,500 and 8,722,018,300, respectively,
which fail the native signed-integer budget guard. The verified admissible scalar
boundary is H=21,474,831 for those settings. This is a mode-specific bound:
approximation policies have different budgets, and QC can change H. No budget
was capped, substituted or changed for this inventory.

The separate bounded scale audit also found whole-family certification and
collection transients and repeated global permutation-bank generation per
worker. Increasing worker count alone does not bound those allocations. Its
1-million-row rendering probe is not qualification of a full-screen scientific
family. The audit's exact frozen source and phase-specific measurements are
identified in the evidence inventory (historical evidence retained locally);
later implementation changes require their own qualification.

## Proposed next bounded gate

1. Choose the actual dataset view, response universe, retained cell universe,
   guide integration, controls, approximation and correction family. Bind input
   provenance and full-library covariates, including required exclusions.
2. Admit metadata and storage at the real dimensions before allocating the full
   family or draw banks. Check representational limits, supported backend/mode,
   derived budgets, maximum treatment/control group sizes and designs.
3. Run a resource-capped representative subset with direct-R versus pipeline
   parity at identical realized settings/budgets, recording actual peak memory,
   wall/CPU time, counts, identities and RNG behavior. Keep original library
   covariates when subsetting and distinguish cold/warm cache policies.
4. Qualify the full family separately, after the subset and collector/storage
   bounds justify a finite resource plan. No full-family launch is authorized or
   implied by this document.

The [DC-TAP benchmark](benchmark.md) covers a complete targeted 279-request family
with 10,932 cells, 93 responses and 110 guides. It supplies bounded real-data
integration evidence; it does **not** qualify these larger screens or support a
runtime extrapolation to them.

## Completed bounded follow-up

The [scale engineering harness and measurements](../benchmark/scale/README.md)
now cover Gasperini subsets of 2,000, 8,000 and 16,000 cells. Each retained 24
eligible hypotheses, six design columns and the naturally resolved
B1/B2/B3 budgets of 499/0/2400, preserving original full-library covariates.
Direct and adapter execution matched complete tables, result records, plans,
preparation, fits and stage RNG states exactly. The separate actual local
Nextflow 2k run completed ten tasks with concurrency one and the same comparison.

These receipts bind worker package `fca6bde5` and pipeline `4578c52`; they are
bounded implementation evidence for those artifacts. The final integrated
runtime requires its own checks. Full-screen family/collector bounds, concurrent
scaling and statistical calibration remain open. Compact metrics and hashes are
public; all real-derived payloads and raw logs remain local. Public backed CRT
setup rejects both execution modes, so its proposed prototype remains deferred.
