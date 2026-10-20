#!/usr/bin/env bash
set -euo pipefail
repo_directory=$(cd "$(dirname "$0")/.." && pwd)
exec bash "$repo_directory/examples/launch_script.sh" "$@"
