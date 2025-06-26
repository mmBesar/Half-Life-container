# syntax=docker/dockerfile:1.4

########################################
# builder: clone FWGS and compile xashds
########################################
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV CC=clang
ENV CXX=clang++

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates git cmake ninja-build clang \
      pkg-config libcurl4-openssl-dev zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth 1 https://github.com/FWGS/xash3d-fwgs.git .

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
FROM ubuntu:24.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive
ARG UID=1000

# 1) update & install runtime deps
RUN apt-get \
      -o Acquire::AllowReleaseInfoChange::Suite=true \
      -o Acquire::AllowReleaseInfoChange::Codename=true \
      update \
 && apt-get install -y --no-install-recommends \
      libcurl4 ca-certificates tini \
 && rm -rf /var/lib/apt/lists/*

# 2) create hl user with its own group (-U)
RUN useradd -m -u "$UID" -U hl

# 3) copy in the compiled server
COPY --from=builder /opt/xashds /opt/xashds

WORKDIR /data
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER hl
ENV XASH3D_BASE=/opt/xashds
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
