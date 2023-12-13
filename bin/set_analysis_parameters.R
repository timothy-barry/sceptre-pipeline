#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)

# obtain the command line arguments
sceptre_object_fp <- args[1]
response_odm_fp <- args[2]
grna_odm_fp <- args[3]
side <- args[4]
grna_integration_strategy <- args[5]
fit_parametric_curve <- args[6]
control_group <- args[7]
resampling_mechanism <- args[8]
multiple_testing_method <- args[9]
multiple_testing_alpha <- args[10]
formula_object_fp <- args[11]
discovery_pairs <- args[12]
positive_control_pairs <- args[13]

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

# fit_parametric_curve
if (identical(fit_parametric_curve, "default")) {
  fit_parametric_curve <- sceptre_object@fit_parametric_curve
} else {
  fit_parametric_curve <- as.logical(fit_parametric_curve)
}

# control_group
if (identical(control_group, "default")) {
  control_group <- if (sceptre_object@control_group_complement) "complement" else "nt_cells"
}

# resampling_mechanism
if (identical(resampling_mechanism, "default")) {
  resampling_mechanism <- if (sceptre_object@run_permutations) "permutations" else "crt"
}

# multiple_testing_method
if (identical(multiple_testing_method, "default")) {
  multiple_testing_method <- sceptre_object@multiple_testing_method
}

# multiple_testing_alpha
if (identical(multiple_testing_alpha, "default")) {
  multiple_testing_alpha <- sceptre_object@multiple_testing_alpha
} else {
  multiple_testing_alpha <- as.numeric(multiple_testing_alpha)
}

# formula_object
formula_object <- readRDS(formula_object_fp)
if (identical(formula_object, NULL)) {
  formula_object <- sceptre_object@formula_object
}

# discovery_pairs
discovery_pairs <- readRDS(discovery_pairs)
if (identical(discovery_pairs, NULL)) {
  discovery_pairs <- sceptre_object@discovery_pairs
}

# positive_control_pairs
positive_control_pairs <- readRDS(positive_control_pairs)
if (identical(positive_control_pairs, NULL)) {
  positive_control_pairs <- sceptre_object@positive_control_pairs
}

# set the analysis parameters
sceptre_object <- sceptre::set_analysis_parameters(
  sceptre_object = sceptre_object,
  discovery_pairs = discovery_pairs,
  positive_control_pairs = positive_control_pairs,
  side = side,
  grna_integration_strategy = grna_integration_strategy,
  formula_object = formula_object,
  fit_parametric_curve = fit_parametric_curve,
  control_group = control_group,
  resampling_mechanism = resampling_mechanism,
  multiple_testing_method = multiple_testing_method,
  multiple_testing_alpha = multiple_testing_alpha
) 

# write the sceptre_object
saveRDS(sceptre_object, "sceptre_object.rds")
sink(file = "analysis_summary.txt", append = FALSE)
sceptre::print(sceptre_object)
sink(NULL)
