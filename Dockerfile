# syntax=docker/dockerfile:1.4

###################################
# → builder: fetch & unpack binary
###################################
FROM ubuntu:24.04 AS builder

ARG TARGETPLATFORM

RUN apt-get update \
 && apt-get install -y --no-install-recommends wget ca-certificates tar gzip \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    case "$TARGETPLATFORM" in \
      "linux/amd64")    ARCH=amd64 ;; \
      "linux/arm64")    ARCH=arm64 ;; \
      "linux/arm/v7")   ARCH=armhf ;; \
      *) echo "Unsupported platform: $TARGETPLATFORM" >&2; exit 1 ;; \
    esac; \
    wget -O /tmp/xashds.tar.gz \
      "https://github.com/FWGS/xash3d-fwgs/releases/download/continuous/xashds-linux-${ARCH}.tar.gz"; \
    mkdir -p /xashds; \
    tar -xzf /tmp/xashds.tar.gz -C /xashds; \
    rm /tmp/xashds.tar.gz; \
    mv /xashds/xashds-linux-*/* /xashds

###################################
# → runtime: minimal Ubuntu + user
###################################
FROM ubuntu:24.04

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
