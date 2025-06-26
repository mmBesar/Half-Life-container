# Multi-stage Dockerfile for Xash3D FWGS Server
# Supports both amd64 and arm64 architectures

# Build stage for Xash3D FWGS engine
FROM debian:bookworm-slim AS xash3d-builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc-multilib \
    g++ \
    python3 \
    python3-pip \
    git \
    wget \
    pkg-config \
    libfontconfig1-dev \
    libfreetype6-dev \
    zlib1g-dev \
    libpng-dev \
    libjpeg-dev \
    libvorbis-dev \
    libogg-dev \
    libopus-dev \
    libopusfile-dev \
    libsdl2-dev \
    cmake \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Clone Xash3D FWGS
RUN git clone --recursive https://github.com/FWGS/xash3d-fwgs.git

# Build Xash3D FWGS engine (server only)
WORKDIR /build/xash3d-fwgs
RUN ./waf configure --build-type=release --dedicated
RUN ./waf build

# Build stage for HLSDK (master branch)
FROM debian:bookworm-slim AS hlsdk-master-builder

RUN apt-get update && apt-get install -y \
    build-essential \
    gcc-multilib \
    g++ \
    git \
    cmake \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Clone HLSDK master branch
RUN git clone https://github.com/FWGS/hlsdk-portable.git hlsdk-master
WORKDIR /build/hlsdk-master

# Build HLSDK master branch
RUN mkdir build && cd build
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release
RUN cmake --build build --parallel $(nproc)

# Build stage for HLSDK (bot10 branch)  
FROM debian:bookworm-slim AS hlsdk-bot10-builder

RUN apt-get update && apt-get install -y \
    build-essential \
    gcc-multilib \
    g++ \
    git \
    cmake \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Clone HLSDK bot10 branch
RUN git clone -b bot10 https://github.com/FWGS/hlsdk-portable.git hlsdk-bot10
WORKDIR /build/hlsdk-bot10

# Build HLSDK bot10 branch
RUN mkdir build && cd build
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release
RUN cmake --build build --parallel $(nproc)

# Runtime stage
FROM debian:bookworm-slim AS runtime

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libsdl2-2.0-0 \
    libvorbisfile3 \
    libopusfile0 \
    libfreetype6 \
    libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*

# Create user for running the server
RUN useradd -m -u 1000 xash3d

# Create directories
RUN mkdir -p /opt/xash3d/bin /opt/xash3d/valve /opt/xash3d/hlsdk

# Copy Xash3D FWGS binaries
COPY --from=xash3d-builder /build/xash3d-fwgs/build/engine/xash3d /opt/xash3d/bin/
COPY --from=xash3d-builder /build/xash3d-fwgs/build/game_launch/xash3d.sh /opt/xash3d/bin/

# Copy HLSDK libraries (master branch)
COPY --from=hlsdk-master-builder /build/hlsdk-master/build/dlls/hl.so /opt/xash3d/hlsdk/hl_amd64.so
COPY --from=hlsdk-master-builder /build/hlsdk-master/build/cl_dll/client.so /opt/xash3d/hlsdk/client_amd64.so

# Copy HLSDK libraries (bot10 branch)
COPY --from=hlsdk-bot10-builder /build/hlsdk-bot10/build/dlls/hl.so /opt/xash3d/hlsdk/bot_amd64.so

# Create symbolic links script
COPY <<'EOF' /opt/xash3d/bin/setup-hlsdk.sh
#!/bin/bash
set -e

# Default to master branch
HLSDK_BRANCH=${HLSDK_BRANCH:-master}

# Remove existing links
rm -f /opt/xash3d/valve/dlls/hl.so
rm -f /opt/xash3d/valve/cl_dlls/client.so

# Create directories
mkdir -p /opt/xash3d/valve/dlls
mkdir -p /opt/xash3d/valve/cl_dlls

# Link appropriate libraries based on branch selection
if [ "$HLSDK_BRANCH" = "bot10" ]; then
    echo "Using bot10 branch (with bots)"
    ln -sf /opt/xash3d/hlsdk/bot_amd64.so /opt/xash3d/valve/dlls/hl.so
    # For bot10, we still need the client dll from master
    ln -sf /opt/xash3d/hlsdk/client_amd64.so /opt/xash3d/valve/cl_dlls/client.so
else
    echo "Using master branch (standard)"
    ln -sf /opt/xash3d/hlsdk/hl_amd64.so /opt/xash3d/valve/dlls/hl.so
    ln -sf /opt/xash3d/hlsdk/client_amd64.so /opt/xash3d/valve/cl_dlls/client.so
fi
EOF

RUN chmod +x /opt/xash3d/bin/setup-hlsdk.sh

# Create server startup script
COPY <<'EOF' /opt/xash3d/bin/start-server.sh
#!/bin/bash
set -e

# Set up HLSDK libraries based on environment
/opt/xash3d/bin/setup-hlsdk.sh

# Default environment variables
: "${HLSERVER_PORT:=27015}"
: "${HLSERVER_IP:=0.0.0.0}"
: "${HLSERVER_MAP:=stalkyard}"
: "${HLSERVER_MAXPLAYERS:=16}"
: "${HLSERVER_BOTS:=false}"
: "${HLSERVER_GAME:=valve}"
: "${HLSDK_BRANCH:=master}"

# Build command line arguments
XASH_ARGS="-dedicated -ip ${HLSERVER_IP} -port ${HLSERVER_PORT} +map ${HLSERVER_MAP} +maxplayers ${HLSERVER_MAXPLAYERS} -game ${HLSERVER_GAME}"

# Add bot configuration if using bot10 branch
if [ "$HLSDK_BRANCH" = "bot10" ] && [ "$HLSERVER_BOTS" = "true" ]; then
    XASH_ARGS="${XASH_ARGS} +exec bot.cfg"
fi

echo "Starting Xash3D FWGS server..."
echo "Game: ${HLSERVER_GAME}"
echo "Map: ${HLSERVER_MAP}"
echo "IP: ${HLSERVER_IP}:${HLSERVER_PORT}"
echo "Max players: ${HLSERVER_MAXPLAYERS}"
echo "HLSDK Branch: ${HLSDK_BRANCH}"
echo "Bots enabled: ${HLSERVER_BOTS}"
echo ""

cd /opt/xash3d
exec ./bin/xash3d ${XASH_ARGS}
EOF

RUN chmod +x /opt/xash3d/bin/start-server.sh

# Set ownership
RUN chown -R xash3d:xash3d /opt/xash3d

# Switch to non-root user
USER xash3d

# Set working directory
WORKDIR /opt/xash3d

# Expose the default port
EXPOSE 27015/udp

# Set default environment variables
ENV HLSERVER_PORT=27015
ENV HLSERVER_IP=0.0.0.0
ENV HLSERVER_MAP=stalkyard
ENV HLSERVER_MAXPLAYERS=16
ENV HLSERVER_BOTS=false
ENV HLSERVER_GAME=valve
ENV HLSDK_BRANCH=master

# Start the server
CMD ["/opt/xash3d/bin/start-server.sh"]
