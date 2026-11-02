import 'dart:convert';
import 'dart:typed_data';
import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';
import '../domain/customer_sync.dart';
import '../domain/customer_validation.dart';
import 'customer_codec.dart';
import 'customer_database.dart';

class LocalCustomerRepository implements CustomerRepository, CustomerSyncStore {
  LocalCustomerRepository(this.db, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final Database db;
  final DateTime Function() clock;
  final _uuid = const Uuid();
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on CustomerException {
      rethrow;
    } catch (_) {
      throw const CustomerException(CustomerProblem.storage);
    }
  }

  @override
  Stream<List<Customer>> watchAll() => customerStore
      .query()
      .onSnapshots(db)
      .map((rows) => rows.map((r) => CustomerCodec.read(r.value)).toList());
  @override
  Future<List<Customer>> all() => _guard(
    () async => (await customerStore.find(
      db,
    )).map((r) => CustomerCodec.read(r.value)).toList(),
  );
  Future<Customer> _existing(
    DatabaseClient txn,
    String id,
    int revision,
  ) async {
    final raw = await customerStore.record(id).get(txn);
    if (raw == null) throw const CustomerException(CustomerProblem.missing);
    final c = CustomerCodec.read(raw);
    if (c.revision != revision) {
      throw const CustomerException(CustomerProblem.staleEdit);
    }
    return c;
  }

  Future<void> _record(DatabaseClient txn, Customer c) async {
    await customerStore.record(c.id).put(txn, CustomerCodec.customer(c));
    final activities = await activityStore.find(
      txn,
      finder: Finder(filter: Filter.equals('customerId', c.id)),
    );
    final id = _uuid.v4();
    await outboxStore.record(id).put(txn, {
      'id': id,
      'customerId': c.id,
      'revision': c.revision,
      'createdAt': c.updatedAt.toIso8601String(),
      'attempts': 0,
      'blocked': false,
      'payload': {
        'customer': CustomerCodec.customer(c),
        'activities': activities.map((a) => a.value).toList(),
      },
    });
  }

