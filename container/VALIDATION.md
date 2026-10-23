# Runtime qualification

The selected native schema-7 archive has SHA256
`f41a8fb7e1bc10366e8efcc7a31644d4c8356bc4eca8adda9ca949c951de4fb4`, source commit
`1e4d5459ab229255694f9217d7cd4ed51a4bf1b8`. Source receipt and archive-schema
admission pass. Context generation preserves exact source bytes.

A fresh Docker Desktop 29.4.3 Linux/ARM64 build succeeded from those exact bytes.
Immutable local image reference:
`sha256:b51c1cdaef908f6386b3313bd787f5d46dcc7b3f08c5fe28b271d2e5c85cd6c9`.
The build enforced schema 7, required native HDF5 dependencies and the archive
checksum. Installed runtime/source assertions passed. Same-image comparisons passed: all nine in-memory direct cases plus artifact
failure guards; all eleven distributed cases, including native HDF5 permutation
and CRT; schema-7 admission and mislabeled historical-object rejection; native
HDF5 relocation with original files absent, raw-input CLI relocation, and missing/
wrong sidecar and corrupt-file rejection. All suite processes exited zero.

Build log, image inspection and installed runtime/source/package provenance are
retained in `container/.build/native7-20261022/`. This is a local immutable image
reference, not a published pullable registry artifact. No image was pushed.
AMD64, Apptainer, hosted CI, HPC and full-screen scale remain separate targets.

Fresh qualification must record the immutable image ID, CPU architecture,
installed dependency versions, exact archive SHA, direct/distributed numerical
comparisons, native HDF5 save/reopen/relocation, Nextflow resume and rejection of
incomplete work. Preserve actual logs and receipts for each target runtime.

The runtime is **not warning-free**. Fresh public namespace import via
`sceptre::import_data()` without first attaching `library(sceptre)` reproduces
`Warning: stack imbalance in '<-', 2 then 4` in a package-only script.
The distributed suite also emitted a stack imbalance warning in `all`.
A separate minimal script with explicit prior `library(sceptre)` completed RAM
and native HDF5 import/getter/matrix realization without the warning. These
observations isolate a package loading path; they do not establish its cause or
justify suppressing the warning. Numerical comparisons passed despite it.

`container/native7-validation.json` binds the image, results, warnings and raw
artifact hashes. This bounded container receipt does not establish warning-free
package acceptance, Nextflow, AMD64, Apptainer, hosted CI, HPC or full-screen scale.

Two additional fresh Rscript processes explicitly called top-level
`requireNamespace("sceptre", quietly=TRUE)` before RAM/native HDF5 public import,
getter and matrix realization; both passed without stack warnings. Explicit
suppressed library attachment also passed without warnings. This establishes
eager namespace initialization as a bounded loading-path mitigation; it does
not establish the underlying package issue's cause.

After adding eager namespace initialization at the pipeline helper entry point,
fresh same-image direct (nine cases plus failure guards), distributed (eleven
cases including HDF5 permutations/CRT), and namespace-only RAM/HDF5 startup
regression processes all exited zero with **zero stack-imbalance warnings**.
The startup regression verifies that the package namespace loads without attaching
`package:sceptre`; it compares full RAM/HDF5 response and guide count matrices.
The package archive remains unchanged. Earlier warning logs and the package-only
lazy-import reproduction remain retained separately. CI checks the final startup
and direct/distributed logs for recurrence.


Actual Docker-backed Nextflow reference/distributed integration and final-bootstrap
native HDF5 CRT all-family execution also passed, including exact public-R
comparisons, resume and failed-worker/configuration/source guards. The separately
sealed pipeline receipt is
`tests/evidence/native7-container-20261022/validation.json`; it records final source
hashes and copied scheduler logs. See `docs/validation.md` for the combined scope.
