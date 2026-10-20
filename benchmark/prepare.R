#!/usr/bin/env Rscript
# Real targeted-screen inputs, shared by independent public R and pipeline runs.
args <- commandArgs(TRUE)
stopifnot(length(args) == 3L)
raw <- args[[1L]]; out <- args[[2L]]; n_pairs <- as.integer(args[[3L]])
source('bin/pipeline.R')
x <- readRDS(file.path(raw, 'grna_matrix_aligned.rds'))
y <- readRDS(file.path(raw, 'response_matrix.rds'))
metadata <- read.csv(file.path(raw, 'grna_target_data_frame.csv'), stringsAsFactors = FALSE)
stopifnot(identical(colnames(x), colnames(y)), identical(rownames(x), metadata$grna_id),
    identical(dim(x), c(110L,10932L)), identical(dim(y), c(93L,10932L)),
    !anyDuplicated(rownames(x)), !anyDuplicated(rownames(y)))
targets <- unique(metadata$grna_target[metadata$grna_target != 'non-targeting'])
stopifnot(length(targets) == 3L)
# Cycle targets fastest in original guide/response row order. The pilot is a
# different complete requested family, not a post-hoc subset of full-family p's.
family <- expand.grid(grna_target = targets, response_id = rownames(y),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
stopifnot(n_pairs >= 3L, n_pairs <= nrow(family))
family <- family[seq_len(n_pairs), , drop = FALSE]
extra <- data.frame(response_n_nonzero_full = as.numeric(Matrix::colSums(y > 0)),
    response_n_umis_full = as.numeric(Matrix::colSums(y)),
    grna_n_nonzero_full = as.numeric(Matrix::colSums(x > 0)),
    grna_n_umis_full = as.numeric(Matrix::colSums(x)), row.names = colnames(y))
formula <- stats::as.formula('~ log(response_n_nonzero_full + 1) + log(response_n_umis_full + 1) + log(grna_n_nonzero_full + 1) + log(grna_n_umis_full + 1)', env = baseenv())
config <- list(analysis = list(discovery_pairs = family, formula_object = formula,
    side = 'both', grna_integration_strategy = 'union', control_group = 'complement',
    resampling_mechanism = 'crt', resampling_approximation = 'no_approximation',
    multiple_testing_method = 'BH', multiple_testing_alpha = 0.1),
    assignment = list(method = 'thresholding', threshold = 5L),
    qc = list(response_n_umis_range = c(0,1), response_n_nonzero_range = c(0,1),
        p_mito_threshold = 1, n_nonzero_trt_thresh = 7L, n_nonzero_cntrl_thresh = 7L),
    calibration = list(), execution = list(output_amount = 2L))
object <- sceptre::import_data(y, x, metadata[, c('grna_id','grna_target')],
    moi = 'high', extra_covariates = extra)
dir.create(out, recursive = TRUE, showWarnings = FALSE)
saveRDS(config, file.path(out, 'config.rds'))
saveRDS(package_identity(), file.path(out, 'lock.rds'))
create_input(object, file.path(out, 'input'), config)
write.csv(family, file.path(out, 'requested-family.csv'), row.names = FALSE)
jsonlite::write_json(list(dataset = 'DC-TAP K562 high MOI GSE303901',
    scope = if (n_pairs == 279L) 'full targeted-screen 279-family' else 'bounded targeted-screen pilot family',
    cells = ncol(y), guides = nrow(x), responses = nrow(y), n_requested = n_pairs,
    full_family_size = 279L, targets = targets, original_count_classes = c(class(y),class(x)),
    combined_count_R_bytes = as.numeric(object.size(x) + object.size(y)),
    count_md5 = as.list(tools::md5sum(file.path(raw, c('grna_matrix_aligned.rds','response_matrix.rds','grna_target_data_frame.csv')))),
    import_identity = object@data@identity, covariates = names(extra),
    assignment = config$assignment, formula = deparse(formula), analysis = config$analysis[c('side','control_group','resampling_mechanism','resampling_approximation','multiple_testing_method','multiple_testing_alpha')]),
    file.path(out, 'dataset.json'), auto_unbox = TRUE, pretty = TRUE)
