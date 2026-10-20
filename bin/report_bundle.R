# A pipeline-owned consumer of package-owned summaries, readers and exports.
# This boundary never collects a full family or serializes the source object.
report_count <- function(value, name, missing = FALSE) {
    if (missing && (is.null(value) || (length(value) == 1L && is.na(value)))) return(NA_real_)
    if (!is.numeric(value) || length(value) != 1L || !is.finite(value) ||
        value < 0 || value != floor(value) || value > 2^53)
        stop("Invalid exact report count: ", name, call. = FALSE)
    as.double(value)
}
report_plain_preview <- function(table, limit = 100L, column_limit = 32L) {
    if (!is.data.frame(table) || nrow(table) > limit)
        stop("Report reader must return a bounded data-frame preview.", call. = FALSE)
    # A result-record attribute may contain a full family/plan. Rebuild only
    # selected scalar columns, never preserve arbitrary frame/column attributes.
    candidate <- seq_len(min(ncol(table), column_limit))
    scalar <- vapply(candidate, function(i) {
        value <- table[[i]]
        (is.atomic(value) && is.null(dim(value))) || is.factor(value)
    }, logical(1))
    selected <- candidate[scalar]
    columns <- lapply(selected, function(i) {
        value <- table[[i]]
        if (is.factor(value)) value <- as.character(value)
        attributes(value) <- NULL
        if (is.character(value)) value <- ifelse(nchar(value) > 500L,
            paste0(substr(value, 1L, 500L), " ... [text truncated]"), value)
        value
    })
    names(columns) <- names(table)[selected]
    out <- structure(columns, class = "data.frame", row.names = .set_row_names(nrow(table)))
    omitted <- setdiff(seq_len(ncol(table)), selected)
    list(table = out, omitted_columns = utils::head(names(table)[omitted], 12L),
         omitted_column_count = length(omitted))
}

report_qc_view <- function(qc) {
    table <- function(value) {
        if (!is.data.frame(value)) return(data.frame())
        report_plain_preview(value[seq_len(min(nrow(value), 100L)), , drop = FALSE])$table
    }
    list(imported_cells = report_count(qc$imported_cells, "imported cells", TRUE),
         retained_cells = report_count(qc$retained_cells, "retained cells", TRUE),
         excluded_cells = report_count(qc$excluded_cells, "excluded cells", TRUE),
         stages = utils::head(qc$stages, 64L), assignments = table(qc$assignments),
         assignment_total_rows = if (is.null(qc$assignment_total_rows)) nrow(qc$assignments) else qc$assignment_total_rows,
         families = table(qc$families), metrics = report_preview(qc$metrics))
}

capture_report_source <- function(source, preview_rows = 100L) {
    if (!is.list(source) || !is.function(source$describe) || !is.function(source$read_preview))
        stop("A report source needs describe() and read_preview() callbacks.", call. = FALSE)
    if (length(preview_rows) != 1L || is.na(preview_rows) || preview_rows < 0L ||
        preview_rows > 100L || preview_rows != as.integer(preview_rows))
        stop("Report previews are capped at 100 rows.", call. = FALSE)
    analyses <- list()
    for (key in c("calibration", "power", "discovery")) {
        description <- source$describe(key)
        if (!is.list(description) || !description$status %in% c("completed", "omitted", "unavailable", "failed"))
            stop("Report source has an invalid analysis status: ", key, call. = FALSE)
        if (description$status != "completed") {
            analyses[[key]] <- list(status = description$status,
                reason = report_preview(description$reason))
            next
        }
        summary <- description$summary
        total <- report_count(summary$returned_rows, paste0(key, ".returned_rows"))
        significant <- report_count(summary$significant_rows,
            paste0(key, ".significant_rows"), missing = TRUE)
        passing <- report_count(summary$pass_qc_rows,
            paste0(key, ".passing_rows"), missing = TRUE)
        if ((!is.na(significant) && significant > total) || (!is.na(passing) && passing > total))
            stop("Report summary exceeds the complete row count: ", key, call. = FALSE)
        count <- min(as.double(preview_rows), total)
        table <- source$read_preview(key, as.integer(count))
        if (!is.data.frame(table) || nrow(table) != count)
            stop("Result preview does not cover exactly the requested saved prefix: ", key, call. = FALSE)
        preview <- report_plain_preview(table, preview_rows)
        analyses[[key]] <- list(status = "completed", table = preview$table,
            total_rows = total, preview_rows = count, significant_count = significant,
            passing_count = passing, omitted_column_count = preview$omitted_column_count,
            omitted_columns = preview$omitted_columns,
            method = report_preview(summary$method), summary = report_preview(summary), provenance = report_preview(description$provenance))
    }
    # report_preview performs a fixed-budget traversal. It does not recursively
    # snapshot all spec/plan fields or copy them into the portable view bundle.
    list(report_schema = 2L, title = if (is.null(source$title)) "SCEPTRE scientific results" else source$title,
         generated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
         analyses = analyses, qc = report_qc_view(source$qc), requested = report_preview(source$requested),
         resolved = report_preview(source$resolved), provenance = report_preview(source$provenance),
         warnings = report_preview(source$warnings), warning_count = length(source$warnings),
         plots = character(), preview_policy = list(order = "first rows in certified saved order",
             maximum_rows = preview_rows, maximum_columns = 32L, maximum_text_characters = 500L))
}

