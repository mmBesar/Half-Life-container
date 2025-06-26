# syntax=docker/dockerfile:1.4

########################################
# 1) builder: Debian Bookworm → compile xashds
########################################
FROM debian:bookworm AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install everything for waf + C++ build (Debian armhf works here)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      git \
      python3 \
      python3-distutils \
      pkg-config \
      build-essential \
      gcc \
      g++ \
      zlib1g-dev \
      libcurl4-openssl-dev \
 && rm -rf /var/lib/apt/lists/* \
 && ln -sf /usr/bin/python3 /usr/bin/python

WORKDIR /src
RUN git clone --depth 1 https://github.com/FWGS/xash3d-fwgs.git . \
 && git submodule update --init --recursive

RUN chmod +x ./waf \
 && ./waf configure -T release --prefix=/opt/xashds -8 \
 && ./waf build \
 && ./waf install

########################################
# 2) runtime: Ubuntu 24.04 + non-root user
########################################
FROM ubuntu:24.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive

# install only runtime libs & adduser
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libcurl4 \
      ca-certificates \
      adduser \
 && rm -rf /var/lib/apt/lists/*

RUN adduser --disabled-password --gecos '' hl

COPY --from=builder /opt/xashds /opt/xashds

WORKDIR /data
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER hl
ENV XASH3D_BASE=/opt/xashds

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
