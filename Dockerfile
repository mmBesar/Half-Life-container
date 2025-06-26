# syntax=docker/dockerfile:1.4

########################################
# builder: clone FWGS and compile xashds
########################################
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV CC=clang
ENV CXX=clang++

# 1) install build dependencies
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates git cmake ninja-build clang \
      pkg-config libcurl4-openssl-dev zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

# 2) grab the source
WORKDIR /src
RUN git clone --depth 1 https://github.com/FWGS/xash3d-fwgs.git .

# 3) configure & build **only** the server binary
WORKDIR /src/build
RUN cmake -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DXASH_SDL=OFF \
      -DXASH_VGUI=OFF \
      -DXASH_CLIENT=OFF \
      -DXASH_XASHDC=OFF \
      -DCMAKE_INSTALL_PREFIX=/opt/xashds \
      .. \
 && ninja install

########################################
# runtime: minimal Ubuntu + hl user
########################################
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# expose UID/GID to the layers below
ARG UID=1000
ARG GID=1000

# 1) update repos (allow any suite rename), install runtime deps
RUN apt-get \
      -o Acquire::AllowReleaseInfoChange::Suite=true \
      -o Acquire::AllowReleaseInfoChange::Codename=true \
      update \
 && apt-get install -y --no-install-recommends \
      libcurl4 ca-certificates tini \
 && rm -rf /var/lib/apt/lists/*

# 2) create the hl user
RUN groupadd -g "$GID" hl \
 && useradd -m -u "$UID" -g hl hl

# 3) copy in the compiled server
COPY --from=builder /opt/xashds /opt/xashds

WORKDIR /data
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER hl
ENV XASH3D_BASE=/opt/xashds
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
