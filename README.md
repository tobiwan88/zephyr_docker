# RTOS Docker Development Environment


Docker container for Zephyr RTOS development with multi-stage builds and selective toolchain support.
## 🎯 Motivation

This custom container offers several advantages over official alternatives like the Zephyr CI container:

- **Smaller size** - Optimized multi-stage builds reduce image size
- **Private registry support** - Can be deployed to your own container registry for enterprise environments
- **Tool control** - Full control over installed tools, versions, and configurations
- **Customizable** - Easy to modify and extend for specific project requirements
- **Selective toolchains** - Install only needed toolchains to minimize size and attack surface

## �🚀 Latest Versions

- **Zephyr SDK v0.17.4** - Current SDK version
- **Debian Trixie Slim** - Base image
- **Multi-platform** - AMD64 and ARM64 support
- **Size optimization**

## 📦 Pre-built Images

Pre-built images are available on GitHub Container Registry:

```bash
# Latest with all toolchains
docker pull ghcr.io/tobiwan88/zephyr_docker:latest

# ARM toolchain only (commonly used)
docker pull ghcr.io/tobiwan88/zephyr_docker:arm

# RISC-V toolchain
docker pull ghcr.io/tobiwan88/zephyr_docker:riscv64

# Multi-toolchain builds
docker pull ghcr.io/tobiwan88/zephyr_docker:arm-riscv64
```

**Note**: Replace `tobiwan88` with the actual repository owner.

## ✨ Key Features

- **SDK Integration** - Zephyr SDK v0.17.4 with selective toolchain installation
- **Security** - Non-root user and minimal package set
- **Multi-Platform** - Support for linux/amd64 and linux/arm64
- **CI/CD Ready** - Works with GitHub Actions and automated workflows
- **Development Tools** - West tool and Python environment included
- **Size Optimized** - Selective toolchain installation and build optimization

## 📋 Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `DEBIAN_VERSION` | `trixie-slim` | Debian base image version |
| `ZEPHYR_VERSION` | `v4.2.0` | Zephyr version for SDK compatibility |
| `TOOLCHAIN_VERSION` | `0.17.4` | Zephyr SDK version |
| `TOOLCHAINS` | `arm-zephyr-eabi` | Comma-separated toolchain list or "all" |

### 🏗️ Available Toolchains

By default, only ARM toolchain is installed to reduce image size (~500MB vs ~2GB for all toolchains).

| Toolchain | Architecture | Use Case |
|-----------|-------------|----------|
| `arm-zephyr-eabi` | ARM Cortex-M/A/R | Common (default) |
| `riscv64-zephyr-elf` | RISC-V 64-bit | RISC-V development |
| `x86_64-zephyr-elf` | x86 64-bit | x86 targets |
| `xtensa-intel_ace15_mtl_zephyr-elf` | Xtensa | Intel Audio DSP |
| `arc-zephyr-elf` | ARC | ARC processors |
| `sparc-zephyr-elf` | SPARC | SPARC processors |
| `all` | All architectures | All toolchains |

## 🔨 Quick Start

### Using Pre-built Images

```bash
# Pull and run with project mounting
docker pull ghcr.io/tobiwan88/zephyr_docker:arm
docker run -it --rm -v $(pwd):/home/zephyr/workspace ghcr.io/tobiwan88/zephyr_docker:arm

# Inside container
source ~/.venv/bin/activate
west init -m https://github.com/zephyrproject-rtos/zephyr --mr v4.2.0 myproject
cd myproject && west update
west build -b qemu_x86 zephyr/samples/hello_world
```

### Custom Builds

```bash
# Build with specific toolchains
TOOLCHAINS="arm-zephyr-eabi,riscv64-zephyr-elf" ./build.sh

# Build all toolchains
TOOLCHAINS="all" ./build.sh

# Build for registry
REGISTRY_PREFIX="ghcr.io/username/repo" ./build.sh --push
```

### CI/CD Integration

```yaml
name: Zephyr Build
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    container: ghcr.io/tobiwan88/zephyr_docker:arm
    steps:
      - uses: actions/checkout@v4
      - run: |
          source ~/.venv/bin/activate
          west init -l . && west update
          west build -b <board> <app>
```

## 📂 Cross-Platform Usage

| Platform | Command |
|----------|---------|
| **Linux/macOS** | `docker run -it --rm -v $(pwd):/home/zephyr/workspace <image>` |
| **Windows (PowerShell)** | `docker run -it --rm -v ${PWD}:/home/zephyr/workspace <image>` |
| **Windows (CMD)** | `docker run -it --rm -v %cd%:/home/zephyr/workspace <image>` |

## 🔧 Container Environment

- **SDK Path**: `/home/zephyr/zephyr-sdk` with selected toolchains
- **Python**: Virtual environment at `/home/zephyr/.venv` with West
- **User**: Non-root `zephyr` user (UID 1000) for security
- **Workspace**: `/home/zephyr/workspace` for project mounting

## 🛠️ Development Workflow

1. Start container with project directory mounted
2. Activate environment: `source ~/.venv/bin/activate`
3. Initialize project: `west init -l .` or `west init -m <manifest>`
4. Update dependencies: `west update`
5. Build application: `west build -b <board> <app>`

## 🏗️ Architecture

Multi-stage optimized build process:
- **Builder Stage**: Downloads and configures Zephyr SDK
- **Production Stage**: Minimal runtime with essential tools
- **Optimization**: Removes documentation and unused components

## � License

MIT License - see [LICENSE](LICENSE) for details.

---

**Optimized for production Zephyr RTOS development workflows**
