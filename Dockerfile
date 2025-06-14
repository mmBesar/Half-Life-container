# Multi-stage build for Half-Life server using xash3d-fwgs
FROM --platform=$BUILDPLATFORM alpine:3.19 AS builder

# Build arguments
ARG BUILDPLATFORM
ARG TARGETPLATFORM
ARG TARGETARCH

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    python3 \
    python3-dev \
    linux-headers \
    zlib-dev \
    freetype-dev \
    fontconfig-dev \
    sdl2-dev \
    curl-dev \
    sqlite-dev

# Clone xash3d-fwgs
WORKDIR /build
RUN git clone --recursive https://github.com/FWGS/xash3d-fwgs.git

# Build xash3d
WORKDIR /build/xash3d-fwgs
RUN python3 waf configure --dedicated --disable-gl4es \
    && python3 waf build

# Runtime stage
FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache \
    zlib \
    freetype \
    fontconfig \
    sdl2 \
    curl \
    sqlite \
    bash \
    su-exec \
    && rm -rf /var/cache/apk/*

# Create directories
RUN mkdir -p /opt/xash3d /data/valve /data/cstrike /data/logs

# Copy built binaries
COPY --from=builder /build/xash3d-fwgs/build/engine/xash3d /opt/xash3d/
COPY --from=builder /build/xash3d-fwgs/build/game_launch/xash3d /opt/xash3d/xash3d-launcher

# Copy startup script (will be created by GitHub Actions)
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Environment variables with defaults
ENV HLSERVER_PORT=27015 \
    HLSERVER_MAP=crossfire \
    HLSERVER_MAXPLAYERS=16 \
    HLSERVER_HOSTNAME="Half-Life Server" \
    HLSERVER_PASSWORD="" \
    HLSERVER_RCON_PASSWORD="" \
    HLSERVER_BOTS=false \
    HLSERVER_BOTS_COUNT=4 \
    HLSERVER_GAME=valve \
    HLSERVER_ADDITIONAL_ARGS="" \
    PUID=1000 \
    PGID=1000

# Expose port
EXPOSE 27015/udp

# Set working directory
WORKDIR /data

# Use entrypoint script
ENTRYPOINT ["/entrypoint.sh"]
