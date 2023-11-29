#!/usr/bin/env Rscript

# obtain the command line arguments
args <- commandArgs(trailingOnly = TRUE)
sceptre_object_fp <- args[1]
response_odm_fp <- args[2]
grna_odm_fp <- args[3]
grna_assignment_method <- args[4]
grna_assignment_fps <- args[seq(5, length(args))]

# load the sceptre object
sceptre_object <- sceptre::read_ondisc_backed_sceptre_object(sceptre_object_fp = sceptre_object_fp,
                                                             response_odm_file_fp = response_odm_fp,
                                                             grna_odm_file_fp = grna_odm_fp)

# obtain the list of initial gRNA assignments
maximum_method <- grna_assignment_method == "maximum" || (grna_assignment_method == "default" && sceptre_object@low_moi)
if (maximum_method) {
  grna_ids <- unique(sceptre_object@ondisc_grna_assignment_info$max_grna)
  initial_grna_assignment_list <- lapply(grna_ids, function(grna_id) which(sceptre_object@ondisc_grna_assignment_info$max_grna == grna_id)) |>
    stats::setNames(grna_ids)
} else {
  initial_grna_assignment_list <- lapply(X = grna_assignment_fps, FUN = readRDS) |> unlist(recursive = FALSE)
}

# obtain the list of processed gRNA assignments

