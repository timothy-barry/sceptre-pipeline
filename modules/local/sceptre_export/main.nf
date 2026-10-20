process SCEPTRE_EXPORT {
    tag "${meta.id}:export"
    label 'process_single'
    cache 'deep'
    publishDir "${params.outdir}", mode: 'copy', overwrite: false

    input:
    tuple val(meta), path(state, name: 'input_state')
    path config, name: 'analysis_config.rds'
    path lock, name: 'environment_lock.rds'
    path backing, name: 'backing'
    path tools_dir, name: 'pipeline_bin'

    output:
    tuple val(meta), path('exports'), emit: exports

    script:
    """
    Rscript --vanilla pipeline_bin/export_state.R analysis_config.rds input_state environment_lock.rds backing
    """
}
