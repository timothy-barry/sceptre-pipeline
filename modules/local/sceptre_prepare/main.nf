process SCEPTRE_PREPARE {
    tag "${meta.id}:${stage}:prepare"
    label 'process_single'
    cache 'deep'
    input:
    tuple val(meta), path(state, name: 'input_state')
    path config, name: 'analysis_config.rds'
    path lock, name: 'environment_lock.rds'
    path backing, name: 'backing'
    path tools_dir, name: 'pipeline_bin'
    val stage
    val seed
    val n_units
    output:
    path 'execution', emit: execution
    path 'execution/unit_ids.txt', emit: units
    path 'versions.yml', emit: versions
    script:
    """
    Rscript --vanilla pipeline_bin/distributed_stage.R prepare analysis_config.rds input_state unused execution '${stage}' '${seed}' '${n_units}' unused environment_lock.rds backing
    Rscript --vanilla pipeline_bin/versions.R environment_lock.rds
    """
}
