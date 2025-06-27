#!/usr/bin/env bash
set -e

# Configuration
XASH_BINARY="${XASH3D_BASE}/xash"
HLSDK_MODE="${HLSDK_MODE:-master}"
HLSDK_LIBS_PATH="${HLSDK_LIBS_PATH:-/opt/hlsdk-libs}"

# Architecture detection
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH_SUFFIX="amd64" ;;
    aarch64) ARCH_SUFFIX="arm64" ;;
    *) echo "Unsupported architecture: $ARCH" && exit 1 ;;
esac

echo "=== Xash3D FWGS Server Startup ==="
echo "Architecture: $ARCH ($ARCH_SUFFIX)"
echo "HLSDK Mode: $HLSDK_MODE"
echo "Working Directory: $(pwd)"

# Ensure game directory exists
mkdir -p valve/dlls valve/cl_dlls

# Set up HLSDK libraries based on mode
setup_hlsdk_libraries() {
    local mode="$1"
    local arch="$2"
    
    echo "=== Setting up HLSDK libraries (mode: $mode, arch: $arch) ==="
    
    case "$mode" in
        "master"|"standard")
            # Standard Half-Life libraries
            local server_lib="${HLSDK_LIBS_PATH}/hl_master_${arch}.so"
            local client_lib="${HLSDK_LIBS_PATH}/client_master_${arch}.so"
            
            if [ -f "$server_lib" ]; then
                echo "Installing standard server library: $server_lib"
                cp "$server_lib" valve/dlls/hl.so
                chmod +x valve/dlls/hl.so
            else
                echo "Warning: Standard server library not found: $server_lib"
                # Try alternative location
                if [ -f "${XASH3D_BASE}/hlsdk/hl_master_${arch}.so" ]; then
                    cp "${XASH3D_BASE}/hlsdk/hl_master_${arch}.so" valve/dlls/hl.so
                    chmod +x valve/dlls/hl.so
                    echo "Using alternative server library location"
                fi
            fi
            
            if [ -f "$client_lib" ]; then
                echo "Installing standard client library: $client_lib"
                cp "$client_lib" valve/cl_dlls/client.so
                chmod +x valve/cl_dlls/client.so
            else
                echo "Warning: Standard client library not found: $client_lib"
                # Try alternative location
                if [ -f "${XASH3D_BASE}/hlsdk/client_master_${arch}.so" ]; then
                    cp "${XASH3D_BASE}/hlsdk/client_master_${arch}.so" valve/cl_dlls/client.so
                    chmod +x valve/cl_dlls/client.so
                    echo "Using alternative client library location"
                fi
            fi
            ;;
            
        "bot10"|"bot"|"bots")
            # Bot-enabled libraries
            local bot_lib="${HLSDK_LIBS_PATH}/hl_bot_${arch}.so"
            
            if [ -f "$bot_lib" ]; then
                echo "Installing bot-enabled server library: $bot_lib"
                cp "$bot_lib" valve/dlls/hl.so
                chmod +x valve/dlls/hl.so
                echo "Bot AI is now available! Use 'bot_add' to add bots."
            else
                echo "Warning: Bot library not found: $bot_lib"
                # Try alternative location
                if [ -f "${XASH3D_BASE}/hlsdk/hl_bot_${arch}.so" ]; then
                    cp "${XASH3D_BASE}/hlsdk/hl_bot_${arch}.so" valve/dlls/hl.so
                    chmod +x valve/dlls/hl.so
                    echo "Using alternative bot library location"
                    echo "Bot AI is now available! Use 'bot_add' to add bots."
                fi
            fi
            ;;
            
        *)
            echo "Unknown HLSDK mode: $mode"
            echo "Available modes: master, standard, bot10, bot, bots"
            exit 1
            ;;
    esac
}

# Set up libraries
setup_hlsdk_libraries "$HLSDK_MODE" "$ARCH_SUFFIX"

# Show what libraries are installed
echo "=== Installed Libraries ==="
ls -la valve/dlls/ 2>/dev/null || echo "No server libraries found"
ls -la valve/cl_dlls/ 2>/dev/null || echo "No client libraries found"

# Show library info
if [ -f valve/dlls/hl.so ]; then
    echo "Server library info:"
    file valve/dlls/hl.so
fi

# Check if xash binary exists
if [ ! -f "$XASH_BINARY" ]; then
    echo "ERROR: Xash3D binary not found at: $XASH_BINARY"
    echo "Available files in ${XASH3D_BASE}:"
    ls -la "${XASH3D_BASE}/" 2>/dev/null || echo "Directory not found"
    exit 1
fi

# Show startup info
echo "=== Starting Xash3D FWGS Server ==="
echo "Binary: $XASH_BINARY"
echo "Arguments: $@"

# Provide some helpful information
echo ""
echo "=== Server Information ==="
echo "• HLSDK Mode: $HLSDK_MODE"
if [ "$HLSDK_MODE" = "bot10" ] || [ "$HLSDK_MODE" = "bot" ] || [ "$HLSDK_MODE" = "bots" ]; then
    echo "• Bot Commands Available:"
    echo "  - bot_add: Add a bot to the server"
    echo "  - bot_kick: Remove bots from the server"
    echo "  - bot_quota <number>: Set maximum number of bots"
fi
echo "• To change HLSDK mode, set environment variable HLSDK_MODE to 'master' or 'bot10'"
echo ""

# Execute the server
exec "$XASH_BINARY" "$@"
