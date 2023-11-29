// Use DSL 2
nextflow.enable.dsl = 2

// method parameter default values
params.grna_assignment_method = "default"

// parallelization default values
params.grna_pod_size = 100
params.pair_pod_size = 500


// PROCESS A: output gRNA info
process output_grna_info {
  time "5m"
  memory "4 GB"
  
  input:
  path "sceptre_object_fp"
  path "response_odm_fp"
  path "grna_odm_fp"
  
  output:
  path "grna_to_pod_map.rds", emit: grna_to_pod_map_ch
  path "grna_pods.txt", emit: grna_pods_ch
  path "low_moi.txt", emit: low_moi_ch
  
  """
  output_grna_info.R $sceptre_object_fp $response_odm_fp $grna_odm_fp ${params.grna_pod_size}
  """
}


// PROCESS B: assign gRNAs
process assign_grnas {
  time {1.m * params.grna_pod_size}
  memory "4 GB"
  
  when:
  !(params.grna_assignment_method == "maximum" || (low_moi == "true" && params.grna_assignment_method == "default"))
  
  input:
  path "sceptre_object_fp"
  path "response_odm_fp"
  path "grna_odm_fp"
  path "grna_to_pod_map"
  val "grna_pod"
  val "low_moi"
  
  output:
  path "grna_assignments.rds", emit: grna_assignments_ch

  """
  assign_grnas.R $sceptre_object_fp $response_odm_fp $grna_odm_fp $grna_to_pod_map $grna_pod ${params.grna_assignment_method}
  """
}


// PROCESS C: process gRNA assignments
process process_grna_assignments {
  time "5m"
  memory "5 GB"
  debug true
  
  input:
  path "sceptre_object_fp"
  path "response_odm_fp"
  path "grna_odm_fp"
  path "grna_assignments"
  
  //"""
  //process_grna_assignments.R $sceptre_object_fp $response_odm_fp $grna_odm_fp ${params.grna_assignment_method} grna_assignments*
  //"""
  
  """
  echo $sceptre_object_fp $response_odm_fp $grna_odm_fp ${params.grna_assignment_method} grna_assignments*
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
  
  // 2. process output from the above
  grna_to_pod_map_ch = output_grna_info.out.grna_to_pod_map_ch.first()
  grna_pods_ch = output_grna_info.out.grna_pods_ch.splitText().map{it.trim()}
  low_moi_ch = output_grna_info.out.low_moi_ch.splitText().map{it.trim()}.first()
  
  // 3. assign gRNAs
  assign_grnas(
    Channel.fromPath(params.sceptre_object_fp).first(),
    Channel.fromPath(params.response_odm_fp).first(),
    Channel.fromPath(params.grna_odm_fp).first(),
    grna_to_pod_map_ch,
    grna_pods_ch,
    low_moi_ch
  )

  
  // 4. process output from the above
  grna_assignments_ch = assign_grnas.out.grna_assignments_ch.ifEmpty(params.sceptre_object_fp).collect()
  
  // 5. process the gRNA assignments
  process_grna_assignments(
    Channel.fromPath(params.sceptre_object_fp).first(),
    Channel.fromPath(params.response_odm_fp).first(),
    Channel.fromPath(params.grna_odm_fp).first(),
    grna_assignments_ch
  )
}
