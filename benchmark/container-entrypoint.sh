#!/bin/bash
# Runs only benchmark containers; records the container's kernel high-water mark.
# This wraps the unchanged Nextflow task command and enforces a hard wall limit.
set -euo pipefail
date +%s.%N > .benchmark-start
cat /sys/fs/cgroup/memory.max > .benchmark-memory.max
finish() {
    local status=$?
    date +%s.%N > .benchmark-end
    cat /sys/fs/cgroup/memory.peak > .benchmark-memory.peak
    cat /sys/fs/cgroup/cpu.stat > .benchmark-cpu.stat
    exit "$status"
}
trap finish EXIT
timeout --kill-after=10s 900s "$@"
