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
trial <- as.logical(args[8])
use_parquet <- as.logical(args[9])

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
if (trial) {
  set.seed(4)
  curr_response_ids <- sample(curr_response_ids, size = min(30, length(curr_response_ids)))
  grna_tagets <- sapply(sceptre_object@grna_assignments$grna_group_idxs, function(elem) length(elem) >= 1L) |>
    which() |> names()
  discovery_pairs <- expand.grid(response_id = curr_response_ids,
                                 grna_target = grna_tagets)
  discovery_pairs$grna_group <- grna_tagets
} else {
  grna_target_df <- sceptre_object@grna_target_data_frame |>
    dplyr::filter(grna_target != "non-targeting") |>
    dplyr::select(grna_target, grna_group)
  discovery_pairs <- grna_target_df[rep(seq(1L, nrow(grna_target_df)), times = length(curr_response_ids)),]
  discovery_pairs$response_id <- rep(curr_response_ids, each = nrow(grna_target_df))
}
sceptre_object@discovery_pairs <- discovery_pairs

# 4. run pairwise qc
sceptre_object <- sceptre:::run_qc_pt_2(sceptre_object)

# 5. prune sceptre_object
sceptre_object@discovery_pairs <- data.frame()
sceptre_object@M_matrix <- matrix()
gc() |> invisible()

# 6. run discovery analysis
if (sceptre_object@n_ok_discovery_pairs >= 1L) {
  sceptre_object <- sceptre::run_discovery_analysis(sceptre_object = sceptre_object, parallel = FALSE)
} else {
  result_df <- sceptre_object@discovery_pairs_with_info
  result_df$p_value <- NA
  result_df$log_2_fold_change <- NA
  sceptre_object@discovery_result <- sceptre:::process_discovery_result(result_df, sceptre_object)
}

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
fp <- paste0("result_", curr_pod_id, if (use_parquet) ".parquet" else ".rds")
arrow::write_parquet(result, sink = fp, chunk_size = nrow(result))
