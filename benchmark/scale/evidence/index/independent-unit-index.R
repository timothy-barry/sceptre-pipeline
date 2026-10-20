args <- commandArgs(TRUE)
extract <- function(file) {
  expressions <- parse(file)
  target <- Filter(function(x) is.call(x) && identical(x[[1L]], as.name("<-")) && identical(x[[2L]], as.name("execution_units")), as.list(expressions))
  stopifnot(length(target) == 1L)
  env <- new.env(); eval(target[[1L]], env); env$execution_units
}
old <- extract(file.path(args[1], "baseline.R"))
new <- extract(file.path(args[1], "candidate.R"))
methods::setClass("W11Plan", slots=c(pairs="data.frame"))
set.seed(6011); checks <- 0L
for (trial in seq_len(200L)) {
  n <- sample(1:300,1); pass <- sample(c(TRUE,FALSE),n,TRUE);pass[1]<-TRUE
  pair <- data.frame(pass_qc=pass)
  context <- list(index=list(pair_rows=data.frame(response_idx=sample(c(1L,7L,21L,999L),sum(pass),TRUE),group_idx=sample(c(3L,9L,55L),sum(pass),TRUE))))
  plan <- methods::new("W11Plan", pairs=pair)
  for (permutation in c(FALSE,TRUE)) for (units in c(1L,2L,3L,99L)) {
    seed <- .Random.seed; a <- old(context,plan,units,permutation); b <- new(context,plan,units,permutation)
    stopifnot(identical(a,b),identical(seed,.Random.seed));checks<-checks+1L
  }
}
cat("PASS",checks,"exact unit/order/RNG comparisons across200 random irregular-key/QC families\n")
