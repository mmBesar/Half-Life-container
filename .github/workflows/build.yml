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
    gcc-multilib \
    g++-multilib \
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
RUN git clone --recursive --depth 1 https://github.com/FWGS/hlsdk-portable.git hlsdk-master

WORKDIR /build/hlsdk-master

# Build HLSDK master with CMake
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release -DGOLDSOURCE_SUPPORT=ON \
    && cmake --build build -j$(nproc)

# Stage 3: Build HLSDK bot10 branch
FROM base-builder AS hlsdk-bot10-builder

# Clone HLSDK bot10 branch
RUN git clone --recursive --depth 1 -b bot10 https://github.com/FWGS/hlsdk-portable.git hlsdk-bot10

WORKDIR /build/hlsdk-bot10

# Build HLSDK bot10 with CMake
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release -DGOLDSOURCE_SUPPORT=ON \
    && cmake --build build -j$(nproc)

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
RUN mkdir -p /opt/xash3d/{bin,data/dlls,valve} \
    && chown -R xash3d:xash3d /opt/xash3d

# Copy Xash3D engine
COPY --from=xash3d-builder /build/xash3d-fwgs/build/engine/xash3d /opt/xash3d/bin/

# Copy HLSDK master files
COPY --from=hlsdk-master-builder /build/hlsdk-master/build/dlls/hl.so /opt/xash3d/data/dlls/hl_$(uname -m | sed 's/x86_64/amd64/').so
COPY --from=hlsdk-master-builder /build/hlsdk-master/build/cl_dll/client.so /opt/xash3d/data/dlls/client_$(uname -m | sed 's/x86_64/amd64/').so

# Copy HLSDK bot10 files  
COPY --from=hlsdk-bot10-builder /build/hlsdk-bot10/build/dlls/hl.so /opt/xash3d/data/dlls/bot_$(uname -m | sed 's/x86_64/amd64/').so

# Create entrypoint script
RUN cat > /opt/xash3d/entrypoint.sh << 'EOF'
#!/bin/bash
set -e

# Default values
: "${HLSERVER_PORT:=27015}"
: "${HLSERVER_IP:=0.0.0.0}"
: "${HLSERVER_MAP:=stalkyard}"
: "${HLSERVER_MAXPLAYERS:=16}"
: "${HLSERVER_GAME:=valve}"
: "${HLSERVER_HOSTNAME:=Xash3D Server}"
: "${HLSERVER_PASSWORD:=}"
: "${HLSERVER_RCON_PASSWORD:=}"
: "${HLSERVER_DLL:=hl}"
: "${HLSERVER_EXTRA_ARGS:=}"

echo "Starting Xash3D server..."
echo "Port: $HLSERVER_PORT"
echo "IP: $HLSERVER_IP"
echo "Map: $HLSERVER_MAP"
echo "Max Players: $HLSERVER_MAXPLAYERS"
echo "Game: $HLSERVER_GAME"
echo "Hostname: $HLSERVER_HOSTNAME"
echo "DLL: $HLSERVER_DLL"

# Detect architecture
ARCH=$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')

# Build server arguments
ARGS=(
    "-dedicated"
    "-port" "$HLSERVER_PORT"
    "-ip" "$HLSERVER_IP"
    "-game" "$HLSERVER_GAME"
    "-dll" "/opt/xash3d/data/dlls/${HLSERVER_DLL}_${ARCH}.so"
    "+hostname" "$HLSERVER_HOSTNAME"
    "+maxplayers" "$HLSERVER_MAXPLAYERS"
    "+map" "$HLSERVER_MAP"
)

# Add optional parameters
if [ -n "$HLSERVER_PASSWORD" ]; then
    ARGS+=("+sv_password" "$HLSERVER_PASSWORD")
fi

if [ -n "$HLSERVER_RCON_PASSWORD" ]; then
    ARGS+=("+rcon_password" "$HLSERVER_RCON_PASSWORD")
fi

# Add extra args if provided
if [ -n "$HLSERVER_EXTRA_ARGS" ]; then
    eval "ARGS+=($HLSERVER_EXTRA_ARGS)"
fi

echo "Starting with args: ${ARGS[*]}"

# Start the server
exec /opt/xash3d/bin/xash3d "${ARGS[@]}"
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
    HLSERVER_GAME=valve \
    HLSERVER_HOSTNAME="Xash3D Server" \
    HLSERVER_PASSWORD="" \
    HLSERVER_RCON_PASSWORD="" \
    HLSERVER_DLL=hl \
    HLSERVER_EXTRA_ARGS=""

ENTRYPOINT ["/opt/xash3d/entrypoint.sh"]
