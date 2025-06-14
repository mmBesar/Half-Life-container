#!/usr/bin/env bash
set -e

: "${HLSERVER_PORT:=27015}"
: "${HLSERVER_MAP:=stalkyard}"
: "${HLSERVER_MAXPLAYERS:=16}"

cd "$XASH3D_BASE"
# Copy configs
mkdir -p /data/valve /data/logs
cp -r /data/valve/* ./valve/ || true

# Compose launch options
ARGS="-port $HLSERVER_PORT +map $HLSERVER_MAP +maxplayers $HLSERVER_MAXPLAYERS"
if [[ "$HLSERVER_BOTS" == "true" && "$HLSERVER_BOTS_COUNT" =~ ^[0-9]+$ ]]; then
  ARGS="$ARGS +sv_cheats 1 +bot_enable 1 +bot_quota $HLSERVER_BOTS_COUNT +bot_quota_mode fill"
fi

echo "Launching Half‑Life server: $ARGS"
./xash3d -game valve $ARGS
