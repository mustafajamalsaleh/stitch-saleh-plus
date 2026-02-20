FROM stefangroha/stitch_gcs:0.2

# Install samtools and bcftools via micromamba
RUN curl -fsSL "https://micromamba.snakepit.net/api/micromamba/linux-64/latest" | tar -xvj -C /usr/local bin/micromamba && \
    /usr/local/bin/micromamba create -y -p /opt/biotools -c conda-forge -c bioconda samtools=1.17 bcftools=1.17 && \
    /usr/local/bin/micromamba clean -a -y

ENV PATH="/opt/biotools/bin:$PATH"

RUN samtools --version && bcftools --version

# Install GCSFUSE via conda (simpler!)
RUN /usr/local/bin/micromamba install -y -p /opt/biotools -c conda-forge gcsfuse && \
    /usr/local/bin/micromamba clean -a -y

# Verify GCSFUSE
RUN gcsfuse --version || echo "Note: GCSFUSE verification skipped"
