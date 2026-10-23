# SCEPTRE pipeline

[![Integration branch checks](https://github.com/timothy-barry/sceptre-pipeline/actions/workflows/ci.yml/badge.svg?branch=codex%2Fovernight-publication-pipeline)](https://github.com/timothy-barry/sceptre-pipeline/actions/workflows/ci.yml?query=branch%3Acodex%2Fovernight-publication-pipeline)
[![Pipeline version](docs/badges/version.svg)](nextflow.config)

The checks badge tracks the historical integration branch; it does not certify
this schema-7 migration.

Nextflow DSL2 execution of the native schema-7 SCEPTRE workflow, with certified process
handoffs and complete-family statistical results. This implementation targets the selected native schema-7 package archive; see [qualification](docs/validation.md) for the
exact tested package and limits.

The scientific package owns assignments, QC, fit reuse, resampling, integration,
and multiplicity. The pipeline owns scheduling, artifact manifests, resource
configuration and publication. Calibration, power and discovery can be selected
independently after QC.

Start with the [documentation site](website/README.md), [one-command demo](docs/demo.md),
[usage](docs/usage.md), and [scientific report](docs/report.md).
[Slurm & Apptainer](docs/hpc.md), [Slurm arrays](docs/array-validation.md), [CI](docs/ci.md),
[test coverage](docs/coverage.md), [architecture](docs/architecture.md) and
[outputs](docs/outputs.md) have separate guides.
This project applies nf-core engineering principles; it is not a formally
published nf-core pipeline.

## Try a complete analysis

With Docker, Python3, Nextflow25.10.4+ and Java17+ installed:

```bash
./demo/demo.sh "$PWD/sceptre-demo"
```

This builds the pinned package runtime, creates deterministic synthetic inputs,
runs real assignment/QC/calibration/power/discovery, and produces an editable
[scientific HTML report](docs/report.md). No manual RDS preparation is needed.
The demo is distinct from the [real-screen benchmark protocol](docs/benchmark.md).

Build and preview the local documentation site with:

```bash
python3 website/build.py
python3 website/preview.py --port 8095
```

## Quick local qualification

Use an isolated library containing the exact qualified package; the ordinary
user library may contain an incompatible release.

```bash
export R_LIBS=/absolute/path/to/isolated/library
Rscript tests/direct-comparison.R /tmp/sceptre-direct-new
bash tests/run-nextflow.sh /tmp/sceptre-nextflow-new
```

Nextflow 25.10.4+, Java 17+, R 4.5+, the pipeline dependency `jsonlite`, and pinned `nf-schema@2.6.1` are required.
The plugin needs network access on first installation; `NXF_OFFLINE=true` can be
used after it is installed. The runtime lock records the actual R version,
package implementation and dependency versions.

## License

GNU General Public License v3.0. See [LICENSE](LICENSE).
