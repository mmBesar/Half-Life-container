FROM debian:bookworm-slim AS builder

ARG TARGETARCH
ARG TARGETPLATFORM

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies for both Xash3D and HLSDK
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    python3 \
    python3-pip \
    gcc \
    g++ \
    libc6-dev \
    pkg-config \
    ca-certificates \
    cmake \
    file \
    && if [ "$TARGETARCH" = "arm64" ]; then \
        apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu; \
    fi \
    && rm -rf /var/lib/apt/lists/*

# Set working directory for Xash3D
WORKDIR /build-xash

# Clone and build Xash3D FWGS
RUN git clone --recursive https://github.com/FWGS/xash3d-fwgs.git . && \
    case "$TARGETARCH" in \
        amd64) ./waf configure --dedicated -T release -8 ;; \
        arm64) ./waf configure --dedicated -T release ;; \
        *) ./waf configure --dedicated -T release ;; \
    esac && \
    ./waf build && \
    ./waf install --destdir=/tmp/xash-install

# Prepare Xash3D binaries
RUN mkdir -p /artifacts/xash && \
    find /tmp/xash-install -name "*xash*" -type f -executable | head -1 | xargs -I {} cp {} /artifacts/xash/xash && \
    find /tmp/xash-install -name "*.so" -type f | xargs -I {} cp {} /artifacts/xash/ 2>/dev/null || true && \
    chmod +x /artifacts/xash/xash

# Build HLSDK Master Branch (standard Half-Life)
WORKDIR /build-hlsdk-master
RUN git clone --depth 1 --branch master https://github.com/FWGS/hlsdk-portable.git . && \
    mkdir build && cd build && \
    case "$TARGETARCH" in \
        amd64) \
            cmake .. -DCMAKE_BUILD_TYPE=Release -DGOLDSOURCE_SUPPORT=ON -D64BIT=ON -Wno-dev && \
            make -j$(nproc) && \
            ls -la dlls/ cl_dll/ && \
            cp dlls/hl_amd64.so /artifacts/hl_master_amd64.so && \
            cp cl_dll/client_amd64.so /artifacts/client_master_amd64.so ;; \
        arm64) \
            cmake .. \
                -DCMAKE_BUILD_TYPE=Release \
                -DGOLDSOURCE_SUPPORT=ON \
                -D64BIT=ON \
                -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
                -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
                -DCMAKE_SYSTEM_NAME=Linux \
                -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
                -Wno-dev && \
            make -j$(nproc) && \
            ls -la dlls/ cl_dll/ && \
            cp dlls/hl_arm64.so /artifacts/hl_master_arm64.so && \
            cp cl_dll/client_arm64.so /artifacts/client_master_arm64.so ;; \
    esac

# Build HLSDK Bot10 Branch (with bot AI)
WORKDIR /build-hlsdk-bot10
RUN git clone --depth 1 --branch bot10 https://github.com/FWGS/hlsdk-portable.git . && \
    mkdir build && cd build && \
    case "$TARGETARCH" in \
        amd64) \
            cmake .. -DCMAKE_BUILD_TYPE=Release -DGOLDSOURCE_SUPPORT=ON -D64BIT=ON -Wno-dev && \
            make -j$(nproc) && \
            ls -la dlls/ && \
            cp dlls/bot_amd64.so /artifacts/hl_bot_amd64.so ;; \
        arm64) \
            cmake .. \
                -DCMAKE_BUILD_TYPE=Release \
                -DGOLDSOURCE_SUPPORT=ON \
                -D64BIT=ON \
                -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
                -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
                -DCMAKE_SYSTEM_NAME=Linux \
                -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
                -Wno-dev && \
            make -j$(nproc) && \
            ls -la dlls/ && \
            cp dlls/bot_*.so /artifacts/hl_bot_arm64.so ;; \
    esac

# Copy all HLSDK libraries to the Xash directory for the container
RUN mkdir -p /artifacts/xash/hlsdk && \
    cp /artifacts/hl_master_*.so /artifacts/xash/hlsdk/ 2>/dev/null || true && \
    cp /artifacts/client_master_*.so /artifacts/xash/hlsdk/ 2>/dev/null || true && \
    cp /artifacts/hl_bot_*.so /artifacts/xash/hlsdk/ 2>/dev/null || true

# Show what we built
RUN echo "=== Built Artifacts ===" && \
    find /artifacts -type f -exec ls -la {} \; && \
    echo "=== File Types ===" && \
    find /artifacts -type f -exec file {} \;

# Final runtime stage
FROM debian:bookworm-slim

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install minimal runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        libcurl4 \
        libc6 \
    && rm -rf /var/lib/apt/lists/*

# Copy all built binaries and libraries
COPY --from=builder /artifacts/xash /opt/xash
COPY --from=builder /artifacts/*.so /opt/hlsdk-libs/

# Set working directory and copy entrypoint
WORKDIR /data
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Environment variables for runtime control
ENV XASH3D_BASE=/opt/xash
ENV HLSDK_MODE=master
ENV HLSDK_LIBS_PATH=/opt/hlsdk-libs

# Use the entrypoint
ENTRYPOINT ["entrypoint.sh"]
