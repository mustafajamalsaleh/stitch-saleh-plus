FROM stefangroha/stitch_gcs:0.2

# Install samtools and bcftools once
RUN apt-get update && \
    apt-get install -y samtools bcftools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
