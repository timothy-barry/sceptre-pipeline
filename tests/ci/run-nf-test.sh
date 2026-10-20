#!/usr/bin/env bash
# Use the identical container to prepare inputs and execute real nf-test cases.
set -euo pipefail
jar=${1:?Usage: tests/ci/run-nf-test.sh NF_TEST_JAR NEW_OUTPUT_DIRECTORY}
out=${2:?Usage: tests/ci/run-nf-test.sh NF_TEST_JAR NEW_OUTPUT_DIRECTORY}
: "${SCEPTRE_CONTAINER_IMAGE:?Build the checksum-qualified runtime first}"
mkdir -p "$out"
out=$(cd "$out" && pwd)
jar=$(cd "$(dirname "$jar")" && pwd)/$(basename "$jar")
export SCEPTRE_CI_ROOT="$PWD"
export SCEPTRE_CI_OUT="$out"
export SCEPTRE_MATRIX_FIXTURES="$out/matrix-fixtures"
export SCEPTRE_TEST_FIXTURE="$out/fixture"
export SCEPTRE_MODULE_FIXTURES="$out/module-fixtures"
export SCEPTRE_NFTEST_WORKDIR="$out/work"
# The distributed case must be discovered, not conditionally absent from CI.
export SCEPTRE_TEST_DISTRIBUTED=true
docker run --rm -v "$PWD:$PWD" -v "$out:$out" -w "$PWD" \
  "$SCEPTRE_CONTAINER_IMAGE" Rscript --vanilla tests/make-input.R "$SCEPTRE_TEST_FIXTURE"
docker run --rm -v "$PWD:$PWD" -v "$out:$out" -w "$PWD" \
  "$SCEPTRE_CONTAINER_IMAGE" Rscript --vanilla tests/ci/make-matrix-inputs.R "$SCEPTRE_MATRIX_FIXTURES"
docker run --rm -v "$PWD:$PWD" -v "$out:$out" -w "$PWD" \
  "$SCEPTRE_CONTAINER_IMAGE" Rscript --vanilla tests/ci/make-module-inputs.R "$SCEPTRE_MODULE_FIXTURES"
java -Xmx2g -jar "$jar" test --ci --profile test,docker \
  --tap "$out/nf-test.tap" --junitxml "$out/nf-test.xml" --log "$out/nf-test.log" \
  2>&1 | tee "$out/nf-test-console.log"
python3 tests/ci/require-nf-test.py "$out/nf-test.tap"
