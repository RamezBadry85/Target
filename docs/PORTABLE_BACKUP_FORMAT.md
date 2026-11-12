# Target portable backup format

Format version 1 is a UTF-8 JSON document. It is independent of the Sembast file format and can be restored on another supported platform when its customer schema is supported. Do not copy a local database file between platforms.

## Envelope

The root object contains exactly the backup body and a checksum descriptor:

```json
{
  "body": { "...": "..." },
  "checksum": { "algorithm": "SHA-256", "value": "lowercase hexadecimal digest" }
}
```

The SHA-256 digest covers the UTF-8 encoding of the body serialized as canonical JSON: keys of every JSON object are sorted lexicographically before encoding; array order and JSON values are preserved. The checksum does not encrypt or authenticate who created the backup. Anyone who can edit a file can recompute its checksum. Store exported files securely.

## Body

- `format`: `target-complete-backup`
- `formatVersion`: `1`
- `appVersion`: Target app version (`0.1.0+1` for this release)
- `schemaVersion`: customer database schema `2`
- `createdAt`: UTC ISO-8601 timestamp
- `counts`: counts for `customers`, `customer_activities`, `customer_outbox`, `customer_conflicts`, and embedded customer `contacts`
- `settings`: currently the `locale` preference (`ar` or `en`) only
- `payload`: the existing version-2 portable customer-store snapshot (`format: target-customers`, `version: 2`, `generatedAt`, then arrays of `{key, value}` records for each of the four stores)

Contacts are embedded in customer records. Activity records reference their owner customer. Outbox operations, retry metadata, synchronization status, conflict snapshots, archive fields and record/contact IDs are retained. Temporary files, database paths, credentials and cloud secrets are not included. No sales, collections or quotation transaction tables are included: those business-record modules do not yet have operational data models.

## Restore contract and safety

The current reader accepts format version 1 and schema version 2 and limits input to 20 MiB. New backups are checksum-verified, including manifest counts, format/schema, setting values, and all existing v2 record invariants using an isolated staging database before touching the live database. For backward compatibility it also accepts the previous raw `target-customers` v2 JSON backup. That legacy format has no checksum and contains no settings: the restore screen warns about the missing checksum, the records are still staged and validated, and the current language setting is retained. Newly created backups always use the checksummed complete format. Unsupported versions and malformed records fail closed.

Restore into an empty workspace is the default. Replacing a nonempty workspace requires an explicit user choice and a successful save of a separate safety backup first. Immediately before replacing, the current stores and settings are fingerprinted and compared again to avoid overwriting data changed during the save dialog. The validated replacement is written in one database transaction; transaction failure rolls back. The incoming portable IDs and records are stored as validated. A language preference is applied on next application startup.

The backup and safety backup are plain JSON, not encrypted. The application does not keep backup history or automatically delete either the exported file or existing data. Keep the safety backup somewhere independent of the device being restored.

Filename pattern: `Target_Backup_<UTC timestamp>.json`; replacement safety copy: `Target_Safety_Backup_<UTC timestamp>.json`.
