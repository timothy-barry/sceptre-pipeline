# Scientific runtime

The runtime installs the selected native schema-7 package archive verbatim. Build the
credential-free context from the bundled receipt, then build a local image:

```bash
python3 container/prepare-context.py --source-manifest tests/runtime/source.json \
  --output /absolute/new/context
docker build --iidfile /absolute/new/image-id /absolute/new/context
```

Archive SHA256 is checked before preparing the context and inside Docker before
installation. The frozen manifest is independently checked when preparing the
bundled receipt. No image is published. `--verify-only` checks identity without
creating a context. Existing contexts are never overwritten.

Use the immutable local `sha256:...` image ID with `--container_image`; tags can
move. Local image IDs are not pullable registry manifest digests. Publishing,
Apptainer conversion and each compute-node architecture need separate validation.

The base is R 4.5.1 at the pinned Rocker multi-architecture digest in Dockerfile.
Dependencies use CRAN snapshot 2025-11-15 and Bioconductor 3.22. The installer reads
Imports, LinkingTo, Depends and Suggests from the exact archive DESCRIPTION and
enforces its minimum versions, including beachmat >=2.26.0, beachmat.hdf5 >=1.8.0,
DropletUtils >=1.30.0 and assorthead >=1.4.0. Native HDF5 replaces the old ondisc
runtime. System-package repositories resolve at build time; Bioconductor release
repositories can also receive updates. Preserve the actual installed versions,
architecture and image ID; these inputs do not promise bit-for-bit rebuilds.

`/opt/sceptre/source.json`, `packages.tsv`, `session-info.txt`,
`cran-snapshot.txt` and `bioconductor-version.txt` record the runtime. The exact source commit and archive checksum are bound by the bundled
`ARCHIVE-IDENTITY.json` receipt.

For deliberate local committed-source builds, `container/build.sh REPOSITORY
EXACT_COMMIT LOCAL_TAG` remains available, including the explicit
`--package-archive FILE --package-sha256 SHA256` pair. Such builds are distinct
from the bundled frozen archive and need their own evidence.

Run direct and distributed comparisons inside the built image before claiming
container qualification. Prepare the input bundle and environment lock in that
same runtime. A successful host test or historical container receipt does not
qualify this image. See [validation](../docs/validation.md).
