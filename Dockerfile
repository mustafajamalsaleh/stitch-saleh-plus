FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    HTSLIB_VERSION=1.20 \
    SAMTOOLS_VERSION=1.20 \
    BCFTOOLS_VERSION=1.20

# Core build + R toolchain + headers needed by common R packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gfortran autoconf automake libtool pkg-config \
    ca-certificates curl wget git \
    zlib1g-dev libbz2-dev liblzma-dev libdeflate-dev \
    libcurl4-openssl-dev libssl-dev libxml2-dev libgit2-dev \
    libopenblas-dev liblapack-dev \
    r-base r-base-dev \
    less vim \
 && rm -rf /var/lib/apt/lists/*

# ===== Build HTSLIB with GCS + libcurl =====
WORKDIR /opt/src
RUN curl -fsSL https://github.com/samtools/htslib/releases/download/${HTSLIB_VERSION}/htslib-${HTSLIB_VERSION}.tar.bz2 \
  | tar -xj && \
  cd htslib-${HTSLIB_VERSION} && \
  ./configure --enable-gcs --enable-libcurl && \
  make -j"$(nproc)" && make install

# Ensure dynamic linker can find libhts.so
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

# ===== Install STITCH in R (with dependencies) =====
# Base compile-time helpers first (clear error surfaces if toolchain is missing)
RUN Rscript -e 'install.packages(c("Rcpp","RcppArmadillo","data.table","foreach","doParallel"), repos="https://cloud.r-project.org")'

# remotes + STITCH from GitHub; pull remaining R deps automatically
RUN Rscript -e 'install.packages("remotes", repos="https://cloud.r-project.org")' && \
    Rscript -e 'remotes::install_github("rwdavies/STITCH", dependencies=TRUE, upgrade="never")'

# Symlink STITCH runner for convenience (/STITCH/STITCH.R)
RUN Rscript -e 'cat(system.file("scripts","STITCH.R", package="STITCH"))' \
    | xargs -I{} ln -s {} /STITCH && \
    ln -sf /STITCH /STITCH/STITCH.R

ENV PATH="/usr/local/bin:${PATH}"
WORKDIR /work
ENTRYPOINT ["/bin/bash"]

