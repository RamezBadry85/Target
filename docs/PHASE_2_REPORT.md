# Phase 2 — Customer management handoff

## Delivered scope

Only Customers was implemented. Other modules remain placeholders. Customer list,
add/edit form, full profile, archive/restore, activity timeline and recording,
export options, local sync status, JSON backup and guarded restore are present.
Arabic/English copy, RTL/LTR and responsive layouts follow the existing shell.
No operational seed data, cloud provider, authentication, sales transactions,
quotations, inventory or warehouse functionality was added.

See `CUSTOMERS.md` for database evaluation, schema, dependencies, recovery and
security considerations, and a future backend recommendation requiring approval.

## Data guarantees and limits

- Native Sembast file or Web IndexedDB, schema v2, explicit upgrade and downgrade
  protection. UUIDs, UTC timestamps, optimistic local revisions and soft archives.
- Every mutation and aggregate outbox entry commits together. UI success follows
  the awaited write. Duplicate checks include archived records and run in the
  transaction. Contact collections are immutable and support multiple contacts.
- Currency amounts are integer hundredths with explicit currency code; no finance
  ledger, currency conversion or jurisdiction-specific credit policies exist.
- Retry/backoff, idempotency and optimistic remote-version gateway contracts are
  prepared and tested with in-process gateways. Conflicts retain local/remote
  snapshots and block that customer. No production sync timer/provider is started.
- Restore validates relationships/outbox snapshots and refuses nonempty workspaces.
  Recovery requeues complete aggregates and preserves blocked conflict snapshots.
  Plaintext backups/exports require secure handling. Browser site data is not a
  guaranteed permanent backup; no storage reset occurs on failure.

## Verification and corrections

Analysis and all 46 isolated VM regression cases passed in preparation run
[41462554223](https://github.com/RamezBadry85/Target/actions/runs/41462554223).
Tests include file database close/reopen, schema migration, stale edits and
concurrent duplicates, activity history, validated recovery, clock rollback,
offline transport failure, retries, acknowledgement races/conflicts, XLSX
round-trip and filter/RTL metadata, PDF embedding/pagination, Arabic/English UI
layout and actual form persistence.

Failures were fixed rather than suppressed:

- SDK lints: added blocks and removed redundant imports with Dart fixes.
- Acknowledgement attempted to mutate immutable Sembast snapshots: copy before
  updating and retain tests for acknowledgement ordering and concurrent edits.
- XLSX midnight fixture decoded as a date-only cell: verify a non-midnight UTC
  timestamp and exact round-trip instead of relying on an ambiguous midnight type.
- XLSX rename lost RTL view metadata: explicitly write a valid RTL worksheet view.
- Widget fixture IO/save futures stalled under fake async or missed a scrolled
  button: dismiss field focus, await the actual repository transaction through a
  test observer and retain saved-record/outbox assertions. No tap warnings were
  suppressed and no tests were skipped to obtain a pass.

The permanent workflow also runs the complete VM suite, explicit Chrome IndexedDB
persistence, Web release and Android debug builds. Its actual final results and
run URL are in the delivery response. A configured pipeline or preparation run is
not by itself evidence that those build steps passed.

## Remaining acceptance work

- Approve a backend before implementing authenticated transport, server revision
  enforcement, pull/cursor reconciliation, cross-device conflict-resolution UI,
  or a production synchronization worker. No cloud sync is operational.
- Manually inspect Arabic PDF glyph quality/line breaks and Excel presentation
  in target viewer applications. Automated tests prove generation, embedded fonts,
  text/number/date round-trip and pagination, not typographic approval.
- Test native file-save/picker dialogs and full application lifecycle on Android,
  iOS, Windows and macOS devices. Windows/Apple builds are not established by Linux
  CI. Android debug compilation is not production signing or installer acceptance.
- Validate Web offline cold-start/service-worker upgrades on deployed HTTPS;
  IndexedDB persistence alone is not proof of a complete offline PWA install.
- Review data-at-rest encryption, trusted-device policies, backup retention and
  large-customer-book performance before deployment. Current repository queries
  scan the local customer book in memory; UI pages 25 rows.

## Delivery

Work remains on `arena/e27dac95-target`. The final response provides the exact
commit hash and final GitHub Actions run URL, avoiding a self-referential commit
hash inside this document. No repository settings or secrets were changed.
