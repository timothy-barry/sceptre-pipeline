# HPC deployment

Slurm and Apptainer are deployment targets requiring qualification of the exact
native package archive, image/SIF, architecture and inputs. Historical
schema-3/ondisc runs do not qualify the migrated pipeline.

Build the chosen native package runtime, preserve its immutable image identity,
then create the input bundle and environment lock inside the same runtime.
Stage native HDF5 counts with `bin/stage_backing.R` into a shared immutable
directory visible on every compute node. See [usage](usage.md) for the exact
backing-directory and distributed execution interface.

Supply institutional account, partition, QoS, memory policy and filesystem mounts
through a site configuration; credentials do not belong in the repository.
Only distributed workers use the opt-in Slurm array policy. A configuration
check or scheduler-only smoke test does not establish scientific correctness.

Before production use, record direct/distributed numerical comparisons at equal
realized budgets, native HDF5 reopening and relocation, retry/missing-worker
rejection, resume, immutable runtime identity and scheduler evidence. Each
architecture and container system is a separate target. Current acceptance
status is in [qualification](validation.md).
