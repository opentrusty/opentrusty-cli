#!/bin/bash
set -e

# OpenTrusty One-Click Bootstrap Installer
# Purpose: Remote installer for quick setup via curl | bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Interaction Helpers
is_interactive() {
  if [ -t 0 ]; then return 0; fi
  if [ -c /dev/tty ] && [ -w /dev/tty ]; then return 0; fi
  return 1
}

read_tty() {
  local prompt="$1"
  local var_name="$2"
  local flags="$3"
  local val=""

  if [ -t 0 ]; then
    read $flags -p "$prompt" val
  elif [ -c /dev/tty ]; then
    read $flags -p "$prompt" val < /dev/tty
  else
    # Non-interactive fallback (uses defaults)
    val=""
  fi
  # Safe assignment without eval
  printf -v "$var_name" '%s' "$val"
}

# 1. Pre-flight checks
if [ "$EUID" -ne 0 ]; then
  log_error "This script must be run as root (or via sudo)."
  exit 1
fi

# 2. Environment & OS Detection
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

if [ "$OS" != "linux" ]; then
  log_error "OpenTrusty currently only supports Linux (for systemd)."
  exit 1
fi

case $ARCH in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) log_error "Unsupported architecture: $ARCH"; exit 1 ;;
esac

# 3. Versioning & Paths
REPO_BASE="https://github.com/opentrusty"
GLOBAL_VERSION=${VERSION:-""}
TMP_DIR="/tmp/opentrusty-bootstrap"

