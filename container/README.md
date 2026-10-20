# Scientific runtime

The Docker recipe installs SCEPTRE from a **committed local source revision**, never a moving Git branch or host R library. The generated context includes only a `git archive` package source, public dependency archives and build instructions. It never copies `.git`, credentials or user R configuration. No image is published by these tools.

```bash
container/build.sh /absolute/path/to/sceptre EXACT_COMMIT sceptre-pipeline:qualified
```

To use an owner-qualified `R CMD build` archive verbatim, supply both options after the explicit image tag:

```bash
container/build.sh /absolute/path/to/sceptre EXACT_COMMIT sceptre-pipeline:qualified \
  --package-archive /absolute/path/to/sceptre_0.99.0.tar.gz --package-sha256 EXACT_SHA256
```

The supplied SHA256 is checked before context creation; Docker checks those same bytes before installation. The source manifest records `archive_kind` (`R_CMD_build` or `git_archive`), archive SHA256 and the separately resolved committed revision. The caller is responsible for supplying the owner-certified archive/revision pair. Supported layouts are the flat Git archive and the `sceptre/` root produced by `R CMD build`.

The script deliberately refuses to overwrite an existing context. Choose a new revision or preserve/rename the old context before repeating preparation. `container/.build/` and build logs are ignored. Use the returned immutable `sha256:...` **local image ID** in Nextflow's `--container_image`; tags can be reassigned. A local image ID is not a registry manifest digest and cannot be pulled on another host. Transfer with `docker save` / `docker load`, or publish separately with explicit authorization and then use its registry digest.

## Pins and provenance

* R 4.5.1: `rocker/r-ver` multi-architecture index digest `sha256:03b023fbf7b1b24ac1bb8b2ac5fd7e15a767e67b40ff50c155e328110981c2aa` (resolved 2026-10-19; amd64 and arm64).
* CRAN sources: fixed Posit CRAN snapshot `2025-07-01`. Base R provides Matrix. No unpinned system-package installation occurs in this recipe.
* Optional ondisc 1.3.1: commit `58e851a95cfd381b316ac40ed4490e569bd40e2f`, source archive SHA256 checked by context preparation and Docker.
* zlib 1.3.2: official source and published SHA256 from [zlib.net](https://zlib.net/), built with position-independent static code for Rhdf5lib.
* Rhdf5lib 1.30.0: Bioconductor 3.21 versioned source with a fixed SHA256.
* The exact SCEPTRE commit and source archive SHA256 are recorded in `/opt/sceptre/source.json`. Installed package versions and runtime appear in `/opt/sceptre/packages.tsv` and `session-info.txt`. Docker validates every copied source archive's checksum before installation.

Set `--build-arg WITH_ONDISC=false` on `docker build` for an explicitly in-memory-only runtime; provenance must retain this build argument. Both public dependency archives are still copied and checked. The default installs ondisc and fails if it cannot compile. The pipeline supports backed **permutation** execution only; package capability checks remain authoritative. Source snapshots and digests freeze inputs, but do not promise bit-for-bit image rebuilds or identical floating-point results across CPU architectures. Keep the resulting image ID and architecture with test evidence.

## Same-runtime validation

Run from the pipeline repository; outputs must be placed in the mounted workspace (not an unmounted host temporary directory):

```bash
IMAGE=sha256:THE_BUILT_LOCAL_IMAGE_ID
docker run --rm -v "$PWD:/work" -w /work -e REQUIRE_ONDISC=true \
  "$IMAGE" Rscript tests/direct-comparison.R /work/container/.build/direct-comparison
```

This invokes real native R computations and compares direct public-API execution with pipeline stage execution in the **same container runtime**, including save/reopen and relocation when the optional backend is available. A host R test does not qualify this image. Follow with the Docker-profile Nextflow integration tests documented at repository root. Never prepare the initial RDS/environment lock with a different host runtime and then assume it is valid in the container.

The implementation follows [nf-core's component principles](https://nf-co.re/docs/specifications/components/overview) of versioned tool environments and explicit version provenance, with a local source build because this package revision has not been released. It uses [Rocker's digest recommendation](https://rocker-project.org/use/reproducibility.html) and [versioned images](https://rocker-project.org/images/versioned/). This is not formal nf-core publication or certification. Docker ARM64 qualification does not establish Docker AMD64, Apptainer, cluster or cloud compatibility.

## Automatic PR/push CI source

The automatic workflow uses the complete qualified source archive committed in
`tests/runtime`, so it does not require an unpublished remote SCEPTRE commit or
a prepublished container. Prepare that same context with:

```bash
python3 container/prepare-context.py --source-manifest tests/runtime/source.json \
  --output /absolute/new/context
```

The archive SHA256 is verified before any download. `--verify-only` checks the
receipt without downloads or writes. The generated metadata explicitly records
`source_resolution: qualified_archive_receipt`; the source commit is the owner's
provenance declaration, and the exact archive checksum binds the installed bytes.
The local Git interface above instead records `source_resolution: local_git_commit`.
See `docs/ci.md` for automated scientific tests, pins, reports and hosted-platform
qualification limits.
