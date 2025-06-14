FROM ubuntu:24.04 AS builder

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV HLSERVER_PATH=/home/hlserver
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Build arguments for multi-arch support
ARG TARGETARCH
ARG TARGETPLATFORM

# Create user and directory
RUN useradd -m hlserver && \
    mkdir -p $HLSERVER_PATH

# Architecture-specific setup
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        dpkg --add-architecture i386; \
    fi

# Update and install dependencies in one layer
RUN apt-get update && \
    if [ "$TARGETARCH" = "amd64" ]; then \
        apt-get install -y \
            git \
            build-essential \
            cmake \
            python3 \
            python3-pip \
            wget \
            pkg-config \
            gcc-multilib \
            g++-multilib \
            libc6-dev-i386 \
            libgl1-mesa-dev \
            libglu1-mesa-dev; \
    else \
        apt-get install -y \
            git \
            build-essential \
            cmake \
            python3 \
            python3-pip \
            wget \
            pkg-config \
            gcc \
            g++ \
            libgl1-mesa-dev \
            libglu1-mesa-dev; \
    fi && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# Switch to hlserver user
USER hlserver
WORKDIR $HLSERVER_PATH

# Clone the repository with optimized settings
RUN git clone --recursive --depth=1 https://github.com/FWGS/xash3d-fwgs.git

# Change to the project directory
WORKDIR $HLSERVER_PATH/xash3d-fwgs

# Configure build with architecture-specific optimizations
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        echo "Building for x86_64 with 32-bit compatibility"; \
        ./waf configure -T release --dedicated --enable-utils; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        echo "Building optimized for ARM64 (Pi4)"; \
        export CFLAGS="-O3 -march=armv8-a+crc -mtune=cortex-a72 -ftree-vectorize"; \
        export CXXFLAGS="-O3 -march=armv8-a+crc -mtune=cortex-a72 -ftree-vectorize"; \
        ./waf configure -T release --dedicated --64bits --enable-utils; \
    else \
        echo "Building for unknown architecture, using 64-bit"; \
        ./waf configure -T release --dedicated --64bits --enable-utils; \
    fi

# Build with parallel jobs (utilize all CPU cores)
RUN ./waf build -j$(nproc)

# Verify build output
RUN echo "Build completed. Contents of build directory:" && \
    ls -la build/ && \
    echo "Binary information:" && \
    file build/xash3d* || true

# Final runtime stage - minimal Ubuntu 24.04
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV HLSERVER_PATH=/home/hlserver
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Build argument for architecture
ARG TARGETARCH

# Create user and directory
RUN useradd -m hlserver && \
    mkdir -p $HLSERVER_PATH

# Install minimal runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libstdc++6 \
        libc6 \
        libgl1 \
        libglu1-mesa \
        ca-certificates \
        $(if [ "$TARGETARCH" = "amd64" ]; then echo "libc6:i386 libstdc++6:i386 libgl1:i386"; fi) \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Switch to hlserver user
USER hlserver
WORKDIR $HLSERVER_PATH

# Copy built files from builder stage
COPY --from=builder --chown=hlserver:hlserver $HLSERVER_PATH/xash3d-fwgs/build ./xash3d-fwgs/build

# Create directories for game content
RUN mkdir -p valve cstrike dod tfc gearbox bshift

# Create an enhanced startup script with Pi4 optimizations
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "=== Half-Life Dedicated Server ==="\n\
echo "Platform: $(uname -a)"\n\
echo "Architecture: $(uname -m)"\n\
echo "Available memory: $(free -h | grep Mem | awk \"{print \\$2}\")"\n\
echo "CPU cores: $(nproc)"\n\
echo ""\n\
\n\
# Pi4 specific optimizations\n\
if [ "$(uname -m)" = "aarch64" ]; then\n\
    echo "Detected ARM64 - applying Pi4 optimizations"\n\
    # Set CPU governor to performance if available\n\
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then\n\
        echo "Current CPU governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo unknown)"\n\
    fi\n\
fi\n\
\n\
echo "Available binaries:"\n\
ls -la ./xash3d-fwgs/build/\n\
echo ""\n\
\n\
# Find the correct binary\n\
BINARY=""\n\
for binary in "./xash3d-fwgs/build/xash3d" "./xash3d-fwgs/build/xashds" "./xash3d-fwgs/build/xash"; do\n\
    if [ -f "$binary" ] && [ -x "$binary" ]; then\n\
        BINARY="$binary"\n\
        break\n\
    fi\n\
done\n\
\n\
if [ -z "$BINARY" ]; then\n\
    echo "ERROR: No suitable binary found!"\n\
    echo "Available files:"\n\
    find ./xash3d-fwgs/build/ -type f -executable 2>/dev/null || true\n\
    exit 1\n\
fi\n\
\n\
echo "Using binary: $BINARY"\n\
echo "Binary info: $(file "$BINARY")"\n\
echo ""\n\
\n\
# Setup default parameters\n\
PORT="${HLSERVER_PORT:-27015}"\n\
MAXPLAYERS="${HLSERVER_MAXPLAYERS:-16}"\n\
MAP="${HLSERVER_MAP:-crossfire}"\n\
\n\
echo "Starting server with:"\n\
echo "  Port: $PORT"\n\
echo "  Max players: $MAXPLAYERS"\n\
echo "  Default map: $MAP"\n\
echo ""\n\
\n\
# Start the server\n\
exec "$BINARY" -dedicated \\\n\
    -port "$PORT" \\\n\
    -maxplayers "$MAXPLAYERS" \\\n\
    +map "$MAP" \\\n\
    "$@"' > start-server.sh

# Make the startup script executable
RUN chmod +x start-server.sh

# Expose the default Half-Life server port
EXPOSE 27015/udp

# Set environment variables with Pi4-friendly defaults
ENV HLSERVER_PORT=27015
ENV HLSERVER_MAXPLAYERS=16
ENV HLSERVER_MAP=crossfire

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD pgrep -f "xash3d\|xashds" > /dev/null || exit 1

# Add labels for better container management
LABEL maintainer="Half-Life Server" \
      description="Multi-arch Half-Life Dedicated Server optimized for Pi4" \
      version="1.0" \
      org.opencontainers.image.source="https://github.com/FWGS/xash3d-fwgs"

# Default command
CMD ["./start-server.sh"]
