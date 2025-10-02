FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    HTSLIB_VERSION=1.20 \
    SAMTOOLS_VERSION=1.20 \
    BCFTOOLS_VERSION=1.20 \
    STITCH_VERSION=1.8.4

# Core toolchain & headers for R package builds + BLAS/LAPACK
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gfortran autoconf automake libtool pkg-config cmake \
    ca-certificates curl wget git unzip \
    zlib1g-dev libbz2-dev liblzma-dev libdeflate-dev \
    libcurl4-openssl-dev libssl-dev libxml2-dev libgit2-dev \
    libopenblas-dev liblapack-dev \
    r-base r-base-dev \
    less vim \
 && rm -rf /var/lib/apt/lists/*

# ---------- HTSLIB (with GCS) ----------
WORKDIR /opt/src
RUN curl -fsSL https://github.com/samtools/htslib/releases/download/${HTSLIB_VERSION}/htslib-${HTSLIB_VERSION}.tar.bz2 \
  | tar -xj && \
  cd htslib-${HTSLIB_VERSION} && \
  ./configure --enable-gcs --enable-libcurl && \
  make -j"$(nproc)" && make install
# Ensure loader finds libhts.so
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/htslib.conf && ldconfig

# ---------- samtools & bcftools (against that htslib) ----------
RUN curl -fsSL https://github.com/samtools/samtools/releases/download/${SAMTOOLS_VERSION}/samtools-${SAMTOOLS_VERSION}.tar.bz2 \
  | tar -xj && cd samtools-${SAMTOOLS_VERSION} && \
  ./configure && make -j"$(nproc)" && make install

RUN curl -fsSL https://github.com/samtools/bcftools/releases/download/${BCFTOOLS_VERSION}/bcftools-${BCFTOOLS_VERSION}.tar.bz2 \
  | tar -xj && cd bcftools-${BCFTOOLS_VERSION} && \
  ./configure && make -j"$(nproc)" && make install

# ---------- STITCH (follow upstream README scripts) ----------
# See: README "github" section: download release -> scripts/install-dependencies.sh -> build-and-install.R
# https://github.com/rwdavies/STITCH
WORKDIR /opt
RUN curl -fsSL -o STITCH.zip "https://github.com/rwdavies/STITCH/archive/refs/tags/${STITCH_VERSION}.zip" && \
    unzip STITCH.zip && \
    mv STITCH-${STITCH_VERSION} STITCH && \
    rm STITCH.zip

WORKDIR /opt/STITCH
# Installs R package dependencies expected by STITCH
RUN ./scripts/install-dependencies.sh
# Builds and installs STITCH into the system R library
RUN ./scripts/build-and-install.R

# Convenience symlink so tasks can call /STITCH/STITCH.R
RUN ln -sf /opt/STITCH/STITCH.R /STITCH && ln -sf /opt/STITCH/STITCH.R /STITCH/STITCH.R

ENV PATH="/usr/local/bin:${PATH}"
WORKDIR /work
ENTRYPOINT ["/bin/bash"]
