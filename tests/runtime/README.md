# Qualified source for automatic CI

`sceptre_0.99.0.tar.gz` is the complete, unmodified `R CMD build` source archive
qualified on 2026-10-19, including R/C++ sources, documentation, tests, notices,
and example data. Its package `DESCRIPTION` records the original authors and
`License: GPL-3`. The GPL-3 text is supplied in `COPYING`; original source notices
remain in the archive. This source includes the locally developed schema-3
refactor and hardening changes from 2026-10-19, followed by the qualified
submission-diagnostic cleanup. The cleanup preserves native algorithms, scientific
traversal, whole-family correction and resampling policy; its exact archive has
separate package qualification at the evidence commit below.

The declared source commit is
`01bb39ccf8373ae8965a2679ee4813a63ea2d85d`; qualification documentation is at
`9a4694450b5d456beedc11f3876ecb1cd84cb05c`. These commits have not been published.
`source.json` binds that qualification receipt to archive SHA256
`606363fce32238354fc0d126d79f515973da7c8287ca43b14ce53ce2d00df4b7`.
The archive checksum is the authoritative install input. A source commit in a
receipt is provenance, not proof that a remote repository serves that commit.

Bundling the source makes fork pull-request CI self-contained without package
repository credentials, a local Git checkout, or an unpublished container image.
No CI step falls back to the package's default branch or an older released API.
The normal container builder still accepts exact local Git revisions.

To update this fixture, obtain a newly qualified complete source archive from
the package owner, replace the archive, and update both commit fields and the
SHA256 in `source.json` in the same review. Run
`python3 tests/ci/check-runtime-source.py`, rebuild the image, and execute the
scientific checks described in `docs/ci.md`. Preserve all source/license notices.
Do not merely change the checksum to accept an unexplained archive.

Earlier CI evidence under `docs/evidence/ci-20261019` qualifies source `169c16e`
and its old archive. Those receipts remain historical; the feature checkpoint
`a06cb2eafc18e89dd565e8ad23c0617918f2b13f` retains that previous bundled source.
Combined-feature qualification of the current cleaned runtime is recorded under
`docs/evidence/ci-cleaned-runtime-20261019`.
