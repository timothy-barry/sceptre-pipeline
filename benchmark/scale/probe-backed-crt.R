#!/usr/bin/env Rscript
# EXPERIMENT ONLY: internal row-reading CRT kernel, not public backed support.
# Never disables the production unsupported guard and never changes budgets.
args <- commandArgs(TRUE)
stopifnot(length(args) == 1L)
out <- args[1]
dir.create(out, recursive = TRUE)
source("tests/fixture.R")
private <- function(n) getFromNamespace(n, "sceptre")
f <- pipeline_fixture(
  moi = "high",
  control = "complement",
  mechanism = "crt",
  approximation = "no_approximation"
)
y <- sceptre::get_response_matrix(f$object)
x <- sceptre::get_grna_matrix(f$object)
cols <- rep(seq_len(ncol(y)), 8L)
ids <- paste0("cell_", seq_along(cols))
y <- y[, cols]
x <- x[, cols]
colnames(y) <- colnames(x) <- ids
extra <- sceptre::get_cell_covariates(f$object)[cols, c("batch", "z")]
rownames(extra) <- ids
metadata <- data.frame(
  grna_id = rownames(x),
  grna_target = c("A", "A", "B", "B", rep("non-targeting", 4L))
)
observations <- list()
guard_rejected <- FALSE
for (backed in c(FALSE, TRUE)) {
  path <- file.path(out, "backing")
  if (backed) {
    dir.create(path)
  }
  object <- sceptre::import_data(
    y,
    x,
    metadata,
    moi = "high",
    extra_covariates = extra,
    use_ondisc = backed,
    directory_to_write = if (backed) path else NULL
  )
  for (stage in c("analysis", "assignment", "qc")) {
    fun <- switch(
      stage,
      analysis = sceptre::set_analysis_parameters,
      assignment = sceptre::assign_grnas,
      qc = sceptre::run_qc
    )
    options <- f$config[[stage]]
    if (stage == "assignment") {
      options$parallel <- FALSE
      options$print_progress <- FALSE
    }
    object <- do.call(fun, c(list(object), options))
  }
  if (backed) {
    error <- tryCatch(
      sceptre::prepare_execution(object, "run_discovery_analysis"),
      error = function(e) e
    )
    guard_rejected <- inherits(error, "error") &&
      grepl("Backed CRT", conditionMessage(error))
    stopifnot(guard_rejected)
  }
  plan <- private("prepare_execution_plan")(
    object,
    "run_discovery_analysis",
    NULL,
    NULL
  )
  context <- private("execution_full_context")(object, plan)
  controls <- list(
    output_amount = 3L,
    print_progress = FALSE,
    parallel = FALSE,
    n_processors = 1L,
    log_dir = tempdir(),
    work_keys = NULL
  )
  set.seed(9271)
  result <- private("run_crt_analysis")(context, controls)
  kernel_rng <- .Random.seed
  set.seed(9271)
  direct <- sceptre::run_discovery_analysis(
    object,
    parallel = FALSE,
    print_progress = FALSE,
    output_amount = 3L
  )
  direct_rng <- .Random.seed
  observations[[if (backed) "backed" else "memory"]] <- list(
    raw = as.data.frame(result$result),
    direct_table = as.data.frame(sceptre::get_result(
      direct,
      "run_discovery_analysis"
    )),
    direct_rng = direct_rng,
    rng = kernel_rng,
    budgets = c(plan@B1, plan@B2, plan@B3)
  )
}
stopifnot(identical(observations$memory, observations$backed))
jsonlite::write_json(
  list(
    status = "internal_kernel_and_tiny_direct_exact_pass",
    public_distributed_guard_still_rejected = guard_rejected,
    cells = ncol(y),
    requested = 5L,
    raw_rows = nrow(observations$memory$raw),
    budgets = observations$memory$budgets,
    limits = "Synthetic repeated fixture; direct table/raw kernel only; no distributed backed execution, certificate/save-reopen/relocation/full-screen or corruption qualification"
  ),
  file.path(out, "probe.json"),
  auto_unbox = TRUE,
  pretty = TRUE
)
