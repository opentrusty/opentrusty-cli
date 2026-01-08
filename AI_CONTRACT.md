# AI_CONTRACT — opentrusty-cli

## Scope of Responsibility
- Database schema migrations (up/down).
- Semantic bootstrap (creating the first Platform Admin).
- Headless administrative scripting and operational commands.

## Explicit Non-Goals
- **NO Long-running Server**: This is a transient CLI tool only.
- **NO Bypass Authentication**: All general management commands MUST interact with `admind` via HTTP API and require authentication.

## Allowed Dependencies
- `github.com/opentrusty/opentrusty-core`
- Infrastructure (Direct DB access) ONLY for migrations and bootstrap.

## Forbidden Dependencies
- **NO internal dependencies** on `opentrusty-admin` or `opentrusty-auth` (interaction via HTTP ONLY).

## Change Discipline
- New migration files MUST follow the established naming and sequence convention.
- Bootstrap logic changes MUST be documented in docs/operations/bootstrap.md.

## Invariants
- **Audit Logging**: Direct DB actions (bootstrap) MUST be recorded in the audit log manually.
- **Fail-Safe**: Migrations must be transactional where supported by the database engine.
