#!/usr/bin/env Rscript
# Executes actual pipeline state/worker/collector adapters serially. No Nextflow claim.
args <- commandArgs(TRUE)
stopifnot(length(args) == 3L)
fixture <- args[1]
out <- args[2]
seed <- as.integer(args[3])
source("bin/pipeline.R")
source("bin/distributed.R")
config <- readRDS(file.path(fixture, "config.rds"))
lock <- readRDS(file.path(fixture, "lock.rds"))
input <- file.path(fixture, "input")
timings <- list()
phase <- function(name, expr) {
  t <- proc.time()
  v <- force(expr)
  timings[[name]] <<- as.list(proc.time() - t)
  v
}
for (stage in c("parameters", "assignment", "qc")) {
  state <- file.path(out, stage, "state")
  dir.create(dirname(state), recursive = TRUE, showWarnings = FALSE)
  phase(stage, run_stage(config, input, state, stage, seed, identity = lock))
  input <- state
}
plan <- file.path(out, "plan")
execution <- phase(
  "prepare_execution",
  prepare_distributed(config, input, plan, "discovery", seed, 3L, NULL, lock)
)
files <- character()
for (unit in rev(execution$units)) {
  path <- file.path(out, paste0(unit$id, ".rds"))
  phase(
    unit$id,
    run_distributed_unit(
      config,
      input,
      plan,
      path,
      "discovery",
      seed,
      unit$id,
      NULL,
      lock
    )
  )
  files <- c(files, path)
}
dir.create(file.path(out, "discovery"), recursive = TRUE, showWarnings = FALSE)
phase(
  "collect",
  collect_distributed(
    config,
    input,
    plan,
    files,
    file.path(out, "discovery", "state"),
    "discovery",
    seed,
    NULL,
    lock
  )
)
jsonlite::write_json(
  timings,
  file.path(out, "phase-timings.json"),
  auto_unbox = TRUE,
  pretty = TRUE
)
