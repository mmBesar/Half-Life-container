FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

ARG TARGETARCH
ARG TARGETPLATFORM

RUN if [ "$TARGETARCH" = "amd64" ]; then \
    dpkg --add-architecture i386; \
  fi

RUN apt-get update && \
    if [ "$TARGETARCH" = "amd64" ]; then \
      apt-get install -y git build-essential cmake python3 python3-pip wget pkg-config \
        gcc-multilib g++-multilib libc6-dev-i386; \
    else \
      apt-get install -y git build-essential cmake python3 python3-pip wget pkg-config gcc g++; \
    fi && \
    rm -rf /var/lib/apt/lists/* && apt-get clean

WORKDIR /tmp/build

RUN git clone --recursive --depth=1 https://github.com/FWGS/xash3d-fwgs.git

WORKDIR /tmp/build/xash3d-fwgs

RUN if [ "$TARGETARCH" = "amd64" ]; then \
    ./waf configure -T release --dedicated --enable-utils; \
  elif [ "$TARGETARCH" = "arm64" ]; then \
    export CFLAGS="-O3 -mcpu=cortex-a72+crc -mtune=cortex-a72 -flto -ftree-vectorize"; \
    export CXXFLAGS="-O3 -mcpu=cortex-a72+crc -mtune=cortex-a72 -flto -ftree-vectorize"; \
    ./waf configure -T release --dedicated --64bits --enable-utils; \
  else \
    ./waf configure -T release --dedicated --64bits --enable-utils; \
  fi

RUN ./waf build -j$(nproc) && strip ./build/engine/xash || true

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

ARG TARGETARCH

RUN mkdir -p /data && chmod -R 0775 /data

RUN if [ "$TARGETARCH" = "amd64" ]; then dpkg --add-architecture i386; fi && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    libstdc++6 libc6 ca-certificates file coreutils \
    $(if [ "$TARGETARCH" = "amd64" ]; then echo "libc6:i386 libstdc++6:i386"; fi) && \
  rm -rf /var/lib/apt/lists/* && apt-get clean

WORKDIR /data

COPY --from=builder /tmp/build/xash3d-fwgs/build /data/xash3d-fwgs/build

RUN echo '#!/bin/bash' > /data/start-server.sh && \
  echo 'set -e' >> /data/start-server.sh && \
  echo 'echo "=== Half-Life Dedicated Server ==="' >> /data/start-server.sh && \
  echo 'echo "Platform: $(uname -a)"' >> /data/start-server.sh && \
  echo 'echo "Architecture: $(uname -m)"' >> /data/start-server.sh && \
  echo 'echo "Available memory: $(free -h | awk "/Mem/ {print \$2}")"' >> /data/start-server.sh && \
  echo 'echo "CPU cores: $(nproc)"' >> /data/start-server.sh && \
  echo 'if [ "$(uname -m)" = "aarch64" ]; then' >> /data/start-server.sh && \
  echo '  echo "Detected ARM64 - applying Pi4 optimizations"' >> /data/start-server.sh && \
  echo '  if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then' >> /data/start-server.sh && \
  echo '    echo "Current CPU governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo unknown)"' >> /data/start-server.sh && \
  echo '  fi' >> /data/start-server.sh && \
  echo 'fi' >> /data/start-server.sh && \
  echo 'echo "Available binaries:"' >> /data/start-server.sh && \
  echo 'ls -la ./xash3d-fwgs/build/' >> /data/start-server.sh && \
  echo 'BINARY=""' >> /data/start-server.sh && \
  echo 'for binary in "./xash3d-fwgs/build/xash3d" "./xash3d-fwgs/build/xashds" "./xash3d-fwgs/build/xash" "./xash3d-fwgs/build/engine/xash"; do' >> /data/start-server.sh && \
  echo '  if [ -f "$binary" ] && [ -x "$binary" ]; then' >> /data/start-server.sh && \
  echo '    BINARY="$binary"' >> /data/start-server.sh && \
  echo '    break' >> /data/start-server.sh && \
  echo '  fi' >> /data/start-server.sh && \
  echo 'done' >> /data/start-server.sh && \
  echo 'if [ -z "$BINARY" ]; then' >> /data/start-server.sh && \
  echo '  echo "ERROR: No suitable binary found!"' >> /data/start-server.sh && \
  echo '  find ./xash3d-fwgs/build/ -type f -executable 2>/dev/null || true' >> /data/start-server.sh && \
  echo '  exit 1' >> /data/start-server.sh && \
  echo 'fi' >> /data/start-server.sh && \
  echo 'echo "Using binary: $BINARY"' >> /data/start-server.sh && \
  echo 'echo "Binary info: $(file \"$BINARY\")"' >> /data/start-server.sh && \
  echo 'mkdir -p /data/logs' >> /data/start-server.sh && \
  echo 'echo "Binary size: $(du -h \"$BINARY\" | cut -f1)" | tee -a /data/logs/startup.log' >> /data/start-server.sh && \
  echo 'PORT="${HLSERVER_PORT:-27015}"' >> /data/start-server.sh && \
  echo 'MAXPLAYERS="${HLSERVER_MAXPLAYERS:-16}"' >> /data/start-server.sh && \
  echo 'MAP="${HLSERVER_MAP:-crossfire}"' >> /data/start-server.sh && \
  echo 'echo "Starting server with:" | tee -a /data/logs/startup.log' >> /data/start-server.sh && \
  echo 'echo "  Port: $PORT" | tee -a /data/logs/startup.log' >> /data/start-server.sh && \
  echo 'echo "  Max players: $MAXPLAYERS" | tee -a /data/logs/startup.log' >> /data/start-server.sh && \
  echo 'echo "  Default map: $MAP" | tee -a /data/logs/startup.log' >> /data/start-server.sh && \
  echo 'exec "$BINARY" -dedicated \\' >> /data/start-server.sh && \
  echo '  -port "$PORT" \\' >> /data/start-server.sh && \
  echo '  -maxplayers "$MAXPLAYERS" \\' >> /data/start-server.sh && \
  echo '  +map "$MAP" \\' >> /data/start-server.sh && \
  echo '  "$@"' >> /data/start-server.sh && \
  chmod 755 /data/start-server.sh

# Allow container to run as any user (default to 1000)
USER 1000:1000

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

CMD ["/data/start-server.sh"]
