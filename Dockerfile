# syntax=docker/dockerfile:1
FROM debian:bullseye-slim AS builder

ARG TARGETPLATFORM

RUN apt-get update \
 && apt-get install -y --no-install-recommends wget jq ca-certificates gzip tar \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    case "$TARGETPLATFORM" in \
      "linux/amd64") ARCH=amd64 ;; \
      "linux/arm64") ARCH=arm64 ;; \
      *) echo "Unsupported arch: $TARGETPLATFORM" >&2; exit 1 ;; \
    esac; \
    JSON=$(wget -qO- https://api.github.com/repos/FWGS/xash3d-fwgs/releases/latest); \
    URL=$(echo "$JSON" \
      | jq -r --arg arch "$ARCH" '.assets[] \
        | select(.name == ("xashds-linux-\($arch).tar.gz")) \
        | .browser_download_url'); \
    test -n "$URL" || (echo "Asset not found for $ARCH" >&2; exit 1); \
    echo "Downloading from $URL"; \
    wget -O /tmp/xashds.tar.gz "$URL"; \
    mkdir -p /xashds && tar -xzf /tmp/xashds.tar.gz -C /xashds; \
    rm /tmp/xashds.tar.gz

FROM debian:bullseye-slim

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
