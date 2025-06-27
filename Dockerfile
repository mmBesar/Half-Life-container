# Multi-stage Dockerfile for Xash3D-FWGS server with HLSDK support
FROM debian:bookworm-slim AS base-builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    python3 \
    python3-pip \
    git \
    pkg-config \
    libsdl2-dev \
    libfontconfig-dev \
    libfreetype6-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Waf
RUN python3 -m pip install --break-system-packages waf

WORKDIR /build

# Stage 1: Build Xash3D-FWGS engine
FROM base-builder AS xash3d-builder

# Clone Xash3D-FWGS with submodules
RUN git clone --recursive --depth 1 https://github.com/FWGS/xash3d-fwgs.git

WORKDIR /build/xash3d-fwgs

# Configure and build Xash3D (dedicated server only)
RUN python3 waf configure -T release --dedicated --64bits \
    && python3 waf build

# Stage 2: Build HLSDK master branch
FROM base-builder AS hlsdk-master-builder

# Clone HLSDK master branch
RUN git clone --depth 1 https://github.com/FWGS/hlsdk-portable.git hlsdk-master

WORKDIR /build/hlsdk-master

# Build HLSDK master with CMake
RUN mkdir build && cd build \
    && cmake .. -DCMAKE_BUILD_TYPE=Release -DGOLDSOURCE_SUPPORT=ON \
    && make -j$(nproc)

# Stage 3: Build HLSDK bot10 branch
FROM base-builder AS hlsdk-bot10-builder

# Clone HLSDK bot10 branch
RUN git clone --depth 1 -b bot10 https://github.com/FWGS/hlsdk-portable.git hlsdk-bot10

WORKDIR /build/hlsdk-bot10

# Build HLSDK bot10 with CMake
RUN mkdir build && cd build \
    && cmake .. -DCMAKE_BUILD_TYPE=Release -DGOLDSOURCE_SUPPORT=ON \
    && make -j$(nproc)

# Final runtime stage
FROM debian:bookworm-slim AS runtime

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libsdl2-2.0-0 \
    libfontconfig1 \
    libfreetype6 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -r -s /bin/false -d /opt/xash3d xash3d

# Create directories
RUN mkdir -p /opt/xash3d/{bin,hlsdk,valve} \
    && chown -R xash3d:xash3d /opt/xash3d

# Copy Xash3D engine
COPY --from=xash3d-builder /build/xash3d-fwgs/build/engine/xash3d /opt/xash3d/bin/

# Copy HLSDK master files
COPY --from=hlsdk-master-builder /build/hlsdk-master/build/dlls/hl.so /opt/xash3d/hlsdk/hl_amd64.so
COPY --from=hlsdk-master-builder /build/hlsdk-master/build/cl_dll/client.so /opt/xash3d/hlsdk/client_amd64.so

# Copy HLSDK bot10 files
COPY --from=hlsdk-bot10-builder /build/hlsdk-bot10/build/dlls/hl.so /opt/xash3d/hlsdk/bot_amd64.so

# Create entrypoint script
RUN cat > /opt/xash3d/entrypoint.sh << 'EOF'
#!/bin/bash
set -e

# Default values
: "${HLSERVER_PORT:=27015}"
: "${HLSERVER_IP:=0.0.0.0}"
: "${HLSERVER_MAP:=stalkyard}"
: "${HLSERVER_MAXPLAYERS:=16}"
: "${HLSERVER_BOTS:=false}"
: "${HLSERVER_GAME:=valve}"

echo "Starting Xash3D server..."
echo "Port: $HLSERVER_PORT"
echo "IP: $HLSERVER_IP"
echo "Map: $HLSERVER_MAP"
echo "Max Players: $HLSERVER_MAXPLAYERS"
echo "Bots: $HLSERVER_BOTS"
echo "Game: $HLSERVER_GAME"

# Set up game library based on bot preference
if [ "$HLSERVER_BOTS" = "true" ]; then
    echo "Using bot10 branch (with bots support)"
    ln -sf /opt/xash3d/hlsdk/bot_amd64.so /opt/xash3d/valve/dlls/hl.so
else
    echo "Using master branch (standard)"
    ln -sf /opt/xash3d/hlsdk/hl_amd64.so /opt/xash3d/valve/dlls/hl.so
    ln -sf /opt/xash3d/hlsdk/client_amd64.so /opt/xash3d/valve/cl_dlls/client.so
fi

# Ensure directories exist
mkdir -p /opt/xash3d/valve/{dlls,cl_dlls}

# Start the server
exec /opt/xash3d/bin/xash3d \
    -dedicated \
    -port "$HLSERVER_PORT" \
    -ip "$HLSERVER_IP" \
    +map "$HLSERVER_MAP" \
    -maxplayers "$HLSERVER_MAXPLAYERS" \
    -game "$HLSERVER_GAME"
EOF

RUN chmod +x /opt/xash3d/entrypoint.sh \
    && chown xash3d:xash3d /opt/xash3d/entrypoint.sh

# Switch to non-root user
USER xash3d
WORKDIR /opt/xash3d

# Expose default port
EXPOSE 27015/udp

# Environment variables with defaults
ENV HLSERVER_PORT=27015 \
    HLSERVER_IP=0.0.0.0 \
    HLSERVER_MAP=stalkyard \
    HLSERVER_MAXPLAYERS=16 \
    HLSERVER_BOTS=false \
    HLSERVER_GAME=valve

ENTRYPOINT ["/opt/xash3d/entrypoint.sh"]
