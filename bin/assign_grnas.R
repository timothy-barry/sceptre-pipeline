#!/usr/bin/env Rscript

# obtain the command line arguments
args <- commandArgs(trailingOnly = TRUE)
sceptre_object_fp <- args[1]
response_odm_fp <- args[2]
grna_odm_fp <- args[3]
grna_to_pod_map <- args[4]
grna_pod <- as.integer(args[5])
grna_assignment_method <- args[6]

saveRDS(grna_pod, "grna_assignments.rds")