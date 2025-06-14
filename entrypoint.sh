#!/bin/bash
set -e

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Create user and group if they don't exist
if ! getent group "$PGID" >/dev/null 2>&1; then
    addgroup -g "$PGID" hlserver
fi

if ! getent passwd "$PUID" >/dev/null 2>&1; then
    adduser -D -u "$PUID" -G "$(getent group "$PGID" | cut -d: -f1)" hlserver
fi

# Ensure directories exist and have correct permissions
mkdir -p /data/valve /data/cstrike /data/logs
chown -R "$PUID:$PGID" /data /opt/xash3d

# Generate server configuration
log "Generating server configuration..."

# Create server.cfg
cat > /data/${HLSERVER_GAME}/server.cfg << EOF
// Auto-generated Half-Life server configuration
hostname "${HLSERVER_HOSTNAME}"
maxplayers ${HLSERVER_MAXPLAYERS}
sv_lan 0
sv_region 255

// Network settings
net_address 0.0.0.0
port ${HLSERVER_PORT}

// Game settings
mp_timelimit 30
mp_fraglimit 50
mp_friendlyfire 0

// Bot settings
$(if [ "$HLSERVER_BOTS" = "true" ]; then
    echo "bot_quota ${HLSERVER_BOTS_COUNT}"
    echo "bot_auto_vacate 1"
    echo "bot_join_after_player 1"
else
    echo "bot_quota 0"
fi)

// RCON settings
$(if [ -n "$HLSERVER_RCON_PASSWORD" ]; then
    echo "rcon_password \"${HLSERVER_RCON_PASSWORD}\""
fi)

// Server password
$(if [ -n "$HLSERVER_PASSWORD" ]; then
    echo "sv_password \"${HLSERVER_PASSWORD}\""
fi)

// Log settings
log on
sv_logbans 1
sv_logecho 1
sv_logfile 1
sv_log_onefile 0

// Start map
map ${HLSERVER_MAP}
EOF

# Create startup script for xash3d
log "Starting Half-Life server..."
log "Game: ${HLSERVER_GAME}"
log "Map: ${HLSERVER_MAP}"
log "Port: ${HLSERVER_PORT}"
log "Max Players: ${HLSERVER_MAXPLAYERS}"
log "Bots Enabled: ${HLSERVER_BOTS}"
if [ "$HLSERVER_BOTS" = "true" ]; then
    log "Bot Count: ${HLSERVER_BOTS_COUNT}"
fi

# Build command arguments
XASH_ARGS="-dedicated -port ${HLSERVER_PORT} -game ${HLSERVER_GAME} +map ${HLSERVER_MAP}"

# Add additional arguments if specified
if [ -n "$HLSERVER_ADDITIONAL_ARGS" ]; then
    XASH_ARGS="${XASH_ARGS} ${HLSERVER_ADDITIONAL_ARGS}"
fi

# Switch to the specified user and start the server
exec su-exec "$PUID:$PGID" /opt/xash3d/xash3d $XASH_ARGS
