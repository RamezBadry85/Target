import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';

const customerSchemaVersion = 2;
final customerStore = stringMapStoreFactory.store('customers');
final activityStore = stringMapStoreFactory.store('customer_activities');
final outboxStore = stringMapStoreFactory.store('customer_outbox');
final conflictStore = stringMapStoreFactory.store('customer_conflicts');

Future<Database> openCustomerDatabase(
  DatabaseFactory factory,
  String path,
) => factory.openDatabase(
  path,
  version: customerSchemaVersion,
  onVersionChanged: (db, oldVersion, newVersion) async {
    if (oldVersion > newVersion) {
      throw StateError(
        'Newer customer database schema; upgrade Target instead of resetting data.',
      );
    }
    if (oldVersion == 1) {
      // v1 persisted customer profiles; v2 adds durable sync metadata/outbox.
      // Sembast's version-change callback is itself atomic with the version bump.
      for (final record in await customerStore.find(db)) {
        final value = Map<String, Object?>.from(record.value);
        value['revision'] = value['revision'] ?? 1;
        value['syncStatus'] = 'pending';
        value['remoteVersion'] = null;
        await customerStore.record(record.key).put(db, value);
        final id = const Uuid().v4();
        await outboxStore.record(id).put(db, {
          'id': id,
          'customerId': record.key,
          'revision': value['revision'],
          'createdAt': value['updatedAt'],
          'attempts': 0,
          'blocked': false,
          'payload': {'customer': value, 'activities': <Object?>[]},
        });
      }
    }
  },
);
