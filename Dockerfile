# Multi-arch Dockerfile for Xash3D FWGS Half-Life Server
FROM ubuntu:22.04

# Set platform-specific variables
ARG TARGETPLATFORM
ARG BUILDPLATFORM

# Install minimal dependencies for dedicated server
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    cmake \
    python3 \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Create user for running the server
RUN useradd -m -s /bin/bash hlserver

# Set working directory
WORKDIR /home/hlserver

# Clone and build Xash3D FWGS
RUN git clone --recursive https://github.com/FWGS/xash3d-fwgs.git
WORKDIR /home/hlserver/xash3d-fwgs

# Build for dedicated server
RUN ./waf configure -T release --dedicated
RUN ./waf build

# Create server directory structure
WORKDIR /home/hlserver
RUN mkdir -p server/valve server/valve/maps server/valve/models server/valve/sprites server/valve/sound

# Find and copy built binaries (they might be in different locations)
RUN find xash3d-fwgs/build -name "xash3d*" -type f -executable | head -10
RUN find xash3d-fwgs/build -name "*dedicated*" -type f -executable -exec cp {} server/ \;

# If dedicated binary not found, try copying the main engine binary
RUN if [ ! -f server/*dedicated* ]; then \
    find xash3d-fwgs/build -name "xash3d" -type f -executable -exec cp {} server/xash3d-dedicated \; \
    fi

# Set permissions
RUN chown -R hlserver:hlserver /home/hlserver/server
USER hlserver

# Expose Half-Life default port
EXPOSE 27015/udp

# Set working directory to server
WORKDIR /home/hlserver/server

# Default command to run dedicated server
CMD ["./xash3d-dedicated", "-dedicated", "+map", "crossfire", "+maxplayers", "16", "+sv_lan", "0"]
