import 'dart:convert';
import 'dart:typed_data';
import '../../features/customers/data/local_customer_repository.dart';
import 'backup_document.dart';

class PreparedBackup {
  const PreparedBackup({required this.document, this.isLegacy = false});
  final BackupDocument document;
  final bool isLegacy;
}

class BackupService {
  BackupService(this.repository);
  final LocalCustomerRepository repository;

  static PreparedBackup inspect(Uint8List bytes) {
    if (bytes.length > 20 * 1024 * 1024) {
      throw const FormatException('Backup exceeds 20 MiB');
    }
    try {
      return PreparedBackup(document: BackupDocument.decode(bytes));
    } on FormatException catch (currentFormatError) {
      try {
        final payload = Map<String, Object?>.from(
          jsonDecode(utf8.decode(bytes)) as Map<Object?, Object?>,
        );
        const keys = {
          'format',
          'version',
          'generatedAt',
          ...BackupDocument.stores,
        };
        if (payload.keys.length != keys.length ||
            !payload.keys.toSet().containsAll(keys) ||
            payload['format'] != 'target-customers' ||
            payload['version'] != 2) {
          throw const FormatException('Unsupported legacy backup');
        }
        final createdAt = DateTime.parse(payload['generatedAt']! as String);
        final document = BackupDocument.create(
          {'payload': payload, 'settings': <String, Object?>{}},
          createdAt,
        );
        return PreparedBackup(
          document: BackupDocument.decode(document.encode()),
          isLegacy: true,
        );
      } on FormatException {
        throw currentFormatError;
      } catch (_) {
        throw currentFormatError;
      }
    }
  }

  Future<BackupDocument> create() async {
    final document = BackupDocument.create(
      await repository.completeSnapshot(),
      DateTime.now(),
    );
    if (document.encode().length > 20 * 1024 * 1024) {
      throw const FormatException('Backup exceeds 20 MiB');
    }
    return document;
  }

  Future<void> restore(
    Uint8List bytes, {
    bool replaceConfirmed = false,
    Future<bool> Function(Uint8List bytes, String filename)? saveSafetyBackup,
  }) async {
    final prepared = inspect(bytes);
    final current = await repository.completeSnapshot();
    final currentPayload = current['payload']! as Map<Object?, Object?>;
    final hasData = BackupDocument.stores.any(
      (name) => (currentPayload[name]! as List<Object?>).isNotEmpty,
    );
    if (!replaceConfirmed && hasData) {
      throw const FormatException('Restore requires an empty database');
    }
    final incoming = prepared.isLegacy
        ? BackupDocument.create(
            {
              'payload': prepared.document.payload,
              'settings': current['settings'],
            },
            prepared.document.createdAt,
          )
        : prepared.document;
    if (replaceConfirmed) {
      if (saveSafetyBackup == null) {
        throw const FormatException('Safety backup is required');
      }
      final safety = BackupDocument.create(current, DateTime.now());
      final safetyBytes = safety.encode();
      if (safetyBytes.length > 20 * 1024 * 1024) {
        throw const FormatException('Safety backup exceeds 20 MiB');
      }
      if (!await saveSafetyBackup(
        safetyBytes,
        BackupDocument.filename(safety.createdAt, safety: true),
      )) {
        throw const FormatException(
          'Safety backup cancelled; database unchanged',
        );
      }
    }
    await repository.restoreComplete(
      incoming,
      expectedCurrentFingerprint: BackupDocument.fingerprint(current),
    );
  }
}
