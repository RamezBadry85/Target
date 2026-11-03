import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:target/core/files/document_files.dart';

void main() {
  final bytes = Uint8List.fromList([1, 2, 3]);
  test('native cancellation is not a saved document', () async {
    expect(await DocumentFiles.save(bytes, 'test', 'pdf', nativeSave: () async => null), isFalse);
  });
  test('native acknowledgement accepts SAF URIs and filesystem paths', () async {
    for (final path in ['content://provider/document/123', r'C:\Reports\test.pdf']) {
      expect(await DocumentFiles.save(bytes, 'test', 'pdf', nativeSave: () async => path), isTrue);
    }
  });
  test('native write failures propagate for UI error handling', () async {
    await expectLater(DocumentFiles.save(bytes, 'test', 'pdf', nativeSave: () async {
      throw PlatformException(code: 'FILE_WRITE_ERROR');
    }), throwsA(isA<PlatformException>()));
  });
  test('empty and legacy error-string acknowledgements cannot mean success', () async {
    for (final result in ['', 'Failed to save file']) {
      await expectLater(DocumentFiles.save(bytes, 'test', 'pdf', nativeSave: () async => result), throwsFormatException);
    }
  });
}
