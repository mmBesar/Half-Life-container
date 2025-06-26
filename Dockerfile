# syntax=docker/dockerfile:1.4

########################################
# 1) builder: clone FWGS & compile xashds
########################################
FROM ubuntu:24.04 AS builder

# suppress tzdata prompts
ENV DEBIAN_FRONTEND=noninteractive

# 1a) install build deps (including python→waf)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      git \
      python3 \
      python-is-python3 \
      python3-distutils \
      pkg-config \
      build-essential \
      gcc \
      g++ \
      zlib1g-dev \
      libcurl4-openssl-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src
# 1b) clone & init submodules (libbacktrace etc.)
RUN git clone --depth 1 https://github.com/FWGS/xash3d-fwgs.git . \
 && git submodule update --init --recursive

# 1c) configure & build only the headless server
RUN chmod +x ./waf \
 && ./waf configure -T release --prefix=/opt/xashds -8 \
 && ./waf build \
 && ./waf install

########################################
# 2) runtime: minimal Ubuntu + hl user
########################################
FROM ubuntu:24.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive

# Expose UID/GID via build args if you still need them later (optional)
ARG UID=1000

# 2a) update + install runtime deps in one layer
RUN apt-get \
      -o Acquire::AllowReleaseInfoChange::Suite=true \
      -o Acquire::AllowReleaseInfoChange::Codename=true \
      update \
 && apt-get install -y --no-install-recommends \
      libcurl4 \
      ca-certificates \
      adduser \
 && rm -rf /var/lib/apt/lists/*

# 2b) create an unprivileged 'hl' user+group
RUN adduser --disabled-password --gecos '' hl

# 2c) copy in the compiled server
COPY --from=builder /opt/xashds /opt/xashds

WORKDIR /data
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER hl
ENV XASH3D_BASE=/opt/xashds

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
