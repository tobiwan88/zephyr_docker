# syntax=docker/dockerfile:1.7

# Optimized Zephyr Docker Container
# Efficient multi-stage build with shallow cloning and selective toolchains

ARG DEBIAN_VERSION=trixie-slim
ARG ZEPHYR_VERSION=v4.3.0
ARG TOOLCHAIN_VERSION=0.17.4
ARG TOOLCHAINS=arm-zephyr-eabi

# Multi-stage build for size optimization
FROM --platform=$TARGETPLATFORM debian:${DEBIAN_VERSION} AS base

# Install minimal runtime packages only (including POSIX support)
# Do not add unnecessary host tools that are only needed during build
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
	apt-get update && apt-get install -y --no-install-recommends \
	ca-certificates \
	python3 \
	python3-venv \
	git \
	cmake \
	gcc \
	libc6-dev \
	ninja-build \
	device-tree-compiler \
	make \
	&& rm -rf /var/lib/apt/lists/*

# Builder stage with all build dependencies
FROM --platform=$TARGETPLATFORM debian:${DEBIAN_VERSION} AS builder-base

# Install build dependencies (more comprehensive for build process)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
	apt-get update && apt-get install -y --no-install-recommends \
	ca-certificates \
	cmake \
	ninja-build \
	gperf \
	ccache \
	dfu-util \
	device-tree-compiler \
	wget \
	git \
	python3 \
	python3-dev \
	python3-venv \
	python3-pip \
	xz-utils \
	file \
	make \
	gcc \
	libc6-dev \
	build-essential \
	libmagic1 \
	&& rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN groupadd -r zephyr && useradd -r -g zephyr -d /home/zephyr -s /bin/bash zephyr \
	&& mkdir -p /home/zephyr \
	&& chown -R zephyr:zephyr /home/zephyr

# Build stage for dependencies
FROM builder-base AS builder

# Re-declare ARGs for this stage
ARG ZEPHYR_VERSION
ARG TOOLCHAIN_VERSION
ARG TOOLCHAINS

USER zephyr
WORKDIR /home/zephyr

# Create Python virtual environment and install dependencies in one layer
RUN python3 -m venv ~/.venv && \
    ~/.venv/bin/pip install --no-cache-dir --upgrade pip setuptools wheel && \
    ~/.venv/bin/pip install --no-cache-dir west && \
    # Clean pip cache immediately
    ~/.venv/bin/pip cache purge

# Initialize Zephyr workspace, install SDK, and cleanup in one layer to minimize disk usage
ENV PATH="/home/zephyr/.venv/bin:${PATH}"
RUN set -ex && \
    # Initialize workspace with shallow clone
    west init -m https://github.com/zephyrproject-rtos/zephyr --mr ${ZEPHYR_VERSION} -o=--depth=1 zephyrproject && \
    cd zephyrproject && \
    west update && \
    west zephyr-export && \
    west packages pip --install && \
    # Install Zephyr SDK
    west sdk install --version ${TOOLCHAIN_VERSION} --install-dir /home/zephyr/zephyr-sdk --toolchains ${TOOLCHAINS} -H && \
    # Immediately cleanup the workspace to save space
    cd /home/zephyr && \
    rm -rf zephyrproject && \
    # Aggressive SDK cleanup
    cd /home/zephyr/zephyr-sdk && \
    find . -name "share/doc" -type d -exec rm -rf {} + 2>/dev/null || true && \
    find . -name "share/man" -type d -exec rm -rf {} + 2>/dev/null || true && \
    find . -name "share/info" -type d -exec rm -rf {} + 2>/dev/null || true && \
    find . -name "*.html" -delete 2>/dev/null || true && \
    find . -name "*.pdf" -delete 2>/dev/null || true && \
    find . -name "*.md" -delete 2>/dev/null || true && \
    find . -name "*.txt" -delete 2>/dev/null || true && \
    # Remove debug symbols and static libraries we don't need
    find . -name "*.a" ! -name "lib*.a" -delete 2>/dev/null || true && \
    find . -name "*.debug" -delete 2>/dev/null || true && \
    # Clean Python cache
    find /home/zephyr/.venv -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true && \
    find /home/zephyr/.venv -name "*.pyc" -delete 2>/dev/null || true && \
    find /home/zephyr/.venv -name "*.pyo" -delete 2>/dev/null || true

# Production stage - minimal runtime
FROM base AS production

# Re-declare ARGs for this stage
ARG ZEPHYR_VERSION
ARG TOOLCHAIN_VERSION
ARG TOOLCHAINS

# Create non-root user and copy files in combined operation
RUN groupadd -r zephyr && useradd -r -g zephyr -d /home/zephyr -s /bin/bash zephyr && \
    mkdir -p /home/zephyr && \
    chown -R zephyr:zephyr /home/zephyr

# Copy only essential files from builder
COPY --from=builder --chown=zephyr:zephyr /home/zephyr/.venv /home/zephyr/.venv
COPY --from=builder --chown=zephyr:zephyr /home/zephyr/zephyr-sdk /home/zephyr/zephyr-sdk

# Copy entrypoint script
COPY --chown=zephyr:zephyr scripts/entrypoint.sh /home/zephyr/entrypoint.sh

# Switch to non-root user and setup environment in one layer
USER zephyr
WORKDIR /home/zephyr

RUN chmod +x /home/zephyr/entrypoint.sh && \
    mkdir -p /home/zephyr/workspace

# Set environment variables
ENV PATH="/home/zephyr/.venv/bin:${PATH}" \
	ZEPHYR_TOOLCHAIN_VARIANT=zephyr \
	ZEPHYR_SDK_INSTALL_DIR=/home/zephyr/zephyr-sdk

WORKDIR /home/zephyr/workspace

# Use proper entrypoint that handles both interactive and command execution
ENTRYPOINT ["/home/zephyr/entrypoint.sh"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
	CMD west --version || exit 1

# Labels
LABEL maintainer="Zephyr Docker Image" \
	version="optimized-${ZEPHYR_VERSION}" \
	description="Optimized Zephyr RTOS development environment with POSIX support and selective toolchains" \
	toolchains="${TOOLCHAINS}" \
	features="posix-support,cross-platform,minimal-runtime"