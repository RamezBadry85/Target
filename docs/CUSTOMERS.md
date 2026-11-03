# Customer management — offline-first design

## Database evaluation and decision

| Candidate | Native platforms | Web | Trade-off |
| --- | --- | --- | --- |
| SQLite + Drift | Excellent SQL, constraints and migrations | WASM/worker assets and browser persistence setup | Strong future reporting option; extra native/Web packaging and generated schema code for this slice |
| Sembast + sembast_web (selected) | File-backed Dart database; mobile/desktop without SQLite binaries | IndexedDB | Transactions, version-change callbacks, consistent API and simple document aggregates; data/indexes largely memory-resident, suited to a single-manager customer book rather than large analytics datasets |
| Shared preferences | Settings storage | Browser settings | No appropriate multi-record transactions/outbox; rejected |
| Hive-style stores | Broad support | Browser storage | Schema/migration and transactional multi-store needs require more custom conventions; not selected |

Sembast is a free embedded database, not a cloud service. No backend or account is
required. A future SQLite adapter can implement the same domain repository contract
if customer volumes demand indexed/paged database queries instead of in-memory
filtering. Current UI paginates 25 records; repository filtering/sorting loads the
customer book in memory. Benchmark realistic data before high-volume deployment.

## Schema v2

All identifiers are UUID v4, times are UTC ISO-8601, and money is integer hundredths
with an explicit three-letter currency code (initial form default EGP, editable).
No aggregate financial arithmetic or exchange rates are implemented.

- `customers` keyed by customer UUID: draft fields (name, medical type, contacts,
  address, governorate/city/area, classification, business sector, representative
  ID, status, potential, credit limit, currency, notes), createdAt, updatedAt,
  archivedAt, local revision, remote version and synchronization state.
- `contacts` are immutable typed records embedded in the customer aggregate with
  independent UUIDs, names, primary/alternative phones and email. Contact identity
  is scoped to its owning customer: `(customerId, contactId)`. Save and v2 restore
  both require nonempty, unique IDs within that aggregate. Existing contact IDs
  are preserved verbatim; no schema migration or identifier rewriting is needed. The form supports
  multiple contacts; the primary phone of each is required.
- `customer_activities` keyed by activity UUID: customer ID, activity type, text,
  occurredAt, createdAt and optional sourceReference. Business activity types are
  descriptive only; no quotation/sale/collection is created.
- `customer_outbox` keyed by immutable operation UUID: customer ID, local revision,
  aggregate snapshot (customer plus activities), createdAt, attempts,
  nextAttemptAt, blocked. Every mutation and outbox entry is one transaction.
- `customer_conflicts` keyed by customer UUID: local change reference, remote
  snapshot/version and detectedAt. Local data is not overwritten on conflict.

Fresh databases open at version 2. The explicit v1-to-v2 migration preserves
profiles, supplies revision/sync metadata and queues them for future sync.
Record update timestamps do not move backwards when a device clock rolls back;
local revision, not wall-clock time, orders changes. Version changes are transactional in Sembast. A newer-than-supported schema is
rejected, never silently reset. Native storage uses Application Support;
Web uses a named IndexedDB database scoped to the origin/browser profile.

## Validation and duplicates

Name (2–200 characters) and at least one valid contact phone are required. Email
and alternative phone are optional but validated when provided. Phone normalization
supports Arabic numerals, strips presentation punctuation and treats `00` and `+`
international prefixes consistently. It does not guess a country code: local and
international spellings may require manual review. Email matching is case-insensitive.

A matching normalized organization name + governorate + city, shared phone, or
shared nonempty email prevents insertion/edit to a duplicate. Archived profiles
are included; review or restore them instead of creating a replacement. Shared
switchboards/emails are therefore intentionally conservative duplicate candidates.
There is no silent override. Validation and duplicate checks occur inside the
transaction, not only in form widgets. Optimistic local revisions reject stale
edits from another tab/window without overwriting newer data.

## Local operations and synchronization

Writes are awaited before success is shown. The UI labels pending changes as
**Saved locally · Pending synchronization** and states that cloud sync is not
configured. No network connection is needed for customer operations or exports.

`CustomerSyncGateway` is provider-neutral; `CustomerSyncService` is NOT started in
production. Once an approved gateway exists, `start(onError: ...)` supplies a
periodic retry hook. Failed transport retains outbox data and durable exponential
backoff; operations remain ordered per customer, including if the clock moves
backward. Acknowledgement advances the remote revision but cannot mark a newer
local edit synchronized while another event remains. Conflicts retain both
snapshots and block that customer's queue. No last-write-wins overwrite is used.

