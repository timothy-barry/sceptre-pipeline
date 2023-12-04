// Use DSL 2
nextflow.enable.dsl = 2

/*************************
* DEFAULT PARAMETER VALUES
*************************/
// gRNA assignment
params.grna_assignment_method = "default"
params.threshold = "default"
params.umi_fraction_threshold = "default"
params.n_em_rep = "default"
params.n_nonzero_cells_cutoff = "default"
params.backup_threshold = "default"
params.probability_threshold = "default"
// QC
params.n_nonzero_trt_thresh = "default"
params.n_nonzero_cntrl_thresh = "default"
params.response_n_umis_range_lower = "default"
params.response_n_umis_range_uppper = "default"
params.response_n_nonzero_range_lower = "default"
params.response_n_nonzero_range_upper = "default"
params.p_mito_threshold = "default"
// parallelization
params.grna_pod_size = 100
params.pair_pod_size = 500

/**********
* PROCESSES
**********/
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
  output_grna_info.R $sceptre_object_fp \
  $response_odm_fp \
  $grna_odm_fp \
  ${params.grna_pod_size}
  """
}

// PROCESS B: assign gRNAs
process assign_grnas {
  time {1.m * params.grna_pod_size}
  memory "4 GB"
  debug true

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
  assign_grnas.R $sceptre_object_fp \
  $response_odm_fp \
  $grna_odm_fp \
  $grna_to_pod_map \
  $grna_pod \
  ${params.grna_assignment_method} \
  ${params.threshold} \
  ${params.n_em_rep} \
  ${params.n_nonzero_cells_cutoff} \
  ${params.backup_threshold} \
  ${params.probability_threshold}
  """
}

// PROCESS C: process gRNA assignments
process process_grna_assignments {
  time "5m"
  memory "5 GB"
  publishDir "${params.output_directory}", mode: 'copy', overwrite: true, pattern: "*.png"
  publishDir "${params.output_directory}", mode: 'copy', overwrite: true, pattern: "*.txt"
  debug true

  input:
  path "sceptre_object_fp"
  path "response_odm_fp"
  path "grna_odm_fp"
  path "grna_assignments"
  
  output:
  path "plot_grna_count_distributions.png"
  path "plot_assign_grnas.png"
  path "analysis_summary.txt"
  path "sceptre_object.rds", emit: sceptre_object_ch_1

  """
  process_grna_assignments.R  $sceptre_object_fp \
  $response_odm_fp \
  $grna_odm_fp \
  ${params.grna_assignment_method} \
  ${params.umi_fraction_threshold} \
  grna_assignments*
  """
}

// PROCESS D: quality control
process run_qc {
  time "30m"
  memory "5 GB"
  publishDir "${params.output_directory}", mode: 'copy', overwrite: true, pattern: "*.png"
  publishDir "${params.output_directory}", mode: 'copy', overwrite: true, pattern: "*.txt"

  input:
  path "sceptre_object_fp"
  path "response_odm_fp"
  path "grna_odm_fp"

  output:
  path "plot_covariates.png"
  path "plot_run_qc.png"
  path "analysis_summary.txt"
  path "sceptre_object.rds", emit: sceptre_object_ch_2

  """
  run_qc.R $sceptre_object_fp \
  $response_odm_fp \
  $grna_odm_fp \
  ${params.n_nonzero_trt_thresh} \
  ${params.n_nonzero_cntrl_thresh} \
  ${params.response_n_umis_range_lower} \
  ${params.response_n_umis_range_uppper} \
  ${params.response_n_nonzero_range_lower} \
  ${params.response_n_nonzero_range_upper} \
  ${params.p_mito_threshold}
  """
}

// PROCESS: PREPARE ASSOCIATION ANALYSIS
process prepare_association_analyses {
  time "5m"
  memory "5 GB"
  debug true

  input:
  path "sceptre_object_fp"

  """
  echo $sceptre_object_fp \
  ${params.pair_pod_size}
  """
}

/**********
* WORKFLOW
**********/
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
  
  // 6. run quality control
  run_qc(
    process_grna_assignments.out.sceptre_object_ch_1,
    Channel.fromPath(params.response_odm_fp).first(),
    Channel.fromPath(params.grna_odm_fp).first(),
  )
  
  /*
  // 7. prepare association analyses
  prepare_association_analyses(
    run_qc.out.sceptre_object_ch_2
  )
  */
}
