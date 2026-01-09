#!/bin/bash
set -e

# install.sh - OpenTrusty CLI Installer
# Purpose: Installs the opentrusty CLI binary.

COMPONENT="cli"
BINARY_NAME="opentrusty"

# 1. Root check
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root."
  exit 1
fi

echo "Installing OpenTrusty ${COMPONENT}..."

# 2. Copy binary
if [ -f "./${BINARY_NAME}" ]; then
  cp "./${BINARY_NAME}" /usr/local/bin/
  chmod +x /usr/local/bin/${BINARY_NAME}
  echo "✓ Installed ${BINARY_NAME} to /usr/local/bin/"
else
  echo "Error: Binary ${BINARY_NAME} not found in current directory."
  exit 1
fi

echo ""
echo "Installation complete!"
echo "Usage: opentrusty <command> [args]"
echo ""
