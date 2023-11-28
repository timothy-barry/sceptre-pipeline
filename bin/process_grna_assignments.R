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

# obtain the list of gRNA assignments
initial_grna_assignment_list <- lapply(X = grna_assignment_fps, FUN = readRDS) |> unlist(recursive = FALSE)

# call the gRNA-to-cell assignment plots; write the summary txt file
