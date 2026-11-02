/// Domain-safe failure codes; presentation maps these to localized messages.
/// Infrastructure exceptions must not leak into domain or UI contracts.
enum FailureKind { validation, unavailable, storage, conflict, unexpected }

class AppFailure implements Exception {
  const AppFailure(this.kind);

  final FailureKind kind;
}
