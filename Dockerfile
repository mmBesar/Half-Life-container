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
    libfreetype6-dev \
    libopus-dev \
    libbz2-dev \
    libvorbis-dev \
    libopusfile-dev \
    libogg-dev \
    pkg-config \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Clone the repository with all submodules
RUN git clone --recursive https://github.com/FWGS/xash3d-fwgs.git .

# Configure the build for dedicated server only
# The --dedicated flag tells WAF to build without SDL2 dependencies (server only)
# The -8 flag builds 64-bit on x86_64, omit for 32-bit
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        ./waf configure --dedicated --build-type=release -8; \
    else \
        ./waf configure --dedicated --build-type=release; \
    fi

# Build the project
RUN ./waf build

# Install to a clean directory structure similar to official releases
RUN ./waf install --destdir=/tmp/install && \
    mkdir -p /xashds && \
    # Find the main executable and copy it as 'xash' to match your entrypoint
    find /tmp/install -name "xash3d" -type f -exec cp {} /xashds/xash \; && \
    # Copy any shared libraries
    find /tmp/install -name "*.so" -type f -exec cp {} /xashds/ \; && \
    # Make sure the main executable is executable
    chmod +x /xashds/xash

# Final runtime stage
FROM ubuntu:24.04

ARG UID=1000
ARG GID=1000

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies - simplified approach
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        libfreetype6 \
        libopus0 \
        libbz2-1.0 \
        libvorbis0a \
        libopusfile0 \
        libogg0 \
    && rm -rf /var/lib/apt/lists/*

# Create user and group
RUN groupadd -g "$GID" hl && useradd -m -u "$UID" -g hl hl

# Copy the built binaries from builder stage (matching your original structure)
COPY --from=builder /xashds /opt/xashds

# Set working directory and copy entrypoint
WORKDIR /data
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to non-root user
USER hl

# Environment variables (matching your original)
ENV XASH3D_BASE=/opt/xashds

# Use your existing entrypoint
ENTRYPOINT ["entrypoint.sh"]
