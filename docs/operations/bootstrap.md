# Platform Bootstrap

The bootstrap process initializes the OpenTrusty platform with its first administrator.

## Process

1. **Database Ready**: Ensure the PostgreSQL database is up and migrations are applied (`migrate up`).
2. **Execute Bootstrap**: Run `opentrusty bootstrap`.
3. **Admin Creds**: The tool will provision a `platform_admin` role to the user specified by `OPENTRUSTY_BOOTSTRAP_ADMIN_EMAIL`.

## Invariants

- Bootstrap can only be run once successfully.
- Subsequent administrative user management MUST be done via the Admin API.
