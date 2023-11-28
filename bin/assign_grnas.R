#!/usr/bin/env Rscript

# obtain the command line arguments
args <- commandArgs(trailingOnly = TRUE)
sceptre_object_fp <- args[1]
response_odm_fp <- args[2]
grna_odm_fp <- args[3]
grna_to_pod_map_fp <- args[4]
grna_pod <- as.integer(args[5])
grna_assignment_method <- args[6]

# load the sceptre object
sceptre_object <- sceptre::read_ondisc_backed_sceptre_object(sceptre_object_fp = sceptre_object_fp,
                                                             response_odm_file_fp = response_odm_fp,
                                                             grna_odm_file_fp = grna_odm_fp)

# load the grna to pod map; determine the grnas in use
grna_to_pod_map <- readRDS(grna_to_pod_map_fp)
grnas_in_use <- subset(grna_to_pod_map, pod_id == grna_pod)$grna_id
sceptre_object@elements_to_analyze <- grnas_in_use

# call the gRNA-to-cell assignment function
sceptre_object <- sceptre::assign_grnas(sceptre_object = sceptre_object,
                                        method = grna_assignment_method,
                                        parallel = FALSE)

# save the assignment list
saveRDS(sceptre_object@initial_grna_assignment_list, "grna_assignments.rds")