# 4. Global Commands (Uninstall)
if [ "$1" = "uninstall" ]; then
  log_info "=== OpenTrusty Global Uninstaller ==="
  echo "This will uninstall selected components from this host."
  
  shift # Remove 'uninstall' from args
  UNINSTALL_COMPONENTS="$@"
  if [ -z "$UNINSTALL_COMPONENTS" ]; then
    if is_interactive; then
      echo "Which components would you like to uninstall? (Separate by space, or leave empty for ALL)"
      echo "Options: cli, admin, auth, control-panel"
      read_tty "Selection [cli admin auth control-panel]: " SELECTED
      UNINSTALL_COMPONENTS=${SELECTED:-"cli admin auth control-panel"}
    else
      UNINSTALL_COMPONENTS="cli admin auth control-panel"
    fi
  fi
  
  mkdir -p "$TMP_DIR"
  cd "$TMP_DIR"

  for comp in $UNINSTALL_COMPONENTS; do
    repo="opentrusty-$comp"
    comp_version=""
    
    # Try local detection first
    if [ "$comp" = "admin" ] && command -v opentrusty-admind &> /dev/null; then
      comp_version=$(opentrusty-admind --version | head -n 1 | tr -d '\r')
    elif [ "$comp" = "auth" ] && command -v opentrusty-authd &> /dev/null; then
      comp_version=$(opentrusty-authd --version | head -n 1 | tr -d '\r')
    elif [ "$comp" = "cli" ] && command -v opentrusty &> /dev/null; then
      comp_version=$(opentrusty --version | head -n 1 | tr -d '\r')
    fi

    # Try version file if binary check failed or for non-binary components
    if [ -z "$comp_version" ] || [ "$comp_version" = "dev" ]; then
      if [ "$comp" = "control-panel" ] && [ -f "/var/www/opentrusty-control-panel/dist/version.txt" ]; then
        comp_version=$(head -n 1 "/var/www/opentrusty-control-panel/dist/version.txt" | tr -d '\r')
      elif [ -f "/etc/opentrusty/${comp}.version" ]; then
        comp_version=$(head -n 1 "/etc/opentrusty/${comp}.version" | tr -d '\r')
      fi
    fi
    
    # Cleanup detected version (ensure it starts with v)
    if [ -n "$comp_version" ] && [ "${comp_version#v}" = "$comp_version" ] && [ "$comp_version" != "dev" ]; then
      comp_version="v$comp_version"
    fi

    # Fallback to GitHub API if local detection failed
    if [ -z "$comp_version" ] || [ "$comp_version" = "vdev" ] || [ "$comp_version" = "dev" ]; then
      log_info "No local version detected for $comp. Fetching latest from GitHub..."
      comp_version=$(curl -s "https://api.github.com/repos/opentrusty/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    fi
    
    if [ -z "$comp_version" ] || echo "$comp_version" | grep -q "api.github.com"; then
      log_error "Could not determine version for $comp. Please set VERSION env var."
      continue
    fi
    
    log_info "Targeting version $comp_version for $comp uninstallation..."

    tarball=""
    if [ "$comp" = "control-panel" ]; then tarball="opentrusty-control-panel-$comp_version.tar.gz"
    elif [ "$comp" = "cli" ]; then tarball="opentrusty-cli-$comp_version-linux-$ARCH.tar.gz"
    else tarball="opentrusty-$comp-$comp_version-linux-$ARCH.tar.gz"; fi
    
    URL="${REPO_BASE}/${repo}/releases/download/${comp_version}/${tarball}"
    log_info "Downloading uninstaller package ($tarball)..."
    if ! curl -sL -f -O "$URL"; then
      log_warn "Failed to download $comp ($URL). Skipping."
      continue
    fi
    
    mkdir -p "$comp-uninstall"
    tar -xzf "$tarball" -C "$comp-uninstall" --strip-components=1
    (cd "$comp-uninstall" && bash ./uninstall.sh)
    rm -rf "$comp-uninstall" "$tarball"
  done
  
  log_success "Uninstallation complete."
  exit 0
fi

# 5. Component Selection Logic
# Priority: 1. CLI Arguments, 2. INSTALL_COMPONENTS Env, 3. Interactive Prompt
COMPONENTS=""

if [ $# -gt 0 ]; then
  COMPONENTS="$@"
elif [ -n "$INSTALL_COMPONENTS" ]; then
  COMPONENTS="$INSTALL_COMPONENTS"
else
  if is_interactive; then
    log_info "No components specified. Entering interactive selection..."
    echo "Which components would you like to install? (Separate by space, or leave empty for ALL)"
    echo "Options: cli, admin, auth, control-panel"
    read_tty "Selection [cli admin auth control-panel]: " SELECTED
    COMPONENTS=${SELECTED:-"cli admin auth control-panel"}
  else
    log_info "Non-interactive mode, installing all components."
    COMPONENTS="cli admin auth control-panel"
  fi
fi

# Save original list for post-install summary
COMPONENTS_ORIG="$COMPONENTS"

log_info "Installing components: $COMPONENTS"

mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

install_component() {
  local comp=$1
  local repo="opentrusty-$comp"
  local comp_version="$GLOBAL_VERSION"
  
  log_info "--- Preparing $comp ---"

  # Detect version for this component if no global version is set
  if [ -z "$comp_version" ]; then
    log_info "Fetching latest version for $repo from GitHub..."
    comp_version=$(curl -s "https://api.github.com/repos/opentrusty/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$comp_version" ] || echo "$comp_version" | grep -q "api.github.com"; then
      log_warn "Failed to fetch version for $comp via API, falling back to v0.1.0"
      comp_version="v0.1.0"
    fi
  fi
  
  log_info "Target Version for $comp: ${comp_version}"

  local tarball=""
  if [ "$comp" = "control-panel" ]; then
    tarball="opentrusty-control-panel-$comp_version.tar.gz"
  elif [ "$comp" = "cli" ]; then
    tarball="opentrusty-cli-$comp_version-linux-$ARCH.tar.gz"
  else
    tarball="opentrusty-$comp-$comp_version-linux-$ARCH.tar.gz"
  fi
  
  URL="${REPO_BASE}/${repo}/releases/download/${comp_version}/${tarball}"
  
  log_info "Downloading $tarball..."
  if ! curl -sL -f -O "$URL"; then
    log_error "Failed to download $comp ($URL). Skipping."
    return 1
  fi
  
  log_info "Extracting $tarball..."
  local extract_dir="$comp-extract"
  mkdir -p "$extract_dir"
  tar -xzf "$tarball" -C "$extract_dir" --strip-components=1
  
  log_info "Running installer for $comp..."
  (cd "$extract_dir" && bash ./install.sh)
  
  # Cleanup extracted files
  rm -rf "$extract_dir" "$tarball"
  
  log_success "$comp installation completed."

  # CLI Post-install initialization logic
  if [ "$comp" = "cli" ]; then
    if is_interactive; then
      run_cli_bootstrapper
    else
      log_warn "Interactive setup skipped because no terminal was detected. Run the script interactively or use 'opentrusty migrate' manually."
    fi
  fi
}

# Shared DB credentials (collected once, reused for env file generation)
OT_DB_HOST=""
OT_DB_PORT=""
OT_DB_USER=""
OT_DB_PASS=""
OT_DB_NAME=""
OT_DB_SSLMODE=""
OT_IDENT_SECRET=""
OT_SESSION_SECRET=""
DB_COLLECTED=false

collect_db_credentials() {
  if [ "$DB_COLLECTED" = true ]; then return 0; fi

  echo ""
  log_info "=== Database & Security Configuration ==="
  log_info "These values will be shared across all installed components."
  echo ""

  read_tty "Enter Database Host [localhost]: " OT_DB_HOST
  OT_DB_HOST=${OT_DB_HOST:-"localhost"}
  read_tty "Enter Database Port [5432]: " OT_DB_PORT
  OT_DB_PORT=${OT_DB_PORT:-"5432"}
  read_tty "Enter Database User [postgres]: " OT_DB_USER
  OT_DB_USER=${OT_DB_USER:-"postgres"}
  read_tty "Enter Database Password [password]: " OT_DB_PASS "-s"
  echo ""
  OT_DB_PASS=${OT_DB_PASS:-"password"}
  read_tty "Enter Database Name [opentrusty]: " OT_DB_NAME
  OT_DB_NAME=${OT_DB_NAME:-"opentrusty"}
  read_tty "Enter Database SSL Mode [require]: " OT_DB_SSLMODE
  OT_DB_SSLMODE=${OT_DB_SSLMODE:-"require"}
  
  # Identity Secret
  read_tty "Enter OPENTRUSTY_IDENTITY_SECRET (hex, or empty to auto-gen): " OT_IDENT_SECRET
  if [ -z "$OT_IDENT_SECRET" ]; then
    OT_IDENT_SECRET=$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')
    log_info "Auto-generated Identity Secret (saved to env files, not displayed)."
  fi

  # Session Secret
  read_tty "Enter OPENTRUSTY_SESSION_SECRET (hex, or empty to auto-gen): " OT_SESSION_SECRET
  if [ -z "$OT_SESSION_SECRET" ]; then
    OT_SESSION_SECRET=$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')
    log_info "Auto-generated Session Secret (saved to env files, not displayed)."
  fi

  DB_COLLECTED=true
}

run_cli_bootstrapper() {
  echo ""
  log_info "=== OpenTrusty CLI Interactive Setup ==="
  log_info "Note: This will perform initialization (migration & bootstrap)."
  
  collect_db_credentials

  export OPENTRUSTY_DB_HOST="$OT_DB_HOST"
  export OPENTRUSTY_DB_PORT="$OT_DB_PORT"
  export OPENTRUSTY_DB_USER="$OT_DB_USER"
  export OPENTRUSTY_DB_PASSWORD="$OT_DB_PASS"
  export OPENTRUSTY_DB_NAME="$OT_DB_NAME"
  export OPENTRUSTY_DB_SSLMODE="$OT_DB_SSLMODE"
  export OPENTRUSTY_IDENTITY_SECRET="$OT_IDENT_SECRET"

  log_info "Running database migrations..."
  if ! opentrusty migrate; then
    log_error "Migration failed. Please check your DB credentials."
    return 1
  fi
  log_success "Migrations completed."

  echo ""
  read_tty "Do you want to bootstrap the platform admin now? (y/N): " RUN_BOOTSTRAP
  if [[ "$RUN_BOOTSTRAP" =~ ^[Yy]$ ]]; then
    read_tty "Enter Platform Admin Email: " ADMIN_EMAIL
    read_tty "Enter Platform Admin Password: " ADMIN_PASSWORD "-s"
    echo ""

    if [ -n "$ADMIN_EMAIL" ] && [ -n "$ADMIN_PASSWORD" ]; then
      export OPENTRUSTY_BOOTSTRAP_ADMIN_EMAIL="$ADMIN_EMAIL"
      export OPENTRUSTY_BOOTSTRAP_ADMIN_PASSWORD="$ADMIN_PASSWORD"
      
      if opentrusty bootstrap; then
        log_success "Platform admin bootstrapped."
      else
        log_error "Bootstrap failed."
      fi
    else
      log_warn "Missing required fields, skipping bootstrap."
    fi
  fi

  echo ""
  read_tty "Do you want to persist CLI settings to /etc/opentrusty/cli.env? (y/N): " PERSIST
  if [[ "$PERSIST" =~ ^[Yy]$ ]]; then
    mkdir -p /etc/opentrusty
    cat > /etc/opentrusty/cli.env << EOF
# OpenTrusty CLI Configuration
OPENTRUSTY_DB_HOST=$OT_DB_HOST
OPENTRUSTY_DB_PORT=$OT_DB_PORT
OPENTRUSTY_DB_USER=$OT_DB_USER
OPENTRUSTY_DB_PASSWORD=$OT_DB_PASS
OPENTRUSTY_DB_NAME=$OT_DB_NAME
OPENTRUSTY_DB_SSLMODE=$OT_DB_SSLMODE
OPENTRUSTY_IDENTITY_SECRET=$OT_IDENT_SECRET
EOF
    chmod 600 /etc/opentrusty/cli.env
    log_success "Persisted CLI configuration to /etc/opentrusty/cli.env"
  fi
}

configure_plane_env() {
  local plane="$1"       # "auth" or "admin"
  local listen_addr="$2" # ":8080" or ":8081"
  local session_ns="$3"  # "auth" or "admin"
  local env_file="/etc/opentrusty/${plane}.env"

  if [ ! -f "$env_file" ]; then
    log_warn "$env_file not found. Skipping env configuration for $plane."
    return 0
  fi

  collect_db_credentials

  log_info "Configuring $env_file with collected credentials..."

  # Overwrite key variables in the env file
  local tmp_env
  tmp_env=$(mktemp)
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      OPENTRUSTY_DB_HOST=*)     echo "OPENTRUSTY_DB_HOST=$OT_DB_HOST" ;;
      OPENTRUSTY_DB_PORT=*)     echo "OPENTRUSTY_DB_PORT=$OT_DB_PORT" ;;
      OPENTRUSTY_DB_USER=*)     echo "OPENTRUSTY_DB_USER=$OT_DB_USER" ;;
      OPENTRUSTY_DB_PASSWORD=*) echo "OPENTRUSTY_DB_PASSWORD=$OT_DB_PASS" ;;
      OPENTRUSTY_DB_NAME=*)     echo "OPENTRUSTY_DB_NAME=$OT_DB_NAME" ;;
      OPENTRUSTY_DB_SSLMODE=*)  echo "OPENTRUSTY_DB_SSLMODE=$OT_DB_SSLMODE" ;;
      OPENTRUSTY_IDENTITY_SECRET=*) echo "OPENTRUSTY_IDENTITY_SECRET=$OT_IDENT_SECRET" ;;
      OPENTRUSTY_SESSION_SECRET=*)  echo "OPENTRUSTY_SESSION_SECRET=$OT_SESSION_SECRET" ;;
      *) echo "$line" ;;
    esac
  done < "$env_file" > "$tmp_env"
  mv "$tmp_env" "$env_file"
  chmod 600 "$env_file"
  chown opentrusty:opentrusty "$env_file" 2>/dev/null || true

  log_success "$env_file configured with production values."
}

