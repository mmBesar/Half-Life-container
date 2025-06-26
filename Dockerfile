# Multi-stage Dockerfile for Half-Life SDK (master and bot10 branches)
FROM debian:bookworm-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    python3 \
    python3-pip \
    python3-venv \
    libstdc++6 \
    gcc-multilib \
    g++-multilib \
    ninja-build \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment and install waf
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install waf

# Set work directory
WORKDIR /build

# Clone the repository
RUN git clone --recursive https://github.com/FWGS/hlsdk-portable.git hlsdk

# Build script arguments
ARG HLSERVER_BRANCH=master
ARG TARGETARCH=amd64

# Build the libraries based on branch
WORKDIR /build/hlsdk
RUN git checkout ${HLSERVER_BRANCH}

# Build using waf (primary build system)
RUN python3 waf configure -T release --64bits=$([ "${TARGETARCH}" = "amd64" ] && echo "1" || echo "0")
RUN python3 waf build

# Copy built libraries to output directory
RUN mkdir -p /output && \
    if [ "${HLSERVER_BRANCH}" = "bot10" ]; then \
        cp build/dlls/bot.so /output/bot_${TARGETARCH}.so 2>/dev/null || \
        find build -name "*.so" -type f -exec cp {} /output/bot_${TARGETARCH}.so \; ; \
    else \
        cp build/dlls/hl.so /output/hl_${TARGETARCH}.so 2>/dev/null || true && \
        cp build/cl_dll/client.so /output/client_${TARGETARCH}.so 2>/dev/null || true || \
        find build -name "hl*.so" -type f -exec cp {} /output/hl_${TARGETARCH}.so \; && \
        find build -name "client*.so" -type f -exec cp {} /output/client_${TARGETARCH}.so \; ; \
    fi

# Runtime stage
FROM debian:bookworm-slim AS runtime

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

# Create hlserver user
RUN useradd -m -u 1000 hlserver

# Environment variables with defaults
ENV HLSERVER_PORT=27015
ENV HLSERVER_IP=0.0.0.0
ENV HLSERVER_MAP=stalkyard
ENV HLSERVER_MAXPLAYERS=16
ENV HLSERVER_BOTS=false
ENV HLSERVER_GAME=valve
ENV HLSERVER_BRANCH=master

# Copy built libraries from builder stage
COPY --from=builder /output/* /opt/hlsdk/

# Create necessary directories
RUN mkdir -p /opt/hlserver && \
    chown -R hlserver:hlserver /opt/hlserver /opt/hlsdk

# Switch to hlserver user
USER hlserver
WORKDIR /opt/hlserver

# Copy startup script
COPY start-server.sh /opt/hlserver/start-server.sh

# Expose the default port
EXPOSE ${HLSERVER_PORT}/udp

# Start the server
CMD ["/opt/hlserver/start-server.sh"]
