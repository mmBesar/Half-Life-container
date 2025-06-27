# Stage 1: Build Xash3D engine
FROM debian:bookworm-slim AS xash3d-builder
RUN apt-get update && apt-get install -y \
  build-essential python3 git libsdl2-dev \
  libfontconfig1-dev libfreetype6-dev zlib1g-dev \
  libpng-dev libjpeg-dev libvorbis-dev libogg-dev \
  libopus-dev libopusfile-dev pkg-config \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /build/xash3d-fwgs
RUN git clone --recursive https://github.com/FWGS/xash3d-fwgs.git .
RUN ./waf configure --build-type=release --dedicated
RUN ./waf build

# Stage 2: Build HLSDK master using waf
FROM debian:bookworm-slim AS hlsdk-master-builder
RUN apt-get update && apt-get install -y \
  build-essential python3 git python3-setuptools \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /build
RUN git clone https://github.com/FWGS/hlsdk-portable.git hlsdk-master
WORKDIR /build/hlsdk-master
RUN ./waf configure --build-type=release
RUN ./waf build

# Stage 3: Build HLSDK bot10 using cmake + make
FROM debian:bookworm-slim AS hlsdk-bot10-builder
RUN apt-get update && apt-get install -y \
  build-essential git cmake make pkg-config \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /build
RUN git clone -b bot10 https://github.com/FWGS/hlsdk-portable.git hlsdk-bot10
WORKDIR /build/hlsdk-bot10
RUN cmake .. -B build -DCMAKE_BUILD_TYPE=Release -DGOLDSOURCE_SUPPORT=ON -D64BIT=ON
RUN cmake --build build --parallel $(nproc)

# Stage 4: Runtime image
FROM debian:bookworm-slim AS runtime
RUN apt-get update && apt-get install -y \
  libsdl2-2.0-0 libvorbisfile3 libopusfile0 \
  libfreetype6 libfontconfig1 && rm -rf /var/lib/apt/lists/*
RUN useradd -m -u 1000 xash3d
WORKDIR /opt/xash3d
RUN mkdir -p bin valve/dlls valve/cl_dlls hlsdk

COPY --from=xash3d-builder /build/xash3d-fwgs/build/engine/xash3d ./bin/
COPY --from=xash3d-builder /build/xash3d-fwgs/build/game_launch/xash3d.sh ./bin/
COPY --from=hlsdk-master-builder /build/hlsdk-master/build/dlls/hl.so ./hlsdk/hl_amd64.so
COPY --from=hlsdk-master-builder /build/hlsdk-master/build/cl_dll/client.so ./hlsdk/client_amd64.so
COPY --from=hlsdk-bot10-builder /build/hlsdk-bot10/build/dlls/hl.so ./hlsdk/bot_amd64.so

COPY <<'EOF' ./bin/setup-hlsdk.sh
#!/bin/bash
set -e
HLSDK_BRANCH=${HLSDK_BRANCH:-master}
rm -f valve/dlls/hl.so valve/cl_dlls/client.so
mkdir -p valve/dlls valve/cl_dlls
if [ "$HLSDK_BRANCH" = "bot10" ]; then
  ln -sf ../hlsdk/bot_amd64.so valve/dlls/hl.so
  ln -sf ../hlsdk/client_amd64.so valve/cl_dlls/client.so
else
  ln -sf ../hlsdk/hl_amd64.so valve/dlls/hl.so
  ln -sf ../hlsdk/client_amd64.so valve/cl_dlls/client.so
fi
EOF
RUN chmod +x ./bin/setup-hlsdk.sh

COPY <<'EOF' ./bin/start-server.sh
#!/bin/bash
set -e
cd /opt/xash3d
./bin/setup-hlsdk.sh
: "${HLSERVER_PORT:=27015}"
: "${HLSERVER_IP:=0.0.0.0}"
: "${HLSERVER_MAP:=stalkyard}"
: "${HLSERVER_MAXPLAYERS:=16}"
: "${HLSERVER_BOTS:=false}"
: "${HLSERVER_GAME:=valve}"
: "${HLSDK_BRANCH:=master}"
: "${XASH_EXTRA_ARGS:=}"
ARGS=\"-dedicated -ip $HLSERVER_IP -port $HLSERVER_PORT +map $HLSERVER_MAP +maxplayers $HLSERVER_MAXPLAYERS -game $HLSERVER_GAME\"
if [[ \"$HLSDK_BRANCH\" == \"bot10\" && \"$HLSERVER_BOTS\" == \"true\" ]]; then
  ARGS+=\" +exec bot.cfg\"
fi
ARGS+=\" $XASH_EXTRA_ARGS\"
exec ./bin/xash3d $ARGS
EOF
RUN chmod +x ./bin/start-server.sh
RUN chown -R xash3d:xash3d .
USER xash3d
EXPOSE 27015/udp

ENV HLSERVER_PORT=27015 \
    HLSERVER_IP=0.0.0.0 \
    HLSERVER_MAP=stalkyard \
    HLSERVER_MAXPLAYERS=16 \
    HLSERVER_BOTS=false \
    HLSERVER_GAME=valve \
    HLSDK_BRANCH=master \
    XASH_EXTRA_ARGS=""

CMD ["bin/start-server.sh"]
