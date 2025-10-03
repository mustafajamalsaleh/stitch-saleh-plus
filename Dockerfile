FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    HTSLIB_VERSION=1.20 \
    SAMTOOLS_VERSION=1.20 \
    BCFTOOLS_VERSION=1.20

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

# ---------- samtools & bcftools (against that htslib) ----------
RUN curl -fsSL https://github.com/samtools/samtools/releases/download/${SAMTOOLS_VERSION}/samtools-${SAMTOOLS_VERSION}.tar.bz2 \
  | tar -xj && cd samtools-${SAMTOOLS_VERSION} && \
  ./configure && make -j"$(nproc)" && make install

RUN curl -fsSL https://github.com/samtools/bcftools/releases/download/${BCFTOOLS_VERSION}/bcftools-${BCFTOOLS_VERSION}.tar.bz2 \
  | tar -xj && cd bcftools-${BCFTOOLS_VERSION} && \
  ./configure && make -j"$(nproc)" && make install

# ---------- STITCH via Bioconda (no source build) ----------
# Install micromamba and create a fixed env with r-stitch
ARG MAMBA_ROOT=/opt/micromamba
ENV MAMBA_ROOT_PREFIX=${MAMBA_ROOT}
RUN curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest \
  | tar -xvj -C /usr/local/bin --strip-components=1 bin/micromamba && \
    micromamba create -y -p ${MAMBA_ROOT}/envs/stitch -c conda-forge -c bioconda r-base=4.* r-stitch=1.8.4 && \
    micromamba clean -a -y
ENV PATH="${MAMBA_ROOT}/envs/stitch/bin:${PATH}"

# Convenience shim so tasks can call /STITCH/STITCH.R (provided by the installed STITCH package)
RUN ln -sf $(Rscript -e 'cat(system.file("scripts","STITCH.R", package="STITCH"))') /STITCH && \
    ln -sf /STITCH /STITCH/STITCH.R

WORKDIR /work
ENTRYPOINT ["/bin/bash"]
