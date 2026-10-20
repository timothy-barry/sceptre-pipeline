#!/usr/bin/env bash
# No registry push. Build only from an exact committed SCEPTRE source tree.
set -euo pipefail
if [[ $# -lt 2 ]]; then
    echo 'Usage: container/build.sh SCEPTRE_REPOSITORY REVISION [LOCAL_IMAGE_TAG] [--package-archive FILE --package-sha256 SHA256]' >&2
    exit 2
fi
here=$(cd "$(dirname "$0")" && pwd)
commit=$(git -C "$1" rev-parse "$2^{commit}")
repository=$1
shift 2
tag=sceptre-pipeline:${commit:0:12}
if [[ $# -gt 0 && "$1" != --* ]]; then
    tag=$1
    shift
fi
context="$here/.build/$commit"
python3 "$here/prepare-context.py" "$repository" "$commit" --output "$context" "$@"
docker version --format '{{json .}}' > "$context/docker-version.json"
docker build --progress plain --iidfile "$context/image-id" --tag "$tag" "$context"
docker image inspect "$tag" > "$context/image-inspect.json"
printf 'Built %s\nImmutable local image ID: %s\nProvenance: %s\n' "$tag" "$(cat "$context/image-id")" "$context/source.json"
