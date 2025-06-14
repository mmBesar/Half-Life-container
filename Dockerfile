# syntax=docker/dockerfile:1
FROM debian:bullseye-slim AS builder

ARG TARGETPLATFORM

RUN apt-get update && apt-get install -y --no-install-recommends wget ca-certificates gzip tar && \
    rm -rf /var/lib/apt/lists/*

# Hardcoded links based on architecture
RUN set -eux; \
    case "$TARGETPLATFORM" in \
      "linux/amd64")  URL="https://github.com/FWGS/xash3d-fwgs/releases/download/master/xashds-linux-amd64.tar.gz" ;; \
      "linux/arm64")  URL="https://github.com/FWGS/xash3d-fwgs/releases/download/master/xashds-linux-arm64.tar.gz" ;; \
      *) echo "Unsupported arch: $TARGETPLATFORM" && exit 1 ;; \
    esac; \
    wget -O /tmp/xashds.tar.gz "$URL"; \
    mkdir -p /xashds && tar -xzf /tmp/xashds.tar.gz -C /xashds && rm /tmp/xashds.tar.gz

FROM debian:bullseye-slim
ARG UID=1000
ARG GID=1000

RUN apt-get update && apt-get install -y --no-install-recommends libcurl4 ca-certificates && \
    groupadd -g "$GID" hl && useradd -m -u "$UID" -g hl hl && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /xashds /opt/xashds
WORKDIR /data
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER hl
ENV XASH3D_BASE=/opt/xashds
ENTRYPOINT ["entrypoint.sh"]
