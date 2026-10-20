# Read-only support guidance. Never retry, select a method, or alter a budget.
# Keep the original package error verbatim; suggestions are conditional checks.
pipeline_recovery_hint <- function(message, stage = NULL) {
    matches <- function(pattern) grepl(pattern, message, ignore.case = TRUE, perl = TRUE)
    hints <- character()
    if (matches("non-targeting|negative control|calibration_group_size"))
        hints <- c(hints, "Inspect non-targeting guide labels, assignment membership and retained cells in the saved QC state. Calibration needs active controls after QC, not just metadata rows. Check calibration_group_size against those active guides and the intended control design. Calibration may be omitted explicitly with --analyses power,discovery (or discovery) if that is the intended analysis; omission supplies no calibration evidence.")
    if (matches("Zero pairs pass|no eligible|zero eligible|pairs have not been supplied"))
        hints <- c(hints, "Inspect the requested target/response IDs and the saved pair-QC table, including pass_qc and treatment/control nonzero counts. An empty family is not a completed negative result. Correct input/assignment errors or reconsider scientifically justified eligibility criteria; do not relax QC solely to obtain discoveries. Omit an unrequested power/discovery stage explicitly with --analyses.")
    if (matches("align|cell.*(order|identit)|barcode|column names.*match"))
        hints <- c(hints, "Verify exact cell IDs and order across response counts, guide counts, covariate rows and external assignments, plus feature/guide metadata IDs. Reorder from verified identifiers before import; renaming mismatched columns does not align cells. Preserve full-library covariates when subsetting features.")
    if (matches("backed|ondisc|count.store|backing"))
        hints <- c(hints, "Inspect the supported storage/mode boundary in docs/usage.md and docs/scale-boundaries.md. Backed inputs require closed descriptors and identity-matched response.odm/grna.odm files staged with --backing_directory. Do not switch CRT to permutations as an automatic recovery; it changes the scientific method.")
    if (matches("identity mismatch|configuration mismatch|checksum mismatch|different run|RNG handoff"))
        hints <- c(hints, "For an unchanged run, retain the original input/config/lock, run signature and Nextflow cache/work directories and use the exact session with -resume. Changed source, runtime, settings or seed requires a new input/lock as applicable and fresh --outdir; never replace a lock or checksum inside an old bundle.")
    paste(unique(hints), collapse = "\n")
}
report_pipeline_failure <- function(condition, stage = NULL, prefix = "SCEPTRE stage failed") {
    message(prefix, ": ", conditionMessage(condition))
    hint <- pipeline_recovery_hint(conditionMessage(condition), stage)
    if (nzchar(hint)) message("Recovery checks (no settings changed): ", hint)
    message("Inspect this task's .command.err/.command.log and the Nextflow trace for the original failure. Earlier certified stages may remain available; a failed family is incomplete. See docs/recovery.md.")
    invisible(NULL)
}
