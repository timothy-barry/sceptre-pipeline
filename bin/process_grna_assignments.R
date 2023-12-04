#!/usr/bin/env Rscript

# obtain the command line arguments
args <- commandArgs(trailingOnly = TRUE)
sceptre_object_fp <- args[1]
response_odm_fp <- args[2]
grna_odm_fp <- args[3]
method <- args[4]
umi_fraction_threshold <- args[5]
grna_assignment_fps <- args[seq(6, length(args))]

# load the sceptre object
sceptre_object <- sceptre::read_ondisc_backed_sceptre_object(sceptre_object_fp = sceptre_object_fp,
                                                             response_odm_file_fp = response_odm_fp,
                                                             grna_odm_file_fp = grna_odm_fp)
# determine the grna assignment method
if (identical(method, "default")) method <- if (sceptre_object@low_moi) "maximum" else "mixture"

# if method is maximum, carry out the standard assignment strategy
if (method == "maximum") {
  sceptre_object@nf_pipeline <- FALSE
  args_to_pass <- list(sceptre_object = sceptre_object, method = "maximum")
  if (!identical(umi_fraction_threshold, "default")) {
    args_to_pass[["umi_fraction_threshold"]] <- as.numeric(umi_fraction_threshold)
  }
  sceptre_object <- do.call(sceptre::assign_grnas, args = args_to_pass)
} else {
  # combine initial assignment list across grnas; update fields of sceptre_object
  sceptre_object@initial_grna_assignment_list <- lapply(grna_assignment_fps, readRDS) |>
    unlist(recursive = FALSE)
  sceptre_object@functs_called[["assign_grnas"]] <- TRUE
  sceptre_object@grna_assignment_method <- method
  sceptre_object <- sceptre:::process_initial_assignment_list(sceptre_object)
}

# write outputs to disk
sceptre:::write_ondisc_backed_sceptre_object(sceptre_object = sceptre_object, "sceptre_object.rds")
p1 <- sceptre::plot_grna_count_distributions(sceptre_object)
p2 <- sceptre::plot_assign_grnas(sceptre_object)
ggplot2::ggsave(filename = "plot_grna_count_distributions.png", plot = p1, device = "png", scale = 1.1, width = 5, height = 4, dpi = 330)
ggplot2::ggsave(filename = "plot_assign_grnas.png", plot = p2, device = "png", scale = 1.1, width = 5, height = 4, dpi = 330)
sink(file = "analysis_summary.txt", append = FALSE)
sceptre::print(sceptre_object)
sink(NULL)
