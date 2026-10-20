# Pinned candidate source for CI

`sceptre_0.99.0.tar.gz` is the complete, unmodified `R CMD build` source archive
from package commit `a9727948fc7b8f74c3b4f461bd9a08ff2fe4fb18`.
`source.json` binds the exact bytes by SHA256
`32c760773f2c46673686e09b44506f09cd15c529fcde786801ca9e582cb692d5`.
Original authors, source notices, GPL-3 license and `COPYING` are retained.
The archive contains tracked package sources, tests, the existing bundled public
example data and the standard built vignettes. Generated vignette output uses
that bundled example; private scale/fitter benchmark outputs are excluded.

At this exact source/archive, the isolated Mac installed suite passed 6,463
assertions across 299 cases with zero failures, errors, warnings or skips.
BiocCheck1.49.30/Bioc3.24 under the original submission flags returned0E1W3N;
strict original category and flagged-instance gates passed with zero new
instances. The subsequent Mac `--as-cran` lane is still running. Final same-archive
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
