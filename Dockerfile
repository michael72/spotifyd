# Multi-stage Dockerfile to cross-compile spotifyd for ARMv7 (Raspberry Pi 2B)
FROM rust:1.89-bookworm AS builder

# Install cross-compilation toolchain and dependencies

RUN dpkg --add-architecture armhf && \
    apt-get update && apt-get install -y \
    pkg-config \
    build-essential \
    curl \
    git \
    gcc-arm-linux-gnueabihf \
    libc6-armhf-cross \
    libc6-dev-armhf-cross \
    cmake \
    clang \
    libclang-dev \
    && rm -rf /var/lib/apt/lists/*

# Install ARM cross-compilation libraries
RUN dpkg --add-architecture armhf && \
    apt-get update && \
    apt-get install -y \
    libasound2-dev:armhf \
    libssl-dev:armhf \
    libdbus-1-dev:armhf \
    libpulse-dev:armhf \
    portaudio19-dev:armhf \
    && rm -rf /var/lib/apt/lists/*

# Add ARMv7 target for cross-compilation
RUN rustup target add armv7-unknown-linux-gnueabihf

# Set environment variables for cross-compilation
ENV CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_LINKER=arm-linux-gnueabihf-gcc
ENV CC_armv7_unknown_linux_gnueabihf=arm-linux-gnueabihf-gcc
ENV CXX_armv7_unknown_linux_gnueabihf=arm-linux-gnueabihf-g++
ENV AR_armv7_unknown_linux_gnueabihf=arm-linux-gnueabihf-ar
ENV PKG_CONFIG_PATH=/usr/lib/arm-linux-gnueabihf/pkgconfig
ENV PKG_CONFIG_ALLOW_CROSS=1

# Set working directory
WORKDIR /build

# Copy sources + build files
COPY . .

# Build for ARMv7 target with default features (ALSA backend)
RUN cargo build --target armv7-unknown-linux-gnueabihf --release

# Create output stage to extract the binary
FROM scratch AS output
COPY --from=builder /build/target/armv7-unknown-linux-gnueabihf/release/spotifyd /spotifyd
ENTRYPOINT ["/spotifyd"]

# Optional: Create a minimal runtime image for testing
FROM debian:bookworm-slim AS runtime

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libasound2 \
    libssl3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy the cross-compiled binary
COPY --from=builder /build/target/armv7-unknown-linux-gnueabihf/release/spotifyd /usr/local/bin/spotifyd

# Make it executable
RUN chmod +x /usr/local/bin/spotifyd

# Create user for running spotifyd
RUN useradd -r -s /bin/false spotifyd

USER spotifyd

ENTRYPOINT ["/usr/local/bin/spotifyd"]
CMD ["--no-daemon"]