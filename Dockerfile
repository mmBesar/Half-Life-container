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

COPY --chmod=755 start-server.sh ./start-server.sh

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
