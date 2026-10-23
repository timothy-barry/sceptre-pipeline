# syntax=docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e
# Multi-architecture index, resolved and recorded 2026-10-19.
FROM rocker/r-ver:4.5.1@sha256:03b023fbf7b1b24ac1bb8b2ac5fd7e15a767e67b40ff50c155e328110981c2aa
ARG CRAN_SNAPSHOT=https://packagemanager.posit.co/cran/2025-11-15
ARG BIOCONDUCTOR_VERSION=3.22
ENV TZ=Etc/UTC OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MAKEFLAGS=-j2
# System repository contents are resolved at build time; preserve the built image ID.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl-dev libcurl4-openssl-dev libxml2-dev zlib1g-dev libbz2-dev liblzma-dev && \
    rm -rf /var/lib/apt/lists/*
COPY sceptre.tar.gz source.json source.sha256 install-dependencies.R /opt/sceptre/
RUN cd /opt/sceptre && sha256sum -c source.sha256 && \
    mkdir package && tar -xzf sceptre.tar.gz -C package && \
    if [ -f package/DESCRIPTION ]; then mv package package-flat && mkdir package && mv package-flat package/sceptre; fi && \
    CRAN_SNAPSHOT="$CRAN_SNAPSHOT" BIOCONDUCTOR_VERSION="$BIOCONDUCTOR_VERSION" \
    Rscript install-dependencies.R && R CMD INSTALL package/sceptre && rm -rf package && \
    Rscript -e 'library(sceptre); stopifnot(identical(methods::getClass("sceptre_object")@prototype@schema_version, 7L)); stopifnot(all(c("get_screen_experiment", "prepare_execution", "execute_work_unit", "collect_execution") %in% getNamespaceExports("sceptre"))); stopifnot(requireNamespace("HDF5Array", quietly=TRUE), requireNamespace("beachmat.hdf5", quietly=TRUE)); write.table(installed.packages()[,c("Package","Version","Built")], "/opt/sceptre/packages.tsv", sep="\t", quote=FALSE, row.names=FALSE); writeLines(capture.output(sessionInfo()), "/opt/sceptre/session-info.txt")'
LABEL org.opencontainers.image.title="SCEPTRE schema-7 pipeline runtime" \
      org.opencontainers.image.description="Frozen SCEPTRE archive; identity in /opt/sceptre/source.json"
ENV SCEPTRE_CRAN_SNAPSHOT=${CRAN_SNAPSHOT} SCEPTRE_BIOCONDUCTOR_VERSION=${BIOCONDUCTOR_VERSION}
WORKDIR /work
CMD ["Rscript", "--version"]
