// Use DSL 2
nextflow.enable.dsl = 2
params.grna_pod_size = 100

// PROCESS A: output gRNA info
process output_grna_info {
  debug true
  time "5m"
  memory "5 GB"
  
  input:
  path "sceptre_object_fp"
  path "response_odm_fp"
  path "grna_odm_fp"
  
  output:
  path "grna_to_pod_map.rds", emit: response_to_pod_id_map_ch
  path "grna_pods.txt", emit: pair_pods_ch
  path "low_moi.txt", emit: low_moi_ch
  
  """
  output_grna_info.R $sceptre_object_fp $response_odm_fp $grna_odm_fp ${params.grna_pod_size}
  """
}

// WORKFLOW
workflow {
  // 1. obtain the gRNA info
  output_grna_info(
    Channel.fromPath(params.sceptre_object_fp, checkIfExists : true),
    Channel.fromPath(params.response_odm_fp, checkIfExists : true),
    Channel.fromPath(params.grna_odm_fp, checkIfExists : true)
  )
  
  // 2. process output of obtain gRNA info
  
}