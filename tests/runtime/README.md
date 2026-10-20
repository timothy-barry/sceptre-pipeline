# Pinned package source for CI

`sceptre_0.99.0.tar.gz` is the complete, unmodified `R CMD build` source archive
from package commit `7829075730f402f66daa1a27df16e09fe0f9f32d`.
`source.json` binds the exact bytes by SHA256
`40945603414e9a1bdcfcfb69d65e6ba85f067d585f3d0eec50e9fb952bd00f1a`.
Original authors, source notices, GPL-3 license and `COPYING` are retained.
The archive contains tracked package sources, tests, the existing bundled public
example data and the standard built vignettes. Generated vignette output uses
that bundled example; private scale/fitter benchmark outputs are excluded.

At this exact source/archive, the isolated Mac installed suite passed 6,473
assertions across 301 cases with zero failures, errors, warnings or skips.
BiocCheck 1.49.30 / Bioc 3.24 under the original submission flags returned
zero errors, one inherited warning and three inherited notes;
strict original category and flagged-instance gates passed with zero new
instances. Mac `--as-cran` also completed with zero errors, zero warnings and two notes.
Final same-archive
platform, fresh runtime and end-to-end/scientific/coverage qualification are
separate gates and are not established by the bundled archive or its checksum.

Bundling the complete source lets fork CI build without package repository
credentials or an unpublished container. CI uses these exact bytes, with no
fallback to a moving package branch. Run `python3 tests/ci/check-runtime-source.py`
to check the receipt and its rejection cases before building the runtime.
The container builder also accepts an explicit local Git revision/archive pair.

The previous archive `606363fce32238354fc0d126d79f515973da7c8287ca43b14ce53ce2d00df4b7`
at package source `01bb39ccf8373ae8965a2679ee4813a63ea2d85d` is a historical
pre-overnight baseline. Its runtime, HPC and CI receipts retain their original
scope; they do not qualify this new archive. The prior source remains recoverable
from the frozen baseline Git history.

This archive repairs a 21-field constructor that older Rcpp versions could not
compile. Actual R 4.1 / Rcpp 1.0.12 and current Mac builds each passed 87 focused
assertions, including all result fields on exact analytic success and failure.
Six old/repaired Mac native payloads match exactly; cross-runtime schemas match
with numeric tolerance 1e-7. The prior a972/32c archive and its coverage and v1
simulation receipts remain historical. Fresh globally unique v2 simulation and
current-head coverage belong to this repaired artifact separately.
