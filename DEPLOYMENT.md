# OpenTrusty Deployment Guide

This document provides a comprehensive guide for deploying the OpenTrusty platform in a production-like environment using systemd.

## 1. Architecture Overview

OpenTrusty is built on an **Autonomous Plane** architecture. Each component is independent and can be deployed on a separate host without shared storage.

- **Authentication Plane (`auth`)**: Handles OIDC/OAuth2 login and end-user consent.
- **Administration Plane (`admin`)**: Management API for tenant and user provisioning.
- **Control Panel (`console`)**: Static frontend UI for administrators.
- **CLI (`opentrusty`)**: Operational tool for database migrations and platform bootstrapping.

> [!TIP]
> **Unix Daemon Naming**: Backend services follow the Unix daemon convention with a `d` suffix (e.g., `opentrusty-admind`, `opentrusty-authd`).

---

## 2. Infrastructure Requirements

- **Operating System**: Linux (amd64/arm64).
- **Database**: PostgreSQL 15+ (Shared or dedicated).
- **Reverse Proxy**: Caddy, Nginx, or similar.

---

## 3. Installation Flow

### 3.1 One-Click Installation (Recommended)

OpenTrusty provides a "One-Click" bootstrap script that handles component selection, installation, and initial configuration.

```bash
# General usage
curl -sSL https://raw.githubusercontent.com/opentrusty/opentrusty-core/main/scripts/bootstrap.sh | sudo bash -s [components]
```

#### First-Time Initialization (The CLI "Workhorse")
On your first deployment host, install the CLI to initialize the database:
```bash
curl ... | sudo bash -s cli
```
The script will launch an **Interactive Wizard** to:
1. Collect discrete Database connection details (Host, Port, User, Password, Name).
2. Collect Platform Admin credentials.
3. Automatically run `migrate` and `bootstrap`.
4. (Optional) Persist credentials to `/etc/opentrusty/cli.env` for future maintenance.

#### Adding Planes (Multi-Host)
On subsequent machines, install the specific plane without re-running initialization:
```bash
# On Admin Host
curl ... | sudo bash -s admin

# On Auth Host
curl ... | sudo bash -s auth

# On Console Host
curl ... | sudo bash -s control-panel
```

---

## 4. Configuration

OpenTrusty uses **Autonomous Configuration**. No `shared.env` is required; each component host is self-contained.

### 4.1 Discrete Database Variables
Configurations now prefer discrete fields over connection strings to avoid URI-encoding issues with special characters in passwords.

- `OPENTRUSTY_DB_HOST`
- `OPENTRUSTY_DB_PORT`
- `OPENTRUSTY_DB_USER`
- `OPENTRUSTY_DB_PASSWORD`
- `OPENTRUSTY_DB_NAME`
- `OPENTRUSTY_DB_SSLMODE`

### 4.2 Location
Configuration files are located in `/etc/opentrusty/`:
- `admin.env`
- `auth.env`
- `cli.env`

---

## 5. Maintenance and Uninstallation

### 5.1 Idempotent Upgrades
Re-running `bootstrap.sh` or component `install.sh` scripts will:
1. Update binaries and systemd units.
2. **Preserve existing configurations**.
3. Automatically migrate/append new required environment variables from `.env.example`.

### 5.2 Clean Uninstallation
To remove OpenTrusty components from a host:

```bash
# Global uninstall from bootstrap
curl -sSL ... | sudo bash -s uninstall [components]

# Or via per-component script
sudo /usr/local/bin/opentrusty-admind --version # Check location
sudo bash /path/to/extracted/deploy/uninstall.sh
```

---

## 6. Reverse Proxy Setup

Refer to `opentrusty-control-panel/Caddyfile.example` for standard reverse proxy configurations (TLS, path routing).
