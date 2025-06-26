#!/usr/bin/env bash

# Half-Life Server Startup Script
# This script handles the startup of Half-Life server with proper library selection

set -e

# Default values (can be overridden by environment variables)
: "${HLSERVER_PORT:=27015}"
: "${HLSERVER_IP:=0.0.0.0}"
: "${HLSERVER_MAP:=stalkyard}"
: "${HLSERVER_MAXPLAYERS:=16}"
: "${HLSERVER_BOTS:=false}"
: "${HLSERVER_GAME:=valve}"
: "${HLSERVER_BRANCH:=master}"

echo "============================================"
echo "Half-Life Dedicated Server"
echo "============================================"
echo "Branch: $HLSERVER_BRANCH"
echo "Game: $HLSERVER_GAME"
echo "Map: $HLSERVER_MAP"
echo "Port: $HLSERVER_PORT"
echo "IP: $HLSERVER_IP"
echo "Max Players: $HLSERVER_MAXPLAYERS"
echo "Bots Enabled: $HLSERVER_BOTS"
echo "============================================"

# Check available libraries
echo "Available libraries:"
ls -la /opt/hlsdk/

# Determine which libraries to use based on branch
if [ "$HLSERVER_BRANCH" = "bot10" ]; then
    # Bot10 branch - use bot library
    if [ "$HLSERVER_BOTS" = "true" ]; then
        echo "Using bot10 branch with bots enabled"
        LIBRARY_PATH="/opt/hlsdk/bot_amd64.so"
    else
        echo "Warning: bot10 branch selected but HLSERVER_BOTS is false"
        echo "Using bot10 branch anyway (bots available but not forced)"
        LIBRARY_PATH="/opt/hlsdk/bot_amd64.so"
    fi
else
    # Master branch - use standard libraries
    echo "Using master branch (standard Half-Life)"
    SERVER_LIBRARY="/opt/hlsdk/hl_amd64.so"
    CLIENT_LIBRARY="/opt/hlsdk/client_amd64.so"
fi

# Verify library files exist
if [ "$HLSERVER_BRANCH" = "bot10" ]; then
    if [ ! -f "$LIBRARY_PATH" ]; then
        echo "ERROR: Bot library not found at $LIBRARY_PATH"
        echo "Available files:"
        ls -la /opt/hlsdk/
        exit 1
    fi
else
    if [ ! -f "$SERVER_LIBRARY" ]; then
        echo "ERROR: Server library not found at $SERVER_LIBRARY"
        echo "Available files:"
        ls -la /opt/hlsdk/
        exit 1
    fi
    if [ ! -f "$CLIENT_LIBRARY" ]; then
        echo "ERROR: Client library not found at $CLIENT_LIBRARY"
        echo "Available files:"
        ls -la /opt/hlsdk/
        exit 1
    fi
fi

# Create game directory structure if it doesn't exist
mkdir -p "$HLSERVER_GAME"
cd "$HLSERVER_GAME"

# Copy libraries to game directory
if [ "$HLSERVER_BRANCH" = "bot10" ]; then
    cp "$LIBRARY_PATH" ./dlls/bot.so
    echo "Copied bot library to game directory"
else
    mkdir -p dlls cl_dlls
    cp "$SERVER_LIBRARY" ./dlls/hl.so
    cp "$CLIENT_LIBRARY" ./cl_dlls/client.so
    echo "Copied server and client libraries to game directory"
fi

# Note: This is a template script for container preparation
# In a real implementation, you would need the actual Half-Life dedicated server binary
# and proper game files. This script shows the library management logic.

echo "============================================"
echo "Libraries prepared successfully!"
echo "============================================"

# Keep container running for inspection/debugging
echo "Container ready. Libraries available in /opt/hlsdk/"
echo "Game directory prepared in: $(pwd)"
echo ""
echo "To run a Half-Life server, you would typically execute:"
if [ "$HLSERVER_BRANCH" = "bot10" ]; then
    echo "  hlds_run -game $HLSERVER_GAME +map $HLSERVER_MAP +maxplayers $HLSERVER_MAXPLAYERS -port $HLSERVER_PORT"
else
    echo "  hlds_run -game $HLSERVER_GAME +map $HLSERVER_MAP +maxplayers $HLSERVER_MAXPLAYERS -port $HLSERVER_PORT"
fi
echo ""
echo "Available libraries:"
ls -la /opt/hlsdk/

# Keep container running
tail -f /dev/null
