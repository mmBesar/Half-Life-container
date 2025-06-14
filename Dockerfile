FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV HLSERVER_PATH=/home/hlserver
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

ARG TARGETARCH
ARG TARGETPLATFORM

RUN useradd -m hlserver && \
    mkdir -p $HLSERVER_PATH

RUN if [ "$TARGETARCH" = "amd64" ]; then \
        dpkg --add-architecture i386; \
    fi

RUN apt-get update && \
    if [ "$TARGETARCH" = "amd64" ]; then \
        apt-get install -y \
            git \
            build-essential \
            cmake \
            python3 \
            python3-pip \
            wget \
            pkg-config \
            gcc-multilib \
            g++-multilib \
            libc6-dev-i386; \
    else \
        apt-get install -y \
            git \
            build-essential \
            cmake \
            python3 \
            python3-pip \
            wget \
            pkg-config \
            gcc \
            g++; \
    fi && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

USER hlserver
WORKDIR $HLSERVER_PATH

RUN git clone --recursive --depth=1 https://github.com/FWGS/xash3d-fwgs.git

WORKDIR $HLSERVER_PATH/xash3d-fwgs

RUN if [ "$TARGETARCH" = "amd64" ]; then \
        ./waf configure -T release --dedicated --enable-utils; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        export CFLAGS="-O3 -mcpu=cortex-a72+crc -mtune=cortex-a72 -flto -ftree-vectorize"; \
        export CXXFLAGS="-O3 -mcpu=cortex-a72+crc -mtune=cortex-a72 -flto -ftree-vectorize"; \
        ./waf configure -T release --dedicated --64bits --enable-utils; \
    else \
        ./waf configure -T release --dedicated --64bits --enable-utils; \
    fi

RUN ./waf build -j$(nproc)

RUN echo "Build completed. Contents of build directory:" && \
    ls -la build/ && \
    echo "Binary information:" && \
    file build/xash3d* || true

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV HLSERVER_PATH=/home/hlserver
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

ARG TARGETARCH

RUN useradd -m hlserver && \
    mkdir -p $HLSERVER_PATH

RUN if [ "$TARGETARCH" = "amd64" ]; then dpkg --add-architecture i386; fi && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        libstdc++6 \
        libc6 \
        ca-certificates \
        $(if [ "$TARGETARCH" = "amd64" ]; then echo "libc6:i386 libstdc++6:i386"; fi) && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

USER hlserver
WORKDIR $HLSERVER_PATH

COPY --from=builder --chown=hlserver:hlserver $HLSERVER_PATH/xash3d-fwgs/build ./xash3d-fwgs/build

RUN mkdir -p valve cstrike dod tfc gearbox bshift

RUN echo '#!/bin/bash' > start-server.sh && \
    echo 'set -e' >> start-server.sh && \
    echo 'echo "=== Half-Life Dedicated Server ==="' >> start-server.sh && \
    echo 'echo "Platform: $(uname -a)"' >> start-server.sh && \
    echo 'echo "Architecture: $(uname -m)"' >> start-server.sh && \
    echo 'echo "Available memory: $(free -h | grep Mem | awk \"{print \\$2}\")"' >> start-server.sh && \
    echo 'echo "CPU cores: $(nproc)"' >> start-server.sh && \
    echo '' >> start-server.sh && \
    echo 'if [ "$(uname -m)" = "aarch64" ]; then' >> start-server.sh && \
    echo '  echo "Detected ARM64 - applying Pi4 optimizations"' >> start-server.sh && \
    echo '  if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then' >> start-server.sh && \
    echo '    echo "Current CPU governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo unknown)"' >> start-server.sh && \
    echo '  fi' >> start-server.sh && \
    echo 'fi' >> start-server.sh && \
    echo 'echo "Available binaries:"' >> start-server.sh && \
    echo 'ls -la ./xash3d-fwgs/build/' >> start-server.sh && \
    echo '' >> start-server.sh && \
    echo 'BINARY=""' >> start-server.sh && \
    echo 'for binary in "./xash3d-fwgs/build/xash3d" "./xash3d-fwgs/build/xashds" "./xash3d-fwgs/build/xash"; do' >> start-server.sh && \
    echo '  if [ -f "$binary" ] && [ -x "$binary" ]; then' >> start-server.sh && \
    echo '    BINARY="$binary"' >> start-server.sh && \
    echo '    break' >> start-server.sh && \
    echo '  fi' >> start-server.sh && \
    echo 'done' >> start-server.sh && \
    echo 'if [ -z "$BINARY" ]; then' >> start-server.sh && \
    echo '  echo "ERROR: No suitable binary found!"' >> start-server.sh && \
    echo '  find ./xash3d-fwgs/build/ -type f -executable 2>/dev/null || true' >> start-server.sh && \
    echo '  exit 1' >> start-server.sh && \
    echo 'fi' >> start-server.sh && \
    echo 'echo "Using binary: $BINARY"' >> start-server.sh && \
    echo 'echo "Binary info: $(file \"$BINARY\")"' >> start-server.sh && \
    echo '' >> start-server.sh && \
    echo 'PORT="${HLSERVER_PORT:-27015}"' >> start-server.sh && \
    echo 'MAXPLAYERS="${HLSERVER_MAXPLAYERS:-16}"' >> start-server.sh && \
    echo 'MAP="${HLSERVER_MAP:-crossfire}"' >> start-server.sh && \
    echo 'echo "Starting server with:"' >> start-server.sh && \
    echo 'echo "  Port: $PORT"' >> start-server.sh && \
    echo 'echo "  Max players: $MAXPLAYERS"' >> start-server.sh && \
    echo 'echo "  Default map: $MAP"' >> start-server.sh && \
    echo '' >> start-server.sh && \
    echo 'exec "$BINARY" -dedicated \' >> start-server.sh && \
    echo '  -port "$PORT" \' >> start-server.sh && \
    echo '  -maxplayers "$MAXPLAYERS" \' >> start-server.sh && \
    echo '  +map "$MAP" \' >> start-server.sh && \
    echo '  "$@"' >> start-server.sh && \
    chmod +x start-server.sh

EXPOSE 27015/udp

ENV HLSERVER_PORT=27015
ENV HLSERVER_MAXPLAYERS=16
ENV HLSERVER_MAP=crossfire

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD pgrep -f "xash3d\|xashds" > /dev/null || exit 1

LABEL maintainer="Half-Life Server" \
      description="Multi-arch Half-Life Dedicated Server optimized for Pi4" \
      version="1.0" \
      org.opencontainers.image.source="https://github.com/FWGS/xash3d-fwgs"

CMD ["./start-server.sh"]
