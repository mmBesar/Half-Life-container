#!/usr/bin/env bash
set -e

# Default values
: "${HLSERVER_PORT:=27015}"
: "${HLSERVER_IP:=0.0.0.0}"
: "${HLSERVER_MAP:=stalkyard}"
: "${HLSERVER_MAXPLAYERS:=16}"
: "${HLSERVER_BOTS:=false}"
: "${HLSERVER_GAME:=valve}"

CONFIG_PATH="/data/configs"
GAME_PATH="/data/${HLSERVER_GAME}"
LIBLIST_DEST="${GAME_PATH}/liblist.gam"

# Verify game directory exists
if [[ ! -d "$GAME_PATH" ]]; then
  echo "❌ Game directory not found: $GAME_PATH"
  exit 1
fi

# Set liblist.gam
if [[ "$HLSERVER_BOTS" == "true" ]]; then
  echo "🧠 Enabling bots: copying liblist.bots.gam"
  cp "${CONFIG_PATH}/liblist.bots.gam" "$LIBLIST_DEST"
else
  echo "🎮 Clean mode: copying liblist.clean.gam"
  cp "${CONFIG_PATH}/liblist.clean.gam" "$LIBLIST_DEST"
fi

# Assemble args
ARGS="-ip $HLSERVER_IP -port $HLSERVER_PORT +map $HLSERVER_MAP +maxplayers $HLSERVER_MAXPLAYERS"

# Change to data dir and launch
cd /data
echo "🚀 Launching server: $XASH3D_BASE/xash -game $HLSERVER_GAME $ARGS"
exec "$XASH3D_BASE/xash" -game "$HLSERVER_GAME" $ARGS