report_preview_plot <- function(analysis, key, directory) {
    table <- analysis$table
    if (!"p_value" %in% names(table) || !nrow(table)) return(NULL)
    valid <- is.finite(table$p_value) & table$p_value >= 0 & table$p_value <= 1
    name <- paste0(key, "-preview.png")
    grDevices::png(file.path(directory, name), width = 1100L, height = 500L, res = 120L)
    on.exit(grDevices::dev.off(), add = TRUE)
    if (any(valid)) {
        x <- which(valid)
        graphics::plot(x, -log10(pmax(table$p_value[valid], .Machine$double.xmin)),
            xlab = "Saved row index within deterministic preview", ylab = "-log10(p-value)",
            pch = 19L, col = "#086c70", main = paste(key, "saved-row preview"))
    } else {
        graphics::plot.new(); graphics::title(main = paste(key, "saved-row preview"))
        graphics::text(0.5, 0.5, "No finite p-values in this preview")
    }
    caption <- paste0(sum(valid), " finite p-values plotted from ", nrow(table), " preview rows; ",
        analysis$total_rows, " total saved rows. ", sum(!valid),
        " preview values omitted as missing/non-finite/out of range. This deterministic prefix is not a full-family calibration plot. Zero p-values use the numeric plotting floor.")
    list(file = name, caption = caption)
}

