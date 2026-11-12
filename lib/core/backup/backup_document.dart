import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Portable JSON only; no database files, paths, caches or credentials.
class BackupDocument {
  BackupDocument._(this.body);
  static const appVersion = '0.1.0+1';
  final Map<String, Object?> body;
  Map<String, Object?> get payload =>
      Map<String, Object?>.from(body['payload']! as Map<Object?, Object?>);
  Map<String, Object?> get settings =>
      Map<String, Object?>.from(body['settings']! as Map<Object?, Object?>);
  DateTime get createdAt =>
      DateTime.parse(body['createdAt']! as String).toUtc();
  Map<String, Object?> get counts =>
      Map<String, Object?>.from(body['counts']! as Map<Object?, Object?>);
  static const stores = [
    'customers',
    'customer_activities',
    'customer_outbox',
    'customer_conflicts',
  ];

  static Object? canonical(Object? value) {
    if (value is Map<Object?, Object?>) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: canonical(value[key])};
    }
    if (value is List<Object?>) return value.map(canonical).toList();
    return value;
  }

  static String digest(Object? value) =>
      sha256.convert(utf8.encode(jsonEncode(canonical(value)))).toString();
  static String fingerprint(Map<String, Object?> snapshot) {
    final payload = Map<String, Object?>.from(
      snapshot['payload']! as Map<Object?, Object?>,
    )..remove('generatedAt');
    return digest({'payload': payload, 'settings': snapshot['settings']});
  }

  static Map<String, Object?> recordCounts(Map<String, Object?> payload) => {
    for (final name in stores) name: (payload[name]! as List<Object?>).length,
    'contacts': (payload['customers']! as List<Object?>).fold<int>(0, (
      sum,
      row,
    ) {
      final record = row as Map<Object?, Object?>;
      return sum +
          (((record['value'] as Map<Object?, Object?>)['data']
                      as Map<Object?, Object?>)['contacts']
                  as List<Object?>)
              .length;
    }),
  };
  factory BackupDocument.create(Map<String, Object?> snapshot, DateTime now) {
    final payload = Map<String, Object?>.from(
      snapshot['payload']! as Map<Object?, Object?>,
    );
    final settings = Map<String, Object?>.from(
      snapshot['settings']! as Map<Object?, Object?>,
    );
    return BackupDocument._({
      'format': 'target-complete-backup',
      'formatVersion': 1,
      'appVersion': appVersion,
      'schemaVersion': 2,
      'createdAt': now.toUtc().toIso8601String(),
      'counts': recordCounts(payload),
      'settings': settings,
      'payload': payload,
    });
  }
  Uint8List encode() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'body': body,
        'checksum': {'algorithm': 'SHA-256', 'value': digest(body)},
      }),
    ),
  );
  factory BackupDocument.decode(Uint8List bytes) {
    try {
      return _decode(bytes);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid backup structure');
    }
  }
  static BackupDocument _decode(Uint8List bytes) {
    if (bytes.length > 20 * 1024 * 1024) {
      throw const FormatException('Backup exceeds 20 MiB');
    }
    final root = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final body = Map<String, Object?>.from(
      root['body'] as Map<Object?, Object?>,
    );
    final checksum = root['checksum'] as Map<Object?, Object?>;
    if (checksum['algorithm'] != 'SHA-256' ||
        checksum['value'] != digest(body)) {
      throw const FormatException('Backup integrity check failed');
    }
    if (body['format'] != 'target-complete-backup' ||
        body['formatVersion'] != 1 ||
        body['schemaVersion'] != 2) {
      throw const FormatException('Incompatible backup or schema');
    }
    final doc = BackupDocument._(body);
    DateTime.parse(body['createdAt']! as String);
    if (body['appVersion'] is! String ||
        doc.payload['format'] != 'target-customers' ||
        doc.payload['version'] != 2 ||
        digest(doc.counts) != digest(recordCounts(doc.payload))) {
      throw const FormatException('Invalid manifest');
    }
    if (doc.settings.keys.any((key) => key != 'locale') ||
        (doc.settings.containsKey('locale') &&
            !['ar', 'en'].contains(doc.settings['locale']))) {
      throw const FormatException('Unsupported settings');
    }
    return doc;
  }

  static String filename(DateTime now, {bool safety = false}) {
    final stamp = now
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('T', '_')
        .replaceAll('Z', '');
    return 'Target_${safety ? 'Safety_' : ''}Backup_$stamp';
  }
}
