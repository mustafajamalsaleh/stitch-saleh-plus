FROM stefangroha/stitch_gcs:0.2

# Use micromamba to install samtools and bcftools
RUN curl -fsSL "https://micromamba.snakepit.net/api/micromamba/linux-64/latest" | tar -xvj -C /usr/local bin/micromamba && \
    /usr/local/bin/micromamba create -y -p /opt/biotools -c conda-forge -c bioconda samtools=1.17 bcftools=1.17 && \
    /usr/local/bin/micromamba clean -a -y

# Add tools to PATH
ENV PATH="/opt/biotools/bin:$PATH"

# Verify samtools/bcftools
RUN samtools --version && bcftools --version

# Install GCSFUSE via direct binary download (works on any Linux)
RUN curl -L -o /tmp/gcsfuse.tar.gz https://github.com/GoogleCloudPlatform/gcsfuse/releases/download/v2.6.0/gcsfuse_2.6.0_amd64.tar.gz && \
    tar -xzf /tmp/gcsfuse.tar.gz -C /usr/local/bin && \
    chmod +x /usr/local/bin/gcsfuse && \
    rm /tmp/gcsfuse.tar.gz

# Verify GCSFUSE
RUN gcsfuse --version
