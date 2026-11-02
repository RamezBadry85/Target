# Customers

Implemented offline-first vertical slice. Domain owns immutable profiles, query and
validation policies, repository/export contracts and provider-neutral sync protocols.
Data owns Sembast native/IndexedDB persistence, migrations, backups, durable outbox
and document generation. Presentation owns list/form/profile/activity/export screens.
Application composition owns database lifetime and bundled PDF fonts.

See `docs/CUSTOMERS.md` for schema, evaluation, privacy/recovery limits and future
backend choices. No cloud provider or production synchronization worker is enabled.
