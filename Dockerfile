FROM stefangroha/stitch_gcs:0.2

# Use micromamba to install samtools and bcftools
RUN curl -fsSL "https://micromamba.snakepit.net/api/micromamba/linux-64/latest" | tar -xvj -C /usr/local bin/micromamba && \
    /usr/local/bin/micromamba create -y -p /opt/biotools -c conda-forge -c bioconda samtools=1.17 bcftools=1.17 && \
    /usr/local/bin/micromamba clean -a -y

# Add tools to PATH
ENV PATH="/opt/biotools/bin:$PATH"

# Verify samtools/bcftools
RUN samtools --version && bcftools --version

# Install GCSFUSE for Tier 2 streaming
RUN export GCSFUSE_REPO=gcsfuse-$(lsb_release -c -s) && \
    echo "deb http://packages.cloud.google.com/apt $GCSFUSE_REPO main" | tee /etc/apt/sources.list.d/gcsfuse.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    apt-get update && \
    apt-get install -y gcsfuse fuse && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Verify GCSFUSE
RUN which gcsfuse && gcsfuse --version
