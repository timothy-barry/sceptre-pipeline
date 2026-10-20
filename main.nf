nextflow.enable.dsl = 2
include { validateParameters; paramsHelp } from 'plugin/nf-schema'
include { SCEPTRE } from './subworkflows/local/sceptre/main'

// Nextflow configFiles omits nested includeConfig files. Resolve a conservative,
// local literal include closure ourselves; reject dynamic includes rather than
// allowing an execution-config change to evade the publication identity.
def configClosure(List roots, List productionSources) {
    def seen = new LinkedHashSet()
    def visit
    visit = { path ->
        path = path.toAbsolutePath().normalize()
        if (!seen.add(path)) return
        if (path in productionSources) return
        if (!java.nio.file.Files.isRegularFile(path))
            error 'Configuration identity requires readable local configuration files.'
        def source = path.text
        def mentions = (source =~ /\bincludeConfig\b/).count
        def includes = (source =~ /(?m)^\s*includeConfig\s*(?:\(\s*)?(['"])([^'"\r\n$]+)\1\s*\)?\s*(?:;\s*)?(?:\/\/[^\r\n]*)?$/)
        def matched = 0
        includes.each { match ->
            matched++
            def child = java.nio.file.Paths.get(match[2])
            if (!child.isAbsolute()) child = path.parent.resolve(child)
            visit(child)
        }
        if (mentions != matched)
            error 'Configuration identity supports only standalone literal local includeConfig paths (without interpolation). Rewrite dynamic/conditional includes as literal configuration files before running.'
    }
    roots.each { visit(it) }
    seen.toList().sort { it.toString() }
}

// Hash local SIF images in bounded memory before any task is admitted.
def imageSha256(java.nio.file.Path path) {
    def digest = java.security.MessageDigest.getInstance('SHA-256')
    def stream = java.nio.file.Files.newInputStream(path)
    try {
        def buffer = new byte[1024 * 1024]
        int count
        while ((count = stream.read(buffer)) != -1) digest.update(buffer, 0, count)
    } finally {
        stream.close()
    }
    digest.digest().encodeHex().toString()
}

workflow {
    if (params.help) {
        log.info 'nextflow run . --input_bundle BUNDLE --analysis_config CONFIG --environment_lock LOCK --outdir RESULTS'
        log.info paramsHelp()
    } else {
        validateParameters()
        def profiles = workflow.profile.tokenize(',')
        if (profiles.any { it in ['docker','apptainer'] } && !params.container_image)
            error 'The docker/apptainer profiles require --container_image.'
        def immutableOci = params.container_image && (params.container_image ==~ /[A-Za-z0-9._:\/-]+@sha256:[a-f0-9]{64}/ || params.container_image ==~ /sha256:[a-f0-9]{64}/)
        if (params.container_image && !immutableOci) {
            if (!params.container_image.endsWith('.sif'))
                error 'container_image must be an immutable image digest (registry/name@sha256:... or local sha256:...), or an absolute checksum-qualified .sif path under the apptainer profile.'
            if (!profiles.contains('apptainer') || profiles.contains('docker'))
                error 'SIF images require the apptainer profile without the docker profile.'
            def sif = java.nio.file.Paths.get(params.container_image)
            if (!sif.isAbsolute()) error 'SIF path must be absolute.'
            if (!java.nio.file.Files.isRegularFile(sif)) error 'SIF path must name an existing regular .sif file.'
            if (!params.container_image_sha256) error 'container_image_sha256 is required for a local SIF image.'
            if (imageSha256(sif) != params.container_image_sha256) error 'SIF SHA256 mismatch: container bytes differ from container_image_sha256.'
        } else if (params.container_image_sha256) {
            error 'container_image_sha256 applies only to local SIF images.'
        }
        def selected = params.analyses ? params.analyses.split(',').toList() : []
        if (selected.toSet().size() != selected.size() || selected.any { !(it in ['calibration','power','discovery']) })
            error 'analyses must contain unique comma-separated calibration,power,discovery names, or an empty string.'
        def signature = file("${params.outdir}/run_signature.rds")
        def occupied = ['parameters','assignment','qc','calibration','power','discovery','exports'].any {
            file("${params.outdir}/${it}").exists()
        }
        if (occupied && !signature.exists())
            error 'Output directory already contains scientific outputs without a compatible run signature. Use a fresh --outdir.'
        // Bind production workflow/module/config/helper bytes, including resolved
        // external configuration files. Keep order stable across checkout relocation.
        def projectSources = ([file("${projectDir}/main.nf"), file("${projectDir}/nextflow.config"),
            file("${projectDir}/nextflow_schema.json")] +
            file("${projectDir}/bin/*.R") + file("${projectDir}/conf/*.config") +
            file("${projectDir}/modules/**/*.nf") + file("${projectDir}/subworkflows/**/*.nf"))
            .flatten().unique().sort { it.toString() }
        def externalConfigs = configClosure(workflow.configFiles.findAll { !(it in projectSources) }, projectSources).findAll { !(it in projectSources) }
        // External site configuration may contain credentials: bind its bytes
        // without mounting or copying it into an R worker/container.
        def externalConfigDigests = externalConfigs.collect {
            java.security.MessageDigest.getInstance('SHA-256').digest(it.bytes).encodeHex().toString()
        }
        def runOptions = groovy.json.JsonOutput.toJson([
            session_id: workflow.sessionId.toString(), external_config_sha256: externalConfigDigests, analyses: selected, stop_after: params.stop_after,
            seed: params.seed, container_image: params.container_image, container_image_sha256: params.container_image_sha256, execution_mode: params.execution_mode, n_work_units: params.n_work_units, array_size: params.array_size
        ])
        SCEPTRE(
            channel.value(tuple([id: 'screen'], file(params.input_bundle, checkIfExists: true))),
            channel.value(file(params.analysis_config, checkIfExists: true)),
            channel.value(file(params.environment_lock, checkIfExists: true)),
            channel.value(file(params.backing_directory, checkIfExists: true)),
            channel.value(file("${projectDir}/bin", checkIfExists: true)),
            channel.value(signature.exists() ? signature : file("${projectDir}/resources/no_previous_run.rds")),
            runOptions, channel.value(projectSources), selected, params.stop_after, params.seed, params.execution_mode, params.n_work_units
        )
    }
}
