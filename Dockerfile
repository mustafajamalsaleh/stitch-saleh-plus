FROM stefangroha/stitch_gcs:0.2

# Install samtools, bcftools, gcsfuse via micromamba
RUN curl -fsSL "https://micromamba.snakepit.net/api/micromamba/linux-64/latest" | tar -xvj -C /usr/local bin/micromamba && \
    /usr/local/bin/micromamba create -y -p /opt/biotools -c conda-forge -c bioconda \
        samtools=1.17 \
        bcftools=1.17 \
        gcsfuse && \
    /usr/local/bin/micromamba clean -a -y

ENV PATH="/opt/biotools/bin:$PATH"

# Install FUSE/fusermount via apt-get (needed for gcsfuse to mount)
RUN apt-get update && \
    apt-get install -y fuse && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Verify all tools
RUN samtools --version && \
    bcftools --version && \
    gcsfuse --version && \
    fusermount --version
