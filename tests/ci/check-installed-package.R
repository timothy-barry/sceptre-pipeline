#!/usr/bin/env Rscript
# Exercise the installed image package using tests from its exact sealed archive.
a <- commandArgs(TRUE)
stopifnot(length(a) == 2L, file.exists(a[1L]), !dir.exists(a[2L]))
archive <- normalizePath(a[1L])
out <- normalizePath(a[2L], mustWork = FALSE)
dir.create(out, recursive = TRUE)
runtime <- jsonlite::read_json("/opt/sceptre/source.json", simplifyVector = TRUE)
archive_sha <- digest::digest(file = archive, algo = "sha256")
stopifnot(identical(archive_sha, runtime$sceptre_archive_sha256))
utils::untar(archive, exdir = file.path(out, "source"))
tests <- file.path(out, "source", "sceptre", "tests", "testthat")
stopifnot(dir.exists(tests))
library(sceptre)
dll <- getLoadedDLLs()[["sceptre"]][["path"]]
jsonlite::write_json(list(archive_sha256 = archive_sha, source = runtime,
    package_path = find.package("sceptre"), native_path = dll,
    native_sha256 = digest::digest(file = dll, algo = "sha256"),
    R = R.version.string, platform = R.version$platform,
    ondisc_version = as.character(packageVersion("ondisc"))),
    file.path(out, "runtime.json"), pretty = TRUE, auto_unbox = TRUE)
writeLines(capture.output(sessionInfo()), file.path(out, "session.txt"))
r <- testthat::test_dir(tests, package = "sceptre", load_package = "installed",
    reporter = "summary", stop_on_failure = FALSE)
saveRDS(r, file.path(out, "tests.rds"))
d <- as.data.frame(r)
s <- list(cases = nrow(d), assertions = sum(d$nb), passed = sum(d$passed),
    failed = sum(d$failed), errors = sum(d$error), warnings = sum(d$warning),
    skipped = sum(d$skipped),
    skips = d[d$skipped, c("file", "test"), drop = FALSE])
jsonlite::write_json(s, file.path(out, "tests.json"), pretty = TRUE,
    auto_unbox = TRUE)
stopifnot(s$failed == 0L, s$errors == 0L, s$warnings == 0L)
