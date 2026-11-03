# Target's audited file_saver 0.3.0 patch

Origin: https://github.com/incrediblezayed/file_saver, tag v0.3.0,
commit 98a99a82bf341098b99a0adc2f154256519dc948. Original MIT LICENSE retained.
Runtime sources and platform build files are vendored; examples/images/upstream
CI are not. This is not a claim that the upstream git tag equals the pub archive
byte-for-byte. The application now resolves **these checked-in sources**, not an
unverified global pub-cache edit. No new runtime package is introduced.

Why vendor rather than upgrade blindly: retain the 0.3.0 API/dependency graph,
make a small reviewable cross-platform fix, and build the exact patched sources.
Revisit an upstream replacement only after testing its platform implementations.

Changes:
- Android SAF writes on IO dispatcher, closes/flushes stream, propagates errors;
  returns destination URI rather than nullable filesystem lookup. Rejects a second
  simultaneous dialog, and completes channel errors from launch failures.
- macOS cancellation completes with null; write/missing-destination failures use
  FlutterError rather than a non-null error string.
- Windows removes invalid bæegin() call, uses an embedded-NUL filter correctly,
  Unicode Win32 dialog APIs/UTF-8 filenames, distinguishes cancellation/dialog
  failure, and checks write/close errors using a portable tested IO helper.
- Android/iOS/macOS normalize dotted extensions (prevent double dots).
- Web uses display:none and releases blob URLs after browser handoff.

Regression coverage: app save-outcome tests; native Android DocumentWriter JVM
unit tests; portable Windows IO/filter C++ tests; native source contract checks.
Native unit/build checks are not device dialog acceptance. No cloud APIs added.
