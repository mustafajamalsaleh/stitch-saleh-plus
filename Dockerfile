# Use Google Cloud SDK image (has FUSE support)
FROM google/cloud-sdk:alpine

# Install basic tools
RUN apk add --no-cache bash curl tar

# Install micromamba
RUN curl -fsSL "https://micromamba.snakepit.net/api/micromamba/linux-64/latest" | tar -xvj -C /usr/local bin/micromamba && \
    /usr/local/bin/micromamba create -y -p /opt/biotools -c conda-forge -c bioconda \
        samtools=1.17 \
        bcftools=1.17 && \
    /usr/local/bin/micromamba clean -a -y

# Install GCSFUSE
RUN curl -L https://github.com/GoogleCloudPlatform/gcsfuse/releases/download/v2.6.0/gcsfuse-v2.6.0-linux-amd64.tar.gz | tar -xz -C /usr/local/bin

# Install STITCH manually
# (You'd need to add STITCH installation here - complex!)

ENV PATH="/opt/biotools/bin:$PATH"

RUN samtools --version && bcftools --version && gcsfuse --version
