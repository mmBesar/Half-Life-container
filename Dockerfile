# Multi-stage build for Xash3D-FWGS Dedicated Server
# Stage 1: Build environment
FROM ubuntu:24.04 as builder

# Set build arguments for architecture support
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
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Clone the repository with all submodules
RUN git clone --recursive https://github.com/FWGS/xash3d-fwgs.git .

# Configure environment for cross-compilation if needed
ENV CC=gcc
ENV CXX=g++

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

# Install to a clean directory
RUN ./waf install --destdir=/install

# Stage 2: Runtime environment
FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies (minimal for server)
RUN apt-get update && apt-get install -y \
    libfreetype6 \
    libopus0 \
    libbz2-1.0 \
    libvorbis0a \
    libopusfile0 \
    libogg0 \
    libstdc++6 \
    libc6 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN groupadd -r xash3d && useradd -r -g xash3d -d /home/xash3d -s /bin/bash xash3d \
    && mkdir -p /home/xash3d /data \
    && chown -R xash3d:xash3d /home/xash3d /data

# Copy the built binaries from builder stage
COPY --from=builder /install/ /opt/xash3d/
COPY --from=builder /build/build/ /opt/xash3d/build/

# Set proper permissions
RUN chmod +x /opt/xash3d/xash3d && \
    chown -R xash3d:xash3d /opt/xash3d

# Create symlinks for easier access
RUN ln -s /opt/xash3d/xash3d /usr/local/bin/xash3d

# Switch to non-root user
USER xash3d

# Set working directory
WORKDIR /data

# Expose default ports (you can override these)
EXPOSE 27015/udp 27015/tcp

# Environment variables for server configuration
ENV XASH3D_BASEDIR=/data
ENV XASH3D_RODIR=/opt/xash3d

# Default command to run the dedicated server
# Users should mount their game data to /data
CMD ["xash3d", "-dedicated", "+map", "crossfire", "+maxplayers", "16"]
