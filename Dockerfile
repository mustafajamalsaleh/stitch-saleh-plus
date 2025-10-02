FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    HTSLIB_VERSION=1.20 \
    SAMTOOLS_VERSION=1.20 \
    BCFTOOLS_VERSION=1.20

# Toolchain, headers for R pkgs, BLAS/LAPACK, plus pandoc/qpdf (avoid vignette failures)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gfortran autoconf automake libtool pkg-config cmake \
    ca-certificates curl wget git unzip \
    zlib1g-dev libbz2-dev liblzma-dev libdeflate-dev \
    libcurl4-openssl-dev libssl-dev libxml2-dev libgit2-dev \
    libopenblas-dev liblapack-dev \
    pandoc qpdf \
    r-base r-base-dev \
    less vim \
 && rm -rf /var/lib/apt/lists/*

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

# ---------- Install STITCH via pak (recommended in README) ----------
# pak resolves R deps cleanly; we also skip building vignettes/manuals to avoid TeX requirements.
ENV R_INSTALL_ARGS="--no-manual --no-build-vignettes" \
    R_BUILD_ARGS="--no-build-vignettes"
RUN Rscript -e 'install.packages("pak", repos="https://cloud.r-project.org")' && \
    Rscript -e 'pak::pkg_install("rwdavies/STITCH/STITCH", ask=FALSE)'

# Convenience symlink so you can call /STITCH/STITCH.R
RUN Rscript -e 'cat(system.file("scripts","STITCH.R", package="STITCH"))' \
    | xargs -I{} ln -s {} /STITCH && \
    ln -sf /STITCH /STITCH/STITCH.R

ENV PATH="/usr/local/bin:${PATH}"
WORKDIR /work
ENTRYPOINT ["/bin/bash"]

