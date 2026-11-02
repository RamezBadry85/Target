import 'dart:async';
import 'dart:math';
import 'customer_sync.dart';

/// Not started in production: no cloud provider is configured. Once approved,
/// call start() to retry automatically; transient offline errors remain durable.
class CustomerSyncService {
  CustomerSyncService(this.store, this.gateway, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final CustomerSyncStore store;
  final CustomerSyncGateway gateway;
  final DateTime Function() clock;
  Timer? _timer;
  bool _running = false;
  void start({required void Function(Object, StackTrace) onError}) {
    _timer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(() async {
        try {
          await flush();
        } catch (error, stack) {
          onError(error, stack);
        }
      }());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> flush() async {
    if (_running) return;
    _running = true;
    try {
      final blocked = <String>{};
      for (final change in await store.pendingChanges()) {
        if (blocked.contains(change.customerId)) continue;
        if (change.blocked ||
            (change.nextAttemptAt?.isAfter(clock().toUtc()) ?? false)) {
          blocked.add(change.customerId);
          continue;
        }
        try {
          final response = await gateway.push(
            change,
            expectedVersion: await store.remoteVersion(change.customerId),
          );
          switch (response) {
            case SyncAccepted():
              await store.acknowledge(change, response.version);
            case SyncConflict():
              await store.conflict(change, response);
              blocked.add(change.customerId);
          }
        } catch (_) {
          await store.retry(
            change,
            clock().toUtc().add(
              Duration(
                seconds: min(
                  3600,
                  5 * pow(2, min(change.attempts, 10)).toInt(),
                ),
              ),
            ),
          );
          blocked.add(change.customerId);
        }
      }
    } finally {
      _running = false;
    }
  }
}
