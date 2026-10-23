# Test coverage and acceptance

The native migration uses real public package calls in reference and distributed
comparison suites. Required checks cover complete result families and plans,
QC/assignments, fits and RNG; native HDF5 reopen/relocation; unit partitions,
missing/duplicate proposals; and Nextflow execution, failure and resume.

The nf-test file-coverage badge records its original measurement. A covered file
is not proof that every scientific branch or deployment platform is qualified.
Historical schema-3/ondisc suite counts, image IDs, hosted runs and scheduler
receipts do not transfer to the new package archive.

A fresh successful CI run must retain the exact archive checksum, image ID,
architecture, installed dependencies, R session, test outputs and task logs.
Host, Docker, hosted CI, Apptainer, HPC and full-screen scalability remain
separate evidence boundaries. See [CI](ci.md) and [qualification](validation.md)
for the current gates and scope.
