# syntax=docker/dockerfile:1.4

###################################
# → builder: fetch & unpack binary
###################################
FROM ubuntu:24.04-slim AS builder

# Docker buildkit supplies TARGETPLATFORM in the form "linux/amd64", "linux/arm64", "linux/arm/v7", "linux/386"
ARG TARGETPLATFORM

# install minimal tooling
RUN apt-get update \
 && apt-get install -y --no-install-recommends wget ca-certificates tar gzip \
 && rm -rf /var/lib/apt/lists/*

# pick the right ARCH suffix and download
RUN set -eux; \
    case "$TARGETPLATFORM" in \
      "linux/amd64") ARCH=amd64 ;; \
      "linux/arm64") ARCH=arm64 ;; \
      "linux/arm/v7") ARCH=armhf ;; \
      "linux/386")    ARCH=i386 ;; \
      *) echo "Unsupported platform: $TARGETPLATFORM" >&2; exit 1 ;; \
    esac; \
    URL="https://github.com/FWGS/xash3d-fwgs/releases/download/continuous/xashds-linux-${ARCH}.tar.gz"; \
    wget -O /tmp/xashds.tar.gz "$URL"; \
    mkdir -p /xashds; \
    tar -xzf /tmp/xashds.tar.gz -C /xashds; \
    rm /tmp/xashds.tar.gz; \
    mv /xashds/xashds-linux-*/* /xashds

###################################
# → runtime: minimal Ubuntu + user
###################################
FROM ubuntu:24.04-slim

ARG UID=1000
ARG GID=1000

RUN apt-get update \
 && apt-get install -y --no-install-recommends libcurl4 ca-certificates \
 && groupadd -g "$GID" hl \
 && useradd -m -u "$UID" -g hl hl \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /xashds /opt/xashds
WORKDIR /data
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER hl
ENV XASH3D_BASE=/opt/xashds

ENTRYPOINT ["entrypoint.sh"]
