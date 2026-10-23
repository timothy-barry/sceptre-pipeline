# Pipeline-owned reporting: all scientific values come from saved public results.
# Rendering this value bundle never invokes a SCEPTRE analysis.
report_escape <- function(x) {
    x <- gsub('&', '&amp;', as.character(x), fixed = TRUE)
    x <- gsub('<', '&lt;', x, fixed = TRUE)
    x <- gsub('>', '&gt;', x, fixed = TRUE)
    gsub('"', '&quot;', x, fixed = TRUE)
}
# Schema2 freezes only bounded previews; complete scientific values/provenance
# remain in complete CSV/native exports and original config/manifest files.
report_preview <- function(x, depth = 0L, budget = NULL) {
    if (is.null(budget)) { budget <- new.env(parent = emptyenv()); budget$remaining <- 512L }
    if (budget$remaining <= 0L) return('<preview entry budget exhausted; see frozen report inputs>')
    budget$remaining <- budget$remaining - 1L
    if (inherits(x, 'formula')) return(substr(paste(deparse(x, width.cutoff = 500L, nlines = 12L), collapse = ' '), 1L, 500L))
    if (is.object(x) && is.list(x) && !is.data.frame(x) && !isS4(x))
        return(paste0('<opaque ', substr(paste(utils::head(class(x), 3L), collapse = '/'), 1L, 500L), ' object omitted; see native export>'))
    if (depth >= 5L && (is.list(x) || isS4(x))) return('<nested content omitted; see frozen report inputs>')
    if (isS4(x)) return(report_preview(stats::setNames(lapply(methods::slotNames(x),
        function(name) methods::slot(x, name)), methods::slotNames(x)), depth + 1L, budget))
    if (is.data.frame(x)) {
        out <- lapply(x[seq_len(min(nrow(x), 12L)), seq_len(min(ncol(x), 12L)), drop = FALSE],
            function(value) report_preview(value, depth + 1L, budget))
        return(list(dimensions = c(rows = nrow(x), columns = ncol(x)), first_rows_and_columns = out))
    }
    if (is.list(x)) {
        count <- length(x)
        # Standard settings/manifest structures have fewer than 64 fields.
        # Show their short scalar settings first, so a large canonical family
        # cannot consume the preview budget before budgets/seed/identity appear.
        candidates <- seq_len(min(count, 64L))
        scalar <- vapply(x[candidates], function(value) is.atomic(value) &&
            is.null(dim(value)) && length(value) <= 12L, logical(1))
        nested <- candidates[!scalar]
        metadata <- if (is.null(names(x))) integer() else nested[grepl(
            '^(plan|spec|manifest|qualified_source|package|identity|analysis|assignment|qc|execution|calibration)$', names(x)[nested])]
        selected <- c(candidates[scalar], utils::head(unique(c(metadata, nested)), 12L))
        out <- lapply(x[selected], function(value) report_preview(value, depth + 1L, budget))
        if (!is.null(names(out))) names(out) <- substr(names(out), 1L, 500L)
        if (count > length(selected)) out[['... omitted entries']] <- count - length(selected)
        return(out)
    }
    # Drop large attributes and matrix payloads before printing. Only previews
    # are reduced; no altered value is written back into the frozen bundle.
    if (is.atomic(x)) {
        count <- length(x)
        out <- as.vector(x[seq_len(min(length(x), 12L))])
        if (is.character(out)) out <- ifelse(nchar(out) > 500L,
            paste0(substr(out, 1L, 500L), ' ... [text truncated]'), out)
        if (count > 12L || !is.null(dim(x))) return(list(length = count,
            dimensions = dim(x), first_values = out))
        return(out)
    }
    if (is.null(x)) return(NULL)
    '<value omitted; see frozen report inputs>'
}
report_text <- function(x) {
    text <- paste(capture.output(dput(report_preview(x))), collapse = '\n')
    if (nchar(text) > 20000L) paste0(substr(text, 1L, 20000L), '\n... [preview text truncated; see frozen report inputs]') else text
}
report_scalar_table <- function(x, max_rows = NULL) {
    if (!is.data.frame(x)) return(data.frame())
    if (!is.null(max_rows)) x <- x[seq_len(min(nrow(x), max_rows)), , drop = FALSE]
    x <- as.data.frame(x)
    keep <- vapply(x, function(y) is.atomic(y) && is.null(dim(y)), logical(1))
    as.data.frame(x[, names(x)[keep], drop = FALSE])
}
scientific_report_html <- function(data, output, fragment = FALSE) {
    esc <- report_escape
    count_text <- function(value) format(value, scientific = FALSE, trim = TRUE)
    bounded <- identical(data$report_schema, 2L)
    complete_location <- if (bounded) 'Complete scalar rows are retained in the CSV downloads; complete native columns and analysis provenance are retained in each linked native export manifest.' else 'Complete scalar columns are retained in the CSV downloads, and all values in the frozen report inputs.'
    table_html <- function(x, total_rows = NULL) {
        total <- if (!is.null(total_rows)) total_rows else if (is.data.frame(x)) nrow(x) else 0L
        omitted <- if (is.data.frame(x)) setdiff(names(x), names(report_scalar_table(x, max_rows = 0L))) else character()
        x <- report_scalar_table(x, max_rows = 100L)
        if (!nrow(x)) return(if (total > 0) paste0('<p class="empty">No rows included in this preview; ', count_text(total), ' complete saved rows remain available in the export.</p>') else '<p class="empty">No rows available.</p>')
        x[] <- lapply(x, function(column) {
            text <- as.character(column)
            ifelse(nchar(text) > 500L, paste0(substr(text, 1L, 500L), ' ... [text truncated]'), text)
        })
        rows <- apply(x, 1L, function(row) paste0('<tr>', paste0('<td>', esc(row), '</td>', collapse = ''), '</tr>'))
        paste0('<p class="preview">', if (total > nrow(x)) paste0('Showing the first ', nrow(x), ' of ', count_text(total),
            paste0(' rows in saved order. Preview truncated. ', complete_location)) else paste0('Showing all ', count_text(total), ' rows.'),
            '</p>', if (length(omitted)) paste0('<p class="preview">Non-scalar columns omitted from this HTML table and CSV: ', esc(paste(omitted, collapse = ', ')), '. Complete values are retained in the linked native result RDS files.</p>'), '<div class="table-wrap"><table><thead><tr>', paste0('<th>', esc(names(x)), '</th>', collapse = ''),
            '</tr></thead><tbody>', paste(rows, collapse = ''), '</tbody></table></div>')
    }
    code <- function(x) paste0('<p class="preview">Bounded preview: up to 64 short scalar settings and 12 other entries or rows per field, 5 nested levels, 512 visited entries, 500 characters per text value and 20,000 displayed characters. Complete settings and provenance are in the original configuration/manifest files and scientific exports; the report view is bounded.</p><pre>', esc(report_text(x)), '</pre>')
    result_section <- function(key, title, description) {
        result <- data$analyses[[key]]
        if (!identical(result$status, 'completed')) return(paste0('<section id="', key, '"><h2>', title,
            '</h2><p class="empty">', esc(result$status), ': ', esc(result$reason), '</p></section>'))
        total <- if (!is.null(result$total_rows)) result$total_rows else nrow(result$table)
        significant <- if (!is.null(result$significant_count)) result$significant_count else
            if ('significant' %in% names(result$table)) sum(result$table$significant, na.rm = TRUE) else NA_integer_
        download <- if (!is.null(result$download)) result$download else paste0('tables/', key, '.csv')
        omission <- if (!is.null(result$omitted_column_count) && result$omitted_column_count > 0L)
            paste0('<p class="preview">', result$omitted_column_count,
                if (result$omitted_column_count == 1L) ' column omitted from the preview' else ' columns omitted from the preview',
                if (length(result$omitted_columns)) paste0(' (up to 12 named here): ', esc(paste(result$omitted_columns, collapse = ', '))) else ' (names not retained in this bounded header)',
                '. Consult the complete export manifest for scalar CSV and native-column availability.</p>') else ''
        paste0('<section id="', key, '"><h2>', title, '</h2><p>', description, '</p><p><strong>', count_text(total),
            ' returned rows</strong>', if (!is.na(significant)) paste0('; ', count_text(significant), ' marked significant by SCEPTRE in the complete family.') else '.',
            if (!total) ' Completed with no returned rows; this is not evidence of no effects.' else '',
            '</p>', if (bounded) '<p class="preview">Counts above describe the complete saved family, including rows outside the deterministic preview.</p>',
            if (is.character(result$method) && length(result$method) == 1L) paste0('<p>Saved method: <strong>', esc(result$method), '</strong>.</p>'),
            '<p><a href="', esc(download), '">Download complete scalar result columns (CSV)</a>', if (!is.null(result$native_result)) paste0(' · <a href="', esc(result$native_result), '">Download complete native result (RDS)</a>'), '</p>',
            if (!is.null(result$export_receipt)) paste0('<details><summary>Complete export row count and streaming hash</summary>', code(result$export_receipt), '</details>'),
            if (!is.null(result$native_export)) paste0('<p><a href="', esc(result$native_export$manifest), '">Complete native result and analysis provenance manifest</a> · SHA256 ', esc(result$native_export$sha256), '</p>'),
            table_html(result$table, total), omission, if (!is.null(result$summary)) paste0('<details><summary>Exact complete-family summary and method</summary>', code(result$summary), '</details>'), '<details><summary>Frozen family settings and realized resampling budgets</summary>', code(result$provenance), '</details></section>')
    }
    provenance_links <- if (bounded) paste0('<p><a href="report-data.rds">Bounded frozen report view (RDS)</a> · <a href="export-manifests.rds">Complete CSV export manifests</a>',
        if ('manifest.rds' %in% data$complete_provenance_files) ' · <a href="manifest.rds">Original pipeline manifest</a>',
        if ('requested-config.rds' %in% data$complete_provenance_files) ' · <a href="requested-config.rds">Original requested configuration</a>',
        ' · <a href="render.R">Editable renderer</a> · <a href="rerender.R">Rerender entry point</a> · <a href="report.qmd">Quarto source</a></p>') else
        '<p><a href="report-data.rds">Frozen report inputs (RDS)</a> · <a href="manifest.rds">Pipeline manifest</a> · <a href="requested-config.rds">Requested configuration</a> · <a href="render.R">Editable renderer</a> · <a href="report.qmd">Quarto source</a></p>'

    body <- paste0('<header><p class="eyebrow">SCEPTRE · SCIENTIFIC RESULTS</p><h1>', esc(data$title), '</h1>',
        '<p>Saved analysis results, quality control and reproducibility record.</p><p class="stamp">', esc(data$generated_utc), '</p></header>',
        '<nav><a href="#qc">Assignment &amp; QC</a><a href="#calibration">Calibration</a><a href="#power">Positive controls</a><a href="#discovery">Discovery</a><a href="#settings">Settings</a><a href="#provenance">Provenance</a></nav>',
        '<main><aside>This scientific report is distinct from the Nextflow execution report. Statistical associations do not establish biological mechanisms. Calibration is optional and is not a prerequisite for discovery.</aside>',
        '<section id="qc"><h2>Assignment and quality control</h2><div class="cards"><div><b>', data$qc$imported_cells,
        '</b><span>Imported cells</span></div><div><b>', data$qc$retained_cells, '</b><span>Cells retained for analysis</span></div><div><b>',
        data$qc$excluded_cells, '</b><span>Excluded cells</span></div></div><p>Completed preparation stages: ', esc(paste(data$qc$stages, collapse = ', ')),
        '.</p><h3>Assignment membership counts</h3>', table_html(data$qc$assignments, data$qc$assignment_total_rows),
        '<h3>Exclusions and retention metrics</h3>', code(data$qc$metrics),
        '<p>Exclusion categories may overlap; membership counts are not disjoint in high-MOI screens. Counts below describe the saved QC state, not a new filtering procedure.</p>',
        '<h3>Hypothesis-family QC</h3>', table_html(data$qc$families), '</section>',
        result_section('calibration', 'Calibration check', 'Negative-control associations characterize calibration for the sampled control family; this is not proof of calibration for every target.'),
        result_section('power', 'Power / positive controls', 'Observed positive-control results describe the supplied control pairs. They are not a general power guarantee for untested effects.'),
        result_section('discovery', 'Discovery analysis', 'Significance flags are copied from the completed SCEPTRE result after its complete-family integration and correction. Failed-QC requests remain visible where supplied by the public output.'),
        '<section><h2>Figures</h2>', if (length(data$plots)) paste(vapply(data$plots, function(x) paste0('<figure><a href="plots/', esc(basename(x)), '"><img src="plots/', esc(basename(x)), '" alt="', esc(basename(x)), '"></a><figcaption><a href="plots/', esc(basename(x)), '">Open full-size figure</a> · ', esc(if (!is.null(data$plot_captions[[basename(x)]])) data$plot_captions[[basename(x)]] else basename(x)), '</figcaption></figure>'), character(1)), collapse = '') else '<p class="empty">No exported figures available for these completed stages.</p>', '</section>',
        '<section><h2>Warnings and availability</h2><p>Capture scope: reference-stage warnings are structured below. Structured aggregation of distributed worker warnings is unavailable; those warnings remain in the execution logs. An empty captured list does not establish that distributed execution emitted no warnings.</p>', if (length(data$warnings)) code(data$warnings) else '<p>No warnings were captured by this pipeline run. This is not a guarantee that upstream imports emitted none.</p>',
        '<p>Omitted, empty and unavailable stages are identified explicitly above. A report-rendering problem does not revoke an already certified scientific artifact.</p></section>',
        '<section id="settings"><h2>Requested versus resolved settings</h2><h3>Requested pipeline configuration</h3>', code(data$requested),
        '<h3>Resolved saved scientific settings</h3>', code(data$resolved),
        '<p>Requested canonical pairs define the target–response family; guide-group expansion and QC may produce a different number of working rows. Bonferroni guide integration and multiple-testing correction retain the package’s complete-family policy; this renderer does not recompute p-values or correction.</p></section>',
        '<section id="provenance"><h2>Exact provenance</h2><p>Seed, RNG handoff, package/runtime identity and parent/object checksums are retained in the manifest. Realized budgets and frozen choices appear under each completed analysis.</p>',
        code(data$provenance), provenance_links, '</section></main><footer>Generated locally from saved SCEPTRE outputs. No analysis is rerun when rendering this bundle.</footer>')
    style <- '<style>:root{font-family:system-ui,-apple-system,sans-serif;color:#20313a;background:#f2f5f4}body{margin:0}header,main,nav,footer{max-width:1120px;margin:auto;padding:24px 32px}header{padding-top:55px}h1{font-family:Georgia,serif;font-size:44px;line-height:1.1;margin:12px 0}h2{font-family:Georgia,serif;font-size:29px}h3{font-size:18px}p,li{line-height:1.65;overflow-wrap:anywhere}a{color:#086c70}.eyebrow{font-size:12px;letter-spacing:2px;color:#086c70;font-weight:700}.stamp,footer{font-size:13px;color:#53666b}nav{display:flex;flex-wrap:wrap;gap:20px;border-top:1px solid #c5d3d0;border-bottom:1px solid #c5d3d0}section{padding:20px 0;border-bottom:1px solid #d0dcda}aside{padding:20px;background:#e4eeeb;border-left:4px solid #087c77;line-height:1.6}.cards{display:flex;flex-wrap:wrap;gap:18px}.cards div{background:white;border:1px solid #cddbd7;border-radius:8px;padding:20px;min-width:170px}.cards b{display:block;font-size:30px;color:#086c70}.cards span{font-size:14px}.table-wrap{max-height:420px;overflow:auto;background:white;border:1px solid #cddbd7}table{border-collapse:collapse;width:100%;font-size:13px}th,td{padding:10px 12px;border-bottom:1px solid #dde5e2;text-align:left;white-space:nowrap}th{position:sticky;top:0;background:#dceae6}tr:nth-child(even){background:#f7faf8}pre{font-size:12px;line-height:1.5;white-space:pre-wrap;overflow-wrap:anywhere;background:#e8eeeb;padding:16px;max-height:500px;overflow:auto}summary{cursor:pointer;padding:14px 0;font-weight:600}.empty{color:#65777c}img{max-width:100%;max-height:560px;object-fit:contain;background:white}figure{margin:20px 0}figcaption{font-size:12px;color:#64777b}@media(max-width:600px){header,main,nav,footer{padding:20px}h1{font-size:34px}.cards div{min-width:120px}}</style>'
    html <- if (fragment) paste0(style, body) else paste0('<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>', esc(data$title), '</title>', style, '</head><body>', body, '</body></html>')
    if (!is.null(output)) writeLines(html, output, useBytes = TRUE)
    invisible(html)
}
# Convert report metadata to base-R values so standalone rendering loads no package.
report_saved_value <- function(x) {
    if (inherits(x, "formula")) return(paste(deparse(x), collapse = " "))
    if (isS4(x)) return(stats::setNames(lapply(methods::slotNames(x), function(name)
        report_saved_value(methods::slot(x, name))), methods::slotNames(x)))
    if (is.data.frame(x)) return(as.data.frame(x))
    if (is.list(x)) return(lapply(x, report_saved_value))
    x
}
# Freeze public schema-7 results. Rendering reads these saved values only.
export_scientific_report <- function(object, manifest, config, directory, helper_path,
    renderer = scientific_report_html, source_files = list()) {
    stopifnot(identical(object@schema_version, 7L))
    dir.create(file.path(directory, "tables"), recursive = TRUE, showWarnings = FALSE)
    analyses <- c(calibration = "run_calibration_check", power = "run_power_check",
        discovery = "run_discovery_analysis")
    results <- lapply(names(analyses), function(stage) {
        if (!stage %in% manifest$completed) return(list(status = "omitted", reason = "Stage was not selected."))
        table <- sceptre::get_result(object, analyses[[stage]])
        utils::write.csv(report_scalar_table(table), file.path(directory, "tables", paste0(stage, ".csv")), row.names = FALSE)
        saveRDS(table, file.path(directory, "tables", paste0(stage, ".rds")))
        list(status = "completed", total_rows = nrow(table), table = utils::head(as.data.frame(table), 100L),
            native_result = paste0("tables/", stage, ".rds"),
            significant_count = if ("significant" %in% names(table)) sum(table$significant, na.rm = TRUE) else NA_integer_,
            provenance = report_saved_value(object@results[[sub("^run_", "", analyses[[stage]])]]$provenance))
    })
    names(results) <- names(analyses)
    imported <- ncol(sceptre::get_screen_experiment(object))
    retained <- if ("qc" %in% manifest$completed) length(object@preparation@analysis_cells) else imported
    assignments <- if ("assignment" %in% manifest$completed) sceptre::get_grna_assignments(object) else NULL
    counts <- if (!is.null(assignments)) data.frame(grna_group = rownames(assignments), cells = as.numeric(Matrix::rowSums(assignments))) else data.frame()
    data <- list(report_schema = 1L, title = "SCEPTRE scientific results",
        generated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
        analyses = results, qc = list(imported_cells = imported, retained_cells = retained,
            excluded_cells = imported - retained, stages = intersect(manifest$completed, c("parameters", "assignment", "qc")),
            assignments = utils::head(counts, 100L), assignment_total_rows = nrow(counts),
            families = data.frame(), metrics = object@preparation@cell_removal_metrics),
        plots = character(), warnings = manifest$warnings, requested = config,
        resolved = stats::setNames(lapply(methods::slotNames(object@spec), function(name) methods::slot(object@spec, name)), methods::slotNames(object@spec)), provenance = list(manifest = manifest))
    saveRDS(data, file.path(directory, "report-data.rds"))
    saveRDS(manifest, file.path(directory, "manifest.rds"))
    saveRDS(config, file.path(directory, "requested-config.rds"))
    sceptre::write_sceptre_object(object, file.path(directory, "sceptre_object.rds"))
    file.copy(helper_path, file.path(directory, "render.R"), overwrite = TRUE)
    writeLines(c('source("render.R")', 'scientific_report_html(readRDS("report-data.rds"), "report.html")'), file.path(directory, "rerender.R"))
    writeLines(c('---', 'title: "SCEPTRE scientific results"', 'format: html', '---',
        '```{r}', 'source("render.R")', 'cat(scientific_report_html(readRDS("report-data.rds"), NULL, fragment = TRUE))', '```'), file.path(directory, "report.qmd"))
    renderer(data, file.path(directory, "report.html"))
    invisible(data)
}
write_scientific_report_safely <- function(object, manifest, config, directory, helper_path,
    renderer = scientific_report_html) {
    dir.create(directory, recursive = TRUE, showWarnings = FALSE)
    tryCatch({
        export_scientific_report(object, manifest, config, directory, helper_path, renderer)
        jsonlite::write_json(list(status = "completed", artifact = "report.html"),
            file.path(directory, "report-status.json"), auto_unbox = TRUE, pretty = TRUE)
        invisible(TRUE)
    }, error = function(condition) {
        jsonlite::write_json(list(status = "failed", reason = conditionMessage(condition)),
            file.path(directory, "report-status.json"), auto_unbox = TRUE, pretty = TRUE)
        message("Scientific report unavailable: ", conditionMessage(condition))
        invisible(FALSE)
    })
}
