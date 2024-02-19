#!/usr/bin/env Rscript

# obtain the command line arguments
args <- commandArgs(trailingOnly = TRUE)
sceptre_object_fp <- args[1]
response_odm_fp <- args[2]
grna_odm_fp <- args[3]
grna_pod_size <- as.integer(args[4])
trial <- as.logical(args[5])

# load the sceptre object
sceptre_object <- sceptre::read_ondisc_backed_sceptre_object(sceptre_object_fp = sceptre_object_fp,
                                                             response_odm_file_fp = response_odm_fp,
                                                             grna_odm_file_fp = grna_odm_fp)
# get the gRNAs in use and obtain the gRNA-to-pod map
grnas_in_use <- sceptre:::determine_grnas_in_use(sceptre_object, trial)
grna_to_pod_map <- data.frame(grna_id = grnas_in_use,
                              pod_id = sceptre:::get_id_vect(grnas_in_use, grna_pod_size))
grna_pods <- unique(grna_to_pod_map$pod_id)

# write and save outputs
sceptre:::write_vector(grna_pods, "grna_pods.txt")
saveRDS(grna_to_pod_map, "grna_to_pod_map.rds")
sceptre:::write_vector(tolower(sceptre_object@low_moi), "low_moi.txt")
