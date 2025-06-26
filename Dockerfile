FROM ubuntu:24.04 AS builder

ARG TARGETARCH
ARG TARGETPLATFORM

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    python3 \
    python3-pip \
    gcc \
    g++ \
    libc6-dev \
    pkg-config \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Clone the repository with all submodules
RUN git clone --recursive https://github.com/FWGS/xash3d-fwgs.git .

# Configure the build for dedicated server only
# The --dedicated flag builds server without SDL2 dependencies
# -T release sets release build type
# -8 builds 64-bit on x86_64 architecture
RUN case "$TARGETARCH" in \
        amd64) ./waf configure --dedicated -T release -8 ;; \
        arm64) ./waf configure --dedicated -T release ;; \
        *) ./waf configure --dedicated -T release ;; \
    esac

# Build the project
RUN ./waf build

# Install to a temporary directory and prepare final structure  
RUN ./waf install --destdir=/tmp/install && \
    mkdir -p /xashds && \
    echo "=== Contents of /tmp/install ===" && \
    find /tmp/install -type f -executable && \
    echo "=== All files in /tmp/install ===" && \
    find /tmp/install -type f && \
    # Copy the main executable - it should be named 'xash3d' in the install directory
    find /tmp/install -name "*xash*" -type f -executable | head -1 | xargs -I {} cp {} /xashds/xash && \
    # Copy engine library if it exists
    find /tmp/install -name "*.so" -type f | xargs -I {} cp {} /xashds/ 2>/dev/null || true && \
    # Ensure executable permissions
    chmod +x /xashds/xash && \
    echo "=== Final /xashds contents ===" && \
    ls -la /xashds/

# Final runtime stage
FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install minimal runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        libc6 \
    && rm -rf /var/lib/apt/lists/*

# Copy the built binaries from builder stage
COPY --from=builder /xashds /opt/xashds

# Set working directory and copy entrypoint
WORKDIR /data
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Environment variables
ENV XASH3D_BASE=/opt/xashds

# Use the entrypoint
ENTRYPOINT ["entrypoint.sh"]
