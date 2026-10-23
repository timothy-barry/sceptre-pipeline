# Schema-7 hosted CI preparation

Status: local preparation only. No new code, package archive, image or logs have
been published, and no hosted run has been dispatched for this migration.

## Exact proposed destination

Public repository: https://github.com/timothy-barry/sceptre-pipeline

New feature branch: `codex/native-schema7-hosted-ci`. Its base is the already
published PR-9 revision `1ec25d369915e602eaa28df0a657a28f8f740b6c`. This clean
branch copies only the native migration delta and its small validation receipts;
it does not publish the 47 intervening local integration commits or their
unrelated count-source/process-controller implementation. The original migration
worktree and ancestry are preserved. Runtime, numerical helpers and workflow
sources match the locally qualified migration, with report documentation updated.

The publication includes the full 3,311,229-byte unreleased package source archive
`tests/runtime/sceptre_0.99.0.tar.gz`, SHA256
`f41a8fb7e1bc10366e8efcc7a31644d4c8356bc4eca8adda9ca949c951de4fb4`,
source commit `1e4d5459ab229255694f9217d7cd4ed51a4bf1b8`, its provenance receipts,
pipeline source/tests/docs and bounded synthetic local-validation receipts.
No original real-screen count matrices or benchmark outputs are added.

## Existing runtime and hosted execution

The existing qualified local image is
`sha256:b51c1cdaef908f6386b3313bd787f5d46dcc7b3f08c5fe28b271d2e5c85cd6c9`,
tag `sceptre-pipeline:native7-f41a8fb7`, Linux ARM64 with R4.5.1/Bioc3.22.
Offline inspection confirmed the exact selected schema-7 source/archive identity.
Its unqualified local RepoDigest is not evidence of registry publication; a
read-only registry lookup could not retrieve that digest. No accessible registry
copy was established. The hosted workflow uses Ubuntu24.04 AMD64 and rebuilds
from the exact bundled archive; it needs no image upload or registry credentials.

The current public PR-9 branch still bundles package source78290757/archive40945603,
not schema7. Its prior green run does not test this migration:
https://github.com/timothy-barry/sceptre-pipeline/actions/runs/39370466627

After destination-specific publication approval, push only the new feature branch,
then dispatch `.github/workflows/ci.yml` on that exact branch/revision and record
the returned run URL and head SHA. Dispatch is supported by the workflow already
registered on the default branch. Feature-branch pushes alone do not trigger this
workflow (automatic push triggers are main/dev; PR triggers are also configured).
No PR creation, main update, merge, release or image publication is required.

Jobs: schema (Ubuntu24.04 AMD64,15min); scientific (Ubuntu24.04 AMD64,90min,
contents-read only). The latter builds the exact-source image, runs the installed
package suite, native admission/HDF5/report guards, mandatory nf-test cases,
direct/distributed and partition comparisons, demo, cached-resume/changed-source
and failed-worker tests. CI publishes diagnostic logs/receipts as GitHub Actions
artifacts retained14days. There are no deployment steps or repository secrets.

## Preflight and remaining uncertainty

Exact archive/corrupt-receipt guards, six resource tests, Slurm configuration,
failure-oracle controls and generation of four real matrix fixtures and module
fixtures in the qualified image passed during preparation. Every workflow input
exists; static native nf-test coverage inventory remains9/10. No workflow fix was
required. This preparation did not rerun the completed broad scientific matrices.

Cold AMD64 builds/dependency resolution, full nf-test execution and the90-minute
hosted time budget remain unverified. GitHub workflow listing/run reads work and
the account has repository WRITE access; reading repository Actions policies
returned403, so administrator-level Actions settings were not verified. No
permission/settings change was attempted.
