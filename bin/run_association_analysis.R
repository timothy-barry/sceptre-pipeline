#!/usr/bin/env Rscript

# obtain the command line arguments
args <- commandArgs(trailingOnly = TRUE)
sceptre_object_fp <- args[1]
response_odm_fp <- args[2]
grna_odm_fp <- args[3]
curr_pod <- as.integer(args[4])
analysis_type <- args[5]

# load the sceptre object
sceptre_object <- sceptre::read_ondisc_backed_sceptre_object(sceptre_object_fp = sceptre_object_fp,
                                                             response_odm_file_fp = response_odm_fp,
                                                             grna_odm_file_fp = grna_odm_fp)

# update the pairs to analyze data frame
pairs_to_analyze_name <- switch(analysis_type,
                                run_calibration_check = "negative_control_pairs",
                                run_power_check = "positive_control_pairs_with_info",
                                run_discovery_analysis = "discovery_pairs_with_info")
slot(sceptre_object, pairs_to_analyze_name) <- subset(slot(sceptre_object, pairs_to_analyze_name),
                                                      pod == curr_pod)
sceptre_object@nf_pipeline <- TRUE

# run the association analysis
funct_to_run <- switch(analysis_type,
  run_calibration_check = sceptre:::run_calibration_check_pt_2,
  run_power_check = sceptre:::run_power_check,
  run_discovery_analysis = sceptre:::run_discovery_analysis
)
sceptre_object <- funct_to_run(sceptre_object)

# obtain the output
result_name <- switch(analysis_type,
                      run_calibration_check = "calibration_result",
                      run_power_check = "power_result",
                      run_discovery_analysis = "discovery_result")
result <- slot(sceptre_object, result_name)

# convert char columns into factors
cols <- colnames(result)
for (col in cols) {
  if (is(result[[col]], "character")) {
    result[[col]] <- factor(result[[col]])
  }
}
saveRDS(result, "result.rds")
if (sceptre_object@control_group_complement) {
  precomputations <- sceptre_object@response_precomputations
  saveRDS(precomputations, "precomputations.rds") 
} else {
  saveRDS(NULL, "precomputations.rds")
}