write_report_source <- function(source, directory, helper_path,
    renderer = scientific_report_html, source_files = list()) {
    if (file.exists(file.path(directory, "report-data.rds")) || file.exists(file.path(directory, "report.html")))
        stop("Report bundle already exists; rerender its retained view or use a fresh directory.", call. = FALSE)
    if (!is.function(source$export_csv) || !is.function(source$export_native))
        stop("Report source needs complete CSV and portable native/provenance exporters.", call. = FALSE)
    dir.create(directory, recursive = TRUE, showWarnings = FALSE)
    dir.create(file.path(directory, "tables"), showWarnings = FALSE)
    dir.create(file.path(directory, "plots"), showWarnings = FALSE)
    dir.create(file.path(directory, "native"), showWarnings = FALSE)
    data <- capture_report_source(source)
    exports <- list()
    for (key in names(data$analyses)) {
        if (data$analyses[[key]]$status != "completed") next
        target <- file.path(directory, "tables", paste0(key, ".csv"))
        receipt <- source$export_csv(key, target)
        rows <- report_count(receipt$rows, paste0(key, ".CSV rows"))
        if (!isTRUE(receipt$complete) || !identical(rows, data$analyses[[key]]$total_rows) || !file.exists(target) ||
            !is.character(receipt$sha256) || length(receipt$sha256) != 1L ||
            !grepl("^[a-f0-9]{64}$", receipt$sha256))
            stop("Incomplete or uncertified complete CSV export: ", key, call. = FALSE)
        if (!is.null(receipt$bytes) && file.info(target)$size != receipt$bytes)
            stop("CSV byte-size differs from export receipt: ", key, call. = FALSE)
        # Trust the package export's streaming hash/count receipt. Do not reread
        # the entire CSV for reporting; qualification independently checks it.
        data$analyses[[key]]$download <- paste0("tables/", key, ".csv")
        data$analyses[[key]]$export_receipt <- report_preview(receipt)
        native_directory <- file.path(directory, "native", key)
        native <- source$export_native(key, native_directory)
        if (!is.list(native) || !isTRUE(native$complete) || !isTRUE(native$provenance_complete) ||
            report_count(native$rows, paste0(key, ".native rows")) != rows ||
            !is.character(native$manifest) || length(native$manifest) != 1L ||
            !is.character(native$sha256) || length(native$sha256) != 1L ||
            !grepl("^[a-f0-9]{64}$", native$sha256))
            stop("Incomplete portable native values/provenance: ", key, call. = FALSE)
        manifest <- normalizePath(file.path(native_directory, native$manifest), mustWork = TRUE)
        root <- paste0(normalizePath(directory, mustWork = TRUE), .Platform$file.sep)
        if (!startsWith(manifest, root) || dir.exists(manifest))
            stop("Native export manifest must be a file inside the portable bundle.", call. = FALSE)
        data$analyses[[key]]$native_export <- list(
            manifest = substring(manifest, nchar(root) + 1L), sha256 = native$sha256,
            rows = rows, complete = TRUE, provenance_complete = TRUE)
        exports[[key]] <- list(csv = report_preview(receipt), native = data$analyses[[key]]$native_export)
        plot <- report_preview_plot(data$analyses[[key]], key, file.path(directory, "plots"))
        if (!is.null(plot)) {
            data$plots <- c(data$plots, plot$file)
            data$plot_captions[[plot$file]] <- plot$caption
        }
    }
    # Raw file copies retain complete input provenance without reading or
    # serializing its potentially H-sized R values into the report view.
    for (name in names(source_files)) {
        if (!name %in% c("manifest.rds", "requested-config.rds"))
            stop("Unsupported report provenance file name.", call. = FALSE)
        if (!file.copy(source_files[[name]], file.path(directory, name), overwrite = FALSE))
            stop("Could not retain original report provenance file: ", name, call. = FALSE)
    }
    data$complete_provenance_files <- names(source_files)
    saveRDS(data, file.path(directory, "report-data.rds"))
    saveRDS(exports, file.path(directory, "export-manifests.rds"))
    if (!file.copy(helper_path, file.path(directory, "render.R"), overwrite = TRUE))
        stop("Could not retain report renderer.", call. = FALSE)
    writeLines(c("---", "title: SCEPTRE scientific results", "format: html", "execute:", "  echo: false", "---", "",
        "```{r}", "#| results: asis", "source('render.R')",
        "cat(scientific_report_html(readRDS('report-data.rds'), NULL, fragment = TRUE))", "```"), file.path(directory, "report.qmd"))
    writeLines(c("source('render.R')", "scientific_report_html(readRDS('report-data.rds'), 'report.html')"), file.path(directory, "rerender.R"))
    writeLines(c("# Bounded report view and complete science", "",
        "report-data.rds contains exact summaries and fixed bounded previews, not complete result rows or provenance.",
        "tables/*.csv contain every scalar result row. Export receipts preserve exact row counts and streaming SHA256 hashes.",
        "native/ contains portable complete native results and analysis provenance, including columns omitted from CSV.",
        "Copy this entire directory, retaining native/, tables/, plots/ and any complete raw provenance files.",
        "Rerender with base R: Rscript --vanilla rerender.R",
        "No analysis, correction, random sampling or full-result loading occurs while rerendering."), file.path(directory, "README.md"))
    renderer(data, file.path(directory, "report.html"))
    invisible(data)
}

write_report_source_safely <- function(source, directory, helper_path,
    renderer = scientific_report_html, source_files = list()) {
    dir.create(directory, recursive = TRUE, showWarnings = FALSE)
    tryCatch({
        write_report_source(source, directory, helper_path, renderer, source_files)
        jsonlite::write_json(list(status = "completed", report_schema = 2L, artifact = "report.html"),
            file.path(directory, "report-status.json"), auto_unbox = TRUE, pretty = TRUE)
        invisible(TRUE)
    }, error = function(condition) {
        jsonlite::write_json(list(status = "failed", reason = conditionMessage(condition),
            scientific_artifact = "unchanged; inspect complete source/export receipts separately"),
            file.path(directory, "report-status.json"), auto_unbox = TRUE, pretty = TRUE)
        message("Scientific report unavailable: ", conditionMessage(condition))
        invisible(FALSE)
    })
}
