// use DSL 2
nextflow.enable.dsl = 2

/*************************
* DEFAULT PARAMETER VALUES
*************************/
// 1. pipeline meta params
params.pipeline_stop = "run_discovery_analysis"
params.trial = "false"
// 2. set analysis parameters
params.side = "default"
params.grna_integration_strategy = "default"
params.fit_parametric_curve = "default"
params.control_group = "default"
params.resampling_mechanism = "default"
params.multiple_testing_method = "default"
params.multiple_testing_alpha = "default"
params.formula_object = "${baseDir}/resources/placeholder_file.rds"
params.discovery_pairs = "${baseDir}/resources/placeholder_file.rds"
params.positive_control_pairs = "${baseDir}/resources/placeholder_file.rds"
// 3. gRNA assignment
params.grna_assignment_method = "default"
params.threshold = "default"
params.umi_fraction_threshold = "default"
params.n_em_rep = "default"
params.n_nonzero_cells_cutoff = "default"
params.backup_threshold = "default"
params.probability_threshold = "default"
params.grna_assignment_formula = "${baseDir}/resources/placeholder_file.rds"
// 4. QC
params.n_nonzero_trt_thresh = "default"
params.n_nonzero_cntrl_thresh = "default"
params.response_n_umis_range_lower = "default"
params.response_n_umis_range_upper = "default"
params.response_n_nonzero_range_lower = "default"
params.response_n_nonzero_range_upper = "default"
params.p_mito_threshold = "default"
// 5. calibration check
params.n_calibration_pairs = "default"
params.calibration_group_size = "default"
// 6. computation: parallelization
params.grna_pod_size = 150
params.pair_pod_size = 25000
// 7. computation: time
params.set_analysis_parameters_time = "15m" // set analysis parameters
params.prepare_assign_grnas_time = "15m" // prepare grna assignments
params.assign_grnas_time_per_grna = "5s" // assign grnas
params.combine_assign_grnas_time = "15m" // process grna assignments
params.run_qc_time = "60m" // run qc
params.prepare_association_analysis_time = "15m" // prepare association analyses
params.run_association_analysis_time_per_pair = "1s" // run association analysis
params.combine_association_analysis_time = "15m" // process association analysis
// 8. computation: memory
params.set_analysis_parameters_memory = "4GB" // set analysis parameters
params.prepare_assign_grnas_memory = "4GB" // prepare grna assignments
params.assign_grnas_memory = "4GB" // assign grnas
params.combine_assign_grnas_memory = "4GB"  // process grna assignments
params.run_qc_memory = "8GB" // run qc
params.prepare_association_analysis_memory = "4GB" // prepare association analyses
params.run_association_analysis_memory = "4GB" // run association analysis
params.combine_association_analysis_memory = "4GB" // process association analysis

/********************
* INCLUDE SUBWORKFLOW
*********************/
include { run_analysis_subworkflow as run_analysis_subworkflow_calibration_check } from './run_analysis_subworkflow.nf'
include { run_analysis_subworkflow as run_analysis_subworkflow_power_check } from './run_analysis_subworkflow.nf'
include { run_analysis_subworkflow as run_analysis_subworkflow_discovery_analysis } from './run_analysis_subworkflow.nf'

/*****************************
* GROOVY PROCESSING OF INPUTS
*****************************/
pipeline_steps = ["set_analysis_parameters", "assign_grnas", "run_qc", "run_calibration_check", "run_power_check", "run_discovery_analysis"]
// get the rank of the input params.pipeline_stop; throw an error if not present in the list
def step_rank = pipeline_steps.indexOf(params.pipeline_stop)
if (step_rank == -1) {
    throw new Exception("'$params.pipeline_stop' is not a step of the sceptre pipeline. The parameter 'pipeline_stop' should be set to one of 'assign_grnas', 'run_qc', 'run_calibration_check', 'run_power_check', or 'run_discovery_analysis'.")
}
if ("$params.trial" == "true") {
  println "Running pipeline in trial mode."
}
disc_pairs = params.discovery_pairs
nuclear = false
if ("$params.discovery_pairs" == "trans") {
  disc_pairs = "${baseDir}/resources/trans_placeholder.rds"
  nuclear = true
}

