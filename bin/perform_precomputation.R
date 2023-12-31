#!/usr/bin/env Rscript

#######
# SETUP
#######

# get the command line args
args <- commandArgs(trailingOnly = TRUE)
modality_name <- args[1] # modality name ("gene" or "grna")
multimodal_metadata_fp <- args[2] # multimodal fp
gene_odm_fp <- args[3] # gene odm fp
pod_id_map <- args[4] # modality to pod id map
pod_id <- as.integer(args[5]) # pod id (integer)
threshold <- as.integer(args[6]) # threshold
inference_method <- args[7] # inference method, either "crt" or "gcm"
fam <- switch(inference_method,
  crt = "nb",
  gcm = "poisson",
  stop("Inference method not recognized"))

# load ondisc
library(ondisc)

##############################
# PREPARE DATA AND HYPERPARAMS
##############################
ids <- readRDS(pod_id_map) |>
  dplyr::filter(pod_id == !!pod_id) |>
  dplyr::pull(id)
mm_odm <- read_multimodal_odm(gene_odm_fp, multimodal_metadata_fp)
modality_odm <- get_modality(mm_odm, modality_name)
global_cell_covariates <- get_cell_covariates(mm_odm)
rm(mm_odm)

####################################
# ITERATE AND PERFORM PRECOMPUTATION
####################################
precomp_sub_matrix <- sapply(X = ids, FUN = function(id) {
  if (modality_name == "gene") {
    print(paste0("Regressing gene ", id, " onto covariates."))
    # load expression data
    expressions <- as.numeric(modality_odm[[id,]])
    # regress expressions onto technical factors
    precomp <- sceptre:::run_gene_precomputation_v2(expressions = expressions,
                                                    covariate_matrix = global_cell_covariates,
                                                    fam = fam)
  } else if (modality_name == "grna") {
    print(paste0("Regressing gRNA group ", id, " onto covariates."))
    # load data
    indicators <- ondisc::load_thresholded_and_grouped_grna(covariate_odm = modality_odm,
                                                            grna_group = id,
                                                            threshold = threshold) |> as.integer()
    # fit model
    precomp <- sceptre:::run_grna_precomputation_v2(indicators = indicators,
                                                    covariate_matrix = global_cell_covariates)
  } else {
    stop("Modality name not recognized.")
  }
}) |> t() |> data.table::as.data.table() |> dplyr::mutate(id = ids)

saveRDS(precomp_sub_matrix, "precomp_sub_matrix.rds")
