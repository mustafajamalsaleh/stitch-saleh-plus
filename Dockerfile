FROM ubuntu:22.04

# --- let Actions pass a GitHub token during build (pak/remotes use GITHUB_PAT) ---
ARG GITHUB_PAT
ENV GITHUB_PAT=${GITHUB_PAT}

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    HTSLIB_VERSION=1.20 \
    SAMTOOLS_VERSION=1.20 \
    BCFTOOLS_VERSION=1.20 \
    R_INSTALL_ARGS="--no-manual --no-build-vignettes" \
    R_BUILD_ARGS="--no-build-vignettes"

# Toolchain + headers for R packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gfortran autoconf automake libtool pkg-config cmake \
    ca-certificates curl wget git unzip \
    zlib1g-dev libbz2-dev liblzma-dev libdeflate-dev \
    libcurl4-openssl-dev libssl-dev libxml2-dev libgit2-dev \
    libopenblas-dev liblapack-dev \
    libicu-dev \                 # for stringi (very common)
    libfontconfig1-dev libfreetype6-dev libharfbuzz-dev libfribidi-dev \  # fonts/text
    libpng-dev libjpeg-turbo8-dev libtiff5-dev \                          # images
    pandoc qpdf \                # avoid vignette/manual PDF failures
    r-base r-base-dev \
    less vim \
 && rm -rf /var/lib/apt/lists/*

# Avoid occasional git “dubious ownership” in CI
RUN git config --global --add safe.directory '*'

# ---------- HTSLIB (with GCS + libcurl) ----------
WORKDIR /opt/src
RUN curl -fsSL https://github.com/samtools/htslib/releases/download/${HTSLIB_VERSION}/htslib-${HTSLIB_VERSION}.tar.bz2 \
  | tar -xj && \
  cd htslib-${HTSLIB_VERSION} && \
  ./configure --enable-gcs --enable-libcurl && \
  make -j"$(nproc)" && make install
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/htslib.conf && ldconfig

# ---------- samtools & bcftools (built against that htslib) ----------
RUN curl -fsSL https://github.com/samtools/samtools/releases/download/${SAMTOOLS_VERSION}/samtools-${SAMTOOLS_VERSION}.tar.bz2 \
  | tar -xj && cd samtools-${SAMTOOLS_VERSION} && \
  ./configure && make -j"$(nproc)" && make install

RUN curl -fsSL https://github.com/samtools/bcftools/releases/download/${BCFTOOLS_VERSION}/bcftools-${BCFTOOLS_VERSION}.tar.bz2 \
  | tar -xj && cd bcftools-${BCFTOOLS_VERSION} && \
  ./configure && make -j"$(nproc)" && make install

# ---------- Install STITCH from GitHub via pak (auth via GITHUB_PAT) ----------
RUN Rscript -e 'install.packages("pak", repos="https://cloud.r-project.org")' && \
    Rscript -e 'pak::pkg_install("rwdavies/STITCH/STITCH", ask=FALSE)'

# Convenience shim so tasks can call /STITCH/STITCH.R
RUN Rscript -e 'cat(system.file("scripts","STITCH.R", package="STITCH"))' \
    | xargs -I{} ln -s {} /STITCH && \
    ln -sf /STITCH /STITCH/STITCH.R

ENV PATH="/usr/local/bin:${PATH}"
WORKDIR /work
ENTRYPOINT ["/bin/bash"]
