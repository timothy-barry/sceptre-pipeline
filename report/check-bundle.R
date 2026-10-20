#!/usr/bin/env Rscript
# Small contract tests; no inference or H-sized family is constructed.
source("bin/scientific_report.R")
source("bin/report_bundle.R")
make_source <- function(total) {
    calls <- new.env(parent = emptyenv()); calls$requested <- integer()
    source <- list(title = "Bounded report contract", qc = list(imported_cells = 320L,
        retained_cells = 315L, excluded_cells = 5L, stages = c("cell_qc", "pair_qc"),
        assignments = data.frame(guide = "guide", assigned_cells = 10L),
        families = data.frame(family = "discovery", requested_pairs = total), metrics = list()),
        requested = list(family = seq_len(total), seed = 271828L),
        resolved = list(multiple_testing_method = "BH"),
        provenance = list(manifest = list(seed = 271828L, package = list(source = "fixed")),
            original_family = seq_len(total)), warnings = list())
    source$describe <- function(key) {
        if (key != "discovery") return(list(status = "omitted", reason = "Not selected"))
        list(status = "completed", summary = list(returned_rows = total,
            pass_qc_rows = total, significant_rows = total,
            correction = "BH", method = "known-fixture"),
            provenance = list(plan = list(family = seq_len(total), B1 = 499L)))
    }
    source$read_preview <- function(key, n) {
        calls$requested <- c(calls$requested, n)
        stopifnot(n <= 100L)
        table <- data.frame(response_id = paste0("gene-", seq_len(n)),
            p_value = rep(0.001, n), significant = rep(TRUE, n))
        # A global family can be attached to the reader frame. It must never
        # leak into the frozen preview via data-frame attributes.
        table$null_payload <- I(lapply(seq_len(n), function(i) paste0("native-", i)))
        attr(table, "sceptre_result_record") <- list(full_family = seq_len(total))
        table
    }
    source$calls <- calls
    source
}
set.seed(345L); before <- .Random.seed
source <- make_source(1000000L)
view <- capture_report_source(source)
stopifnot(identical(.Random.seed, before), view$analyses$discovery$total_rows == 1000000,
    nrow(view$analyses$discovery$table) == 100L,
    identical(source$calls$requested, 100L),
    is.null(attr(view$analyses$discovery$table, "sceptre_result_record")),
    as.numeric(object.size(view)) < 150000L)
html <- scientific_report_html(view, NULL)
stopifnot(grepl("1000000 returned rows", html, fixed = TRUE),
    grepl("Showing the first 100 of 1000000 rows", html, fixed = TRUE),
    grepl("1000000 marked significant", html, fixed = TRUE))
rejects <- function(expression) stopifnot(inherits(tryCatch({ force(expression); NULL }, error = identity), "error"))
bad <- source; bad$read_preview <- function(...) data.frame(p_value = 0.1)
rejects(capture_report_source(bad))
bad <- source; bad$describe <- function(key) list(status = "completed", summary = list(returned_rows = -1))
rejects(capture_report_source(bad))
bad <- source; original <- bad$describe
bad$describe <- function(key) { x <- original(key); if (key == "discovery") x$summary$significant_rows <- 1000001; x }
rejects(capture_report_source(bad))
rejects(capture_report_source(source, preview_rows = 101L))
bad <- source; bad$qc$stages <- list(family = seq_len(2000L))
rejects(capture_report_source(bad))
for (count in list(list(family = seq_len(2000L)), c(1L, 2L), -1L)) {
    bad <- source; bad$qc$assignment_total_rows <- count
    rejects(capture_report_source(bad))
}
attr(source$qc$stages, "global_family") <- seq_len(1000000L)
`[.report_forbidden_reader` <- function(...) stop("Opaque metadata must not invoke a reader")
source$requested$opaque <- structure(list(family = seq_len(1000000L)), class = "report_forbidden_reader")
source$requested$formula <- ~ response_n_umis
view <- capture_report_source(source)
stopifnot(is.null(attr(view$qc$stages, "global_family")),
    grepl("response_n_umis", view$requested$formula, fixed = TRUE),
    as.numeric(object.size(view)) < 150000L)
