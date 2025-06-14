# syntax=docker/dockerfile:1

FROM --platform=$TARGETPLATFORM debian:bullseye-slim AS build
ARG TARGETPLATFORM

RUN apt-get update \
 && apt-get install -y --no-install-recommends wget ca-certificates xz-utils \
 && rm -rf /var/lib/apt/lists/*

RUN wget -O /tmp/xash3d.tar.xz \
    https://github.com/FWGS/xash3d-fwgs/releases/latest/download/xash3d-fwgs-linux.tar.xz \
 && mkdir -p /xash3d \
 && tar -xJf /tmp/xash3d.tar.xz -C /xash3d \
 && rm /tmp/xash3d.tar.xz

FROM --platform=$TARGETPLATFORM debian:bullseye-slim
ARG UID=1000
ARG GID=1000

RUN apt-get update \
 && apt-get install -y --no-install-recommends libcurl4 lib32stdc++6 lib32gcc-s1 lib32gcc1 ca-certificates \
 && groupadd -g "$GID" hl && useradd -m -u "$UID" -g hl hl \
 && rm -rf /var/lib/apt/lists/*

COPY --from=build /xash3d /opt/xash3d

WORKDIR /data
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER hl
ENV XASH3D_BASE=/opt/xash3d
ENTRYPOINT ["entrypoint.sh"]
