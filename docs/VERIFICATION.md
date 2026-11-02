# Verification record

## Sandbox results — 2026-11-02

Host: Linux. No Flutter or Dart executable is installed. Android SDK, Java,
Windows toolchain and Apple/Xcode toolchains are unavailable. Outbound network
access is restricted; no SDK installation/build success is claimed.

| Check | Actual result |
| --- | --- |
| Existing repository inspection | Original `README.md` only; clean working tree, initial commit `7e46e78` |
| `python tool/verify_scaffold.py` | PASS: 248 structural checks; XML, JSON and plist parsing passed |
| `flutter analyze` | Blocked: command not found (exit 127) |
| `flutter test` | Blocked: command not found (exit 127); tests added but not executed locally |
| `flutter build apk --debug` | Blocked: command not found (exit 127); no Android SDK/Java |
| `flutter build web` | Blocked: command not found (exit 127) |
| `flutter build windows` | Blocked: command not found (exit 127); requires Windows host |
| `flutter run -d web-server --web-hostname 0.0.0.0` | Blocked: command not found (exit 127); startup not verified |
| iOS/macOS builds | Not run; require macOS/Xcode and Flutter |
| Responsive/RTL/LTR runtime checks | Widget tests authored, not run locally; no visual/device verification |

Structural checks validate scaffolding and relative Dart import paths, not
Flutter types, plugin registration, native compilation or runtime layout.
Python Pillow was used in an isolated tooling environment for deterministic
icons; it is not an application dependency. No generated SDK cache is tracked.

The workflow in `.github/workflows/flutter.yml` is a separate verification path;
its actual run status must be checked on GitHub. Workflow existence is not evidence
that its checks passed. See delivery chat for any subsequently observed CI result.

## Required verification on a Flutter-enabled host

Use Flutter 3.38.5 to match the platform template baseline:

```sh
flutter --version
flutter doctor -v
flutter pub get
# Commit pubspec.lock after resolution; do not hand-author dependency hashes.
dart format lib test
flutter analyze
flutter test
flutter build web --release
flutter build apk --debug
flutter run -d chrome
```

On Windows with Visual Studio C++ desktop tooling:

```sh
flutter config --enable-windows-desktop
flutter build windows --release
flutter run -d windows
```

On macOS with Xcode and any Flutter-requested native dependencies installed:

```sh
flutter build ios --no-codesign
flutter build macos --release
flutter run -d macos
```

Flutter generates host-specific ephemeral files, plugin registrants, SDK paths,
Gradle wrapper and Web bootstrap output as needed; they are not fabricated here.
If the pinned SDK requests additional host setup, follow `flutter doctor -v`.
Do not overwrite application code by regenerating the entire project blindly.

## Manual acceptance checklist (pending)

- Cold launch in Arabic; text and sidebar/drawer flow RTL.
- Switch English/Arabic in Settings and language action; current module remains.
- Visit all ten destinations with drawer and sidebar; confirm honest empty states.
- Check 360px phone, 800px tablet and 1440px desktop widths, plus compact landscape.
- Check large text, keyboard focus/tab order, screen reader labels and scrolling.
- Confirm Arabic rendering, mixed-script text and localized control tooltips on
  Android, iOS, Windows, Web and macOS devices before platform acceptance.
- Verify no overflow and no console/runtime errors; check screen resize transitions.
- Confirm that no customer/financial data appears in logs.

## Platform template provenance

Native and Web hosts were rendered from official Flutter 3.38.5 templates at
`f6ff1529fd6d8af5f706051d9251ac9231c83407` (see exact upstream hash in
`PHASE_1_REPORT.md`). Optional plugin hooks and Swift Package Manager sections
were omitted as in a plain app. Binary template placeholders were replaced with
locally generated Target monograms and valid launch assets. The upstream BSD
license is preserved in `FLUTTER_TEMPLATE_LICENSE`. Display names, locale metadata
and web colors were adjusted; signing and distribution remain unconfigured.
