#!/usr/bin/env Rscript
# Actual scheduler outputs versus uninterrupted direct public R in the same image.
# Reuse the strict expected-family/design/pairQC/metrics/table/plan/fit/RNG checker.
source("tests/ci/compare-workflow.R")
args <- commandArgs(TRUE)
if (length(args) != 3L) stop("Usage: compare-nextflow.R FIXTURE RESULTS SEED")
compare_saved_workflow(args[1], args[2], args[3], "analysis", "calibration,power,discovery", "none")
message("PASS actual Nextflow vs same-runtime uninterrupted public R: exact complete tables/global plans/budgets/assignments/QC/fits/RNG")
