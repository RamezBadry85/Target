# Target


## Sales Management System — Customer phase

An Arabic-first, responsive Flutter application foundation for a single Sales Manager.
Customer management includes offline local storage, profiles, activities, archive/restore,
portable complete backup, and customer/activity XLSX/PDF reports. Other business modules,
inventory, authentication and cloud synchronization are **not implemented**.
No operational sample data is bundled. See [Customer architecture](docs/CUSTOMERS.md),
[Reporting and backup operations](docs/REPORTING_AND_BACKUP.md), and the
[portable backup format](docs/PORTABLE_BACKUP_FORMAT.md).

### Getting started

Use **Flutter 3.38.5** (the platform template and CI baseline), Dart 3.10+, and the
host toolchain for your target platform:

```sh
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Arabic is the default language. Use the language action or Settings to switch to
English; the selected language is stored with local workspace settings and included
in portable backups. Localizations provide RTL/LTR automatically. Wide screens
(1100 logical pixels and above) use a sidebar; smaller screens use a scrollable
drawer. Reports and Backup are connected to customer data; reserved business
modules remain clearly separate from implemented transaction records.

### Structure

```text
lib/
  main.dart                    # Bootstrap and error hooks
  app/                         # Composition root, destinations, responsive shell
  core/
    backup/                    # Portable integrity-checked backup/recovery and UI
    errors/                    # Domain-safe failure classification
    files/                     # Native save/open integration
    logging/                   # Central technical logging
    l10n/                      # Arabic/English copy and delegate
    theme/                     # Navy/white theme, shared spacing, form/table styles
    presentation/              # Responsive policy and reusable empty state
  features/
    dashboard/ customers/ sales/ quotations/ opportunities/
    follow_ups/ sales_targets/ collections/ reports/ settings/
      domain/                  # Customer models/contracts; report query/records
      data/                    # Database/exports and report generation
      presentation/            # Workspaces, report dashboard and placeholders
android/ ios/ windows/ web/ macos/  # Unverified native/web host scaffolds
test/                         # Unit and widget tests
tool/                         # Structural checks, reproducible icon generation
docs/                         # Architecture, verification and handoff
```

See [architecture](docs/ARCHITECTURE.md), [verification](docs/VERIFICATION.md), and
[Phase 1 handoff](docs/PHASE_1_REPORT.md). The original repository README heading
has been retained.

### Dependencies

- `flutter`: framework, Material widgets, navigation and session UI state.
- `flutter_localizations`: SDK delegates for Arabic/English widgets and direction.
- `flutter_test`: SDK test tooling (development only).
- `flutter_lints`: Dart/Flutter lint baseline (development only).

The customer phase uses Sembast/IndexedDB, path utilities, UUIDs, XLSX/PDF generation,
SHA-256 (`crypto`), ZIP/XML support, and native file-save/picker adapters; see
`pubspec.yaml`, [customer architecture](docs/CUSTOMERS.md), and the reporting/backup
guides for details. No paid backend has been selected. `pubspec.lock` is generated
with Flutter 3.38.5 and committed. CI enforces locked dependency versions and hashes
using `flutter pub get --enforce-lockfile`. See [CI verification](docs/CI.md).

### Platforms and CI

Host scaffolds are present for Android (Kotlin), iOS (Swift), Windows (C++/CMake),
Web, and macOS (Swift). **Scaffold presence is not build readiness.** See the actual
verification results before treating any platform as ready. Application identifiers
are provisional `com.target.sales`; confirm ownership before release. Android's
standard template release configuration uses a debug signing key and must not be
used for production distribution. Apple signing teams and Windows distribution
signing are deliberately not configured; do not commit signing credentials.

The GitHub Actions workflow checks SDK versions, structural validity, locked
dependencies, Dart formatting, strict analysis, VM/Chrome persistence and report/backup
tests, Web and Android builds, Android document-writer JVM tests, and Windows Release
plus native IO tests on pushes/PRs and manual dispatch. CI independently opens generated
XLSX fixtures, parses and rasterizes generated A4 PDFs, and exercises portable backup
recovery on Windows using a Linux-generated fixture. These checks do not replace
interactive device/desktop acceptance or production signing. No repository settings
or secrets are changed.
