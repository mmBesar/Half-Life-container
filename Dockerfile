# syntax=docker/dockerfile:1
FROM debian:bullseye-slim AS builder

ARG TARGETPLATFORM

RUN apt-get update \
 && apt-get install -y --no-install-recommends wget jq ca-certificates xz-utils \
 && rm -rf /var/lib/apt/lists/*

# Download correct arch binary from GitHub
RUN set -eux; \
    ARCH=""; \
    case "$TARGETPLATFORM" in \
      "linux/amd64") ARCH="linux-x86_64" ;; \
      "linux/arm64") ARCH="linux-arm64" ;; \
      *) echo "Unsupported TARGETPLATFORM: $TARGETPLATFORM" && exit 1 ;; \
    esac; \
    TAG=$(wget -qO- https://api.github.com/repos/FWGS/xash3d-fwgs/releases/latest | jq -r .tag_name); \
    echo "Fetching Xash3D tag: $TAG for arch: $ARCH"; \
    URL="https://github.com/FWGS/xash3d-fwgs/releases/download/${TAG}/xash3d-fwgs-${TAG}-${ARCH}.tar.xz"; \
    wget -O /tmp/xash3d.tar.xz "$URL"; \
    mkdir -p /xash3d; \
    tar -xJf /tmp/xash3d.tar.xz -C /xash3d; \
    rm /tmp/xash3d.tar.xz

FROM debian:bullseye-slim

ARG UID=1000
ARG GID=1000

RUN apt-get update \
 && apt-get install -y --no-install-recommends libcurl4 ca-certificates \
 && groupadd -g "$GID" hl \
 && useradd -m -u "$UID" -g hl hl \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /xash3d /opt/xash3d
WORKDIR /data
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER hl
ENV XASH3D_BASE=/opt/xash3d
ENTRYPOINT ["entrypoint.sh"]
