#!/usr/bin/env Rscript

# obtain the command line arguments
args <- commandArgs(trailingOnly = TRUE)
sceptre_object_fp <- args[1]
response_odm_fp <- args[2]
grna_odm_fp <- args[3]
grna_to_pod_map_fp <- args[4]
grna_pod <- as.integer(args[5])
grna_assignment_method <- args[6]
threshold <- args[7]
n_em_rep <- args[8]
n_nonzero_cells_cutoff <- args[9]
backup_threshold <- args[10]
probability_threshold <- args[11]

# load the sceptre object
sceptre_object <- sceptre::read_ondisc_backed_sceptre_object(sceptre_object_fp = sceptre_object_fp,
                                                             response_odm_file_fp = response_odm_fp,
                                                             grna_odm_file_fp = grna_odm_fp)

# load the grna to pod map; determine the grnas in use
grna_to_pod_map <- readRDS(grna_to_pod_map_fp)
grnas_in_use <- subset(grna_to_pod_map, pod_id == grna_pod)$grna_id
sceptre_object@elements_to_analyze <- grnas_in_use
sceptre_object@nf_pipeline <- TRUE

# process the default arguments
args_to_pass <- list(sceptre_object = sceptre_object,
                     method = grna_assignment_method,
                     parallel = FALSE)
optional_args_names <- c("threshold", "n_em_rep", "n_nonzero_cells_cutoff",
                         "backup_threshold", "probability_threshold")
for (optional_arg_name in optional_args_names) {
  optional_arg_value <- get(x = optional_arg_name)
  if (!identical(optional_arg_value, "default")) {
    args_to_pass[[optional_arg_name]] <- as.numeric(optional_arg_value)
  }
}

# call the gRNA-to-cell assignment function
sceptre_object <- do.call(what = sceptre::assign_grnas,
                          args = args_to_pass)

# save the initial assignment list
saveRDS(sceptre_object@initial_grna_assignment_list, "grna_assignments.rds")
