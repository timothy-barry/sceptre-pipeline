# Continuous integration

The workflow in `.github/workflows/ci.yml` checks the native schema-7 pipeline.
It verifies the selected archive before constructing a Docker context;
there is no fallback to a moving package branch or old schema runtime.

The runtime targets R 4.5.1, CRAN snapshot 2025-11-15 and Bioconductor 3.22.
The installer reads dependency declarations and enforces minimum versions from
the exact archive DESCRIPTION. Native SingleCellExperiment/HDF5 dependencies
replace ondisc. Base-image and GitHub action digests, Nextflow 25.10.4,
nf-schema 2.6.1 and nf-test 0.9.5 remain explicit in source.

Scientific checks run inside the built image: installed-package checks, native
schema admission, direct/distributed comparisons, partition guards, reports,
Nextflow execution and resume. Source configuration is a requested CI gate;
only an actual successful run qualifies the hosted platform. Historical suite
counts, badges and ARM64/Slurm receipts do not qualify this migration.

Artifacts preserve image ID/inspection, installed package versions, session info,
source receipt, scientific outputs and task logs. The source receipt binds commit `1e4d5459ab229255694f9217d7cd4ed51a4bf1b8`
and archive SHA256 `f41a8fb7e1bc10366e8efcc7a31644d4c8356bc4eca8adda9ca949c951de4fb4`;
the bundled archive-identity and package-admission receipts retain their own scope. No workflow publishes an image
or submits cluster work. System and Bioconductor release repositories may update;
preserve the actual built runtime for each qualification.

Verify identity locally without downloads:

```bash
python3 container/prepare-context.py --verify-only --source-manifest tests/runtime/source.json
```
