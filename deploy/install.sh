#!/bin/bash
set -e

# install.sh - OpenTrusty CLI Installer
# Purpose: Installs the opentrusty CLI binary.

COMPONENT="cli"
BINARY_NAME="opentrusty"
VERSION="dev"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# 1. Root check
if [ "$EUID" -ne 0 ]; then
  log_error "This script must be run as root."
  exit 1
fi

echo "Installing OpenTrusty ${COMPONENT}..."
echo ""

# 2. Copy binary
if [ -f "./${BINARY_NAME}" ]; then
  cp "./${BINARY_NAME}" /usr/local/bin/
  chmod +x /usr/local/bin/${BINARY_NAME}
  log_info "Installed ${BINARY_NAME} to /usr/local/bin/"
else
  log_error "Binary ${BINARY_NAME} not found in current directory."
  exit 1
fi

# 3. Create config directory and version file
CONFIG_DIR="/etc/opentrusty"
mkdir -p "${CONFIG_DIR}"
echo "$VERSION" > "${CONFIG_DIR}/${COMPONENT}.version"
log_info "Config directory ${CONFIG_DIR}/ exists and version recorded."

echo ""
echo "============================================"
echo "Installation complete!"
echo "============================================"
echo ""
echo "Usage: opentrusty <command> [args]"
echo ""
