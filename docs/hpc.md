> Publication scope: historical validation below refers to the explicitly named original source/runtime. Detailed local evidence and raster previews are not distributed in this review branch. This publication commit has its own pending qualification; see the publication scope document.

# Slurm and Apptainer scientific qualification

The portable harness in `hpc/` runs one selected synthetic scientific case through
actual Nextflow processes, then compares the saved artifacts with uninterrupted
public SCEPTRE R calls inside **the same SIF**. This is a qualification harness,
not a benchmark or a default deployment policy. Cluster scientific qualification
is pending until a terminal receipt is recorded; earlier Betty array receipts are
scheduler-only evidence and do not establish scientific AMD64 compatibility.
The cleaned runtime has a successful local AMD64 build and identity check (historical evidence retained locally).
Its image has not been transferred or converted to SIF; no scientific Slurm run
is claimed.

## Runtime and shared paths

Build the maintained `container/Dockerfile` for the compute-node architecture from
`tests/runtime/source.json`. Preserve the OCI image/archive identities and source
receipt. A preconverted SIF can be built from a Docker-save archive using
[Apptainer's docker-archive bootstrap](https://apptainer.org/docs/user/1.4/appendix.html).
Record the resulting SIF SHA256 independently of the OCI digest. The harness reuses
that local SIF; it does not exercise Nextflow registry pulling or OCI-to-SIF
conversion. See [Nextflow container guidance](https://docs.seqera.io/nextflow/container).

The checkout, SIF, external site config, run directory, count backing files and
Nextflow work/cache directories must be readable at the same absolute shared
paths on the launch host and compute nodes. Backed descriptors depend on those
paths. Load the site's initialized Slurm and Apptainer environment. Stage the
pinned `nf-schema@2.6.1` plugin in the chosen `NXF_HOME` before an offline run;
retain that runtime/cache rather than changing the package environment between
input generation and execution. Use Nextflow25.10.4 for the recorded contract.

Copy `hpc/site.config.example` to an external shared file and replace every
`YOUR_*` placeholder with site-approved values. Partition/account/QoS and resource
policy belong there. The Betty qualification plan uses one CPU, 5632MB per task,
and two minutes per scientific task; that policy is site-specific and is not a
portable default. At most two tasks should run concurrently for this small test. Set
`apptainer.runOptions = '--cleanenv'` in that external config; the harness checks
it and uses `--cleanenv` for direct/preflight commands as well, preventing host
`R_LIBS` settings from contaminating the SIF. Run the harness itself inside a
bounded Slurm driver allocation so fixture generation and the direct R comparison
also execute on a compute node; the child Nextflow jobs have their own limits.

## Prepare one versioned x86_64 image

On the build machine, from this checkout, use the same maintained Dockerfile and
qualified package archive as CI. The exact source is selected by
`tests/runtime/source.json`; image tags and SIF filenames are labels. The output
context must be new:

```bash
python3 container/prepare-context.py --source-manifest tests/runtime/source.json \
  --output /tmp/sceptre-amd64-context
docker build --platform linux/amd64 --progress plain \
  --iidfile /tmp/sceptre-amd64-image-id.txt \
  --tag sceptre-pipeline:qualified-amd64 /tmp/sceptre-amd64-context
docker save --output sceptre-amd64.tar "$(cat /tmp/sceptre-amd64-image-id.txt)"
shasum -a 256 sceptre-amd64.tar > sceptre-amd64.tar.sha256
```

Transfer the archive and its SHA256 to the cluster's shared runtime directory.
No registry push is needed. Inside a site-approved bounded conversion allocation:

```bash
sha256sum -c sceptre-amd64.tar.sha256
apptainer build --mksquashfs-args '-processors 1' \
  sceptre-qualified-amd64.sif docker-archive:/shared/runtime/sceptre-amd64.tar
sha256sum sceptre-qualified-amd64.sif
```

Retain the resulting immutable SIF and checksum for subsequent clean/resumed runs.
The archive's OCI image ID, source receipt and SIF SHA are different identities;
record all three. Do not replace image bytes behind an existing run's path.
Choose the actual target architecture when preparing a different cluster.

## One selected run

`preflight.sh` checks launch prerequisites, SIF bytes and the bundled scientific
archive receipt without submitting jobs:

```bash
bash hpc/preflight.sh /shared/sceptre-qualified-amd64.sif SIF_SHA256 /shared/preflight
```

`qualify.sh` submits real jobs. Use a fresh shared directory for each invocation:

```bash
bash hpc/qualify.sh \
  --image /shared/sceptre-qualified-amd64.sif --sha256 SIF_SHA256 \
  --site-config /shared/site.config --run-dir /shared/new-qualification \
  --case low_nt_permutation --mode distributed --n-work-units 2 \
  --resume --worker-failure
```

The native `--container_image_sha256` option verifies the absolute SIF before
Nextflow tasks and binds its checksum in run identity. Docker/OCI executions
retain their immutable-digest requirement.

Choose one case per invocation:

| Case | Supported harness mode | Scientific branch |
|---|---|---|
| `low_nt_permutation` | `reference` or `distributed` | Low MOI, non-targeting controls, permutations |
| `high_empirical_crt` | `distributed` (or explicit reference diagnostic) | High MOI, complementary controls, empirical CRT |
| `low_nt_permutation_backed` | `reference` or `distributed` | Real ondisc-backed permutations; backing directory passed explicitly |

Default analyses are calibration, power and discovery. `--analyses discovery`
selects discovery directly after QC. Input, runtime lock and fixture configuration
are generated inside the SIF. The harness sets one initial analysis seed271828;
package draw budgets and scientific parameters are not overridden. The shared R
oracle checks exact public tables (including significance, order and failed-QC
rows), realized plans/budgets, fits, assignments, ordered retained cells, design,
pair-QC tables/metrics, family presence and saved RNG states.

`--resume` reruns runtime validation while requiring every scientific task and
export to be cached, then repeats the direct comparison. `--worker-failure`
performs a separate distributed discovery invocation using the existing test-only
pre-worker exit42 injection; it requires no collector and no completed discovery
publication. This failure check does not claim post-computation retry coverage;
that separate contract is exercised by the automatic scheduling nf-tests.

## Evidence and limits

The run directory retains preflight/runtime identity, SIF checksum, launch logs,
complete traces, direct-comparison logs, optional resume/failure logs, and a
terminal `qualification.json`. Production/harness/oracle source hashes are taken
before and after execution and must match. A missing terminal receipt is not a
successful qualification. Preserve compute-node accounting and SIF-conversion
receipts alongside this directory when recording a site qualification.

A successful small synthetic run establishes the selected branch in that exact
runtime and site configuration. It does not qualify full-size screens, all
statistical settings, other architectures/sites, performance scaling, or an image
rebuild. The scientific report is a saved-value presentation; it does not add new
inference. No cluster scientific success is asserted by adding these scripts.
