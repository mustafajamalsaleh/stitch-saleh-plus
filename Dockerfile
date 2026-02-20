FROM stefangroha/stitch_gcs:0.2

# Install samtools, bcftools, gcsfuse via micromamba
RUN curl -fsSL "https://micromamba.snakepit.net/api/micromamba/linux-64/latest" | tar -xvj -C /usr/local bin/micromamba && \
    /usr/local/bin/micromamba create -y -p /opt/biotools -c conda-forge -c bioconda \
        samtools=1.17 \
        bcftools=1.17 \
        gcsfuse && \
    /usr/local/bin/micromamba clean -a -y

ENV PATH="/opt/biotools/bin:$PATH"

# Check if fusermount exists anywhere in the system and symlink it
RUN find / -name fusermount 2>/dev/null | head -1 | xargs -I {} ln -sf {} /opt/biotools/bin/fusermount || echo "fusermount not found in base image"

# Verify tools
RUN samtools --version && bcftools --version && gcsfuse --version
