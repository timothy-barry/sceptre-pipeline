#!/usr/bin/env Rscript
# Fixed representative systems fixture, not a full-screen scientific family.
# Read bounded raw CSR rows, retain original full-library cell covariates.
args <- commandArgs(TRUE)
stopifnot(length(args) == 3L)
raw <- args[1]
out <- args[2]
C <- as.integer(args[3])
source("bin/pipeline.R")
original <- readRDS(file.path(
  raw,
  "sceptre-pipeline/sceptre_object_initial.rds"
))
cov <- attr(original, "covariate_data_frame")
stopifnot(nrow(cov) == 207324L, C %in% c(2000L, 8000L, 16000L))
cells <- unique(as.integer(round(seq(1, nrow(cov), length.out = C))))
metadata <- read.csv(file.path(raw, "sceptre/grna_target_data_frame.csv"))
genes <- read.csv(file.path(raw, "gene_summary_stats.csv"))
response_ids <- genes$gene[order(
  -genes$gene_n_nonzero,
  seq_len(nrow(genes))
)][seq_len(8L)]
targets <- unique(metadata$grna_target[
  metadata$grna_target != "non-targeting"
])[seq_len(3L)]
metadata <- metadata[
  metadata$grna_target %in% targets,
  c("grna_id", "grna_target")
]
stopifnot(nrow(metadata) == 6L)
read_rows <- function(path, ids) {
  dimensions <- rhdf5::h5read(path, "dimension")
  names <- rhdf5::h5read(path, "feature_ids")
  stopifnot(
    dimensions[2L] == nrow(cov),
    length(names) == dimensions[1L],
    !anyDuplicated(names)
  )
  rows <- match(ids, names)
  stopifnot(!anyNA(rows))
  ptr <- rhdf5::h5read(path, "ptr")
  stopifnot(length(ptr) == dimensions[1L] + 1L, all(diff(ptr) >= 0))
  ii <- jj <- xx <- list()
  for (k in seq_along(rows)) {
    r <- rows[k]
    start <- ptr[r] + 1
    end <- ptr[r + 1L]
    if (start > end) {
      next
    }
    at <- seq.int(start, end)
    j <- rhdf5::h5read(path, "j", index = list(at)) + 1L
    x <- rhdf5::h5read(path, "x", index = list(at))
    stopifnot(all(j >= 1L & j <= nrow(cov)), !anyDuplicated(j))
    local <- match(j, cells)
    keep <- !is.na(local)
    ii[[k]] <- rep.int(k, sum(keep))
    jj[[k]] <- local[keep]
    xx[[k]] <- x[keep]
  }
  Matrix::sparseMatrix(
    i = unlist(ii),
    j = unlist(jj),
    x = unlist(xx),
    dims = c(length(ids), length(cells)),
    dimnames = list(ids, rownames(cov)[cells])
  )
}
y <- read_rows(file.path(raw, "sceptre-pipeline/response.odm"), response_ids)
x <- read_rows(file.path(raw, "sceptre-pipeline/grna.odm"), metadata$grna_id)
extra <- cov[
  cells,
  c(
    "response_n_nonzero",
    "response_n_umis",
    "grna_n_nonzero",
    "grna_n_umis",
    "prep_batch"
  )
]
names(extra)[1:4] <- paste0(names(extra)[1:4], "_full")
family <- expand.grid(
  grna_target = targets,
  response_id = response_ids,
  KEEP.OUT.ATTRS = FALSE,
  stringsAsFactors = FALSE
)
config <- list(
  analysis = list(
    discovery_pairs = family,
    formula_object = stats::as.formula(
      "~ log(response_n_nonzero_full + 1) + log(response_n_umis_full + 1) + log(grna_n_nonzero_full + 1) + log(grna_n_umis_full + 1) + prep_batch",
      env = baseenv()
    ),
    side = "both",
    grna_integration_strategy = "union",
    control_group = "complement",
    resampling_mechanism = "crt",
    resampling_approximation = "no_approximation",
    multiple_testing_method = "BH",
    multiple_testing_alpha = .1
  ),
  assignment = list(method = "thresholding", threshold = 5L),
  qc = list(
    response_n_umis_range = c(0, 1),
    response_n_nonzero_range = c(0, 1),
    p_mito_threshold = 1,
    n_nonzero_trt_thresh = 7L,
    n_nonzero_cntrl_thresh = 7L
  ),
  execution = list(output_amount = 2L)
)
object <- sceptre::import_data(
  y,
  x,
  metadata,
  moi = "high",
  extra_covariates = extra
)
dir.create(out, recursive = TRUE)
saveRDS(config, file.path(out, "config.rds"))
saveRDS(package_identity(), file.path(out, "lock.rds"))
create_input(object, file.path(out, "input"), config)
write.csv(family, file.path(out, "requested-family.csv"), row.names = FALSE)
write.csv(
  data.frame(original_cell_index = cells, cell_id = rownames(extra)),
  file.path(out, "cells.csv"),
  row.names = FALSE
)
jsonlite::write_json(
  list(
    dataset = "Gasperini",
    cells = C,
    responses = nrow(y),
    guides = nrow(x),
    requested = nrow(family),
    family_sha256 = hash_value(family),
    covariates_sha256 = hash_value(extra),
    full_library_covariates_preserved = identical(
      unname(as.matrix(extra[, 1:4])),
      unname(as.matrix(cov[
        cells,
        c(
          "response_n_nonzero",
          "response_n_umis",
          "grna_n_nonzero",
          "grna_n_umis"
        )
      ]))
    ),
    y_sha256 = hash_value(y),
    x_sha256 = hash_value(x),
    cell_alignment_authority = "Original paired stores and closed-state row order, matched dimensions; no independent store cell-barcode array or full content scan",
    source_metadata_md5 = as.list(tools::md5sum(file.path(
      raw,
      c(
        "sceptre-pipeline/sceptre_object_initial.rds",
        "sceptre/grna_target_data_frame.csv",
        "gene_summary_stats.csv"
      )
    ))),
    scope = "Fixed evenly spaced original cells; eight most detected responses; first three targets; complete declared 24-request subset; no biological validation"
  ),
  file.path(out, "dataset.json"),
  auto_unbox = TRUE,
  pretty = TRUE
)
