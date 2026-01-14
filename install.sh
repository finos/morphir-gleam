#!/usr/bin/env bash
# Morphir Gleam Installer
# Install the morphir-gleam CLI tool on Linux and macOS
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/finos/morphir-gleam/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/finos/morphir-gleam/main/install.sh | bash -s v0.1.0
#
# Environment variables:
#   INSTALL_DIR - Installation directory (default: $HOME/.local/bin)
#   VERSION     - Specific version to install (default: latest)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITHUB_REPO="finos/morphir-gleam"
BINARY_NAME="morphir-gleam"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
VERSION="${VERSION:-${1:-}}"

# Detect OS and architecture
detect_platform() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)

    case "$os" in
        linux*)
            OS="linux"
            ;;
        darwin*)
            OS="macos"
            ;;
        *)
            echo -e "${RED}Error: Unsupported operating system: $os${NC}"
            exit 1
            ;;
    esac

    case "$arch" in
        x86_64|amd64)
            ARCH="x64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            echo -e "${RED}Error: Unsupported architecture: $arch${NC}"
            exit 1
            ;;
    esac

    PLATFORM="${OS}-${ARCH}"
    echo -e "${BLUE}Detected platform: ${PLATFORM}${NC}"
}

# Get the latest release version from GitHub
get_latest_version() {
    if [ -n "$VERSION" ]; then
        echo -e "${BLUE}Using specified version: ${VERSION}${NC}"
        return
    fi

    echo -e "${BLUE}Fetching latest release version...${NC}"

    if command -v curl >/dev/null 2>&1; then
        VERSION=$(curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    elif command -v wget >/dev/null 2>&1; then
        VERSION=$(wget -qO- "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    else
        echo -e "${RED}Error: Neither curl nor wget found. Please install one of them.${NC}"
        exit 1
    fi

    if [ -z "$VERSION" ]; then
        echo -e "${RED}Error: Could not determine latest version${NC}"
        exit 1
    fi

    echo -e "${GREEN}Latest version: ${VERSION}${NC}"
}

# Download and install the binary
install_binary() {
    local download_url="https://github.com/${GITHUB_REPO}/releases/download/${VERSION}/${BINARY_NAME}-${PLATFORM}"
    local temp_file="/tmp/${BINARY_NAME}"

    echo -e "${BLUE}Downloading ${BINARY_NAME} from ${download_url}...${NC}"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$download_url" -o "$temp_file"
    else
        wget -q "$download_url" -O "$temp_file"
    fi

    if [ ! -f "$temp_file" ]; then
        echo -e "${RED}Error: Download failed${NC}"
        exit 1
    fi

    # Create install directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"

    # Make it executable and move to install directory
    chmod +x "$temp_file"
    mv "$temp_file" "$INSTALL_DIR/$BINARY_NAME"

    echo -e "${GREEN}✓ Installed to $INSTALL_DIR/$BINARY_NAME${NC}"
}

# Verify installation
verify_installation() {
    if [ -x "$INSTALL_DIR/$BINARY_NAME" ]; then
        echo -e "${BLUE}Verifying installation...${NC}"
        "$INSTALL_DIR/$BINARY_NAME" version
        echo -e "${GREEN}✓ Installation successful!${NC}"
    else
        echo -e "${RED}Error: Installation verification failed${NC}"
        exit 1
    fi
}

# Check if install directory is in PATH
check_path() {
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        echo -e "${YELLOW}Warning: $INSTALL_DIR is not in your PATH${NC}"
        echo -e "${YELLOW}Add the following to your shell profile (~/.bashrc, ~/.zshrc, etc.):${NC}"
        echo -e "${BLUE}  export PATH=\"\$PATH:$INSTALL_DIR\"${NC}"
        echo ""
    fi
}

# Main installation flow
main() {
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Morphir Gleam Installer${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    detect_platform
    get_latest_version
    install_binary
    verify_installation
    check_path

    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Installation complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}Run 'morphir-gleam --help' to get started${NC}"
}

main "$@"
