# syntax=docker/dockerfile:1.7

# Optimized Zephyr Docker Container
# Efficient multi-stage build with shallow cloning and selective toolchains

ARG DEBIAN_VERSION=trixie-slim
ARG ZEPHYR_VERSION=v4.2.0
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

# Create Python virtual environment as zephyr user
RUN python3 -m venv ~/.venv

# Install Python dependencies
RUN ~/.venv/bin/pip install --no-cache-dir --upgrade pip setuptools wheel \
	&& ~/.venv/bin/pip install --no-cache-dir west

# Initialize Zephyr workspace with shallow clone for efficiency
ENV PATH="/home/zephyr/.venv/bin:${PATH}"
RUN west init -m https://github.com/zephyrproject-rtos/zephyr --mr ${ZEPHYR_VERSION}  -o=--depth=1 zephyrproject \
    && cd zephyrproject \
	&& west update \
	&& west zephyr-export \
	&& west packages pip --install

# Install Zephyr SDK using west (as zephyr user)
RUN cd /home/zephyr/zephyrproject && \
	west sdk install --version ${TOOLCHAIN_VERSION} --install-dir /home/zephyr/zephyr-sdk --toolchains ${TOOLCHAINS} -H

# Aggressive cleanup - remove everything except the minimal SDK
RUN rm -rf /home/zephyr/zephyrproject && \
	cd /home/zephyr/zephyr-sdk && \
	find . -name "share/doc" -type d -exec rm -rf {} + 2>/dev/null || true && \
	find . -name "share/man" -type d -exec rm -rf {} + 2>/dev/null || true && \
	find . -name "share/info" -type d -exec rm -rf {} + 2>/dev/null || true && \
	find . -name "*.html" -delete 2>/dev/null || true && \
	find . -name "*.pdf" -delete 2>/dev/null || true

# Production stage - minimal runtime
FROM base AS production

# Re-declare ARGs for this stage
ARG ZEPHYR_VERSION
ARG TOOLCHAIN_VERSION
ARG TOOLCHAINS

# Copy only essential files from builder
COPY --from=builder --chown=zephyr:zephyr /home/zephyr/.venv /home/zephyr/.venv
COPY --from=builder --chown=zephyr:zephyr /home/zephyr/zephyr-sdk /home/zephyr/zephyr-sdk

# Create non-root user in production
RUN groupadd -r zephyr && useradd -r -g zephyr -d /home/zephyr -s /bin/bash zephyr \
	&& mkdir -p /home/zephyr \
	&& chown -R zephyr:zephyr /home/zephyr

# Switch to non-root user
USER zephyr
WORKDIR /home/zephyr

# Clean up Python cache and unnecessary files
RUN find /home/zephyr/.venv -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true && \
	find /home/zephyr/.venv -name "*.pyc" -delete 2>/dev/null || true && \
	find /home/zephyr/.venv -name "*.pyo" -delete 2>/dev/null || true

# Create workspace directory
RUN mkdir -p /home/zephyr/workspace

# Copy entrypoint script
COPY --chown=zephyr:zephyr scripts/entrypoint.sh /home/zephyr/entrypoint.sh

# Make script executable
RUN chmod +x /home/zephyr/entrypoint.sh

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