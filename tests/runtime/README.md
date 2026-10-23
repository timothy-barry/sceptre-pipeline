# Selected native schema-7 package source

`sceptre_0.99.0.tar.gz` is the unmodified selected native schema-7 source archive,
SHA256 `f41a8fb7e1bc10366e8efcc7a31644d4c8356bc4eca8adda9ca949c951de4fb4`, built from
source commit `1e4d5459ab229255694f9217d7cd4ed51a4bf1b8`.
`source.json`, `ARCHIVE-IDENTITY.json` and `ROOT-ADMISSION.json` bind exact bytes,
source-file hashes and original package qualification scope. Original source
notices, GPL-3 and `COPYING` are retained.

The package uses native SingleCellExperiment/HDF5 storage and requires R >=4.5.
The container targets Bioconductor 3.22 and enforces minimum versions from this
archive's DESCRIPTION. It does not install ondisc or support older schema lanes.

Verify source identity and schema admission without downloads or writes:

```bash
python3 container/prepare-context.py --verify-only --source-manifest tests/runtime/source.json
```

Package qualification recorded in ROOT-ADMISSION does not qualify this pipeline,
new Docker/hosted CI/HPC runtimes or full-screen performance. Those require fresh
same-archive numerical, native HDF5, Nextflow and deployment evidence. The schema-4
RC11d archive was rejected during target selection and is not bundled or supported.

Bounded native pipeline checks are recorded in [validation](../../docs/validation.md)
and `tests/evidence/native7-local-20261022/`; their local host scope does not
qualify a new container or deployment.
