// PROCESS: run association analysis
process run_association_analysis {
  time {1.s * params.pair_pod_size}
  memory params.association_analysis_mem

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
process process_association_analysis_results {
  time "20m"
  memory params.connecting_process_mem
  publishDir "${params.output_directory}", mode: 'copy', overwrite: true, pattern: "*.png"
  publishDir "${params.output_directory}", mode: 'copy', overwrite: true, pattern: "*.txt"
  publishDir "${params.output_directory}", mode: 'copy', overwrite: true, pattern: "results_*"

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
  path "results_*"
  path "*.png"
  path "analysis_summary.txt"

  """
  process_association_analysis_results.R $sceptre_object_fp \
  $analysis_type \
  results* \
  precomputations*
  """
}

// PROCESS: dummy channel
process dummy_process {
  when:
  run_analysis == "false"

  input:
  path "sceptre_object_fp"
  val "run_analysis"

  output:
  path "sceptre_object_fp", emit: sceptre_object_ch

  """
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
  process_association_analysis_results(
    sceptre_object_ch,
    run_association_analysis.out.results_ch.collect(),
    run_association_analysis.out.precomputations_ch.collect(),
    run_analysis_ch,
    analysis_type
  )
  dummy_process(
    sceptre_object_ch,
    run_analysis_ch
  )
  output_sceptre_ch = process_association_analysis_results.out.sceptre_object_ch.mix(dummy_process.out.sceptre_object_ch)

  emit:
  output_sceptre_ch
}
