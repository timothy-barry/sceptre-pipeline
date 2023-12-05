#!/usr/bin/env Rscript

# obtain the command line arguments
args <- commandArgs(trailingOnly = TRUE)
sceptre_object_fp <- args[1]
n_additional_args <- length(args) - 1L
result_fps <- args[seq(2L, n_additional_args/2 + 1)]
precomputation_fps <- args[seq(n_additional_args/2 + 2, length(args))]

# load the results and precomputations; combine
result_df <- lapply(result_fps, readRDS) |> data.table::rbindlist()
data.table::setorderv(result_df, cols = c("p_value", "response_id"))
precomputation_list <- lapply(precomputation_fps, readRDS) |> unlist(recursive = FALSE)

# load the sceptre_object; update response precomputations and results
sceptre_object <- readRDS(sceptre_object_fp)
sceptre_object@response_precomputations <- c(sceptre_object@response_precomputations,
                                             precomputation_list)
sceptre_object@calibration_result <- result_df

# create plot
p <- sceptre::plot(sceptre_object)

# save outputs
saveRDS(sceptre_object, "sceptre_object.rds")
ggplot2::ggsave(filename = "plot_run_calibration_check.png", plot = p, device = "png", scale = 1.1, width = 5, height = 4, dpi = 330)
sink(file = "analysis_summary.txt", append = FALSE)
sceptre::print(sceptre_object)
sink(NULL)