# 6. Execution Loop
# Ensure CLI is installed first if selected (handles migrations)
if echo "$COMPONENTS" | grep -qw "cli"; then
  install_component "cli"
  # Filter out cli from the rest to avoid double install
  REMAINING=""
  for _c in $COMPONENTS; do
    if [ "$_c" != "cli" ]; then
      REMAINING="$REMAINING $_c"
    fi
  done
  COMPONENTS="$REMAINING"
fi

for comp in $COMPONENTS; do
  if [ -n "$comp" ]; then
    install_component "$comp"

    # Post-install: configure env files for auth/admin planes
    if is_interactive; then
      case "$comp" in
        auth)
          configure_plane_env "auth" ":8080" "auth"
          ;;
        admin)
          configure_plane_env "admin" ":8081" "admin"
          ;;
        control-panel)
          # control-panel install.sh already prompts for API/Auth URLs
          ;;
      esac
    fi
  fi
done

# 7. Post-install summary
echo ""
log_success "=========================================="
log_success "OpenTrusty Bootstrap Complete!"
log_success "=========================================="
echo ""

if echo "$COMPONENTS_ORIG" | grep -qw "auth"; then
  echo "Auth Plane:"
  echo "  sudo systemctl enable --now opentrusty-authd"
  echo "  sudo systemctl status opentrusty-authd"
  echo "  journalctl -u opentrusty-authd -f"
  echo ""
fi

if echo "$COMPONENTS_ORIG" | grep -qw "admin"; then
  echo "Admin Plane:"
  echo "  sudo systemctl enable --now opentrusty-admind"
  echo "  sudo systemctl status opentrusty-admind"
  echo "  journalctl -u opentrusty-admind -f"
  echo ""
fi

# Cleanup temp directory
rm -rf "$TMP_DIR"
