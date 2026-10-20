# Pipeline-owned reporting: all scientific values come from saved public results.
# Rendering this value bundle never invokes a SCEPTRE analysis.
report_escape <- function(x) {
    x <- gsub('&', '&amp;', as.character(x), fixed = TRUE)
    x <- gsub('<', '&lt;', x, fixed = TRUE)
    x <- gsub('>', '&gt;', x, fixed = TRUE)
    gsub('"', '&quot;', x, fixed = TRUE)
}
# Only the HTML view is bounded. Complete scientific tables/settings/provenance
# remain in report-data.rds and the complete scalar-column CSV downloads.
report_preview <- function(x, depth = 0L, budget = NULL) {
    if (is.null(budget)) { budget <- new.env(parent = emptyenv()); budget$remaining <- 512L }
    if (budget$remaining <= 0L) return('<preview entry budget exhausted; see frozen report inputs>')
    budget$remaining <- budget$remaining - 1L
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
    table_html <- function(x) {
        total <- if (is.data.frame(x)) nrow(x) else 0L
        x <- report_scalar_table(x, max_rows = 100L)
        if (!nrow(x)) return('<p class="empty">No rows available.</p>')
        x[] <- lapply(x, function(column) {
            text <- as.character(column)
            ifelse(nchar(text) > 500L, paste0(substr(text, 1L, 500L), ' ... [text truncated]'), text)
        })
        rows <- apply(x, 1L, function(row) paste0('<tr>', paste0('<td>', esc(row), '</td>', collapse = ''), '</tr>'))
        paste0('<p class="preview">', if (total > nrow(x)) paste0('Showing the first ', nrow(x), ' of ', total,
            ' rows in saved order. Preview truncated; complete values are retained in the CSV downloads and frozen report inputs.') else paste0('Showing all ', total, ' rows.'),
            '</p><div class="table-wrap"><table><thead><tr>', paste0('<th>', esc(names(x)), '</th>', collapse = ''),
            '</tr></thead><tbody>', paste(rows, collapse = ''), '</tbody></table></div>')
    }
    code <- function(x) paste0('<p class="preview">Bounded preview: up to 64 short scalar settings and 12 other entries or rows per field, 5 nested levels, 512 visited entries, 500 characters per text value and 20,000 displayed characters. Complete settings and provenance are in the frozen report inputs.</p><pre>', esc(report_text(x)), '</pre>')
    result_section <- function(key, title, description) {
        result <- data$analyses[[key]]
        if (!identical(result$status, 'completed')) return(paste0('<section id="', key, '"><h2>', title,
            '</h2><p class="empty">', esc(result$status), ': ', esc(result$reason), '</p></section>'))
        significant <- if ('significant' %in% names(result$table)) sum(result$table$significant, na.rm = TRUE) else NA_integer_
        paste0('<section id="', key, '"><h2>', title, '</h2><p>', description, '</p><p><strong>', nrow(result$table),
            ' returned rows</strong>', if (!is.na(significant)) paste0('; ', significant, ' marked significant by SCEPTRE.') else '.',
            '</p><p><a href="tables/', key, '.csv">Download scalar result columns (CSV)</a></p>',
            table_html(result$table), '<details><summary>Frozen family, settings and realized resampling budgets</summary>', code(result$provenance), '</details></section>')
    }
    body <- paste0('<header><p class="eyebrow">SCEPTRE · SCIENTIFIC RESULTS</p><h1>', esc(data$title), '</h1>',
        '<p>Saved analysis results, quality control and reproducibility record.</p><p class="stamp">', esc(data$generated_utc), '</p></header>',
        '<nav><a href="#qc">Assignment &amp; QC</a><a href="#calibration">Calibration</a><a href="#power">Positive controls</a><a href="#discovery">Discovery</a><a href="#settings">Settings</a><a href="#provenance">Provenance</a></nav>',
        '<main><aside>This scientific report is distinct from the Nextflow execution report. Statistical associations do not establish biological mechanisms. Calibration is optional and is not a prerequisite for discovery.</aside>',
        '<section id="qc"><h2>Assignment and quality control</h2><div class="cards"><div><b>', data$qc$imported_cells,
        '</b><span>Imported cells</span></div><div><b>', data$qc$retained_cells, '</b><span>Cells retained for analysis</span></div><div><b>',
        data$qc$excluded_cells, '</b><span>Excluded cells</span></div></div><p>Completed preparation stages: ', esc(paste(data$qc$stages, collapse = ', ')),
        '.</p><h3>Assignment membership counts</h3>', table_html(data$qc$assignments),
        '<h3>Exclusions and retention metrics</h3>', code(data$qc$metrics),
        '<p>Exclusion categories may overlap; membership counts are not disjoint in high-MOI screens. Counts below describe the saved QC state, not a new filtering procedure.</p>',
        '<h3>Hypothesis-family QC</h3>', table_html(data$qc$families), '</section>',
        result_section('calibration', 'Calibration check', 'Negative-control associations characterize calibration for the sampled control family; this is not proof of calibration for every target.'),
        result_section('power', 'Power / positive controls', 'Observed positive-control results describe the supplied control pairs. They are not a general power guarantee for untested effects.'),
        result_section('discovery', 'Discovery analysis', 'Significance flags are copied from the completed SCEPTRE result after its complete-family integration and correction. Failed-QC requests remain visible where supplied by the public output.'),
        '<section><h2>Figures</h2>', if (length(data$plots)) paste(vapply(data$plots, function(x) paste0('<figure><img src="plots/', esc(basename(x)), '" alt="', esc(basename(x)), '"><figcaption>', esc(basename(x)), '</figcaption></figure>'), character(1)), collapse = '') else '<p class="empty">No exported figures available for these completed stages.</p>', '</section>',
        '<section><h2>Warnings and availability</h2><p>Capture scope: reference-stage warnings are structured below. Structured aggregation of distributed worker warnings is unavailable; those warnings remain in the execution logs. An empty captured list does not establish that distributed execution emitted no warnings.</p>', if (length(data$warnings)) code(data$warnings) else '<p>No warnings were captured by this pipeline run. This is not a guarantee that upstream imports emitted none.</p>',
        '<p>Omitted, empty and unavailable stages are identified explicitly above. A report-rendering problem does not revoke an already certified scientific artifact.</p></section>',
        '<section id="settings"><h2>Requested versus resolved settings</h2><h3>Requested pipeline configuration</h3>', code(data$requested),
        '<h3>Resolved saved scientific settings</h3>', code(data$resolved),
        '<p>Requested canonical pairs define the target–response family; guide-group expansion and QC may produce a different number of working rows. Bonferroni guide integration and multiple-testing correction retain the package’s complete-family policy; this renderer does not recompute p-values or correction.</p></section>',
        '<section id="provenance"><h2>Exact provenance</h2><p>Seed, RNG handoff, package/runtime identity and parent/object checksums are retained in the manifest. Realized budgets and frozen choices appear under each completed analysis.</p>',
        code(data$provenance), '<p><a href="report-data.rds">Frozen report inputs (RDS)</a> · <a href="manifest.rds">Pipeline manifest</a> · <a href="requested-config.rds">Requested configuration</a> · <a href="render.R">Editable renderer</a> · <a href="report.qmd">Quarto source</a></p></section></main><footer>Generated locally from saved SCEPTRE outputs. No analysis is rerun when rendering this bundle.</footer>')
    style <- '<style>:root{font-family:system-ui,-apple-system,sans-serif;color:#20313a;background:#f2f5f4}body{margin:0}header,main,nav,footer{max-width:1120px;margin:auto;padding:24px 32px}header{padding-top:55px}h1{font-family:Georgia,serif;font-size:44px;line-height:1.1;margin:12px 0}h2{font-family:Georgia,serif;font-size:29px}h3{font-size:18px}p,li{line-height:1.65}a{color:#086c70}.eyebrow{font-size:12px;letter-spacing:2px;color:#086c70;font-weight:700}.stamp,footer{font-size:13px;color:#53666b}nav{display:flex;flex-wrap:wrap;gap:20px;border-top:1px solid #c5d3d0;border-bottom:1px solid #c5d3d0}section{padding:20px 0;border-bottom:1px solid #d0dcda}aside{padding:20px;background:#e4eeeb;border-left:4px solid #087c77;line-height:1.6}.cards{display:flex;flex-wrap:wrap;gap:18px}.cards div{background:white;border:1px solid #cddbd7;border-radius:8px;padding:20px;min-width:170px}.cards b{display:block;font-size:30px;color:#086c70}.cards span{font-size:14px}.table-wrap{max-height:420px;overflow:auto;background:white;border:1px solid #cddbd7}table{border-collapse:collapse;width:100%;font-size:13px}th,td{padding:10px 12px;border-bottom:1px solid #dde5e2;text-align:left;white-space:nowrap}th{position:sticky;top:0;background:#dceae6}tr:nth-child(even){background:#f7faf8}pre{font-size:12px;line-height:1.5;white-space:pre-wrap;overflow-wrap:anywhere;background:#e8eeeb;padding:16px;max-height:500px;overflow:auto}summary{cursor:pointer;padding:14px 0;font-weight:600}.empty{color:#65777c}img{max-width:100%;max-height:560px;object-fit:contain;background:white}figure{margin:20px 0}figcaption{font-size:12px;color:#64777b}@media(max-width:600px){header,main,nav,footer{padding:20px}h1{font-size:34px}.cards div{min-width:120px}}</style>'
    html <- if (fragment) paste0(style, body) else paste0('<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>', esc(data$title), '</title>', style, '</head><body>', body, '</body></html>')
    if (!is.null(output)) writeLines(html, output, useBytes = TRUE)
    invisible(html)
}
export_scientific_report <- function(object, manifest, config, directory, helper_path, renderer = scientific_report_html) {
    dir.create(directory, recursive = TRUE, showWarnings = FALSE)
    # Read-only public getters and value snapshots form this reporting boundary.
    # Nonmutation is verified on small real states in report/check.R; production
    # must not serialize the full count/result object twice just for an assertion.
    dir.create(file.path(directory, 'tables'), showWarnings = FALSE)
    dir.create(file.path(directory, 'plots'), showWarnings = FALSE)
    snapshot <- function(x) {
        if (isS4(x)) return(stats::setNames(lapply(methods::slotNames(x), function(n) snapshot(methods::slot(x, n))), methods::slotNames(x)))
        if (inherits(x, 'formula')) return(paste(deparse(x), collapse = ' '))
        if (is.list(x) && !is.data.frame(x)) return(lapply(x, snapshot))
        x
    }
    analyses <- list()
    for (key in c('calibration', 'power', 'discovery')) {
        family <- switch(key, calibration = 'run_calibration_check', power = 'run_power_check', discovery = 'run_discovery_analysis')
        if (!key %in% manifest$completed) {
            analyses[[key]] <- list(status = 'omitted', reason = 'Not run in this pipeline artifact.')
            next
        }
        result <- tryCatch({ sceptre::get_result(object, family); sceptre::get_result(object, family, historical = TRUE) }, error = function(condition) condition)
        if (inherits(result, 'error')) {
            analyses[[key]] <- list(status = 'unavailable', reason = conditionMessage(result)); next
        }
        record <- attr(result, 'sceptre_result_record')
        analyses[[key]] <- list(status = 'completed', table = result, provenance = snapshot(record$provenance))
        utils::write.csv(report_scalar_table(result), file.path(directory, 'tables', paste0(key, '.csv')), row.names = FALSE)
    }
    families <- lapply(c('discovery', 'positive_control'), function(kind) {
        requested <- if (kind == 'discovery') object@spec@discovery_pairs else object@spec@positive_control_pairs
        compiled <- if (kind == 'discovery') object@preparation@discovery_pairs_with_info else object@preparation@positive_control_pairs_with_info
        data.frame(family = kind, requested_pairs = nrow(requested), compiled_rows = nrow(compiled),
            passing_rows = if ('pass_qc' %in% names(compiled)) sum(compiled$pass_qc, na.rm = TRUE) else NA_integer_)
    })
    qc_complete <- all(c('cell_qc', 'pair_qc') %in% names(object@preparation@stages))
    assignments <- object@preparation@guide_assignments
    plots <- list.files(dirname(directory), pattern = '[.]png$', full.names = TRUE)
    if (length(plots)) file.copy(plots, file.path(directory, 'plots'), overwrite = TRUE)
    source_receipt <- if (file.exists('/opt/sceptre/source.json')) jsonlite::fromJSON('/opt/sceptre/source.json', simplifyVector = FALSE) else 'Not available in this runtime; see package identity below.'
    data <- list(title = 'SCEPTRE scientific results', generated_utc = format(Sys.time(), tz = 'UTC', usetz = TRUE),
        qc = list(imported_cells = ncol(object@data@response_matrix), retained_cells = if (qc_complete) length(object@preparation@analysis_cells) else NA_integer_,
            excluded_cells = if (qc_complete) ncol(object@data@response_matrix) - length(object@preparation@analysis_cells) else NA_integer_,
            stages = names(object@preparation@stages), metrics = object@preparation@cell_removal_metrics,
            assignments = data.frame(guide = names(assignments), assigned_cells = lengths(assignments)), families = do.call(rbind, families)),
        analyses = analyses, warnings = manifest$warnings, warning_capture = list(reference_stages = 'structured conditions; not suppressed', distributed_workers = 'unavailable as structured report data; inspect execution logs'), requested = snapshot(config), resolved = snapshot(object@spec),
        plots = basename(plots), provenance = list(manifest = manifest, qualified_source = source_receipt))
    saveRDS(data, file.path(directory, 'report-data.rds'))
    saveRDS(manifest, file.path(directory, 'manifest.rds'))
    saveRDS(config, file.path(directory, 'requested-config.rds'))
    file.copy(helper_path, file.path(directory, 'render.R'), overwrite = TRUE)
    writeLines(c('---', 'title: "SCEPTRE scientific results"', 'format: html', 'execute:', '  echo: false', '---', '',
        'Edit this source to customize presentation; the frozen report data are not recomputed.', '',
        '```{r}', '#| results: asis', 'source("render.R")', 'cat(scientific_report_html(readRDS("report-data.rds"), NULL, fragment = TRUE))', '```'), file.path(directory, 'report.qmd'))
    writeLines(c('# Rerender without rerunning science', '', 'Rscript -e \'source("render.R"); scientific_report_html(readRDS("report-data.rds"), "report.html")\'', '',
        'Optional editable Quarto view: quarto render report.qmd (requires Quarto and knitr).', 'The renderer reads only this bundle; CSV files expose scalar scientific results.', 'Warning scope: reference-stage conditions are structured; distributed worker warnings remain in execution logs and are not aggregated in this bundle.'), file.path(directory, 'README.md'))
    renderer(data, file.path(directory, 'report.html'))
    invisible(data)
}

write_scientific_report_safely <- function(object, manifest, config, directory, helper_path,
    renderer = scientific_report_html) {
    dir.create(directory, recursive = TRUE, showWarnings = FALSE)
    tryCatch({
        export_scientific_report(object, manifest, config, directory, helper_path, renderer)
        jsonlite::write_json(list(status = 'completed', artifact = 'report.html'),
            file.path(directory, 'report-status.json'), auto_unbox = TRUE, pretty = TRUE)
        invisible(TRUE)
    }, error = function(condition) {
        jsonlite::write_json(list(status = 'failed', reason = conditionMessage(condition),
            scientific_artifact = 'unchanged; use saved results independently'),
            file.path(directory, 'report-status.json'), auto_unbox = TRUE, pretty = TRUE)
        message('Scientific report unavailable: ', conditionMessage(condition))
        invisible(FALSE)
    })
}
