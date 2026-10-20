#!/usr/bin/env Rscript
x <- readRDS(commandArgs(TRUE)[1L])
writeLines(c('sceptre:', paste0('  version: "', x$version, '"'),
    paste0('  installed_sha256: "', x$installed_sha256, '"'),
    paste0('  R: "', x$R, '"')), 'versions.yml')
