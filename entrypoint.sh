#!/bin/bash

# entrypoint.sh - Xash3D FWGS Half-Life Server Entrypoint

set -e

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to generate server.cfg
generate_server_cfg() {
    local config_file="/data/${HLSERVER_GAME}/server.cfg"
    
    log "Generating server.cfg at ${config_file}"
    
    # Create game directory if it doesn't exist
    mkdir -p "/data/${HLSERVER_GAME}"
    
    cat > "${config_file}" << EOF
// Xash3D FWGS Server Configuration
// Generated automatically by container

// Server settings
hostname "${HLSERVER_HOSTNAME}"
maxplayers ${HLSERVER_MAXPLAYERS}
port ${HLSERVER_PORT}

// Map settings
map ${HLSERVER_MAP}

// Password settings
EOF

    if [[ -n "$HLSERVER_PASSWORD" ]]; then
        echo "password \"${HLSERVER_PASSWORD}\"" >> "${config_file}"
    fi
    
    if [[ -n "$HLSERVER_RCON_PASSWORD" ]]; then
        echo "rcon_password \"${HLSERVER_RCON_PASSWORD}\"" >> "${config_file}"
    fi

    # Bot configuration (ONLY works for Counter-Strike with proper game files)
    if [[ "$HLSERVER_BOTS" == "true" && "$HLSERVER_BOTS_COUNT" -gt 0 && "$HLSERVER_GAME" == "cstrike" ]]; then
        cat >> "${config_file}" << EOF

// Bot settings (Counter-Strike only)
bot_quota ${HLSERVER_BOTS_COUNT}
bot_quota_mode fill
bot_auto_vacate 1
bot_join_after_player 1
bot_difficulty 1
EOF
        log "Bot configuration added (Counter-Strike only)"
    elif [[ "$HLSERVER_BOTS" == "true" && "$HLSERVER_GAME" != "cstrike" ]]; then
        log "WARNING: Bots are only supported in Counter-Strike (cstrike) game mode"
        log "Current game: $HLSERVER_GAME - Bots will be disabled"
    fi

    cat >> "${config_file}" << EOF

// Logging
log on
sv_logecho 1
sv_logfile 1
sv_log_onefile 0

// Network settings
sv_lan 0
sv_region 255

// Game settings
mp_friendlyfire 0
mp_footsteps 1
mp_flashlight 1
mp_autocrosshair 1
mp_forcerespawn 0
mp_weaponstay 0
mp_falldamage 0
mp_teamplay 0
mp_fraglimit 0
mp_timelimit 20

// Execute additional configs if they exist
exec banned.cfg
exec listip.cfg
EOF

    log "Server configuration generated successfully"
}

# Function to setup user permissions
setup_user() {
    local user_spec="${1:-1000:1000}"
    local uid=$(echo "$user_spec" | cut -d: -f1)
    local gid=$(echo "$user_spec" | cut -d: -f2)
    
    # Create group if it doesn't exist
    if ! getent group "$gid" > /dev/null 2>&1; then
        addgroup -g "$gid" xashgroup 2>/dev/null || true
    fi
    
    # Create user if it doesn't exist
    if ! getent passwd "$uid" > /dev/null 2>&1; then
        adduser -u "$uid" -G "$(getent group "$gid" | cut -d: -f1)" -s /bin/bash -D xashuser 2>/dev/null || true
    fi
    
    # Ensure data directory ownership
    chown -R "$uid:$gid" /data 2>/dev/null || true
}

# Function to start the server
start_server() {
    local server_args=(
        "-console"
        "-dedicated"
        "-port" "$HLSERVER_PORT"
        "-game" "$HLSERVER_GAME"
        "+maxplayers" "$HLSERVER_MAXPLAYERS"
        "+map" "$HLSERVER_MAP"
        "+exec" "server.cfg"
    )
    
    # Add additional arguments if specified
    if [[ -n "$HLSERVER_ADDITIONAL_ARGS" ]]; then
        IFS=' ' read -ra ADDR <<< "$HLSERVER_ADDITIONAL_ARGS"
        for arg in "${ADDR[@]}"; do
            server_args+=("$arg")
        done
    fi
    
    log "Starting Xash3D FWGS dedicated server..."
    log "Game: $HLSERVER_GAME"
    log "Port: $HLSERVER_PORT"
    log "Map: $HLSERVER_MAP"
    log "Max Players: $HLSERVER_MAXPLAYERS"
    log "Bots: $HLSERVER_BOTS (Count: $HLSERVER_BOTS_COUNT)"
    
    # Check if Half-Life game data exists
    if [[ ! -d "/data/${HLSERVER_GAME}" ]]; then
        log "ERROR: Game directory /data/${HLSERVER_GAME} not found!"
        log "Please mount your Half-Life game data to /data/${HLSERVER_GAME}"
        exit 1
    fi
    
    # Check for essential files
    if [[ ! -f "/data/${HLSERVER_GAME}/liblist.gam" ]]; then
        log "WARNING: liblist.gam not found in /data/${HLSERVER_GAME}"
        log "This might indicate missing or incomplete game data"
    fi
    
    # Generate server configuration
    generate_server_cfg
    
    # Create logs directory
    mkdir -p /data/logs
    
    # Set PATH to include xash3d binaries
    export PATH="/opt/xash3d/bin:$PATH"
    export LD_LIBRARY_PATH="/opt/xash3d/lib:$LD_LIBRARY_PATH"
    
    # Execute the server
    exec /opt/xash3d/bin/xash3d "${server_args[@]}" 2>&1 | tee -a "/data/logs/server-$(date +%Y%m%d-%H%M%S).log"
}

# Main execution
main() {
    log "Xash3D FWGS Half-Life Server Container Starting..."
    
    # Setup user if USER environment variable is provided
    if [[ -n "${USER:-}" ]]; then
        setup_user "$USER"
        # Switch to the specified user and re-run this script
        exec su-exec "$USER" "$0" "$@"
    fi
    
    # Validate required environment variables
    if [[ -z "$HLSERVER_GAME" ]]; then
        log "ERROR: HLSERVER_GAME environment variable is required"
        exit 1
    fi
    
    # Start the server
    start_server
}

# Handle container shutdown gracefully
trap 'log "Shutting down server..."; kill -TERM $!; wait $!' SIGTERM SIGINT

# Run main function
main "$@"
