nextflow.enable.dsl = 2

// Use the exact production process name and resource label, so the production
// Slurm profile selects this fixture in the same way as certified workers.
process SCEPTRE_WORKER {
    tag "${item}"
    label 'process_medium'
    array (workflow.profile.tokenize(',').contains('slurm') ? params.array_size : null)
    input:
    val item
    output:
    path "item_${item}.tsv", emit: rows
    script:
    """
    if [[ ${item} -eq ${params.fail_item} ]]; then
        echo ARRAY_SMOKE_CONTROLLED_FAILURE >&2
        exit 42
    fi
    printf '%s\t%s\t%s\n' '${item}' "\${SLURM_ARRAY_JOB_ID:-none}" "\${SLURM_ARRAY_TASK_ID:-none}" > item_${item}.tsv
    """
}

process SCEPTRE_COLLECT {
    label 'process_single'
    publishDir params.outdir, mode: 'copy', overwrite: false
    input:
    path rows
    output:
    path 'collected.tsv'
    script:
    """
    cat ${rows} | sort -n > collected.tsv
    """
}

workflow {
    if (!(params.n_items instanceof Integer) || params.n_items < 1)
        error 'n_items must be a positive integer.'
    if (!(params.array_size instanceof Integer) || params.array_size < 1)
        error 'array_size must be a positive integer.'
    SCEPTRE_WORKER(channel.fromList((1..params.n_items).toList()))
    SCEPTRE_COLLECT(SCEPTRE_WORKER.out.rows.toList())
}
