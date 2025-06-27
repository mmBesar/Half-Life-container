FROM debian:bookworm-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    cmake \
    python3 \
    python3-pip \
    pkg-config \
    libsdl2-dev \
    libfontconfig-dev \
    libfreetype6-dev \
    && rm -rf /var/lib/apt/lists/*

# Create build directory
WORKDIR /build

# Clone Xash3D-FWGS engine
RUN git clone --recursive https://github.com/FWGS/xash3d-fwgs.git

# Clone HLSDK-portable master branch
RUN git clone https://github.com/FWGS/hlsdk-portable.git hlsdk-master

# Clone HLSDK-portable bot10 branch
RUN git clone -b bot10 https://github.com/FWGS/hlsdk-portable.git hlsdk-bot10

# Build Xash3D-FWGS engine (server only)
WORKDIR /build/xash3d-fwgs
RUN ./waf configure -T release --dedicated --enable-lto --enable-bundled-deps
RUN ./waf build

# Build HLSDK master branch (regular Half-Life)
WORKDIR /build/hlsdk-master
RUN mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc)

# Build HLSDK bot10 branch (with bots)
WORKDIR /build/hlsdk-bot10
RUN mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc)

# Runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libsdl2-2.0-0 \
    libfontconfig1 \
    libfreetype6 \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /opt/xash3d/valve/dlls /opt/xash3d/data/dll

# Copy Xash3D engine binaries
COPY --from=builder /build/xash3d-fwgs/build/engine/xash3d /opt/xash3d/

# Copy HLSDK libraries
# Master branch libraries
COPY --from=builder /build/hlsdk-master/build/dlls/hl.so /opt/xash3d/data/dll/hl.so
COPY --from=builder /build/hlsdk-master/build/cl_dll/client.so /opt/xash3d/data/dll/client.so

# Bot10 branch library
COPY --from=builder /build/hlsdk-bot10/build/dlls/hl.so /opt/xash3d/data/dll/bot.so

# Create valve directory and link default libraries
RUN ln -sf /opt/xash3d/data/dll/hl.so /opt/xash3d/valve/dlls/hl.so && \
    ln -sf /opt/xash3d/data/dll/client.so /opt/xash3d/valve/dlls/client.so

# Environment variables with defaults
ENV HLSERVER_PORT=27015
ENV HLSERVER_IP=0.0.0.0
ENV HLSERVER_MAP=stalkyard
ENV HLSERVER_MAXPLAYERS=16
ENV HLSERVER_BOTS=false
ENV HLSERVER_GAME=valve
ENV HLSERVER_DLL=hl

# Create startup script
RUN cat > /opt/xash3d/start-server.sh << 'EOF'
#!/bin/bash

# Set up game directory
GAME_DIR="/opt/xash3d/${HLSERVER_GAME}"
mkdir -p "${GAME_DIR}/dlls"

# Link appropriate DLL based on HLSERVER_BOTS or HLSERVER_DLL
if [ "${HLSERVER_BOTS}" = "true" ] || [ "${HLSERVER_DLL}" = "bot" ]; then
    echo "Starting server with bot support..."
    ln -sf /opt/xash3d/data/dll/bot.so "${GAME_DIR}/dlls/hl.so"
else
    echo "Starting server without bots..."
    ln -sf /opt/xash3d/data/dll/hl.so "${GAME_DIR}/dlls/hl.so"
fi

# Always link client library
ln -sf /opt/xash3d/data/dll/client.so "${GAME_DIR}/dlls/client.so"

# Build command line arguments
ARGS="-dedicated"
ARGS="${ARGS} -port ${HLSERVER_PORT}"
ARGS="${ARGS} -ip ${HLSERVER_IP}"
ARGS="${ARGS} +map ${HLSERVER_MAP}"
ARGS="${ARGS} +maxplayers ${HLSERVER_MAXPLAYERS}"
ARGS="${ARGS} -game ${HLSERVER_GAME}"

# Add custom DLL if specified and different from default
if [ "${HLSERVER_DLL}" != "hl" ] && [ "${HLSERVER_DLL}" != "bot" ]; then
    ARGS="${ARGS} -dll ${HLSERVER_DLL}"
fi

echo "Starting Xash3D server with args: ${ARGS}"
cd /opt/xash3d
exec ./xash3d ${ARGS}
EOF

RUN chmod +x /opt/xash3d/start-server.sh

WORKDIR /opt/xash3d
EXPOSE ${HLSERVER_PORT}/udp

CMD ["/opt/xash3d/start-server.sh"]
