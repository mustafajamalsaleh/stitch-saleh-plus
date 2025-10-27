FROM stefangroha/stitch_gcs:0.2

# Use micromamba (lightweight conda) to install samtools and bcftools
# This avoids apt-get issues and is compatible with most base images
RUN curl -fsSL "https://micromamba.snakepit.net/api/micromamba/linux-64/latest" | tar -xvj -C /usr/local bin/micromamba && \
    /usr/local/bin/micromamba create -y -p /opt/biotools -c conda-forge -c bioconda samtools=1.17 bcftools=1.17 && \
    /usr/local/bin/micromamba clean -a -y

# Add tools to PATH so they're available directly
ENV PATH="/opt/biotools/bin:$PATH"

# Verify installations
RUN samtools --version && bcftools --version