/**********
* PROCESSES
**********/
// PROCESS A: set analysis parameters
process set_analysis_parameters {
  publishDir "${params.output_directory}", mode: 'copy', overwrite: true, pattern: "*.txt"

  time params.set_analysis_parameters_time
  memory params.set_analysis_parameters_memory

  input:
  path "sceptre_object_fp"
  path "response_odm_fp"
  path "grna_odm_fp"
  path "formula_object"
  path "discovery_pairs"
  path "positive_control_pairs"

  output:
  path "sceptre_object.rds", emit: sceptre_object_ch
  path "analysis_summary.txt"

  """
  set_analysis_parameters.R $sceptre_object_fp \
  $response_odm_fp \
  $grna_odm_fp \
  ${params.side} \
  ${params.grna_integration_strategy} \
  ${params.fit_parametric_curve} \
  ${params.control_group} \
  ${params.resampling_mechanism} \
  ${params.multiple_testing_method} \
  ${params.multiple_testing_alpha} \
  $formula_object \
  $discovery_pairs \
  $positive_control_pairs \
  ${params.trial}
  """
}

// PROCESS B: output gRNA info
process prepare_assign_grnas {
  time params.prepare_assign_grnas_time
  memory params.prepare_assign_grnas_memory

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
  ${params.grna_pod_size} \
  ${params.trial}
  """
}

// PROCESS C: assign gRNAs
process assign_grnas {
  time {params.assign_grnas_time_per_grna * params.grna_pod_size}
  memory params.assign_grnas_memory

  when:
  !(params.grna_assignment_method == "maximum" || (low_moi == "true" && params.grna_assignment_method == "default"))

  input:
  path "sceptre_object_fp"
  path "response_odm_fp"
  path "grna_odm_fp"
  path "grna_to_pod_map"
  val "grna_pod"
  val "low_moi"
  path "grna_assignment_formula"

  output:
  path "grna_assignments.rds", emit: grna_assignments_ch
  path "grna_assignment_formula.rds", emit: grna_assignment_formula_ch

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
  ${params.probability_threshold} \
  $grna_assignment_formula
  """
}

// PROCESS D: process gRNA assignments
process combine_assign_grnas {
  publishDir "${params.output_directory}", mode: 'copy', overwrite: true, pattern: "*.png"
  publishDir "${params.output_directory}", mode: 'copy', overwrite: true, pattern: "*.txt"
  publishDir "${params.output_directory}", mode: 'copy', overwrite: true, pattern: "grna_assignment_matrix.rds"

  time params.combine_assign_grnas_time
  memory params.combine_assign_grnas_memory

  input:
  path "sceptre_object_fp"
  path "response_odm_fp"
  path "grna_odm_fp"
  path "grna_assignment_formula"
  path "grna_assignments"

  output:
  path "plot_grna_count_distributions.png"
  path "plot_assign_grnas.png"
  path "analysis_summary.txt"
  path "grna_assignment_matrix.rds"
  path "sceptre_object.rds", emit: sceptre_object_ch

  """
  process_grna_assignments.R $sceptre_object_fp \
  $response_odm_fp \
  $grna_odm_fp \
  ${params.grna_assignment_method} \
  ${params.umi_fraction_threshold} \
  $grna_assignment_formula \
  grna_assignments*
  """
}

// PROCESS E.1: quality control
process run_qc {
  publishDir "${params.output_directory}", mode: 'copy', overwrite: true, pattern: "*.png"
  publishDir "${params.output_directory}", mode: 'copy', overwrite: true, pattern: "*.txt"

  time params.run_qc_time
  memory params.run_qc_memory

  input:
  path "sceptre_object_fp"
  path "response_odm_fp"
  path "grna_odm_fp"

  output:
  path "plot_covariates.png"
  path "plot_run_qc.png"
  path "analysis_summary.txt"
  path "sceptre_object.rds", emit: sceptre_object_ch

  """
  run_qc.R $sceptre_object_fp \
  $response_odm_fp \
  $grna_odm_fp \
  ${params.n_nonzero_trt_thresh} \
  ${params.n_nonzero_cntrl_thresh} \
  ${params.response_n_umis_range_lower} \
  ${params.response_n_umis_range_upper} \
  ${params.response_n_nonzero_range_lower} \
  ${params.response_n_nonzero_range_upper} \
  ${params.p_mito_threshold}
  """
}

// PROCESS F.1: prepare association analysis
process prepare_association_analysis {
  time params.prepare_association_analysis_time
  memory params.prepare_association_analysis_memory

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
  path "sceptre_object.rds", emit: sceptre_object_ch

  """
  prepare_association_analyses.R $sceptre_object_fp \
  $response_odm_fp \
  $grna_odm_fp \
  ${params.n_calibration_pairs} \
  ${params.calibration_group_size} \
  ${params.pair_pod_size}
  """
}

// PROCESS E.2: nuclear quality control

// PROCESS F.2: nuclear prepare association analysis

// PROCESS G: nuclear association analysis

