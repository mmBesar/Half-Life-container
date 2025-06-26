# syntax=docker/dockerfile:1.4

########################################
# 1) builder: clone FWGS, init submodules & compile server
########################################
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# install build tools + waf prerequisites
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      git \
      python3 \
      pkg-config \
      build-essential \
      gcc \
      g++ \
      zlib1g-dev \
      libcurl4-openssl-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src
# clone & pull submodules
RUN git clone --depth 1 https://github.com/FWGS/xash3d-fwgs.git . \
 && git submodule update --init --recursive

# configure & build *only* the dedicated server
RUN chmod +x ./waf \
 && ./waf configure -T release --prefix=/opt/xashds -8 \
 && ./waf build \
 && ./waf install

########################################
# 2) runtime: minimal Ubuntu + hl user
########################################
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# install runtime deps
RUN apt-get \
      -o Acquire::AllowReleaseInfoChange::Suite=true \
      -o Acquire::AllowReleaseInfoChange::Codename=true \
      update \
 && apt-get install -y --no-install-recommends \
      libcurl4 \
      ca-certificates \
      tini \
      adduser \
 && rm -rf /var/lib/apt/lists/*

# create an unprivileged 'hl' user
RUN adduser --disabled-password --gecos '' hl

# copy the built server
COPY --from=builder /opt/xashds /opt/xashds

WORKDIR /data
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER hl
ENV XASH3D_BASE=/opt/xashds
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
