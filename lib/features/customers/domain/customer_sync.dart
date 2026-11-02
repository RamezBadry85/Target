/// Provider-neutral, optimistic-concurrency synchronization contracts.
/// An approved gateway MUST enforce idempotencyKey and expectedVersion atomically.
class CustomerChange {
  const CustomerChange({required this.id, required this.customerId, required this.revision,
    required this.payload, required this.createdAt, this.attempts = 0, this.nextAttemptAt,
    this.blocked = false});
  final String id, customerId;
  final int revision, attempts;
  final Map<String,Object?> payload;
  final DateTime createdAt;
  final DateTime? nextAttemptAt;
  final bool blocked;
}
sealed class SyncResponse { const SyncResponse(); }
class SyncAccepted extends SyncResponse {
  const SyncAccepted(this.version);
  final String version;
}
class SyncConflict extends SyncResponse {
  const SyncConflict(this.remoteSnapshot, this.version);
  final Map<String,Object?> remoteSnapshot;
  final String version;
}
abstract interface class CustomerSyncGateway {
  Future<SyncResponse> push(CustomerChange change, {String? expectedVersion});
  // Pull/cursor reconciliation must be added with the approved backend contract.
}
abstract interface class CustomerSyncStore {
  Future<List<CustomerChange>> pendingChanges();
  Future<String?> remoteVersion(String customerId);
  Future<void> acknowledge(CustomerChange change, String version);
  Future<void> retry(CustomerChange change, DateTime nextAttempt);
  Future<void> conflict(CustomerChange change, SyncConflict response);
}
