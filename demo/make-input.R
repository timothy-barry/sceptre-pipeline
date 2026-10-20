#!/usr/bin/env Rscript
# Deterministic synthetic public inputs: no downloaded or individual-level data.
args <- commandArgs(TRUE)
if (length(args) != 1L) stop('Usage: Rscript demo/make-input.R NEW_DIRECTORY')
source('bin/pipeline.R')
if (dir.exists(args[1])) stop('Demo input directory already exists.')
dir.create(args[1], recursive = TRUE)
set.seed(20261019L)
n <- 320L
ids <- c('a1', 'a2', 'b1', 'b2', 'nt1', 'nt2', 'nt3', 'nt4')
cells <- paste0('synthetic_cell_', seq_len(n))
assigned <- rep(seq_along(ids), length.out = n)
g <- matrix(0, length(ids), n, dimnames = list(ids, cells))
g[cbind(assigned, seq_len(n))] <- 50
responses <- paste0('RNA_', seq_len(8L))
y <- matrix(rpois(length(responses) * n, 3), length(responses), n, dimnames = list(responses, cells))
y[1L, assigned %in% 1:2] <- y[1L, assigned %in% 1:2] + 20
y[2L, assigned %in% 3:4] <- 1L
y[4L, ] <- 0L
metadata <- data.frame(grna_id = ids, grna_target = c('TargetA', 'TargetA', 'TargetB', 'TargetB', rep('non-targeting', 4L)))
config <- list(analysis = list(
    discovery_pairs = data.frame(grna_target = c('TargetB', 'TargetA', 'TargetA', 'TargetB', 'TargetA'), response_id = responses[c(5, 3, 1, 2, 4)]),
    positive_control_pairs = data.frame(grna_target = c('TargetA', 'TargetB'), response_id = responses[1:2]),
    formula_object = stats::as.formula('~ batch + z', env = baseenv()), side = 'both',
    grna_integration_strategy = 'union', control_group = 'nt_cells', resampling_mechanism = 'permutations',
    resampling_approximation = 'skew_normal', multiple_testing_method = 'BH', multiple_testing_alpha = 0.1),
    assignment = list(method = 'maximum'),
    qc = list(response_n_umis_range = c(0, 1), response_n_nonzero_range = c(0, 1),
        n_nonzero_trt_thresh = 7L, n_nonzero_cntrl_thresh = 7L, additional_cells_to_remove = c(2L, 17L, 49L, 103L, 158L)),
    calibration = list(n_calibration_pairs = 8L, calibration_group_size = 2L), execution = list(output_amount = 2L))
object <- sceptre::import_data(Matrix::Matrix(y, sparse = TRUE), Matrix::Matrix(g, sparse = TRUE), metadata,
    moi = 'low', extra_covariates = data.frame(batch = factor(rep(c('a', 'b', 'b', 'a', 'b'), length.out = n)),
        z = sin(seq_len(n)), row.names = cells))
saveRDS(config, file.path(args[1], 'config.rds'))
saveRDS(package_identity(), file.path(args[1], 'lock.rds'))
create_input(object, file.path(args[1], 'input'), config)
writeLines(c('Synthetic demonstration only; no real participant or experimental data.',
    'Generation seed: 20261019; analysis seed: 271828.',
    '320 cells, 8 response features, 8 guides, two constructed effects, one all-zero failed-QC response.'), file.path(args[1], 'README.txt'))
