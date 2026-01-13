#!/bin/bash
set -e

# uninstall.sh - OpenTrusty CLI Uninstaller
# Purpose: Removes the opentrusty CLI binary and optionally configurations.

COMPONENT="cli"
BINARY_NAME="opentrusty"
CONFIG_DIR="/etc/opentrusty"

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

echo "Uninstalling OpenTrusty ${COMPONENT}..."
echo ""

# 2. Remove binary
if [ -f "/usr/local/bin/${BINARY_NAME}" ]; then
  rm -f "/usr/local/bin/${BINARY_NAME}"
  log_info "Removed binary /usr/local/bin/${BINARY_NAME}"
else
  log_info "No binary found at /usr/local/bin/${BINARY_NAME}"
fi

# 3. Optional: Remove config
read -p "Do you want to remove CLI configuration in ${CONFIG_DIR}/cli.env? (y/N): " REMOVE_CONFIG
if [[ "$REMOVE_CONFIG" =~ ^[Yy]$ ]]; then
  rm -f "${CONFIG_DIR}/cli.env"
  log_info "Removed ${CONFIG_DIR}/cli.env"
  
  # Check if config directory is empty, if so remove it
  if [ -d "${CONFIG_DIR}" ] && [ -z "$(ls -A ${CONFIG_DIR})" ]; then
    rm -rf "${CONFIG_DIR}"
    log_info "Removed empty config directory ${CONFIG_DIR}"
  fi
else
  log_info "Preserved CLI configuration."
fi

echo ""
log_info "OpenTrusty ${COMPONENT} uninstallation complete."
