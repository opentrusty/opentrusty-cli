# OpenTrusty CLI

OpenTrusty CLI is the **Operator & Lifecycle Tooling** for the OpenTrusty Identity Platform.

It is used for database migrations, initial system bootstrap, and headless administrative scripting.

## Role & Responsibility

- **Database Migrations**: Managing schema evolution via `migrate up` and `migrate down`.
- **System Bootstrap**: Initial provisioning of the platform administrator and foundational roles.
- **Headless Operations**: Direct interaction with the persistence layer for recovery or automation (requires explicit database access).
- **Architecture**: Depends on `opentrusty-core`. Does NOT run a persistent network service.

## Requirements

- PostgreSQL (via `OPENTRUSTY_DB_*` variables)
- OpenTrusty Core (Go module)

## Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/opentrusty/opentrusty-cli/main/scripts/bootstrap.sh | sudo bash
```

## Getting Started

1. Set up environment variables:
   ```bash
   cp .env.example .env
   ```
2. Build the tool:
   ```bash
   make build
   ```
3. Run migrations:
   ```bash
   ./opentrusty migrate
   ```
4. Bootstrap the platform:
   ```bash
   ./opentrusty bootstrap
   ```

## Deployment

Pre-built binaries for the CLI are available in the [GitHub Releases](https://github.com/opentrusty/opentrusty-cli/releases).

Detailed instructions are available in the [Deployment Guide](./DEPLOYMENT.md) and the `README.md` included in each release package.

## License


Apache-2.0
