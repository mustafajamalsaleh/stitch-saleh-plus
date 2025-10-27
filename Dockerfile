FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    HTSLIB_VERSION=1.20 \
    SAMTOOLS_VERSION=1.20 \
    BCFTOOLS_VERSION=1.20

# base deps: compilers, libs for htslib/samtools/bcftools, R
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gfortran autoconf automake libtool pkg-config cmake \
    ca-certificates curl wget git unzip bzip2 \
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

# avoid git "dubious ownership" warnings
RUN git config --global --add safe.directory '*'

# ---------- build & install htslib ----------
WORKDIR /opt/src
RUN curl -fsSL https://github.com/samtools/htslib/releases/download/${HTSLIB_VERSION}/htslib-${HTSLIB_VERSION}.tar.bz2 \
  | tar -xj && \
  cd htslib-${HTSLIB_VERSION} && \
  ./configure --enable-gcs --enable-libcurl && \
  make -j"$(nproc)" && make install && \
  echo "/usr/local/lib" > /etc/ld.so.conf.d/htslib.conf && ldconfig

# ---------- build & install samtools ----------
RUN curl -fsSL https://github.com/samtools/samtools/releases/download/${SAMTOOLS_VERSION}/samtools-${SAMTOOLS_VERSION}.tar.bz2 \
  | tar -xj && \
  cd samtools-${SAMTOOLS_VERSION} && \
  ./configure && make -j"$(nproc)" && make install

# ---------- build & install bcftools ----------
RUN curl -fsSL https://github.com/samtools/bcftools/releases/download/${BCFTOOLS_VERSION}/bcftools-${BCFTOOLS_VERSION}.tar.bz2 \
  | tar -xj && \
  cd bcftools-${BCFTOOLS_VERSION} && \
  ./configure && make -j"$(nproc)" && make install

# ---------- install STITCH in system R ----------
RUN Rscript -e 'install.packages("remotes", repos="https://cloud.r-project.org")' && \
    Rscript -e 'remotes::install_github("davidsli/STITCH")'

# wrapper that resolves STITCH.R location dynamically
RUN cat > /usr/local/bin/stitch <<'EOF' && chmod +x /usr/local/bin/stitch
#!/usr/bin/env bash
set -euo pipefail
p=$(Rscript -e 'cat(system.file("scripts","STITCH.R", package="STITCH"))')
if [ -z "$p" ] || [ ! -f "$p" ]; then
  echo "ERROR: STITCH.R not found in STITCH package" >&2
  exit 1
fi
exec Rscript "$p" "$@"
EOF

# keep /STITCH/STITCH.R for WDL
RUN mkdir -p /STITCH && \
    printf '%s\n' '#!/usr/bin/env bash' 'exec stitch "$@"' > /STITCH/STITCH.R && \
    chmod +x /STITCH/STITCH.R

WORKDIR /work
ENTRYPOINT ["/bin/bash"]
