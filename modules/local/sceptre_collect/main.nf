process SCEPTRE_COLLECT {
    tag "${meta.id}:${stage}:collect"
    label 'process_medium'
    cache 'deep'
    publishDir "${params.outdir}/${stage}", mode: 'copy', overwrite: false
    input:
    tuple val(meta), path(state, name: 'input_state')
    path config, name: 'analysis_config.rds'
    path lock, name: 'environment_lock.rds'
    path backing, name: 'backing'
    path tools_dir, name: 'pipeline_bin'
    path execution, name: 'execution'
    path proposals, name: 'proposals/*'
    val stage
    val seed
    output:
    tuple val(meta), path('state'), emit: state
    path 'versions.yml', emit: versions
    script:
    """
    Rscript --vanilla pipeline_bin/distributed_stage.R collect analysis_config.rds input_state execution state '${stage}' '${seed}' 1 unused environment_lock.rds backing
    Rscript --vanilla pipeline_bin/versions.R environment_lock.rds
    """
}
