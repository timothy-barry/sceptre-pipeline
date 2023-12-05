#!/usr/bin/env Rscript

# obtain the command line arguments
args <- commandArgs(trailingOnly = TRUE)
sceptre_object_fp <- args[1]
response_odm_fp <- args[2]
grna_odm_fp <- args[3]
curr_pod <- as.integer(args[4])

# load the sceptre object
sceptre_object <- sceptre::read_ondisc_backed_sceptre_object(sceptre_object_fp = sceptre_object_fp,
                                                             response_odm_file_fp = response_odm_fp,
                                                             grna_odm_file_fp = grna_odm_fp)

# load the pair to pod map; update the sceptre object
sceptre_object@negative_control_pairs <- subset(sceptre_object@negative_control_pairs,
                                                pod == curr_pod)
sceptre_object@nf_pipeline <- TRUE
sceptre_object <- sceptre:::run_calibration_check_pt_2(sceptre_object = sceptre_object)

# save the output
result <- sceptre_object@calibration_result
precomputations <- sceptre_object@response_precomputations
saveRDS(result, "result.rds")
saveRDS(precomputations, "precomputations.rds")