This is **not operational cloud synchronization**. Backend approval, authentication,
scoped tenant/actor identity, pull cursors, tombstone retention, cross-device
conflict-resolution UI, transport security and multi-tab sync-worker ownership
remain future work. Other customers' queues may proceed past a blocked customer.
No production provider is configured; synchronized/error/conflict states are
exercised with deterministic test gateways only.

### Recommended future backend (approval required)

Prefer PostgreSQL behind an authenticated HTTPS API for future relational sales,
collections and reporting. The server must atomically enforce operation UUID
idempotency, expected remote revision, ownership and an ordered change cursor.
Return explicit conflicts instead of silently overwriting records. Compare:

1. Self-hosted PostgreSQL + a small API: maximum control, hosting/backup/ops burden.
2. Managed PostgreSQL plus a custom API: reduced DB operations, recurring hosting
   cost and data residency review.
3. Supabase/PostgreSQL or Firebase: convenience, but provider-specific auth/sync
   semantics and quotas/costs require review. Neither is selected or integrated.

No cloud SDK, provider, secrets or remote endpoint has been added. Present concrete
hosting, security and cost choices for approval before that phase.

## Backup and recovery

JSON backup captures a transactionally consistent snapshot of customers,
activities, pending operations and conflict snapshots. Exported JSON is NOT
encrypted: store it securely, restrict access and test recovery regularly.
Restore is limited to an empty workspace, validates format/schema and relationships,
and runs atomically. It does not overwrite an existing book. Current aggregate
snapshots are requeued for future reconciliation rather than claiming a backup is
already synchronized. Keep the original backup for forensic/outbox history.

The Web build bundles renderer resources (`--no-web-resources-cdn`) rather than
requiring the CanvasKit CDN. An initial HTTPS load/install and a stable origin are
required; air-gapped first installation is not claimed. Browser offline cold-start
and service-worker upgrade behavior still require deployment acceptance testing.

The browser may evict site storage, private sessions may not persist, and deleting
site/app data removes local records. The UI warns explicitly. Native OS backups
are not a substitute for application backups. On corruption/open/quota failure,
the UI shows an error and does not reset the database. Preserve the original file
or browser profile; recover into a separate empty workspace and verify before
removing the old copy. Data-at-rest encryption is not implemented; deployment on
shared/untrusted devices requires a separate security review.

## Exports

- XLSX: real customer fields, Arabic/English headers, RTL worksheet when Arabic,
  typed dates in UTC, numeric money, currency column, frozen header and OOXML
  AutoFilter compatible with Excel sorting/filtering. Text remains text rather
  than executable formulas. Exports use all filtered matches, not just one page;
  an explicit all-records option includes the archive.
- PDF: A4, navy/white identity, title, generation time, count, selected filters,
  page numbers and full profile tables. Amiri regular/bold fonts are bundled under
  SIL OFL, not fetched from the network. Long values are split into bounded table
  rows to permit pagination. Arabic uses PDF bidi/RTL shaping; English uses LTR.
- Native file-save dialogs and browser downloads use file_saver byte APIs.
  Browser download initiation cannot prove that a user retained the file. File
  selector is only used for picking JSON backups. No Android broad-storage
  permission is requested.

Tests distinguish document generation from OS save-dialog/device acceptance.
Arabic glyph embedding, PDF structure/pagination and UI RTL are automated; manual
visual PDF review and native save dialogs on all host OSes remain acceptance work.

## Dependency purposes

Sembast + sembast_web: transactional native/IndexedDB adapters. path_provider and
path: native app-support path. uuid: record/contact/operation identifiers.
excel: XLSX encoding. archive + xml: standard OOXML AutoFilter/freeze augmentation.
pdf: offline PDF rendering. file_saver: user-directed native saves/browser download.
file_selector: backup file selection. All resolved versions are in pubspec.lock;
transitive plugin dependencies are not used to contact a network service.

## Test and build evidence

The delivery response links the final verified revision/run and reports actual
executed results. The existing CI runs formatting, analysis, VM tests, an explicit
Chrome IndexedDB persistence test, Web release and Android debug builds. Native
Windows/iOS/macOS runtimes and production signing are not established by those
checks. No operational records are bundled; test fixtures are isolated test data.


The pinned-SDK preparation run
[41462554223](https://github.com/RamezBadry85/Target/actions/runs/41462554223)
passed analysis and all isolated regression groups: 4 foundation + 6 app widget +
15 repository/migration/recovery + 5 validation + 5 sync + 7 export + 4 customer
widget tests (46 total). The temporary write-enabled preparation workflow was
then removed. Permanent CI uses read-only permissions and a non-mutating format
check. The final delivery response reports the full-suite, Chrome and build run
for the delivered revision; preparation alone is not build verification.
