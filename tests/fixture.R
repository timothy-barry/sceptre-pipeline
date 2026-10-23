# Small deterministic screens exercise native tests without external data.
# Fixtures deliberately include failed-QC requests and two guides per target.
pipeline_fixture <- function(moi = "low", control = "nt_cells",
                             mechanism = "permutations", integration = "union",
                             backed = FALSE, directory = NULL, assignment_method = NULL,
                             approximation = "skew_normal", calibration_pairs = 4L) {
    stopifnot(moi %in% c("low", "high"))
    set.seed(20261019)
    n <- 160L
    guides <- c("a1", "a2", "b1", "b2", "nt1", "nt2", "nt3", "nt4")
    cells <- paste0("cell_", seq_len(n))
    assignment <- rep(seq_along(guides), length.out = n)
    g <- matrix(0, length(guides), n, dimnames = list(guides, cells))
    g[cbind(assignment, seq_len(n))] <- 50
    if (moi == "high") {
        g[1L, seq(10L, n, 16L)] <- 50
        g[3L, seq(5L, n, 16L)] <- 50
        g[6L, seq(3L, n, 16L)] <- 50
    }
    y <- matrix(stats::rpois(6L * n, 3), 6L, n,
                dimnames = list(paste0("r", 1:6), cells))
    y[1L, assignment %in% 1:2] <- y[1L, assignment %in% 1:2] + 20
    y[2L, assignment %in% 3:4] <- if (approximation == "no_approximation") 1L else 0L
    # Empirical-budget cases have four eligible discovery pairs and one failed
    # pair, so calibration size three cannot silently set later family budgets.
    y[4L, ] <- 0
    metadata <- data.frame(grna_id = guides,
        grna_target = c("A", "A", "B", "B", rep("non-targeting", 4L)))
    object <- sceptre::import_data(
        response_matrix = Matrix::Matrix(y, sparse = TRUE),
        grna_matrix = Matrix::Matrix(g, sparse = TRUE),
        grna_target_data_frame = metadata, moi = moi,
        use_hdf5 = backed, directory_to_write = directory,
        extra_covariates = data.frame(
            batch = factor(rep(c("a", "b", "b", "a", "b"), length.out = n)),
            z = sin(seq_len(n)), row.names = cells))
    if (backed) {
        matrices <- list(sceptre::get_response_matrix(object), sceptre::get_grna_matrix(object))
        files <- unique(unlist(lapply(matrices, function(matrix) DelayedArray::seedApply(matrix,
            function(seed) if (isS4(seed) && "filepath" %in% methods::slotNames(seed))
                as.character(methods::slot(seed, "filepath")) else character())), use.names = FALSE))
        for (file in files) {
            staged <- file.path(directory, paste0(digest::digest(file = file, algo = "sha256"), ".h5"))
            if (!file.exists(staged)) stopifnot(file.copy(file, staged))
        }
    }
    config <- list(
        analysis = list(
            discovery_pairs = data.frame(grna_target = c("B", "A", "A", "B", "A"),
                response_id = c("r5", "r3", "r1", "r2", "r4")),
            positive_control_pairs = data.frame(grna_target = c("A", "B"),
                response_id = c("r1", "r2")),
            formula_object = stats::as.formula("~ batch + z", env = baseenv()),
            side = "both", grna_integration_strategy = integration,
            control_group = control, resampling_mechanism = mechanism,
            resampling_approximation = approximation,
            multiple_testing_method = "BH", multiple_testing_alpha = 0.1),
        assignment = if (moi == "low") list(method = "maximum") else
            list(method = "thresholding", threshold = 40),
        qc = list(response_n_umis_range = c(0, 1),
            response_n_nonzero_range = c(0, 1),
            n_nonzero_trt_thresh = 7L, n_nonzero_cntrl_thresh = 7L,
            additional_cells_to_remove = c(2L, 17L, 49L, 103L, 158L)),
        calibration = list(n_calibration_pairs = as.integer(calibration_pairs), calibration_group_size = 2L),
        execution = list(output_amount = 2L))
    if (!is.null(assignment_method)) {
        config$assignment <- list(method = assignment_method)
        if (assignment_method == "mixture") config$assignment$formula_object <-
            stats::as.formula("~ batch + z", env = baseenv())
    }
    list(object = object, config = config, moi = moi,
         control = if (moi == "high") "complement" else control,
         mechanism = mechanism, integration = integration)
}

pipeline_fixture_cases <- function() list(
    low_nt_permutation = list("low", "nt_cells", "permutations", "union"),
    low_complement_permutation = list("low", "complement", "permutations", "union"),
    low_nt_crt = list("low", "nt_cells", "crt", "union"),
    low_complement_crt = list("low", "complement", "crt", "bonferroni"),
    high_crt = list("high", "complement", "crt", "union"),
    high_mixture_crt = list("high", "complement", "crt", "union", assignment_method = "mixture"),
    high_permutation = list("high", "complement", "permutations", "singleton"),
    low_nt_empirical_permutation = list("low", "nt_cells", "permutations", "union",
        approximation = "no_approximation", calibration_pairs = 3L),
    high_empirical_crt = list("high", "complement", "crt", "union",
        approximation = "no_approximation", calibration_pairs = 3L))

# Read the realized public plan, never override budgets through a private seam.
assert_empirical_budget <- function(plan, stage, config) {
    if (config$analysis$resampling_approximation != "no_approximation") return(invisible(NULL))
    expected <- c(B1 = 499L, B2 = 0L, B3 = if (stage == "calibration") 300L else 400L)
    actual <- vapply(names(expected), function(name) methods::slot(plan, name), integer(1))
    stopifnot(identical(actual, expected))
    invisible(actual)
}