  @override
  Future<Customer> save(
    CustomerDraft draft, {
    String? id,
    int? expectedRevision,
  }) => _guard(() async {
    CustomerValidation.validate(draft);
    return db.transaction((txn) async {
      Customer? old;
      if (id != null) {
        if (expectedRevision == null) {
          throw const CustomerException(CustomerProblem.staleEdit);
        }
        old = await _existing(txn, id, expectedRevision);
      }
      for (final row in await customerStore.find(txn)) {
        if (row.key != id &&
            CustomerValidation.duplicate(
              draft,
              CustomerCodec.read(row.value).data,
            )) {
          throw CustomerException(
            CustomerProblem.duplicate,
            relatedId: row.key,
          );
        }
      }
      final now = clock().toUtc();
      final c = Customer(
        id: id ?? _uuid.v4(),
        data: CustomerCodec.readDraft(CustomerCodec.draft(draft)),
        createdAt: old?.createdAt ?? now,
        updatedAt: now,
        archivedAt: old?.archivedAt,
        revision: (old?.revision ?? 0) + 1,
        remoteVersion: old?.remoteVersion,
        syncStatus: old?.syncStatus == CustomerSyncStatus.conflict
            ? CustomerSyncStatus.conflict
            : CustomerSyncStatus.pending,
      );
      await _record(txn, c);
      return c;
    });
  });
  @override
  Future<Customer> setArchived(
    String id,
    int expectedRevision,
    bool archived,
  ) => _guard(
    () => db.transaction((txn) async {
      final old = await _existing(txn, id, expectedRevision);
      final now = clock().toUtc();
      final c = Customer(
        id: id,
        data: old.data,
        createdAt: old.createdAt,
        updatedAt: now,
        archivedAt: archived ? now : null,
        revision: old.revision + 1,
        remoteVersion: old.remoteVersion,
        syncStatus: old.syncStatus == CustomerSyncStatus.conflict
            ? CustomerSyncStatus.conflict
            : CustomerSyncStatus.pending,
      );
      await _record(txn, c);
      return c;
    }),
  );
  @override
  Future<void> addActivity(
    String customerId,
    int expectedRevision,
    ActivityType type,
    String text,
    DateTime occurredAt, {
    String? sourceReference,
  }) => _guard(() async {
    if (text.trim().isEmpty ||
        text.length > 10000 ||
        occurredAt.isAfter(clock().add(const Duration(minutes: 5)))) {
      throw const CustomerException(
        CustomerProblem.validation,
        fields: ['activity'],
      );
    }
    await db.transaction((txn) async {
      final old = await _existing(txn, customerId, expectedRevision);
      final now = clock().toUtc();
      final a = CustomerActivity(
        id: _uuid.v4(),
        customerId: customerId,
        type: type,
        text: text.trim(),
        occurredAt: occurredAt.toUtc(),
        createdAt: now,
        sourceReference: sourceReference,
      );
      await activityStore.record(a.id).put(txn, CustomerCodec.activity(a));
      await _record(
        txn,
        Customer(
          id: old.id,
          data: old.data,
          createdAt: old.createdAt,
          updatedAt: now,
          archivedAt: old.archivedAt,
          revision: old.revision + 1,
          remoteVersion: old.remoteVersion,
          syncStatus: old.syncStatus == CustomerSyncStatus.conflict
              ? CustomerSyncStatus.conflict
              : CustomerSyncStatus.pending,
        ),
      );
    });
  });
  @override
  Future<List<CustomerActivity>> activities(String customerId) =>
      _guard(() async {
        final rows = await activityStore.find(
          db,
          finder: Finder(
            filter: Filter.equals('customerId', customerId),
            sortOrders: [SortOrder('occurredAt', false), SortOrder('id')],
          ),
        );
        return rows.map((r) => CustomerCodec.readActivity(r.value)).toList();
      });
  @override
  Future<List<CustomerChange>> pendingChanges() => _guard(() async {
    final rows = await outboxStore.find(
      db,
      finder: Finder(
        sortOrders: [
          SortOrder('customerId'),
          SortOrder('revision'),
          SortOrder('id'),
        ],
      ),
    );
    return rows.map((r) {
      final m = r.value;
      return CustomerChange(
        id: r.key,
        customerId: m['customerId'] as String,
        revision: m['revision'] as int,
        payload: Map<String, Object?>.from(
          m['payload'] as Map<Object?, Object?>,
        ),
        createdAt: DateTime.parse(m['createdAt'] as String),
        attempts: m['attempts'] as int,
        nextAttemptAt: m['nextAttemptAt'] == null
            ? null
            : DateTime.parse(m['nextAttemptAt'] as String),
        blocked: m['blocked'] as bool,
      );
    }).toList();
  });
  @override
  Future<String?> remoteVersion(String customerId) async =>
      (await customerStore.record(customerId).get(db))?['remoteVersion']
          as String?;
  @override
  Future<void> acknowledge(CustomerChange change, String version) => _guard(
    () => db.transaction((txn) async {
      if (!await outboxStore.record(change.id).exists(txn)) return;
      await outboxStore.record(change.id).delete(txn);
      final stored = await customerStore.record(change.customerId).get(txn);
      final value = stored == null ? null : Map<String, Object?>.from(stored);
      if (value != null) {
        value['remoteVersion'] = version;
        final remaining = await outboxStore.find(
          txn,
          finder: Finder(
            filter: Filter.equals('customerId', change.customerId),
          ),
        );
        if (remaining.isEmpty && value['syncStatus'] != 'conflict') {
          value['syncStatus'] = 'synchronized';
        }
        await customerStore.record(change.customerId).put(txn, value);
      }
    }),
  );
  @override
  Future<void> retry(CustomerChange change, DateTime nextAttempt) => _guard(
    () => db.transaction((txn) async {
      await outboxStore.record(change.id).update(txn, {
        'attempts': change.attempts + 1,
        'nextAttemptAt': nextAttempt.toIso8601String(),
      });
      await customerStore.record(change.customerId).update(txn, {
        'syncStatus': 'error',
      });
    }),
  );
  @override
  Future<void> conflict(CustomerChange change, SyncConflict response) => _guard(
    () => db.transaction((txn) async {
      await outboxStore.record(change.id).update(txn, {'blocked': true});
      await conflictStore.record(change.customerId).put(txn, {
        'changeId': change.id,
        'remoteSnapshot': response.remoteSnapshot,
        'remoteVersion': response.version,
        'detectedAt': clock().toUtc().toIso8601String(),
      });
      await customerStore.record(change.customerId).update(txn, {
        'syncStatus': 'conflict',
      });
    }),
  );
  @override
  Future<Uint8List> backup() => _guard(
    () => db.transaction((txn) async {
      final contents = <String, Object?>{
        'format': 'target-customers',
        'version': 2,
        'generatedAt': clock().toUtc().toIso8601String(),
      };
      for (final store in [
        customerStore,
        activityStore,
        outboxStore,
        conflictStore,
      ]) {
        contents[store.name] = (await store.find(
          txn,
        )).map((r) => {'key': r.key, 'value': r.value}).toList();
      }
      return Uint8List.fromList(utf8.encode(jsonEncode(contents)));
    }),
  );
  @override
  Future<void> restore(Uint8List bytes) => _guard(() async {
    if (bytes.length > 20 * 1024 * 1024) {
      throw const CustomerException(CustomerProblem.invalidBackup);
    }
    try {
      final root = Map<String, Object?>.from(
        jsonDecode(utf8.decode(bytes)) as Map<Object?, Object?>,
      );
      if (root['format'] != 'target-customers' || root['version'] != 2) {
        throw const FormatException();
      }
      final stores = [customerStore, activityStore, outboxStore, conflictStore];
      final records = <String, List<Map<String, Object?>>>{};
      for (final store in stores) {
        records[store.name] = (root[store.name] as List<Object?>)
            .map((r) => Map<String, Object?>.from(r as Map<Object?, Object?>))
            .toList();
      }
      final customerIds = <String>{};
      final contactIds = <String>{};
      final restoredCustomers = <String, Customer>{};
      for (final row in records[customerStore.name]!) {
        final c = CustomerCodec.read(
          Map<String, Object?>.from(row['value'] as Map<Object?, Object?>),
        );
        CustomerValidation.validate(c.data);
        if (c.id != row['key'] ||
            !customerIds.add(c.id) ||
            c.revision < 1 ||
            c.updatedAt.isBefore(c.createdAt)) {
          throw const FormatException();
        }
        if (restoredCustomers.values.any(
          (other) => CustomerValidation.duplicate(c.data, other.data),
        )) {
          throw const FormatException();
        }
        restoredCustomers[c.id] = c;
        for (final contact in c.data.contacts) {
          if (!contactIds.add(contact.id)) throw const FormatException();
        }
      }
      final activityIds = <String>{};
      for (final row in records[activityStore.name]!) {
        final a = CustomerCodec.readActivity(
          Map<String, Object?>.from(row['value'] as Map<Object?, Object?>),
        );
        if (a.id != row['key'] ||
            !customerIds.contains(a.customerId) ||
            !activityIds.add(a.id) ||
            a.text.trim().isEmpty) {
          throw const FormatException();
        }
      }
      final operationIds = <String>{};
      for (final row in records[outboxStore.name]!) {
        final m = Map<String, Object?>.from(
          row['value'] as Map<Object?, Object?>,
        );
        final id = m['id'] as String;
        final customerId = m['customerId'] as String;
        final revision = m['revision'] as int;
        final payload = Map<String, Object?>.from(
          m['payload'] as Map<Object?, Object?>,
        );
        final snapshot = CustomerCodec.read(
          Map<String, Object?>.from(
            payload['customer'] as Map<Object?, Object?>,
          ),
        );
        if (id != row['key'] ||
            !operationIds.add(id) ||
            !customerIds.contains(customerId) ||
            revision < 1 ||
            revision > restoredCustomers[customerId]!.revision ||
            snapshot.id != customerId ||
            snapshot.revision != revision ||
            (m['attempts'] as int) < 0 ||
            m['blocked'] is! bool) {
          throw const FormatException();
        }
        CustomerValidation.validate(snapshot.data);
        DateTime.parse(m['createdAt'] as String);
        if (m['nextAttemptAt'] != null) {
          DateTime.parse(m['nextAttemptAt'] as String);
        }
        for (final raw in payload['activities'] as List<Object?>) {
          final activity = CustomerCodec.readActivity(
            Map<String, Object?>.from(raw as Map<Object?, Object?>),
          );
          if (activity.customerId != customerId ||
              !activityIds.contains(activity.id)) {
            throw const FormatException();
          }
        }
      }
      final conflicted = <String>{};
      for (final row in records[conflictStore.name]!) {
        final id = row['key'] as String;
        final m = Map<String, Object?>.from(
          row['value'] as Map<Object?, Object?>,
        );
        if (!customerIds.contains(id) ||
            !conflicted.add(id) ||
            !operationIds.contains(m['changeId']) ||
            m['remoteSnapshot'] is! Map<Object?, Object?> ||
            (m['remoteVersion'] as String).isEmpty) {
          throw const FormatException();
        }
        DateTime.parse(m['detectedAt'] as String);
      }
      // Requeue current complete aggregates instead of trusting imported sync
      // acknowledgements. Preserve conflicts and block them after recovery.
      await db.transaction((txn) async {
        for (final store in stores) {
          if (await store.count(txn) > 0) {
            throw const CustomerException(CustomerProblem.invalidBackup);
          }
        }
        for (final row in records[activityStore.name]!) {
          await activityStore
              .record(row['key'] as String)
              .put(
                txn,
                Map<String, Object?>.from(
                  row['value'] as Map<Object?, Object?>,
                ),
              );
        }
        for (final row in records[customerStore.name]!) {
          final old = CustomerCodec.read(
            Map<String, Object?>.from(row['value'] as Map<Object?, Object?>),
          );
          await _record(
            txn,
            Customer(
              id: old.id,
              data: old.data,
              createdAt: old.createdAt,
              updatedAt: clock().toUtc(),
              archivedAt: old.archivedAt,
              revision: old.revision + 1,
              remoteVersion: old.remoteVersion,
              syncStatus: conflicted.contains(old.id)
                  ? CustomerSyncStatus.conflict
                  : CustomerSyncStatus.pending,
            ),
          );
          if (conflicted.contains(old.id)) {
            for (final entry in await outboxStore.find(
              txn,
              finder: Finder(filter: Filter.equals('customerId', old.id)),
            )) {
              await outboxStore.record(entry.key).update(txn, {
                'blocked': true,
              });
            }
          }
        }
        // Preserve snapshots, and point conflict metadata at the recovered
        // blocked operation so a second backup/recovery remains self-consistent.
        for (final row in records[conflictStore.name]!) {
          final id = row['key'] as String;
          final value = Map<String, Object?>.from(
            row['value'] as Map<Object?, Object?>,
          );
          final recovered = await outboxStore.find(
            txn,
            finder: Finder(filter: Filter.equals('customerId', id)),
          );
          value['originalChangeId'] =
              value['originalChangeId'] ?? value['changeId'];
          value['changeId'] = recovered.single.key;
          await conflictStore.record(id).put(txn, value);
        }
      });
    } on CustomerException {
      rethrow;
    } catch (_) {
      throw const CustomerException(CustomerProblem.invalidBackup);
    }
  });
  @override
  Future<void> close() => db.close();
}
