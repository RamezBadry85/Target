# Target


## Sales Management System — Customer phase

An Arabic-first, responsive Flutter foundation for a single Sales Manager.
Customer management now includes offline local storage, profiles, activities,
archive/restore, backup recovery and XLSX/PDF generation. Other business modules,
inventory, authentication and cloud synchronization are **not implemented**.
No operational sample data is bundled. See [Customer architecture](docs/CUSTOMERS.md).

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
English. Language and navigation selection are session-only until persistence is
introduced. Localizations provide RTL/LTR automatically. Wide screens (1100 logical
pixels and above) use a sidebar; smaller screens use a scrollable navigation drawer.
All ten modules are accessible from either navigation mode.

### Structure

```text
lib/
  main.dart                    # Bootstrap and error hooks
  app/                         # Composition root, destinations, responsive shell
  core/
    errors/                    # Domain-safe failure classification
    logging/                   # Central technical logging
    l10n/                      # Arabic/English copy and delegate
    theme/                     # Navy/white theme, shared spacing, form/table styles
    presentation/              # Responsive policy and reusable empty state
  features/
    dashboard/ customers/ sales/ quotations/ opportunities/
    follow_ups/ sales_targets/ collections/ reports/ settings/
      domain/                  # Customer models/contracts; other modules reserved
      data/                    # Customer database/exports; other modules reserved
      presentation/            # Customer workspace; other modules placeholders
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

The customer phase adds Sembast/IndexedDB, path utilities, UUIDs, report generation
and file-save/picker adapters; see `pubspec.yaml` and `docs/CUSTOMERS.md` for purposes.
No paid backend has been selected. `pubspec.lock` is generated with
Flutter 3.38.5 and committed. CI enforces the locked dependency versions and hashes
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
dependencies, Dart formatting, analysis, VM and Chrome persistence tests, Web release and Android debug
builds on pushes/PRs and supports manual dispatch. Windows and Apple
builds still need their native hosts. No repository settings or secrets are changed.
