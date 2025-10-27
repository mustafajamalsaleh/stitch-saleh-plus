FROM stefangroha/stitch_gcs:0.2

# Install dependencies and tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget \
    bzip2 \
    ca-certificates \
    libncurses5-dev \
    zlib1g-dev \
    libbz2-dev \
    liblzma-dev \
    libcurl4-openssl-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install samtools
RUN wget https://github.com/samtools/samtools/releases/download/1.17/samtools-1.17.tar.bz2 && \
    tar -xjf samtools-1.17.tar.bz2 && \
    cd samtools-1.17 && \
    ./configure --prefix=/usr/local && \
    make && \
    make install && \
    cd .. && \
    rm -rf samtools-1.17 samtools-1.17.tar.bz2

# Install bcftools
RUN wget https://github.com/samtools/bcftools/releases/download/1.17/bcftools-1.17.tar.bz2 && \
    tar -xjf bcftools-1.17.tar.bz2 && \
    cd bcftools-1.17 && \
    ./configure --prefix=/usr/local && \
    make && \
    make install && \
    cd .. && \
    rm -rf bcftools-1.17 bcftools-1.17.tar.bz2

# Verify installations
RUN samtools --version && bcftools --version

# Keep the original entrypoint/cmd from base image
