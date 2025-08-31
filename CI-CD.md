# CI/CD Documentation

This document describes the continuous integration and deployment setup for the Zephyr Docker project.

## GitHub Actions Workflows

### 1. Build and Publish (`build-and-publish.yml`)

**Triggers:**
- Push to `main`/`master` branches
- Tags starting with `v*`
- Manual workflow dispatch

**Features:**
- **Smart Build Matrix**: Automatically adjusts build matrix based on trigger type
  - PR/Push: ARM toolchain only (fast feedback)
  - Tags: Comprehensive matrix (ARM, RISC-V, all toolchains)
  - Manual: User-configurable
- **Multi-arch Support**: Builds for `linux/amd64` and `linux/arm64`
- **Registry Integration**: Publishes to GitHub Container Registry (`ghcr.io`)
- **Smart Tagging**: Generates appropriate tags based on toolchains and versions
- **Comprehensive Testing**: Validates functionality before publishing
- **Cleanup**: Automatically removes old untagged package versions

**Registry Tags:**
- `latest`: All toolchains build
- `arm`: ARM toolchain only
- `riscv64`: RISC-V 64-bit toolchain only
- `arm-riscv64`: Multi-toolchain builds
- Version tags: `v1.0.0`, `arm-v1.0.0`, etc.

### 2. Test Pull Request (`test-pr.yml`)

**Triggers:**
- Pull requests to `main`/`master`
- Changes to `Dockerfile`, `build.sh`, or workflow files

**Features:**
- Fast feedback with ARM-only builds
- Comprehensive functionality testing
- Build script validation
- Image size monitoring

## Build Script Enhancements

The `build.sh` script has been enhanced with CI/CD capabilities:

### New Options

- `--ci`: Enable CI mode with optimized output
- `--get-tag`: Output generated image tag and exit
- `--platforms`: Multi-architecture build support

### New Environment Variables

- `REGISTRY_PREFIX`: Container registry prefix (e.g., `ghcr.io/username/`)
- `CI_MODE`: Enable CI-optimized behavior

### CI Mode Features

- Simplified, structured output
- Progress indicators suitable for automation
- Optimized for log parsing
- Reduced noise in CI environments

## Usage Examples

### Local Development
```bash
# Standard build
./build.sh

# Build for registry
REGISTRY_PREFIX="ghcr.io/username/" ./build.sh

# Multi-platform build
./build.sh --platforms linux/amd64,linux/arm64
```

### CI/CD Integration
```bash
# CI build
./build.sh --ci

# Get tag for other tools
TAG=$(./build.sh --get-tag)
echo "Built: $TAG"

# Registry build and push
REGISTRY_PREFIX="ghcr.io/myorg/" ./build.sh --ci --push
```

### Manual Workflow Dispatch

You can manually trigger builds through GitHub's Actions tab:

1. Go to Actions → Build and Publish Zephyr Docker Images
2. Click "Run workflow"
3. Configure:
   - Zephyr version
   - Toolchain version
   - Debian base version
   - Toolchains to build
   - Whether to push images

## Registry Access

Images are published to GitHub Container Registry:

```bash
# Pull latest (all toolchains)
docker pull ghcr.io/OWNER/REPO:latest

# Pull ARM-only build
docker pull ghcr.io/OWNER/REPO:arm

# Pull specific version
docker pull ghcr.io/OWNER/REPO:v1.0.0
```

## Security Considerations

- Uses `GITHUB_TOKEN` for registry authentication
- Images are scanned automatically by GitHub
- Only publishes on protected branches and tags
- PR builds don't push to registry

## Monitoring and Maintenance

- **Size Monitoring**: PR tests check image size regression
- **Package Cleanup**: Automatically removes old versions
- **Multi-arch**: Ensures compatibility across platforms

## Troubleshooting

### Build Failures
1. Check build logs in Actions tab
2. Verify Dockerfile syntax
3. Test locally with `--dry-run`

### Registry Issues
1. Verify `GITHUB_TOKEN` permissions
2. Check package settings in repository
3. Ensure proper branch protection

### Size Issues
1. Monitor PR test output for size changes
2. Use `docker images` to check local builds
3. Compare with previous successful builds
