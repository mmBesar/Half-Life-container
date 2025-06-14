# Stage: builder
FROM debian:bullseye-slim AS builder

RUN apt-get update \
 && apt-get install -y --no-install-recommends wget jq ca-certificates xz-utils \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    LATEST_TAG=$(wget -qO- https://api.github.com/repos/FWGS/xash3d-fwgs/releases/latest | jq -r '.tag_name'); \
    echo "Latest Xash3D release: $LATEST_TAG"; \
    DOWNLOAD_URL="https://github.com/FWGS/xash3d-fwgs/releases/download/${LATEST_TAG}/xash3d-fwgs-linux.tar.xz"; \
    wget -O /tmp/xash3d.tar.xz "$DOWNLOAD_URL"; \
    mkdir -p /xash3d; \
    tar -xJf /tmp/xash3d.tar.xz -C /xash3d; \
    rm /tmp/xash3d.tar.xz

# Stage: runtime
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
