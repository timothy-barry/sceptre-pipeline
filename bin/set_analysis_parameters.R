#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
set.seed(4)

# obtain the command line arguments
sceptre_object_fp <- args[1]
response_odm_fp <- args[2]
grna_odm_fp <- args[3]
side <- args[4]
grna_integration_strategy <- args[5]
resampling_approximation <- args[6]
control_group <- args[7]
resampling_mechanism <- args[8]
multiple_testing_method <- args[9]
multiple_testing_alpha <- args[10]
formula_object_fp <- args[11]
discovery_pairs <- args[12]
positive_control_pairs <- args[13]
trial <- as.logical(args[14])

# load the sceptre object
sceptre_object <- sceptre::read_ondisc_backed_sceptre_object(sceptre_object_fp = sceptre_object_fp,
                                                             response_odm_file_fp = response_odm_fp,
                                                             grna_odm_file_fp = grna_odm_fp)
# process the default arguments
# side
if (identical(side, "default")) {
  side <- c("left", "both", "right")[sceptre_object@side_code + 2L]
}

#  grna_integration_strategy
if (identical(grna_integration_strategy, "default")) {
  grna_integration_strategy <- sceptre_object@grna_integration_strategy
}

# resampling_approximation
if (identical(resampling_approximation, "default")) {
  resampling_approximation <- sceptre_object@resampling_approximation
}

# control_group
if (identical(control_group, "default")) {
  control_group <- if (sceptre_object@control_group_complement) "complement" else "nt_cells"
}

# resampling_mechanism
if (identical(resampling_mechanism, "default")) {
  resampling_mechanism <- if (sceptre_object@run_permutations) "permutations" else "crt"
}

# formula_object
formula_object <- readRDS(formula_object_fp)
if (identical(formula_object, NULL)) {
  formula_object <- sceptre_object@formula_object
}

# discovery_pairs
discovery_pairs <- readRDS(discovery_pairs)
nuclear <- identical(discovery_pairs, "trans")
if (nuclear) {
  discovery_pairs <- data.frame(grna_target = character(0), response_id = character(0))
} else {
  if (identical(discovery_pairs, NULL)) {
    discovery_pairs <- sceptre_object@discovery_pairs
  }
  if (trial) {
    n_pairs <- nrow(discovery_pairs)
    discovery_pairs <- discovery_pairs |> dplyr::sample_n(min(100, n_pairs))
  }
}

# positive_control_pairs
if (nuclear) {
  positive_control_pairs <- data.frame(grna_target = character(0), response_id = character(0))
} else {
  positive_control_pairs <- readRDS(positive_control_pairs)
  if (identical(positive_control_pairs, NULL)) {
    positive_control_pairs <- sceptre_object@positive_control_pairs
  }
  if (trial) {
    n_pairs <- nrow(positive_control_pairs)
    positive_control_pairs <- positive_control_pairs |> dplyr::sample_n(min(100, n_pairs))
  }
}

# multiple_testing_method
if (nuclear) {
  multiple_testing_method <- "none"
} else if (identical(multiple_testing_method, "default")) {
  multiple_testing_method <- sceptre_object@multiple_testing_method
}

# multiple_testing_alpha
if (identical(multiple_testing_alpha, "default")) {
  multiple_testing_alpha <- sceptre_object@multiple_testing_alpha
} else {
  multiple_testing_alpha <- as.numeric(multiple_testing_alpha)
}

# set the analysis parameters
sceptre_object <- sceptre::set_analysis_parameters(
  sceptre_object = sceptre_object,
  discovery_pairs = discovery_pairs,
  positive_control_pairs = positive_control_pairs,
  side = side,
  grna_integration_strategy = grna_integration_strategy,
  formula_object = formula_object,
  resampling_approximation = resampling_approximation,
  control_group = control_group,
  resampling_mechanism = resampling_mechanism,
  multiple_testing_method = multiple_testing_method,
  multiple_testing_alpha = multiple_testing_alpha
)
if (nuclear) sceptre_object@nuclear <- TRUE

# write the sceptre_object
saveRDS(sceptre_object, "sceptre_object.rds")
sink(file = "analysis_summary.txt", append = FALSE)
sceptre::print(sceptre_object)
sink(NULL)
