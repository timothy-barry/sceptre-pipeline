#!/usr/bin/env Rscript

# obtain the command line arguments
args <- commandArgs(trailingOnly = TRUE)
sceptre_object_fp <- args[1]
response_odm_fp <- args[2]
grna_odm_fp <- args[3]
method <- args[4]
umi_fraction_threshold <- args[5]
grna_assignment_fps <- args[seq(6, length(args))]
UMI_FRACTION_THRESHOLD_DEFAULT <- 0.8

# load the sceptre object
sceptre_object <- sceptre::read_ondisc_backed_sceptre_object(sceptre_object_fp = sceptre_object_fp,
                                                             response_odm_file_fp = response_odm_fp,
                                                             grna_odm_file_fp = grna_odm_fp)
# determine the grna assignment method
if (identical(method, "default")) method <- if (sceptre_object@low_moi) "maximum" else "mixture"
sceptre_object@grna_assignment_method <- method
sceptre_object@functs_called[["assign_grnas"]] <- TRUE

# obtain the list of initial gRNA assignments (treating maximum as a special case)
if (method == "maximum") {
  if (identical(umi_fraction_threshold, "default")) {
    umi_fraction_threshold <- UMI_FRACTION_THRESHOLD_DEFAULT 
  } else {
    umi_fraction_threshold <- as.numeric(umi_fraction_threshold)
  }
  grna_ids <- unique(sceptre_object@ondisc_grna_assignment_info$max_grna)
  initial_assignment_list <- lapply(grna_ids, function(grna_id) {
    which(sceptre_object@ondisc_grna_assignment_info$max_grna == grna_id) 
  }) |> stats::setNames(grna_ids)
  cells_w_multiple_grnas <- which(sceptre_object@ondisc_grna_assignment_info$max_grna_frac_umis > umi_fraction_threshold)
} else {
  initial_assignment_list <- lapply(X = grna_assignment_fps, FUN = readRDS) |> unlist(recursive = FALSE)
}
sceptre_object@ondisc_grna_assignment_info <- list()

# obtain the list of processed gRNA assignments
processed_assignment_out <- sceptre:::process_initial_assignment_list(initial_assignment_list = initial_assignment_list,
                                                                      grna_target_data_frame = sceptre_object@grna_target_data_frame,
                                                                      n_cells = ncol(sceptre_object@grna_matrix),
                                                                      low_moi = sceptre_object@low_moi,
                                                                      maximum_assignment = (method == "maximum"))
sceptre_object@grna_assignments_raw <- processed_assignment_out$grna_assignments_raw
sceptre_object@grnas_per_cell <- processed_assignment_out$grnas_per_cell
sceptre_object@cells_w_multiple_grnas <- if (method != "maximum") processed_assignment_out$cells_w_multiple_grnas else cells_w_multiple_grnas
sceptre_object@initial_grna_assignment_list <- initial_assignment_list

# write outputs to disk
sceptre:::write_ondisc_backed_sceptre_object(sceptre_object = sceptre_object, "sceptre_object.rds")
p1 <- sceptre::plot_grna_count_distributions(sceptre_object)
p2 <- sceptre::plot_assign_grnas(sceptre_object)
ggplot2::ggsave(filename = "plot_grna_count_distributions.png", plot = p1, device = "png", scale = 1.1, width = 5, height = 4, dpi = 330)
ggplot2::ggsave(filename = "plot_assign_grnas.png", plot = p2, device = "png", scale = 1.1, width = 5, height = 4, dpi = 330)
sink(file = "analysis_summary.txt", append = FALSE)
sceptre::print(sceptre_object)
sink(NULL)
