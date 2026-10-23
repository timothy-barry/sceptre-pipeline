#!/usr/bin/env Rscript
# Invoke in a fresh Rscript process: initialize the namespace before lazy APIs.
args <- commandArgs(TRUE)
if (length(args) != 1L) stop('Usage: Rscript tests/runtime/check-startup.R NEW_DIRECTORY')
stopifnot(!isNamespaceLoaded('sceptre'))
source('bin/pipeline.R')
stopifnot(isNamespaceLoaded('sceptre'), !'package:sceptre' %in% search())
source('tests/fixture.R')
dir.create(args[1L], recursive = TRUE)
ram <- pipeline_fixture()
hdf5 <- pipeline_fixture(backed = TRUE, directory = file.path(args[1L], 'counts'))
counts <- function(object) list(response = as.matrix(sceptre::get_response_matrix(object)),
    grna = as.matrix(sceptre::get_grna_matrix(object)))
stopifnot(identical(counts(ram$object), counts(hdf5$object)))
cat('PASS fresh namespace-only pipeline startup; exact RAM/native HDF5 public counts\n')
