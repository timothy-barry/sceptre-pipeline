# syntax=docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e
# Multi-architecture index, resolved and recorded 2026-10-19.
FROM rocker/r-ver:4.5.1@sha256:03b023fbf7b1b24ac1bb8b2ac5fd7e15a767e67b40ff50c155e328110981c2aa
ARG CRAN_SNAPSHOT=https://packagemanager.posit.co/cran/2025-07-01
ARG WITH_ONDISC=true
ENV TZ=Etc/UTC OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
COPY install-dependencies.R /opt/sceptre/install-dependencies.R
RUN CRAN_SNAPSHOT="$CRAN_SNAPSHOT" WITH_ONDISC="$WITH_ONDISC" Rscript /opt/sceptre/install-dependencies.R
COPY ondisc.tar.gz Rhdf5lib.tar.gz zlib.tar.gz optional.sha256 /opt/sceptre/deps/
RUN cd /opt/sceptre/deps && sha256sum -c optional.sha256 && \
    if [ "$WITH_ONDISC" = true ]; then \
      tar -xzf zlib.tar.gz && cd zlib-1.3.2 && \
      CFLAGS="-O2 -fPIC" ./configure --static --prefix=/usr/local && make -j4 && make install && \
      cd .. && R CMD INSTALL Rhdf5lib.tar.gz && R CMD INSTALL ondisc.tar.gz; fi && \
    rm -rf /opt/sceptre/deps
COPY sceptre.tar.gz source.json source.sha256 /opt/sceptre/
RUN cd /opt/sceptre && sha256sum -c source.sha256 && \
    mkdir package && tar -xzf sceptre.tar.gz -C package && \
    if [ -f package/DESCRIPTION ]; then R CMD INSTALL package; \
    elif [ -f package/sceptre/DESCRIPTION ]; then R CMD INSTALL package/sceptre; \
    else echo "Unsupported SCEPTRE archive layout" >&2; exit 1; fi && rm -rf package && \
    Rscript -e 'library(sceptre); stopifnot(getClass("sceptre_object")@slots[["schema_version"]] == "integer"); write.table(installed.packages()[,c("Package","Version","Built")], "/opt/sceptre/packages.tsv", sep="\t", quote=FALSE, row.names=FALSE); writeLines(capture.output(sessionInfo()), "/opt/sceptre/session-info.txt")'
LABEL org.opencontainers.image.title="SCEPTRE schema-3 pipeline runtime" \
      org.opencontainers.image.description="Exact local SCEPTRE source; identity in /opt/sceptre/source.json"
ENV SCEPTRE_WITH_ONDISC=${WITH_ONDISC} SCEPTRE_CRAN_SNAPSHOT=${CRAN_SNAPSHOT}
WORKDIR /work
CMD ["Rscript", "--version"]
