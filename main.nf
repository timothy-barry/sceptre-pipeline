// Use DSL 2
nextflow.enable.dsl = 2

/*************************
* DEFAULT PARAMETER VALUES
*************************/
// set analysis parameters
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
// calibration check
params.n_calibration_pairs = "default"
params.calibration_group_size = "default"
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
  memory "4 GB"
  publishDir "${params.output_directory}", mode: 'copy', overwrite: true, pattern: "*.png"
  publishDir "${params.output_directory}", mode: 'copy', overwrite: true, pattern: "*.txt"

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
  memory "4 GB"
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

// PROCESS E: prepare association analysis
process prepare_association_analyses {
  time "1h"
  memory "4 GB"

  input:
  path "sceptre_object_fp"
  path "response_odm_fp"
  path "grna_odm_fp"
  
  output:
  path "run_calibration_check", emit: run_calibration_check_ch
  path "run_discovery_analysis", emit: run_discovery_analysis_ch
  path "run_power_check", emit: run_power_check_ch
  path "calibration_check_pods", emit: calibration_check_pods_ch
  path "power_check_pods", emit: power_check_pods_ch
  path "discovery_analysis_pods", emit: discovery_analysis_pods_ch
  path "sceptre_object.rds", emit: sceptre_object_ch_3
  
  """
  prepare_association_analyses.R $sceptre_object_fp \
  $response_odm_fp \
  $grna_odm_fp \
  ${params.n_calibration_pairs} \
  ${params.calibration_group_size} \
  ${params.pair_pod_size}
  """
}

// PROCESS F: run calibration check
process run_calibration_check {
  time {1.m * params.pair_pod_size}
  memory "4 GB"
  
  when:
  run_calibration_check == "true"
  
  output:
  path "result.rds", emit: result_ch
  path "precomputations.rds", emit: precomputations_ch
  
  input:
  path "sceptre_object_fp"
  path "response_odm_fp"
  path "grna_odm_fp"
  val "pair_pod"
  val "run_calibration_check"
  
  """
  run_calibration_check.R $sceptre_object_fp \
  $response_odm_fp \
  $grna_odm_fp \
  $pair_pod
  """
}

// PROCESS F: process calibration check results
process process_calibration_check_results {
  time "5m"
  memory "4 GB"
  publishDir "${params.output_directory}", mode: 'copy', overwrite: true, pattern: "*.png"
  publishDir "${params.output_directory}", mode: 'copy', overwrite: true, pattern: "*.txt"
  
  when:
  run_calibration_check == "true"
  
  output:
  path "sceptre_object.rds", emit: sceptre_object_ch_4
  path "plot_run_calibration_check.png"
  path "analysis_summary.txt"

  input:
  path "sceptre_object_fp"
  path "results"
  path "precomputations"
  val "run_calibration_check"
  
  """
  echo $sceptre_object_fp \
  results* \
  precomputations*
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

  // 2. process output from above process
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

  // 4. process output from above process
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
  
  // 7. prepare association analyses
  prepare_association_analyses(
    run_qc.out.sceptre_object_ch_2,
    Channel.fromPath(params.response_odm_fp).first(),
    Channel.fromPath(params.grna_odm_fp).first()
  )

  // 8. run calibration check
  sceptre_object_ch_3 = prepare_association_analyses.out.sceptre_object_ch_3
  calibration_check_pods_ch = prepare_association_analyses.out.calibration_check_pods_ch.splitText().map{it.trim()}
  run_calibration_check_ch = prepare_association_analyses.out.run_calibration_check_ch.splitText().map{it.trim()}.first()
  run_calibration_check(
    sceptre_object_ch_3,
    Channel.fromPath(params.response_odm_fp).first(),
    Channel.fromPath(params.grna_odm_fp).first(),
    calibration_check_pods_ch,
    run_calibration_check_ch
  )
  
  // 9. process outputs from above process
  process_calibration_check_results(
    sceptre_object_ch_3,
    run_calibration_check.out.result_ch.collect(),
    run_calibration_check.out.precomputations_ch.collect(),
    run_calibration_check_ch
  )
}