source <- make_source(125L)
source$export_csv <- function(key, target) {
    # This tiny fixture stands in for the package streaming writer only in
    # contract tests. Large/export-correction qualification uses the real store.
    utils::write.csv(data.frame(response_id = paste0("gene-", seq_len(125L)),
        p_value = rep(0.001, 125L), significant = TRUE), target, row.names = FALSE)
    list(rows = 125L, sha256 = digest::digest(file = target, algo = "sha256"),
        bytes = unname(file.info(target)$size), omitted_columns = "null_payload", complete = TRUE)
}
source$export_native <- function(key, directory) {
    dir.create(directory, recursive = TRUE)
    table <- data.frame(response_id = paste0("gene-", seq_len(125L)), p_value = rep(0.001, 125L), significant = TRUE)
    table$null_payload <- I(lapply(seq_len(125L), function(i) if (i == 125L) "NATIVE_TAIL_SENTINEL" else paste0("native-", i)))
    saveRDS(list(table = table, provenance = list(full_family = seq_len(125L), seed = 271828L)), file.path(directory, "result.rds"))
    list(manifest = "result.rds", rows = 125L,
        sha256 = digest::digest(file = file.path(directory, "result.rds"), algo = "sha256"),
        complete = TRUE, provenance_complete = TRUE)
}
out <- tempfile("report-contract-"); dir.create(out)
report <- write_report_source(source, out, normalizePath("bin/scientific_report.R"))
stopifnot(identical(.Random.seed, before), nrow(read.csv(file.path(out, "tables/discovery.csv"))) == 125L,
    nrow(readRDS(file.path(out, "report-data.rds"))$analyses$discovery$table) == 100L)
# Recover an induced presentation error from the retained small view. The
# complete CSV must remain byte-identical; no inference/package is loaded.
hash <- tools::md5sum(file.path(out, "tables/discovery.csv"))
failed <- tempfile("report-render-failure-")
stopifnot(!write_report_source_safely(source, failed, normalizePath("bin/scientific_report.R"),
    renderer = function(...) stop("deliberate presentation failure")),
    jsonlite::fromJSON(file.path(failed, "report-status.json"))$status == "failed",
    file.exists(file.path(failed, "report-data.rds")),
    identical(unname(tools::md5sum(file.path(failed, "tables/discovery.csv"))), unname(hash)))
# The failed view remains rerenderable without collecting any science.
out <- failed
relocated <- tempfile("report-relocated-"); dir.create(relocated)
stopifnot(all(file.copy(list.files(out, full.names = TRUE), relocated, recursive = TRUE)))
old <- setwd(relocated)
status <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", "rerender.R"))
setwd(old)
stopifnot(status == 0L, identical(unname(tools::md5sum(file.path(relocated, "tables/discovery.csv"))), unname(hash)))
relocated_view <- readRDS(file.path(relocated, "report-data.rds"))
native_link <- relocated_view$analyses$discovery$native_export
native_path <- file.path(relocated, native_link$manifest)
native <- readRDS(native_path)
stopifnot(identical(native$table$null_payload[[125L]], "NATIVE_TAIL_SENTINEL"),
    identical(native$provenance$full_family, seq_len(125L)),
    identical(digest::digest(file = native_path, algo = "sha256"), native_link$sha256),
    !"null_payload" %in% names(relocated_view$analyses$discovery$table),
    grepl("native/discovery/result.rds", paste(readLines(file.path(relocated, "report.html")), collapse = ""), fixed = TRUE))
html <- paste(readLines(file.path(relocated, "report.html")), collapse = "")
links <- regmatches(html, gregexpr('(href|src)="[^"]+"', html))[[1L]]
links <- sub('^[^=]+="', '', sub('"$', '', links))
links <- links[!startsWith(links, "#")]
stopifnot(all(file.exists(file.path(relocated, links))))
for (kind in c("incomplete native", "missing provenance", "wrong native rows")) {
    bad <- source; native_writer <- source$export_native
    bad$export_native <- function(key, target) {
        receipt <- native_writer(key, target)
        if (kind == "incomplete native") receipt$complete <- FALSE
        if (kind == "missing provenance") receipt$provenance_complete <- FALSE
        if (kind == "wrong native rows") receipt$rows <- 124L
        receipt
    }
    rejects(write_report_source(bad, tempfile("bad-native-"), normalizePath("bin/scientific_report.R")))
}
for (kind in c("incomplete", "wrong rows", "wrong hash")) {
    bad <- source; writer <- source$export_csv
    bad$export_csv <- function(key, target) {
        receipt <- writer(key, target)
        if (kind == "incomplete") receipt$complete <- FALSE
        if (kind == "wrong rows") receipt$rows <- 124L
        if (kind == "wrong hash") receipt$sha256 <- "not-a-sha256"
        receipt
    }
    rejects(write_report_source(bad, tempfile("bad-report-"), normalizePath("bin/scientific_report.R")))
}
cat("PASS bounded capture; exact summary/preview distinction; stripped global attributes; unchanged RNG; complete-export/native-provenance receipt guards; relocated native tail sentinel/recovery\n")
