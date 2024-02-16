#!/usr/bin/env Rscript

# 0. obtain the command line arguments
args <- commandArgs(trailingOnly = TRUE)
sceptre_object_fp <- args[1]
response_odm_fp <- args[2]
grna_odm_fp <- args[3]
response_to_pod_map_fp <- args[4]
curr_pod_id <- as.integer(args[5])
n_nonzero_trt_thresh <- args[6]
n_nonzero_cntrl_thresh <- args[7]

# 1. load the sceptre object
sceptre_object <- sceptre::read_ondisc_backed_sceptre_object(sceptre_object_fp = sceptre_object_fp,
                                                             response_odm_file_fp = response_odm_fp,
                                                             grna_odm_file_fp = grna_odm_fp)

# 2. process n_nonzero_trt_thresh, n_nonzero_cntrl_thresh
args_to_pass <- list(sceptre_object)
optional_args_names <- c("n_nonzero_trt_thresh", "n_nonzero_cntrl_thresh")
for (optional_arg_name in optional_args_names) {
  optional_arg_value <- get(x = optional_arg_name)
  if (!identical(optional_arg_value, "default")) {
    args_to_pass[[optional_arg_name]] <- as.integer(optional_arg_value)
  }
}

# 3. define the discovery pairs; insert into sceptre_object
curr_response_ids <- readRDS(response_to_pod_map_fp) |>
  dplyr::filter(pod_id == curr_pod_id) |>
  dplyr::pull(response_id)
grna_target_df <- sceptre_object@grna_target_data_frame |>
   dplyr::filter(grna_target != "non-targeting") |>
   dplyr::select(grna_target, grna_group)
discovery_pairs <- grna_target_df[rep(seq(1L, nrow(grna_target_df)), times = length(curr_response_ids)),] 
discovery_pairs$response_id <- rep(curr_response_ids, each = nrow(grna_target_df))
sceptre_object@discovery_pairs <- discovery_pairs

# 4. run pairwise qc
sceptre_object <- sceptre:::run_qc_pt_2(sceptre_object)

# 5. prune sceptre_object
sceptre_object@discovery_pairs <- data.frame()
gc() |> invisible()

# 6. run discovery analysis
sceptre_object <- sceptre::run_discovery_analysis(sceptre_object = sceptre_object, parallel = FALSE)

# 7. convert char columns into factors; remove significant column
result <- sceptre_object@discovery_result
sceptre_object@discovery_result <- data.frame()
result$significant <- NULL
cols <- colnames(result)
for (col in cols) {
  if (is(result[[col]], "character")) {
    result[[col]] <- factor(result[[col]])
  }
}

# 8. save result
fp <- paste0("result_", curr_pod_id, ".parquet")
arrow::write_parquet(result, sink = fp, chunk_size = nrow(result))
