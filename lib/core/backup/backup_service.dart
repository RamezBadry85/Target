import 'dart:typed_data';
import '../../features/customers/data/local_customer_repository.dart';
import 'backup_document.dart';

class BackupService {
  BackupService(this.repository);
  final LocalCustomerRepository repository;
  Future<BackupDocument> create() async {
    final document = BackupDocument.create(await repository.completeSnapshot(), DateTime.now());
    if (document.encode().length > 20 * 1024 * 1024) throw const FormatException('Backup exceeds 20 MiB');
    return document;
  }
  Future<void> restore(Uint8List bytes, {
    bool replaceConfirmed = false,
    Future<bool> Function(Uint8List bytes, String filename)? saveSafetyBackup,
  }) async {
    final incoming = BackupDocument.decode(bytes);
    if (!replaceConfirmed) {
      await repository.restoreComplete(incoming);
      return;
    }
    if (saveSafetyBackup == null) throw const FormatException('Safety backup is required');
    final current = await repository.completeSnapshot();
    final safety = BackupDocument.create(current, DateTime.now());
    if (!await saveSafetyBackup(safety.encode(), BackupDocument.filename(safety.createdAt, safety: true))) {
      throw const FormatException('Safety backup cancelled; database unchanged');
    }
    await repository.restoreComplete(incoming, expectedCurrentFingerprint: BackupDocument.fingerprint(current));
  }
}
