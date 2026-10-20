repo <- Sys.getenv("CRAN_SNAPSHOT")
stopifnot(nzchar(repo))
options(repos = c(CRAN = repo), Ncpus = 2L, timeout = 1200L)
packages <- c("digest", "cowplot", "crayon", "data.table", "dplyr", "ggplot2",
              "Rcpp", "BH", "scales", "purrr", "parallelly", "withr", "jsonlite",
              "testthat", "R.utils", "sessioninfo")
if (identical(Sys.getenv("WITH_ONDISC"), "true")) packages <- c(packages, "readr")
install.packages(packages)
missing <- setdiff(packages, rownames(installed.packages()))
if (length(missing)) stop("Dependency installation failed: ", paste(missing, collapse = ", "))
writeLines(repo, "/opt/sceptre/cran-snapshot.txt")