/***************
* MAIN WORKFLOW
***************/
workflow {
  // 0. set analysis parameters
  if (step_rank >= 0) {
    set_analysis_parameters(
      Channel.fromPath(params.sceptre_object_fp, checkIfExists : true),
      Channel.fromPath(params.response_odm_fp, checkIfExists : true),
      Channel.fromPath(params.grna_odm_fp, checkIfExists : true),
      Channel.fromPath(params.formula_object, checkIfExists : true),
      Channel.fromPath(disc_pairs, checkIfExists : true),
      Channel.fromPath(params.positive_control_pairs, checkIfExists : true)
    )
  }

  if (step_rank >= 1) {
  // 2. obtain the gRNA info
  prepare_assign_grnas(
    set_analysis_parameters.out.sceptre_object_ch.first(),
    Channel.fromPath(params.response_odm_fp, checkIfExists : true),
    Channel.fromPath(params.grna_odm_fp, checkIfExists : true)
  )

  // 3. process output from above process
  grna_to_pod_map_ch = prepare_assign_grnas.out.grna_to_pod_map_ch.first()
  grna_pods_ch = prepare_assign_grnas.out.grna_pods_ch.splitText().map{it.trim()}
  low_moi_ch = prepare_assign_grnas.out.low_moi_ch.splitText().map{it.trim()}.first()

  // 4. assign gRNAs
  assign_grnas(
    set_analysis_parameters.out.sceptre_object_ch.first(),
    Channel.fromPath(params.response_odm_fp).first(),
    Channel.fromPath(params.grna_odm_fp).first(),
    grna_to_pod_map_ch,
    grna_pods_ch,
    low_moi_ch,
    Channel.fromPath(params.grna_assignment_formula).first()
  )

  // 5. process output from above process
  grna_assignments_ch = assign_grnas.out.grna_assignments_ch.ifEmpty(params.sceptre_object_fp).collect()
  grna_assignment_formula_ch = assign_grnas.out.grna_assignment_formula_ch.first()

  // 6. process the gRNA assignments
  combine_assign_grnas(
    set_analysis_parameters.out.sceptre_object_ch.first(),
    Channel.fromPath(params.response_odm_fp).first(),
    Channel.fromPath(params.grna_odm_fp).first(),
    grna_assignment_formula_ch,
    grna_assignments_ch
  )
  }
  
  if (!nuclear) {
    if (step_rank >= 2) {
    // 7. run quality control
    run_qc(
      combine_assign_grnas.out.sceptre_object_ch,
      Channel.fromPath(params.response_odm_fp).first(),
      Channel.fromPath(params.grna_odm_fp).first(),
    )
    }

    if (step_rank >= 3) {
    // 8. prepare association analyses
    prepare_association_analysis(
      run_qc.out.sceptre_object_ch,
      Channel.fromPath(params.response_odm_fp).first(),
      Channel.fromPath(params.grna_odm_fp).first()
    )

    // 9. run calibration check
    calibration_check_pods_ch = prepare_association_analysis.out.calibration_check_pods_ch.splitText().map{it.trim()}
    run_calibration_check_ch = prepare_association_analysis.out.run_calibration_check_ch.splitText().map{it.trim()}.first()
    run_analysis_subworkflow_calibration_check(
      prepare_association_analysis.out.sceptre_object_ch,
      Channel.fromPath(params.response_odm_fp).first(),
      Channel.fromPath(params.grna_odm_fp).first(),
      calibration_check_pods_ch,
      run_calibration_check_ch,
      Channel.from("run_calibration_check").first()
    )
    }

    if (step_rank >= 4) {
    // 10. run power check
    power_check_pods_ch = prepare_association_analysis.out.power_check_pods_ch.splitText().map{it.trim()}
    run_power_check_ch = prepare_association_analysis.out.run_power_check_ch.splitText().map{it.trim()}.first()
    run_analysis_subworkflow_power_check(
      run_analysis_subworkflow_calibration_check.out.first(),
      Channel.fromPath(params.response_odm_fp).first(),
      Channel.fromPath(params.grna_odm_fp).first(),
      power_check_pods_ch,
      run_power_check_ch,
      Channel.from("run_power_check").first()
    )
    }

    if (step_rank >= 5) {
    // 11. run discovery analysis
    discovery_analysis_pods_ch = prepare_association_analysis.out.discovery_analysis_pods_ch.splitText().map{it.trim()}
    run_discovery_analysis_ch = prepare_association_analysis.out.run_discovery_analysis_ch.splitText().map{it.trim()}.first()
    run_analysis_subworkflow_discovery_analysis(
      run_analysis_subworkflow_power_check.out.first(),
      Channel.fromPath(params.response_odm_fp).first(),
      Channel.fromPath(params.grna_odm_fp).first(),
      discovery_analysis_pods_ch,
      run_discovery_analysis_ch,
      Channel.from("run_discovery_analysis").first()
    )
    } 
  } else { // going nuclear
    
  }
}
