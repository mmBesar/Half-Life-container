# syntax=docker/dockerfile:1.4

#####################################
# ← builder: clone & compile server
#####################################
FROM ubuntu:24.04 AS builder

# avoid any interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
# use clang for faster cross-compile under emulation
ENV CC=clang
ENV CXX=clang++

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates git cmake ninja-build clang \
      pkg-config libcurl4-openssl-dev zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src/xash3d-fwgs
RUN git clone --depth 1 https://github.com/FWGS/xash3d-fwgs.git . \
 && git submodule update --init --recursive

WORKDIR /src/xash3d-fwgs/build
RUN cmake -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DXASH_SDL=OFF \
      -DXASH_VGUI=OFF \
      -DXASH_CLIENT=OFF \
      -DCMAKE_INSTALL_PREFIX=/opt/xashds \
      .. \
 && ninja install

#####################################
# ← runtime: minimal Ubuntu + user
#####################################
FROM ubuntu:24.04 AS runtime

# 1) allow noninteractive debconf
ENV DEBIAN_FRONTEND=noninteractive

# 2) expose UID/GID before any RUN that uses them
ARG UID=1000
ARG GID=1000

# 3) update, tolerating any repo “suite” or “codename” shifts
RUN apt-get \
      -o Acquire::AllowReleaseInfoChange::Suite=true \
      -o Acquire::AllowReleaseInfoChange::Codename=true \
      update

# 4) install only what we need, no recommends
RUN apt-get install -y --no-install-recommends \
      libcurl4 ca-certificates tini \
 && rm -rf /var/lib/apt/lists/*

# 5) create group & user in its own layer
RUN groupadd -g "$GID" hl \
 && useradd -m -u "$UID" -g hl hl

# 6) copy the compiled engine in
COPY --from=builder /opt/xashds /opt/xashds

WORKDIR /data
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER hl
ENV XASH3D_BASE=/opt/xashds
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]

