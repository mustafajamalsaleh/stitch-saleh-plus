FROM stefangroha/stitch_gcs:0.2

# Install samtools, bcftools, and rclone via micromamba
RUN curl -fsSL "https://micromamba.snakepit.net/api/micromamba/linux-64/latest" | tar -xvj -C /usr/local bin/micromamba && \
    /usr/local/bin/micromamba create -y -p /opt/biotools -c conda-forge -c bioconda \
        samtools=1.17 \
        bcftools=1.17 \
        rclone && \
    /usr/local/bin/micromamba clean -a -y

ENV PATH="/opt/biotools/bin:$PATH"

# Verify all tools
RUN samtools --version && \
    bcftools --version && \
    rclone --version
