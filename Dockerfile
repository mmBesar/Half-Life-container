# syntax=docker/dockerfile:1.4

########################################
# 1) builder: clone FWGS, init submodules & compile server
########################################
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

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
RUN git clone --depth 1 https://github.com/FWGS/xash3d-fwgs.git . \
 && git submodule update --init --recursive

RUN chmod +x ./waf \
 && ./waf configure -T release --prefix=/opt/xashds -8 \
 && ./waf build \
 && ./waf install

########################################
# 2) runtime: Ubuntu + hl user (no tini)
########################################
FROM ubuntu:24.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive

# update & install just the runtime deps
RUN apt-get \
      -o Acquire::AllowReleaseInfoChange::Suite=true \
      -o Acquire::AllowReleaseInfoChange::Codename=true \
      update \
 && apt-get install -y --no-install-recommends \
      libcurl4 \
      ca-certificates \
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

# drop 'tini' here; if you want an init, run with --init
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
