#!/usr/bin/env Rscript

# obtain the command line arguments
args <- commandArgs(trailingOnly = TRUE)
sceptre_object_fp <- args[1]
response_odm_fp <- args[2]
grna_odm_fp <- args[3]
grna_pod_size <- as.integer(args[4])

# load the sceptre object
sceptre_object <- sceptre::read_ondisc_backed_sceptre_object(sceptre_object_fp = sceptre_object_fp,
                                                             response_odm_file_fp = response_odm_fp,
                                                             grna_odm_file_fp = grna_odm_fp)

# define helper functions
get_id_vect <- function(v, pod_size) {
  n_elements <- length(v)
  breaks <- round(n_elements/pod_size)
  if (breaks >= 2) {
    as.integer(cut(seq(1, n_elements), breaks)) 
  } else {
    rep(1L, n_elements)
  }
}
write_vector <- function(vector, file_name) {
  file_con <- file(file_name)
  writeLines(as.character(vector), file_con)
  close(file_con)
}

# get the gRNAs in use and obtian the gRNA-to-pod map
grnas_in_use <- sceptre:::determine_grnas_in_use(sceptre_object)
grna_to_pod_map <- data.frame(grna_id = grnas_in_use,
                              pod_id = get_id_vect(grnas_in_use, grna_pod_size))
grna_pods <- unique(grna_to_pod_map$pod_id)

# write and save outputs
# write_vector(sceptre_object@low_moi, "low_moi.txt")
write_vector(grna_pods, "grna_pods.txt")
saveRDS(grna_to_pod_map, "grna_to_pod_map.rds")
write_vector(tolower(sceptre_object@low_moi), "low_moi.txt")
