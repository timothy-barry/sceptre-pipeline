# Certified distributed execution boundary

The whole-family reference remains available. A narrow package-owned executor
boundary is implemented by public `prepare_execution()`, `execute_work_unit()`
and `collect_execution()` in the qualified schema-3 package. The pipeline uses
these APIs for opt-in distributed execution; reference remains the default.

Preparation must freeze the global eligible family, failed-QC bookkeeping,
scientific input identity, complete resampling budgets, calibration sampled
pseudogroups and sampler dimensions. A serialized plan must contain values,
never open handles, native draw resources, closures or cached draws.

Partition response blocks for permutation resampling, and whole guide groups
for CRT. Each worker reconstructs the process-local count and native contexts
using global fitting dimensions, full budgets and original native fixed seeds.
R-level task seeds are not a replacement for the native sharing/traversal
contract. CRT workers can contain different guides for the same target-response
integration family: this is safe only because proposals contain raw guide rows.

A worker proposal must certify its ordered unit IDs, exact input/context/method
and runtime identity, raw rows and compatible compact fit updates. It must not
claim `complete_family` or contain finalized/integrated results.

The package collector must require every declared unit exactly once, reject
missing/duplicate/overlapping/conflicting proposals and incompatible fits, and
prove exact disjoint coverage of the global eligible row IDs. It restores global
failed-QC bookkeeping, performs guide integration and the package-defined family
multiplicity once, then atomically commits the ResultRecord. Failed workers must
prevent collection. Calibration bypasses perturbation cache and uses the single
globally sampled pseudogroup definition.

This seam is owned by the R package. Pipeline modules provide scheduling and
manifest wrapping; they must not reproduce result processing or revive removed
pipeline slots. Direct-vs-split/collected tests must cover the actual control,
mechanism, MOI, integration and backing branches at equal realized budgets.
