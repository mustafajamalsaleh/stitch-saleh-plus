what do i do with the scirpt you sent:
 # ===== Base: Ubuntu + system deps =====
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    HTSLIB_VERSION=1.20 \
    SAMTOOLS_VERSION=1.20 \
    BCFTOOLS_VERSION=1.20

# Core build + compression + SSL + curl (needed for htslib cloud backends)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential autoconf automake libtool pkg-config \
    ca-certificates curl wget git \
    zlib1g-dev libbz2-dev liblzma-dev libdeflate-dev libcurl4-openssl-dev \
    libssl-dev \
    # R base and compilers for STITCH
    r-base r-base-dev \
    # helpers
    less vim \
 && rm -rf /var/lib/apt/lists/*

# ===== Build HTSLIB with GCS + libcurl =====
# --enable-gcs turns on Google Cloud Storage support
# --enable-libcurl enables HTTP/HTTPS and complements cloud backends
WORKDIR /opt/src
RUN curl -fsSL https://github.com/samtools/htslib/releases/download/${HTSLIB_VERSION}/htslib-${HTSLIB_VERSION}.tar.bz2 \
  | tar -xj && \
  cd htslib-${HTSLIB_VERSION} && \
  ./configure --enable-gcs --enable-libcurl && \
  make -j"$(nproc)" && make install

# Ensure loader can find libhts.so
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/htslib.conf && ldconfig

# ===== Build samtools & bcftools against the installed htslib =====
RUN curl -fsSL https://github.com/samtools/samtools/releases/download/${SAMTOOLS_VERSION}/samtools-${SAMTOOLS_VERSION}.tar.bz2 \
  | tar -xj && \
  cd samtools-${SAMTOOLS_VERSION} && \
  ./configure && make -j"$(nproc)" && make install

RUN curl -fsSL https://github.com/samtools/bcftools/releases/download/${BCFTOOLS_VERSION}/bcftools-${BCFTOOLS_VERSION}.tar.bz2 \
  | tar -xj && \
  cd bcftools-${BCFTOOLS_VERSION} && \
  ./configure && make -j"$(nproc)" && make install

# ===== Install STITCH in R =====
# STITCH.R will be available in the package’s inst/ folder; we’ll symlink it.
RUN Rscript -e 'install.packages(c("Rcpp","RcppArmadillo"), repos="https://cloud.r-project.org")' && \
    Rscript -e 'install.packages("remotes", repos="https://cloud.r-project.org")' && \
    Rscript -e 'remotes::install_github("rwdavies/STITCH", upgrade="never")'

# Symlink STITCH runner for convenience
RUN Rscript -e 'cat(system.file("scripts","STITCH.R", package="STITCH"))' \
    | xargs -I{} ln -s {} /STITCH && \
    ln -sf /STITCH /STITCH/STITCH.R

# ===== Default environment tweaks =====
ENV PATH="/usr/local/bin:${PATH}"

WORKDIR /work
ENTRYPOINT ["/bin/bash"]
