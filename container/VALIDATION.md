# Container validation log

2026-10-19: local engine inspection confirmed Docker Desktop 4.74.0 (227015), Docker client/engine 29.4.3, `desktop-linux`, Linux ARM64. The pinned Rocker 4.5.1 index contains both Linux AMD64 and ARM64 images. Baseline source context was generated from SCEPTRE commit `cef47da5ec9b8ae4f2ad8eb5d1b6e20978e04932`; git archive SHA256 `d7c36bc3d472606326ae922e1a3e478a2e1f9bbf267e71fb3183976f129f4d41`.

Context generation and shell/Python syntax checks passed. Build/test outcomes and final hardened package identity must be appended after completion; this paragraph does not certify a completed image or science test.

Baseline build completed successfully. Immutable local image reference: `sha256:9464f916c3b8173af33ba51b2c9295292c88d43e00216b1e46d368aceb4681ee` (`sceptre-pipeline:cef47da5`, Linux ARM64). `docker run` by that exact reference confirmed R 4.5.1, SCEPTRE 0.99.0 and ondisc 1.3.1. The first attempt identified missing zlib headers; the completed recipe compiled checksum-pinned zlib 1.3.2 before Rhdf5lib and ondisc. Docker `build --check` completed with no warnings.

Actual `REQUIRE_ONDISC=true Rscript tests/direct-comparison.R` inside this image exited 0: all seven in-memory complete-family comparisons passed, artifact rejection/failure checks passed, and low- and high-MOI backed permutation save/reopen/relocation comparisons passed. No backend skip occurred. This is a same-runtime pipeline-stage-versus-direct-public-R comparison; it does not yet certify the actual Nextflow scheduler or a later hardened package revision. Ignored local evidence: `container/baseline.build.log`, `container/baseline-test.build.log`, and `container/.build/baseline-direct/direct-comparison.rds`.

The actual Nextflow Docker reference workflow subsequently passed in this exact image:
all full result tables and realized plans matched a fresh direct public workflow
in the same image. Resume reran runtime validation and cached six scientific tasks
plus exports; unknown legacy parameters rejected. Evidence:
`/private/tmp/pipeline-docker-baseline-reference-v2.log` and its `results/pipeline_info/trace.tsv`.
This qualifies the baseline Docker reference path; final hardened/distributed
package qualification remains separate.

PROVISIONAL checkpoint `f9f8142bd404c6da1dc39eca2c993f78cb6e5eb1` also built successfully as local image `sha256:436aab5cd7d2dcf25515f69033df33d720f20cec45be3d7dd96074e360802c7f`; source archive SHA256 `5ac7968d85869b40ca4f5d05a3cc79f58f272118b54910404ea8b6c9f8a25dce`. Both `direct-comparison.R` and `distributed-comparison.R` exited 0 with `REQUIRE_ONDISC=true`: nine memory cases including empirical calibration budgets 300/400, plus both backed permutation cases. This checkpoint is superseded and is not final qualification. Logs: `container/provisional-{direct,distributed}.build.log`; results under `container/.build/provisional-f9f8142-{direct,distributed}/`.

The exact-archive context option was tested with an incorrect expected SHA256: it rejected the archive with exit 2 before creating the requested context directory. This protects the `R CMD build` archive handoff; `archive_kind`, exact SHA256 and committed revision are recorded in the manifest.

Candidate `8cbecfb88afdfbb3b45a991f63def7bcef8c8848` built from the owner's **exact R CMD build archive**, SHA256 `529ceb34c0acd8be8455ef16613a006a8e30029c1a05b5b46e97277452c0edde`, as immutable local image `sha256:acd40ede502f79ddfd31591415f473e53c87705a7e7fede2fca781e013eca4eb`. An in-container manifest assertion confirmed archive kind, source commit and exact archive SHA; runtime is R 4.5.1 / SCEPTRE 0.99.0 / ondisc 1.3.1. Docker recipe checks again passed with no warnings. Distributed comparisons exited 0: all nine memory cases and both backed permutation cases passed with the backend required. Direct comparisons also exited 0: all nine memory cases, artifact failure checks and both backed save/reopen/relocation cases passed with the backend required. This is candidate evidence only: a package metadata revision is forthcoming, so final source identity qualification remains open. Logs: `container/final-candidate{,-direct,-distributed,-lint}.build.log`; results under `container/.build/candidate-8cbecfb-{direct,distributed}/`.

## Final exact-archive qualification

Final package source commit: `169c16e4ba00c687c1f03fe37e9d79a11d01cd8f`. Owner-qualified `R CMD build` archive SHA256: `fb6c3ad20da63c2d2595e08b54a8916e8eed9002e50fa62e877867718afa11b4`. The later evidence-only package HEAD `a3433c71fd339932e4c2d366e5413e13ad8299c9` is not the source identity used in this image.

Built immutable local image: `sha256:9d150dbba87ba7d4944b55399859ac1ce7244ec9c8ac5dd18d4afeb5ddaa1623` (`sceptre-pipeline:qualified-169c16e`). In-container assertions verified `archive_kind=R_CMD_build`, the exact source commit and exact archive SHA. Runtime: Linux ARM64, R 4.5.1, SCEPTRE 0.99.0, ondisc 1.3.1, testthat 3.2.3. Docker `build --check` completed with no warnings.

Both current suites exited **0** with `REQUIRE_ONDISC=true`: `tests/direct-comparison.R` passed nine memory cases, artifact failure checks, both backed save/reopen/relocation cases, and both `prepare_input.R` CLI regressions for stale descriptor paths and rejection of raw active handles; `tests/distributed-comparison.R` passed nine memory cases and both backed permutation cases. Both suites execute direct and pipeline code in this same immutable runtime. No backend case was skipped.

Independent source equivalence: all 126 committed files under `R/`, `src/`, `man/`, `inst/`, `data/`, plus `NAMESPACE`, match the exact archive byte for byte. All committed DESCRIPTION fields match after DCF whitespace normalization; only standard R CMD build fields `Author`, `Maintainer`, `NeedsCompilation`, and `Packaged` were added. The source/evidence commit comparison shows no changes to DESCRIPTION, R, src, NAMESPACE or man. Proof: ignored `container/.build/169c16e4ba00c687c1f03fe37e9d79a11d01cd8f/source-equivalence.json`.

Final local evidence: `container/qualified{,-direct,-distributed,-lint}.build.log`, image/provenance files under `container/.build/169c16e4ba00c687c1f03fe37e9d79a11d01cd8f/`, and result reports `container/.build/qualified-169c16e-{direct,distributed}/`. Actual Nextflow Docker scheduling is separately qualified by the parent integration run; these results do not establish AMD64, cluster, cloud or Apptainer qualification. No image was pushed.
