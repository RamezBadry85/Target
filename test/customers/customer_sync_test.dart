import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:target/features/customers/data/customer_database.dart';
import 'package:target/features/customers/data/local_customer_repository.dart';
import 'package:target/features/customers/domain/customer.dart';
import 'package:target/features/customers/domain/customer_sync.dart';
import 'package:target/features/customers/domain/customer_sync_service.dart';
import 'customer_repository_test.dart' show draft;

class Gateway implements CustomerSyncGateway {
  Gateway(this.handler);
  final Future<SyncResponse> Function(CustomerChange, String?) handler;
  @override
  Future<SyncResponse> push(CustomerChange change, {String? expectedVersion}) =>
      handler(change, expectedVersion);
}

void main() {
  late LocalCustomerRepository repo;
  late DateTime now;
  setUp(() async {
    now = DateTime.utc(2025);
    repo = LocalCustomerRepository(
      await openCustomerDatabase(newDatabaseFactoryMemory(), 'sync.db'),
      clock: () => now,
    );
  });
  tearDown(() async => repo.close());
  test(
    'offline edits survive failed transport and retry with persisted backoff',
    () async {
      await repo.save(draft());
      var calls = 0;
      final engine = CustomerSyncService(
        repo,
        Gateway((change, version) async {
          calls++;
          throw StateError('Offline');
        }),
        clock: () => now,
      );
      await engine.flush();
      expect(calls, 1);
      final entry = (await repo.pendingChanges()).single;
      expect(entry.attempts, 1);
      expect(entry.nextAttemptAt, now.add(const Duration(seconds: 5)));
      expect((await repo.all()).single.syncStatus, CustomerSyncStatus.error);
      await engine.flush();
      expect(calls, 1);
      expect((await repo.all()).single.data.name, 'مؤسسة الاختبار');
      now = now.add(const Duration(seconds: 6));
      await engine.flush();
      expect(calls, 2);
    },
  );
  test(
    'acknowledgement drains ordered events and advances server version',
    () async {
      final c = await repo.save(draft());
      await repo.save(draft(name: 'تعديل'), id: c.id, expectedRevision: 1);
      final versions = <String?>[];
      final ids = <String>[];
      final engine = CustomerSyncService(
        repo,
        Gateway((change, version) async {
          versions.add(version);
          ids.add(change.id);
          return SyncAccepted('v${ids.length}');
        }),
      );
      await engine.flush();
      expect(versions, [null, 'v1']);
      expect(ids.toSet(), hasLength(2));
      expect(await repo.pendingChanges(), isEmpty);
      expect(
        (await repo.all()).single.syncStatus,
        CustomerSyncStatus.synchronized,
      );
    },
  );
  test(
    'edit during upload is never marked synchronized by an older acknowledgement',
    () async {
      final c = await repo.save(draft());
      final engine = CustomerSyncService(
        repo,
        Gateway((change, version) async {
          await repo.save(
            draft(name: 'تعديل أثناء الرفع'),
            id: c.id,
            expectedRevision: 1,
          );
          return const SyncAccepted('v1');
        }),
      );
      await engine.flush();
      expect(await repo.pendingChanges(), hasLength(1));
      final current = (await repo.all()).single;
      expect(current.revision, 2);
      expect(current.syncStatus, CustomerSyncStatus.pending);
      expect(current.data.name, 'تعديل أثناء الرفع');
    },
  );
  test(
    'conflict blocks later events and retains both versions without overwrite',
    () async {
      final c = await repo.save(draft());
      await repo.save(draft(name: 'نسخة محلية'), id: c.id, expectedRevision: 1);
      var calls = 0;
      final engine = CustomerSyncService(
        repo,
        Gateway((change, version) async {
          calls++;
          return const SyncConflict({'name': 'remote version'}, 'server-v2');
        }),
      );
      await engine.flush();
      await engine.flush();
      expect(calls, 1);
      expect(await repo.pendingChanges(), hasLength(2));
      expect((await repo.pendingChanges()).first.blocked, isTrue);
      expect((await repo.all()).single.data.name, 'نسخة محلية');
      expect((await repo.all()).single.syncStatus, CustomerSyncStatus.conflict);
      expect(
        await conflictStore.record(c.id).get(repo.db),
        containsPair('remoteVersion', 'server-v2'),
      );
    },
  );
  test('backup recovery preserves and blocks unresolved conflicts', () async {
    await repo.save(draft());
    final engine = CustomerSyncService(
      repo,
      Gateway(
        (change, version) async => const SyncConflict({'name': 'remote'}, 'v2'),
      ),
    );
    await engine.flush();
    final other = LocalCustomerRepository(
      await openCustomerDatabase(
        newDatabaseFactoryMemory(),
        'conflict-restore.db',
      ),
    );
    try {
      await other.restore(await repo.backup());
      expect(
        (await other.all()).single.syncStatus,
        CustomerSyncStatus.conflict,
      );
      expect((await other.pendingChanges()).single.blocked, isTrue);
    } finally {
      await other.close();
    }
  });
}
