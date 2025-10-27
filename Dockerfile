FROM ubuntu:22.04

# ----- basic env -----
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    HTSLIB_VERSION=1.20 \
    SAMTOOLS_VERSION=1.20 \
    BCFTOOLS_VERSION=1.20 \
    MAMBA_ROOT=/opt/micromamba \
    MAMBA_ROOT_PREFIX=/opt/micromamba

# ----- system deps: compilers, libs, R, bzip2 -----
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
    bzip2 \
    less vim && \
    rm -rf /var/lib/apt/lists/*

# avoid git "dubious ownership" noise
RUN git config --global --add safe.directory '*'

# ----- build & install htslib -----
WORKDIR /opt/src
RUN curl -fsSL https://github.com/samtools/htslib/releases/download/${HTSLIB_VERSION}/htslib-${HTSLIB_VERSION}.tar.bz2 \
  | tar -xj && \
  cd htslib-${HTSLIB_VERSION} && \
  ./configure --enable-gcs --enable-libcurl && \
  make -j"$(nproc)" && make install && \
  echo "/usr/local/lib" > /etc/ld.so.conf.d/htslib.conf && ldconfig

# ----- build & install samtools -----
RUN curl -fsSL https://github.com/samtools/samtools/releases/download/${SAMTOOLS_VERSION}/samtools-${SAMTOOLS_VERSION}.tar.bz2 \
  | tar -xj && \
  cd samtools-${SAMTOOLS_VERSION} && \
  ./configure && make -j"$(nproc)" && make install

# ----- build & install bcftools -----
RUN curl -fsSL https://github.com/samtools/bcftools/releases/download/${BCFTOOLS_VERSION}/bcftools-${BCFTOOLS_VERSION}.tar.bz2 \
  | tar -xj && \
  cd bcftools-${BCFTOOLS_VERSION} && \
  ./configure && make -j"$(nproc)" && make install

# ----- micromamba + STITCH env -----
# micromamba is a tiny self-contained mamba binary commonly used in Docker
# to quickly create conda envs without installing full conda. :contentReference[oaicite:1]{index=1}
#
# we detect arch via TARGETARCH so we pull the right tarball:
#   amd64   -> linux-64
#   arm64   -> linux-aarch64
# this matters because r-stitch exists for both arches on bioconda. :contentReference[oaicite:2]{index=2}
ARG TARGETARCH
RUN set -euo pipefail; \
    case "$TARGETARCH" in \
      "amd64")  MM_ARCH="linux-64" ;; \
      "arm64")  MM_ARCH="linux-aarch64" ;; \
      *) echo "Unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://micro.mamba.pm/api/micromamba/${MM_ARCH}/latest" -o /tmp/micromamba.tar.bz2; \
    tar -xjf /tmp/micromamba.tar.bz2 -C /usr/local/bin --strip-components=1 bin/micromamba; \
    /usr/local/bin/micromamba create -y -p ${MAMBA_ROOT}/envs/stitch \
        -c conda-forge -c bioconda \
        r-base=4.* r-stitch=1.8.4; \
    /usr/local/bin/micromamba clean -a -y; \
    rm -f /tmp/micromamba.tar.bz2

# make sure that env is first on PATH (so Rscript, bcftools from env if any, etc)
ENV PATH="${MAMBA_ROOT}/envs/stitch/bin:${PATH}"

# ----- stitch launcher -----
# we make a stable "stitch" command that finds STITCH.R inside the R package
# (the STITCH R package ships a script called STITCH.R). :contentReference[oaicite:3]{index=3}
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

# backward-compat path because your WDL calls /STITCH/STITCH.R
RUN mkdir -p /STITCH && \
    printf '%s\n' '#!/usr/bin/env bash' 'exec stitch "$@"' > /STITCH/STITCH.R && \
    chmod +x /STITCH/STITCH.R

WORKDIR /work
ENTRYPOINT ["/bin/bash"]
