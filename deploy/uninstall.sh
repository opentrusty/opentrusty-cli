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

# Detect interactive mode
INTERACTIVE=false
if [ -t 0 ]; then INTERACTIVE=true; fi

# Support force flag
FORCE_REMOVE=${FORCE_REMOVE:-false}

echo "Uninstalling OpenTrusty ${COMPONENT}..."
echo ""

# 2. Remove binary
if [ -f "/usr/local/bin/${BINARY_NAME}" ]; then
  rm -f "/usr/local/bin/${BINARY_NAME}"
  log_info "Removed binary /usr/local/bin/${BINARY_NAME}"
else
  log_info "No binary found at /usr/local/bin/${BINARY_NAME}"
fi

# Remove version file unconditionally
if [ -f "${CONFIG_DIR}/${COMPONENT}.version" ]; then
  rm -f "${CONFIG_DIR}/${COMPONENT}.version"
  log_info "Removed version record ${CONFIG_DIR}/${COMPONENT}.version"
fi

# 3. Optional: Remove config
REMOVE_CONFIG="n"
if [ "$INTERACTIVE" = true ] && [ "$FORCE_REMOVE" = false ]; then
  read -p "Do you want to remove CLI configuration in ${CONFIG_DIR}/cli.env? (y/N): " REMOVE_CONFIG
elif [ "$FORCE_REMOVE" = true ]; then
  REMOVE_CONFIG="y"
fi

if [[ "$REMOVE_CONFIG" =~ ^[Yy]$ ]]; then
  # Source credentials to know which DB to drop
  if [ -f "${CONFIG_DIR}/cli.env" ]; then
    source "${CONFIG_DIR}/cli.env"
  fi

  # 4. Optional: Drop Database
  # Only prompt if no other OpenTrusty .version files exist (meaning no other components depend on the DB)
  if [ -d "${CONFIG_DIR}" ] && ! ls "${CONFIG_DIR}"/*.version >/dev/null 2>&1; then
    DROP_DB="n"
    if [ "$INTERACTIVE" = true ] && [ "$FORCE_REMOVE" = false ]; then
      echo ""
      log_warn "No other OpenTrusty components are installed."
      read -p "Do you want to completely DROP the OpenTrusty database '${OPENTRUSTY_DB_NAME}'? This is IRREVERSIBLE! (y/N): " DROP_DB
    elif [ "$FORCE_REMOVE" = true ]; then
      DROP_DB="y"
    fi

    if [[ "$DROP_DB" =~ ^[Yy]$ ]]; then
      if command -v psql &> /dev/null; then
        export PGPASSWORD="${OPENTRUSTY_DB_PASSWORD}"
        log_info "Dropping database ${OPENTRUSTY_DB_NAME}..."
        psql -h "${OPENTRUSTY_DB_HOST}" -p "${OPENTRUSTY_DB_PORT}" -U "${OPENTRUSTY_DB_USER}" -d postgres -c "DROP DATABASE IF EXISTS \"${OPENTRUSTY_DB_NAME}\";" || log_warn "Failed to drop database. You may need to drop it manually."
      else
        log_warn "psql command not found. Please drop the database '${OPENTRUSTY_DB_NAME}' manually."
      fi
    else
      log_info "Preserved database '${OPENTRUSTY_DB_NAME}'."
    fi
  else
    if [ -n "${OPENTRUSTY_DB_NAME}" ]; then
      log_info "Preserved database '${OPENTRUSTY_DB_NAME}' (other components are still installed)."
    fi
  fi

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
