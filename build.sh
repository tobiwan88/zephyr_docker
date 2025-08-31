#!/bin/bash

# Optimized Zephyr Docker Build Script
# Builds efficient multi-stage container with smart tag generation

set -euo pipefail

# Default configuration (can be overridden via environment variables)
DEBIAN_VERSION="${DEBIAN_VERSION:-trixie-slim}"
ZEPHYR_VERSION="${ZEPHYR_VERSION:-v4.2.0}"
TOOLCHAIN_VERSION="${TOOLCHAIN_VERSION:-0.17.4}"
TOOLCHAINS="${TOOLCHAINS:-arm-zephyr-eabi}"
REGISTRY_PREFIX="${REGISTRY_PREFIX:-}"
BUILD_ARGS=""
BUILD_CONTEXT="."
CI_MODE="${CI_MODE:-false}"

# Function to display usage
show_usage() {
    cat << EOF
🛠️  Optimized Zephyr Docker Build Script

Usage: $0 [OPTIONS]

Environment Variables:
  DEBIAN_VERSION     Debian base version (default: trixie-slim)
  ZEPHYR_VERSION     Zephyr RTOS version (default: v4.2.0)
  TOOLCHAIN_VERSION  Zephyr SDK version (default: 0.17.4)
  TOOLCHAINS         Comma-separated toolchains or 'all' (default: arm-zephyr-eabi)
  REGISTRY_PREFIX    Container registry prefix (default: none)

Examples:
  # Build with ARM toolchain (default)
  $0

  # Build with multiple toolchains
  TOOLCHAINS="arm-zephyr-eabi,riscv64-zephyr-elf" $0

  # Build with all toolchains
  TOOLCHAINS="all" $0

  # Custom versions
  ZEPHYR_VERSION="v4.1.0" TOOLCHAIN_VERSION="0.16.8" $0

  # Build for registry
  REGISTRY_PREFIX="ghcr.io/username/repo-name" $0

Options:
  --help, -h         Show this help message
  --no-cache         Build without using Docker cache
  --push             Push to registry after successful build
  --dry-run          Show what would be built without building
  --ci               Enable CI mode (optimized for automation)
  --get-tag          Output the generated image tag and exit
  --platforms        Comma-separated platforms for multi-arch build

EOF
}

# Function to generate smart image tag based on toolchains
generate_image_tag() {
    local toolchains="$1"
    
    # Handle registry prefix properly
    if [ -n "$REGISTRY_PREFIX" ]; then
        local base_tag="$REGISTRY_PREFIX"
    else
        local base_tag="zephyr-docker"
    fi

    if [ "$toolchains" = "all" ]; then
        echo "${base_tag}:latest"
    else
        # Create abbreviated tag from toolchain names
        local tag_suffix=$(echo "$toolchains" | sed 's/,/-/g' | sed 's/-zephyr-eabi//g' | sed 's/-zephyr-elf//g')
        echo "${base_tag}:${tag_suffix}"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_usage
            exit 0
            ;;
        --no-cache)
            BUILD_ARGS="$BUILD_ARGS --no-cache"
            shift
            ;;
        --push)
            PUSH_IMAGE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --ci)
            CI_MODE=true
            BUILD_ARGS="$BUILD_ARGS --progress=plain"
            shift
            ;;
        --get-tag)
            IMAGE_TAG=$(generate_image_tag "$TOOLCHAINS")
            echo "$IMAGE_TAG"
            exit 0
            ;;
        --platforms)
            shift
            if [[ $# -eq 0 ]]; then
                echo "❌ Error: --platforms requires a value"
                exit 1
            fi
            PLATFORMS="$1"
            BUILD_ARGS="$BUILD_ARGS --platform $PLATFORMS"
            shift
            ;;
        *)
            echo "❌ Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Generate smart image tag
IMAGE_TAG=$(generate_image_tag "$TOOLCHAINS")

# Display build information
if [ "$CI_MODE" = "true" ]; then
    echo "🏗️ [CI] Building Zephyr Docker container:"
    echo "  Image Tag: $IMAGE_TAG"
    echo "  Toolchains: $TOOLCHAINS"
    echo "  Zephyr: $ZEPHYR_VERSION | Toolchain: $TOOLCHAIN_VERSION | Debian: $DEBIAN_VERSION"
    if [ -n "${PLATFORMS:-}" ]; then
        echo "  Platforms: $PLATFORMS"
    fi
else
    echo "ℹ [INFO] Building Zephyr Docker container:"
    echo "  🐧 Debian Version: $DEBIAN_VERSION"
    echo "  🚀 Zephyr Version: $ZEPHYR_VERSION"
    echo "  🔧 Toolchain Version: $TOOLCHAIN_VERSION"
    echo "  🏗️  Toolchains: $TOOLCHAINS"
    echo "  🏷️  Image Tag: $IMAGE_TAG"
    if [ -n "${PLATFORMS:-}" ]; then
        echo "  🌐 Platforms: $PLATFORMS"
    fi
fi
echo

# Dry run - show what would be built
if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "🔍 [DRY RUN] Would execute:"
    echo "docker buildx build $BUILD_ARGS \\"
    echo "  --load \\"
    echo "  --build-arg DEBIAN_VERSION=$DEBIAN_VERSION \\"
    echo "  --build-arg ZEPHYR_VERSION=$ZEPHYR_VERSION \\"
    echo "  --build-arg TOOLCHAIN_VERSION=$TOOLCHAIN_VERSION \\"
    echo "  --build-arg TOOLCHAINS=$TOOLCHAINS \\"
    echo "  --tag $IMAGE_TAG \\"
    echo "  $BUILD_CONTEXT"
    exit 0
fi

# Build the Docker image
if [ "$CI_MODE" = "true" ]; then
    echo "🏗️ [CI] Starting Docker build..."
else
    echo "ℹ [INFO] Starting Docker build..."
fi

docker buildx build $BUILD_ARGS \
    --load \
    --build-arg DEBIAN_VERSION="$DEBIAN_VERSION" \
    --build-arg ZEPHYR_VERSION="$ZEPHYR_VERSION" \
    --build-arg TOOLCHAIN_VERSION="$TOOLCHAIN_VERSION" \
    --build-arg TOOLCHAINS="$TOOLCHAINS" \
    --tag "$IMAGE_TAG" \
    "$BUILD_CONTEXT"

if [ $? -eq 0 ]; then
    if [ "$CI_MODE" = "true" ]; then
        echo "✅ [CI] Docker image built successfully: $IMAGE_TAG"
    else
        echo "✅ [SUCCESS] Docker image built successfully: $IMAGE_TAG"
        echo

        # Quick test
        echo "ℹ [INFO] Quick test:"
        docker run --rm "$IMAGE_TAG" west --version
        echo

        # Usage examples
        echo "ℹ [INFO] Usage examples:"
        echo "  # Interactive development"
        echo "  docker run -it --rm -v \$(pwd):/home/zephyr/workspace $IMAGE_TAG"
        echo
        echo "  # Run with environment pre-activated"
        echo "  docker run -it --rm $IMAGE_TAG bash"
    fi

    # Push if requested
    if [ "${PUSH_IMAGE:-false}" = "true" ]; then
        echo
        if [ "$CI_MODE" = "true" ]; then
            echo "📤 [CI] Pushing image to registry..."
        else
            echo "📤 [INFO] Pushing image to registry..."
        fi
        docker push "$IMAGE_TAG"
        echo "✅ [SUCCESS] Image pushed: $IMAGE_TAG"
    fi
else
    echo "❌ [ERROR] Docker build failed"
    exit 1
fi