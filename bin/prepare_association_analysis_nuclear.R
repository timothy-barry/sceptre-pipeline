#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
sceptre_object_fp <- args[1]
response_odm_fp <- args[2]
grna_odm_fp <- args[3]
pair_pod_size <- as.integer(args[4])

# load the sceptre object
sceptre_object <- sceptre::read_ondisc_backed_sceptre_object(sceptre_object_fp = sceptre_object_fp,
                                                             response_odm_file_fp = response_odm_fp,
                                                             grna_odm_file_fp = grna_odm_fp)

# get the number of grna groups and n responses per pod
n_grna_groups <- sceptre_object@grna_target_data_frame |>
  dplyr::filter(grna_group != "non-targeting") |>
  dplyr::pull(grna_group) |> unique() |> length()
responses <- sceptre::get_response_matrix(sceptre_object) |> rownames()
n_responses <- length(responses)
n_pods <- ceiling(n_responses * n_grna_groups / pair_pod_size)

# map each response to a pod
pods <- rep(x = seq(1L, n_pods), length.out = n_responses) |> sample()
response_to_pod_map <- data.frame(response_id = responses, pod_id = pods) |>
  dplyr::arrange(pod_id, response_id)

# write the response-to-pod map as well as the pod ids
sceptre:::write_vector(unique(response_to_pod_map$pod), "discovery_analysis_pods")
saveRDS(response_to_pod_map, "response_to_pod_map.rds")
