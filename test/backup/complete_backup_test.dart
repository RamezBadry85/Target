import 'dart:convert';
import 'dart:io';
import 'package:sembast/sembast_io.dart';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:target/core/backup/backup_document.dart';
import 'package:target/core/backup/backup_service.dart';
import 'package:target/features/customers/data/customer_database.dart';
import 'package:target/features/customers/data/local_customer_repository.dart';
import 'package:target/features/customers/domain/customer.dart';
import 'package:target/features/customers/domain/customer_validation.dart';
import '../customers/customer_repository_test.dart' show draft;

void main() {
  late LocalCustomerRepository source, destination;
  setUp(() async {
    source = LocalCustomerRepository(
      await openCustomerDatabase(newDatabaseFactoryMemory(), 'source'),
    );
    destination = LocalCustomerRepository(
      await openCustomerDatabase(newDatabaseFactoryMemory(), 'destination'),
    );
    final customer = await source.save(draft());
    await source.addActivity(
      customer.id,
      customer.revision,
      ActivityType.visit,
      'Visit note',
      DateTime.utc(2025),
    );
    await source.setArchived(customer.id, 2, true);
    await source.saveLocale('en');
  });
  tearDown(() async {
    await source.close();
    await destination.close();
  });
  test(
    'portable complete backup round-trips records, contacts, activity, archive, settings and original outbox IDs',
    () async {
      final document = await BackupService(source).create();
      final samplePath = Platform.environment['TARGET_REPORT_SAMPLES'];
      if (samplePath != null) {
        Directory(samplePath).createSync(recursive: true);
        File(
          '$samplePath/complete_backup.json',
        ).writeAsBytesSync(document.encode());
      }
      expect(document.counts['customers'], 1);
      expect(document.counts['contacts'], 1);
      expect(document.counts['customer_activities'], 1);
      expect(document.counts['customer_outbox'], 3);
      await BackupService(destination).restore(document.encode());
      expect(
        BackupDocument.fingerprint(await destination.completeSnapshot()),
        BackupDocument.fingerprint(await source.completeSnapshot()),
      );
      expect((await destination.all()).single.archived, isTrue);
      expect((await destination.readSettings())['locale'], 'en');
      expect(
        (await destination.activities(
          (await destination.all()).single.id,
        )).single.text,
        'Visit note',
      );
    },
  );
  test(
    'corruption and unsupported schema are rejected without changing destination',
    () async {
      await destination.save(draft(name: 'Existing', phone: '01099999999'));
      final before = BackupDocument.fingerprint(
        await destination.completeSnapshot(),
      );
      final doc = await BackupService(source).create();
      final root =
          jsonDecode(utf8.decode(doc.encode())) as Map<String, dynamic>;
      final body = root['body'] as Map<String, dynamic>;
      body['schemaVersion'] = 999;
      await expectLater(
        BackupService(
          destination,
        ).restore(Uint8List.fromList(utf8.encode(jsonEncode(root)))),
        throwsA(isA<FormatException>()),
      );
      root['checksum'] = {
        'algorithm': 'SHA-256',
        'value': BackupDocument.digest(body),
      };
      await expectLater(
        BackupService(
          destination,
        ).restore(Uint8List.fromList(utf8.encode(jsonEncode(root)))),
        throwsA(isA<FormatException>()),
      );
      expect(
        BackupDocument.fingerprint(await destination.completeSnapshot()),
        before,
      );
    },
  );
  test(
    'nonempty workspace cannot restore without confirmation and safety backup',
    () async {
      await destination.save(draft(name: 'Existing', phone: '01099999999'));
      final before = BackupDocument.fingerprint(
        await destination.completeSnapshot(),
      );
      final bytes = (await BackupService(source).create()).encode();
      await expectLater(
        BackupService(destination).restore(bytes),
        throwsFormatException,
      );
      await expectLater(
        BackupService(destination).restore(bytes, replaceConfirmed: true),
        throwsFormatException,
      );
      await expectLater(
        BackupService(destination).restore(
          bytes,
          replaceConfirmed: true,
          saveSafetyBackup: (bytes, name) async => false,
        ),
        throwsFormatException,
      );
      expect(
        BackupDocument.fingerprint(await destination.completeSnapshot()),
        before,
      );
    },
  );
  test(
    'explicit replacement saves recoverable safety backup before committing',
    () async {
      await destination.save(draft(name: 'Existing', phone: '01099999999'));
      final before = BackupDocument.fingerprint(
        await destination.completeSnapshot(),
      );
      Uint8List? safety;
      await BackupService(destination).restore(
        (await BackupService(source).create()).encode(),
        replaceConfirmed: true,
        saveSafetyBackup: (bytes, name) async {
          safety = bytes;
          expect(name, startsWith('Target_Safety_Backup_'));
          return true;
        },
      );
      expect(
        BackupDocument.fingerprint({
          'payload': BackupDocument.decode(safety!).payload,
          'settings': BackupDocument.decode(safety!).settings,
        }),
        before,
      );
      expect(
        BackupDocument.fingerprint(await destination.completeSnapshot()),
        BackupDocument.fingerprint(await source.completeSnapshot()),
      );
    },
  );
  test('concurrent change during safety saving prevents replacement', () async {
    final bytes = (await BackupService(source).create()).encode();
    await expectLater(
      BackupService(destination).restore(
        bytes,
        replaceConfirmed: true,
        saveSafetyBackup: (bytes, name) async {
          await destination.save(
            draft(name: 'Concurrent', phone: '01099999999'),
          );
          return true;
        },
      ),
      throwsFormatException,
    );
    expect((await destination.all()).single.data.name, 'Concurrent');
  });
  test(
    'interrupted transactional restore rolls back cleared records and settings',
    () async {
      await destination.save(draft(name: 'Existing', phone: '01099999999'));
      await destination.saveLocale('ar');
      final before = BackupDocument.fingerprint(
        await destination.completeSnapshot(),
      );
      await expectLater(
        destination.restoreComplete(
          await BackupService(source).create(),
          expectedCurrentFingerprint: before,
          afterClearForTest: () async {
            throw StateError('interrupted');
          },
        ),
        throwsStateError,
      );
      expect(
        BackupDocument.fingerprint(await destination.completeSnapshot()),
        before,
      );
    },
  );
  test(
    'checksum-valid but invalid business records fail staging without writes',
    () async {
      final document = BackupDocument.decode(
        (await BackupService(source).create()).encode(),
      );
      final payload = document.payload;
      final rows = payload['customers']! as List<Object?>;
      final first = rows.first! as Map<String, Object?>;
      final value = first['value']! as Map<String, Object?>;
      final data = value['data']! as Map<String, Object?>;
      data['name'] = '';
      await expectLater(
        BackupService(destination).restore(document.encode()),
        throwsA(isA<CustomerException>()),
      );
      expect(await destination.all(), isEmpty);
    },
  );
  test(
    'portable snapshot restores to a native file and survives closing/reopening',
    () async {
      final external = Platform.environment['TARGET_CROSS_PLATFORM_BACKUP'];
      final bytes = external == null
          ? (await BackupService(source).create()).encode()
          : await File(external).readAsBytes();
      final document = BackupDocument.decode(bytes);
      final directory = await Directory.systemTemp.createTemp(
        'target-portable-recovery-',
      );
      final path = '${directory.path}/customers.db';
      var native = LocalCustomerRepository(
        await openCustomerDatabase(databaseFactoryIo, path),
      );
      try {
        await BackupService(native).restore(bytes);
        await native.close();
        native = LocalCustomerRepository(
          await openCustomerDatabase(databaseFactoryIo, path),
        );
        expect(
          BackupDocument.fingerprint(await native.completeSnapshot()),
          BackupDocument.fingerprint({
            'payload': document.payload,
            'settings': document.settings,
          }),
        );
      } finally {
        await native.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
