#!/usr/bin/env Rscript

# obtain the command line arguments
args <- commandArgs(trailingOnly = TRUE)
sceptre_object_fp <- args[1]
analysis_type <- args[2]
result_fps <- grep(x = args, pattern = "results*", value = TRUE)
precomp_fps <- grep(x = args, pattern = "precomputations*", value = TRUE)

# load the sceptre object
sceptre_object <- readRDS(sceptre_object_fp)
sceptre_object@functs_called[[analysis_type]] <- TRUE

# process the results
result_df <- lapply(result_fps, readRDS) |> data.table::rbindlist()
data.table::setorderv(result_df, cols = c("p_value", "response_id"), na.last = TRUE)
process_funct <- switch(analysis_type,
                        run_calibration_check = sceptre:::process_calibration_result,
                        run_power_check = sceptre:::apply_grouping_to_result,
                        run_discovery_analysis = sceptre:::process_discovery_result)
result_df <- process_funct(result_df, sceptre_object)
result_df$pod <- NULL
sceptre_object@calibration_result <- result_df

# process the response precomputations
precomputation_list <- lapply(precomputation_fps, readRDS) |> unlist(recursive = FALSE)
sceptre_object@response_precomputations <- c(sceptre_object@response_precomputations,
                                             precomputation_list)

# create plot
p <- sceptre::plot(sceptre_object)

# save outputs
saveRDS(sceptre_object, "sceptre_object.rds")
ggplot2::ggsave(filename = "plot_run_calibration_check.png", plot = p, device = "png", scale = 1.1, width = 5, height = 4, dpi = 330)
sink(file = "analysis_summary.txt", append = FALSE)
sceptre::print(sceptre_object)
sink(NULL)
