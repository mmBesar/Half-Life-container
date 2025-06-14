#!/usr/bin/env bash
set -e

: "${HLSERVER_PORT:=27015}"
: "${HLSERVER_MAP:=stalkyard}"
: "${HLSERVER_MAXPLAYERS:=16}"
: "${HLSERVER_BOTS:=false}"

if [[ "$HLSERVER_BOTS" == "true" ]]; then
  echo "Enabling bot mode: linking liblist.bots.gam"
  cp /data/configs/liblist.bots.gam /data/valve/liblist.gam
else
  echo "Running clean server: linking liblist.clean.gam"
  cp /data/configs/liblist.clean.gam /data/valve/liblist.gam
fi

cd "$XASH3D_BASE"
ARGS="-port $HLSERVER_PORT +map $HLSERVER_MAP +maxplayers $HLSERVER_MAXPLAYERS"
echo "Launching Half‑Life dedicated server: $ARGS"
./xashds -game valve $ARGS
