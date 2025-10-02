FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    HTSLIB_VERSION=1.20 \
    SAMTOOLS_VERSION=1.20 \
    BCFTOOLS_VERSION=1.20 \
    STITCH_VERSION=1.8.4 \
    # Use a reliable CRAN mirror for CI
    CRAN_URL=https://cloud.r-project.org

# Toolchain + headers for R pkgs; BLAS/LAPACK; fonts/images; pandoc/qpdf
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gfortran autoconf automake libtool pkg-config cmake \
    ca-certificates curl wget git unzip \
    zlib1g-dev libbz2-dev liblzma-dev libdeflate-dev \
    libcurl4-openssl-dev libssl-dev libxml2-dev libgit2-dev \
    libopenblas-dev liblapack-dev \
    libicu-dev \
    libfontconfig1-dev libfreetype6-dev libharfbuzz-dev libfribidi-dev \
    libpng-dev libjpeg-turbo8-dev libtiff5-dev \
    pandoc qpdf \
    r-base r-base-dev \
    less vim && \
    rm -rf /var/lib/apt/lists/*

# Avoid occasional git “dubious ownership” warnings in CI
RUN git config --global --add safe.directory '*'

# ---------- HTSLIB (with GCS + libcurl) ----------
WORKDIR /opt/src
RUN curl -fsSL https://github.com/samtools/htslib/releases/download/${HTSLIB_VERSION}/htslib-${HTSLIB_VERSION}.tar.bz2 \
  | tar -xj && \
  cd htslib-${HTSLIB_VERSION} && \
  ./configure --enable-gcs --enable-libcurl && \
  make -j"$(nproc)" && make install
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/htslib.conf && ldconfig
# (GCS + libcurl is required for streaming gs:// and HTTP(S).) :contentReference[oaicite:2]{index=2}

# ---------- samtools & bcftools (against that htslib) ----------
RUN curl -fsSL https://github.com/samtools/samtools/releases/download/${SAMTOOLS_VERSION}/samtools-${SAMTOOLS_VERSION}.tar.bz2 \
  | tar -xj && cd samtools-${SAMTOOLS_VERSION} && \
  ./configure && make -j"$(nproc)" && make install

RUN curl -fsSL https://github.com/samtools/bcftools/releases/download/${BCFTOOLS_VERSION}/bcftools-${BCFTOOLS_VERSION}.tar.bz2 \
  | tar -xj && cd bcftools-${BCFTOOLS_VERSION} && \
  ./configure && make -j"$(nproc)" && make install

# ---------- STITCH (from a tagged release, per README) ----------
WORKDIR /opt
RUN curl -fsSL -o STITCH.zip "https://github.com/rwdavies/STITCH/archive/refs/tags/${STITCH_VERSION}.zip" && \
    unzip STITCH.zip && mv STITCH-${STITCH_VERSION} STITCH && rm STITCH.zip

WORKDIR /opt/STITCH

# Make the dependency script verbose and fail-fast, and set CRAN mirror
# Also show the script contents before running for easier debugging in CI logs.
RUN sed -n '1,200p' scripts/install-dependencies.sh && \
    bash -euxo pipefail -c '\
      echo "options(repos=c(CRAN=\"${CRAN_URL}\"))" >/etc/R/Rprofile.site; \
      ./scripts/install-dependencies.sh \
    '

# Use project’s recommended installer (runs R install of the built package and sets up STITCH.R) 
RUN make install

# Convenience symlink so tasks can call /STITCH/STITCH.R
RUN ln -sf /opt/STITCH/STITCH.R /STITCH && ln -sf /opt/STITCH/STITCH.R /STITCH/STITCH.R

ENV PATH="/usr/local/bin:${PATH}"
WORKDIR /work
ENTRYPOINT ["/bin/bash"]
