#!/usr/bin/env Rscript
# Bounded synthetic presentation regression; this never runs scientific inference.
args <- commandArgs(TRUE)
if (length(args) < 1L) stop('Usage: Rscript report/check-memory.R OUTPUT [N_ROWS] [render|baseline] [RENDERER]')
output <- args[1L]
n <- if (length(args) >= 2L) as.integer(args[2L]) else 100000L
mode <- if (length(args) >= 3L) args[3L] else 'render'
helper <- if (length(args) >= 4L) args[4L] else 'bin/scientific_report.R'
stopifnot(!dir.exists(output), !is.na(n), n > 100L, mode %in% c('render', 'baseline'))
dir.create(output, recursive = TRUE)
source(helper)
rows <- data.frame(grna_target = rep('target', n), response_id = sprintf('gene-%09d', seq_len(n)),
    p_value = rep(0.5, n), significant = rep(FALSE, n))
rows$response_id[n] <- 'TAIL_VALUE_MUST_STAY_IN_FULL_DATA'
rows$grna_target[1L] <- '<tag>&"'
pairs <- rows[c('grna_target', 'response_id')]
provenance <- list(plan = c(list(family = pairs), as.list(stats::setNames(rep(1L, 16L), paste0('field_', 1:16))),
    list(B1 = 499L, B2 = 4999L, B3 = 0L, eligible_pairs = n)), rng = seq_len(n))
data <- list(title = 'Bounded renderer regression', generated_utc = 'fixed',
    qc = list(imported_cells = n, retained_cells = n, excluded_cells = 0L,
        stages = c('cell_qc', 'pair_qc'), assignments = data.frame(guide = 'guide', assigned_cells = n),
        metrics = list(removed = integer()), families = data.frame(family = 'discovery', compiled_rows = n)),
    analyses = list(calibration = list(status = 'omitted', reason = 'test'),
        power = list(status = 'omitted', reason = 'test'),
        discovery = list(status = 'completed', table = rows, provenance = provenance)),
    plots = character(), warnings = list(), requested = list(discovery_pairs = pairs),
    resolved = list(discovery_pairs = pairs, multiple_testing_method = 'BH'),
    provenance = list(manifest = c(list(large_family = pairs), as.list(stats::setNames(rep(1L, 16L), paste0('field_', 1:16))),
        list(seed = 271828L, package = list(source_sha256 = 'SCIENTIFIC_SOURCE_IDENTITY')))))
frozen <- file.path(output, 'report-data.rds')
csv <- file.path(output, 'discovery.csv')
saveRDS(data, frozen)
utils::write.csv(report_scalar_table(rows), csv, row.names = FALSE)
hashes <- tools::md5sum(c(frozen, csv))
# Record only renderer allocations, after all complete inputs/downloads exist.
gc()
profile <- file.path(output, 'render-allocations.txt')
elapsed <- 0
if (mode == 'render') {
    Rprofmem(profile)
    elapsed <- system.time(scientific_report_html(data, file.path(output, 'report.html')))[['elapsed']]
    Rprofmem(NULL)
    html <- paste(readLines(file.path(output, 'report.html'), warn = FALSE), collapse = '\n')
    stopifnot(grepl(paste0('Showing the first 100 of ', n, ' rows'), html, fixed = TRUE),
        grepl('Bounded preview:', html, fixed = TRUE),
        all(vapply(c('B1 = 499L', 'B2 = 4999L', 'B3 = 0L', 'eligible_pairs', 'seed = 271828L',
            'SCIENTIFIC_SOURCE_IDENTITY', 'multiple_testing_method'), function(value) grepl(value, html, fixed = TRUE), logical(1))),
        grepl('&lt;tag&gt;&amp;&quot;', html, fixed = TRUE),
        !grepl('TAIL_VALUE_MUST_STAY_IN_FULL_DATA', html, fixed = TRUE),
        file.info(file.path(output, 'report.html'))$size < 150000L,
        identical(data$analyses$discovery$table$response_id[n], 'TAIL_VALUE_MUST_STAY_IN_FULL_DATA'))
    allocations <- suppressWarnings(as.numeric(sub(' .*', '', readLines(profile, warn = FALSE))))
    allocations <- allocations[is.finite(allocations)]
    stopifnot(max(allocations, 0) < 5000000L)
}
# Streaming CSV readback proves all rows (and the last value) remain downloadable.
connection <- file(csv, 'rt')
count <- 0L; last <- NULL
repeat {
    lines <- readLines(connection, n = 10000L, warn = FALSE)
    if (!length(lines)) break
    count <- count + length(lines); last <- utils::tail(lines, 1L)
}
close(connection)
stopifnot(count == n + 1L, grepl('TAIL_VALUE_MUST_STAY_IN_FULL_DATA', last, fixed = TRUE),
    identical(tools::md5sum(c(frozen, csv)), hashes))
metrics <- data.frame(rows = n, mode = mode,
    html_bytes = if (mode == 'render') file.info(file.path(output, 'report.html'))$size else 0,
    render_seconds = elapsed, max_render_allocation_bytes = if (mode == 'render') max(allocations, 0) else 0,
    total_render_allocated_bytes = if (mode == 'render') sum(allocations) else 0,
    frozen_bytes = file.info(frozen)$size, csv_bytes = file.info(csv)$size)
write.csv(metrics, file.path(output, 'metrics.csv'), row.names = FALSE)
print(metrics)
cat('PASS: bounded presentation; full frozen inputs and all CSV rows retained unchanged\n')
