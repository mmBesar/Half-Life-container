# Base build stage
FROM debian:bullseye-slim AS builder

# Install download utilities
RUN apt-get update \
 && apt-get install -y --no-install-recommends wget ca-certificates xz-utils \
 && rm -rf /var/lib/apt/lists/*

# Determine latest release URL dynamically
RUN LATEST_TAG=$(wget -qO- https://api.github.com/repos/FWGS/xash3d-fwgs/releases/latest \
                  | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/') \
 && echo "Downloading Xash3D FWGS $LATEST_TAG" \
 && wget -O /tmp/xash3d.tar.xz \
      https://github.com/FWGS/xash3d-fwgs/releases/download/$LATEST_TAG/xash3d-fwgs-linux.tar.xz

RUN mkdir -p /xash3d \
 && tar -xJf /tmp/xash3d.tar.xz -C /xash3d \
 && rm /tmp/xash3d.tar.xz

# Final runtime image
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
