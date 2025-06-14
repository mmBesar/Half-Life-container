#!/usr/bin/env bash
set -e

: "${HLSERVER_PORT:=27015}"
: "${HLSERVER_MAP:=stalkyard}"
: "${HLSERVER_MAXPLAYERS:=16}"
: "${HLSERVER_BOTS:=false}"
: "${HLSERVER_GAME:=valve}"

CONFIG_PATH="/data/configs"
GAME_PATH="/data/${HLSERVER_GAME}"
LIBLIST_DEST="${GAME_PATH}/liblist.gam"

# Bot toggle via liblist.gam swap
if [[ "$HLSERVER_BOTS" == "true" ]]; then
  echo "🧠 Enabling bots: copying liblist.bots.gam"
  cp "${CONFIG_PATH}/liblist.bots.gam" "$LIBLIST_DEST"
else
  echo "🎮 Clean mode: copying liblist.clean.gam"
  cp "${CONFIG_PATH}/liblist.clean.gam" "$LIBLIST_DEST"
fi

cd "$XASH3D_BASE"
ARGS="-port $HLSERVER_PORT +map $HLSERVER_MAP +maxplayers $HLSERVER_MAXPLAYERS"

echo "🚀 Launching server: ./xash -game $HLSERVER_GAME $ARGS"
cd "/data"
exec "$XASH3D_BASE/xash" -game "$HLSERVER_GAME" $ARGS
