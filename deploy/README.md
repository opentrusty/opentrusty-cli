# OpenTrusty CLI

This package contains the `opentrusty` command-line tool for database migrations and platform bootstrapping.

## Package Contents

- `opentrusty`: The Go binary.
- `install.sh`: Automated installer script.
- `.env.example`: Example environment variables.
- `LICENSE`: Apache 2.0 license.

## Installation

1. Extract the tarball:
   ```bash
   tar -xzf opentrusty-cli-<version>-linux-amd64.tar.gz
   cd opentrusty-cli/
   ```

2. Run the installer as root:
   ```bash
   sudo ./install.sh
   ```

## Usage

The CLI tool is used for initial setup and maintenance.

### Database Migrations
```bash
OPENTRUSTY_DATABASE_URL=... opentrusty migrate
```

### Platform Bootstrap
```bash
OPENTRUSTY_DATABASE_URL=... OPENTRUSTY_IDENTITY_SECRET=... opentrusty bootstrap
```

Refer to `.env.example` for required environment variables.
