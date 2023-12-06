// PROCESS: run association analysis
process run_association_analysis {
  time {1.m * params.pair_pod_size}
  memory "4 GB"
  
  when:
  run_analysis == "true"
  
  input:
  path "sceptre_object_fp"
  path "response_odm_fp"
  path "grna_odm_fp"
  val "pair_pod"
  val "run_analysis"
  val "analysis_type"
  
  output:
  path "result.rds", emit: results_ch
  path "precomputations.rds", emit: precomputations_ch
  
  """
  run_association_analysis.R $sceptre_object_fp \
  $response_odm_fp \
  $grna_odm_fp \
  $pair_pod \
  $analysis_type
  """
}

// PROCESS: process association analysis results
process proces_association_analysis_results {
  debug true
  time "5m"
  memory "4 GB"
  publishDir "${params.output_directory}", mode: 'copy', overwrite: true, pattern: "*.png"
  publishDir "${params.output_directory}", mode: 'copy', overwrite: true, pattern: "*.txt"
  
  when:
  run_analysis == "true"

  input:
  path "sceptre_object_fp"
  path "results"
  path "precomputations"
  val "run_analysis"
  val "analysis_type"
  
  output:
  path "sceptre_object.rds", emit: sceptre_object_ch
  path "plot_run_calibration_check.png"
  path "analysis_summary.txt"
  
  """
  process_calibration_check_results.R $sceptre_object_fp \
  results* \
  precomputations*
  """
}

workflow run_analysis_subworkflow {
  take:
  sceptre_object_ch
  response_odm_fp_ch
  grna_odm_fp_ch
  pods_ch
  run_analysis_ch
  analysis_type

  main:
  run_association_analysis(
    sceptre_object_ch,
    response_odm_fp_ch,
    grna_odm_fp_ch,
    pods_ch,
    run_analysis_ch,
    analysis_type
  )
  proces_association_analysis_results(
    sceptre_object_ch,
    run_association_analysis.out.results_ch.collect(),
    run_association_analysis.out.precomputations_ch.collect(),
    run_analysis_ch,
    analysis_type
  )
  
  /*
  emit:
  proces_association_analysis_results.out.sceptre_object_ch
  */
}