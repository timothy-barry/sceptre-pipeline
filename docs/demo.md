# One-command scientific demo

From a clean checkout in a supported environment:

```bash
./demo/demo.sh "$PWD/sceptre-demo"
```

Install Docker (daemon running), Python 3, and a pipeline-compatible Nextflow
with Java first (the default profile requests up to 8 GB for scientific tasks); see the [usage and runtime guide](usage.md).
The command builds the pinned container using the bundled frozen SCEPTRE
archive receipt in `tests/runtime/source.json`, creates synthetic counts,
configuration and the environment lock **inside that image**, and runs real
assignment, QC, calibration, positive-control and discovery analyses through
Nextflow. No manually prepared RDS is required. The first build downloads public
dependencies from the configured CRAN snapshot and Bioconductor release and may take several minutes. A new output directory is
required; existing data are never overwritten.

To reuse an already built exact image without rebuilding:

```bash
SCEPTRE_DEMO_IMAGE=sha256:YOUR_IMMUTABLE_LOCAL_IMAGE_ID ./demo/demo.sh "$PWD/another-demo"
```

For this small fixture on a resource-limited machine or CI runner, use
`SCEPTRE_DEMO_PROFILE=test,docker` to select the existing small-resource profile;
it changes execution resources, not scientific settings.

A mutable image tag is rejected; reused images must carry the same frozen
package archive receipt. Local image IDs cannot be pulled on another
machine; build locally or transfer a qualified image explicitly. The default
build uses the same source-manifest interface as CI, without requiring an
unpublished package Git revision to exist remotely. Architecture-specific image
builds and results still require qualification on that architecture.

## What is run

The committed `demo/make-input.R` deterministically generates 320 synthetic
cells, eight response features and eight guides. It includes two constructed
effects and one all-zero response to demonstrate failed-QC requests. There is no
participant-level or real experimental data. Input generation uses seed
20261019; the analysis begins at seed 271828 and hands RNG state across pipeline
stages. It uses low-MOI maximum assignment, non-targeting controls, permutation
tests, skew-normal approximation, union integration and BH correction at 0.1.
The script requests eight calibration pairs and two positive-control pairs.
These are demonstration choices, not recommended defaults for a real study.

The scientific object, requested configuration, runtime lock and source/image
receipt are retained. Determinism means the same inputs/settings/seeds in the
same pinned runtime; timestamps, Nextflow session IDs and execution timings are
expected to differ. Cross-architecture bitwise equivalence is not promised.

## Open the results

- `sceptre-demo/results/exports/scientific-report/report.html`: scientific results.
- The same directory: frozen report data, CSV tables, figures, editable R renderer
  and optional Quarto source; see [report customization](report.md).
- `sceptre-demo/results/pipeline_info/report.html`: Nextflow execution report.
- `sceptre-demo/demo-receipt.json`: source receipt, image and generator identity.
- `sceptre-demo/results/{qc,calibration,power,discovery}`: certified stage artifacts.

The scientific report and Nextflow report answer different questions. Discovery
associations in a synthetic screen are not biological-mechanism claims.
Calibration is optional for other runs and is not a discovery prerequisite.
The wrapper reports an unsuccessful rendering step separately even when science
has completed; the saved scientific artifacts remain usable.

## Executable acceptance and recovery walkthrough

After building an exact image, run `demo/acceptance.sh NEW_DIRECTORY` with
`SCEPTRE_DEMO_IMAGE=sha256:...`. It runs the public demo, validates its saved
public results, reopens saved state, rerenders a relocated report without loading
SCEPTRE, checks cached resume, induces a transient task failure and recovers it
with an identical resume. It retains commands/logs and asserts that failed
science was not published. See [recovery instructions](recovery.md). This is a
small synthetic acceptance check, not statistical validation or a scale claim.
