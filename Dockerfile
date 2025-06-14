# Multi-stage build for xash3d-fwgs Half-Life server
FROM --platform=$BUILDPLATFORM alpine:3.19 AS builder

# Build arguments
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    python3 \
    py3-pip \
    pkgconfig \
    linux-headers \
    musl-dev \
    gcc \
    g++ \
    make

# Set working directory
WORKDIR /build

# Clone xash3d-fwgs repository
RUN git clone --recursive https://github.com/FWGS/xash3d-fwgs.git . && \
    git submodule update --init --recursive

# Configure and build for the target architecture
RUN case "${TARGETARCH}" in \
    "amd64") \
        export CFLAGS="-O2 -march=x86-64 -mtune=generic" && \
        export CXXFLAGS="-O2 -march=x86-64 -mtune=generic" \
        ;; \
    "arm64") \
        export CFLAGS="-O2 -march=armv8-a -mtune=cortex-a72" && \
        export CXXFLAGS="-O2 -march=armv8-a -mtune=cortex-a72" \
        ;; \
    esac && \
    python3 waf configure --dedicated --enable-lto --enable-utils --prefix=/opt/xash3d && \
    python3 waf build && \
    python3 waf install

# Runtime stage
FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache \
    libgcc \
    libstdc++ \
    bash \
    curl \
    su-exec \
    && addgroup -g 1000 xash \
    && adduser -u 1000 -G xash -s /bin/bash -D xash

# Copy built binaries from builder stage
COPY --from=builder /opt/xash3d /opt/xash3d

# Create necessary directories
RUN mkdir -p /data/valve /data/cstrike /data/logs /data/config && \
    chown -R xash:xash /data /opt/xash3d

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set working directory
WORKDIR /data

# Environment variables with defaults
ENV HLSERVER_PORT=27015 \
    HLSERVER_MAP=stalkyard \
    HLSERVER_MAXPLAYERS=16 \
    HLSERVER_BOTS=false \
    HLSERVER_BOTS_COUNT=0 \
    HLSERVER_HOSTNAME="Xash3D FWGS Server" \
    HLSERVER_PASSWORD="" \
    HLSERVER_RCON_PASSWORD="" \
    HLSERVER_GAME=valve \
    HLSERVER_ADDITIONAL_ARGS=""

# Expose default port
EXPOSE 27015/udp

# Use entrypoint script
ENTRYPOINT ["/entrypoint.sh"]
