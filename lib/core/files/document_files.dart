import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

abstract final class DocumentFiles {
  /// A null native result means the user cancelled; never report that as saved.
  static Future<bool> save(Uint8List bytes,String name,String extension) async {
    final mime=switch(extension) {'pdf'=>MimeType.pdf,'xlsx'=>MimeType.microsoftExcel,_=>MimeType.json};
    if(kIsWeb) {
      await FileSaver.instance.saveFile(name:name,bytes:bytes,ext:extension,mimeType:mime);
      return true; // Browser download requested, not confirmation of disk persistence.
    }
    return await FileSaver.instance.saveAs(name:name,bytes:bytes,ext:extension,mimeType:mime)!=null;
  }
  static Future<Uint8List?> pickBackup() async {
    final file=await openFile(acceptedTypeGroups:[const XTypeGroup(label:'Target backup',extensions:['json'],mimeTypes:['application/json'],uniformTypeIdentifiers:['public.json'])]);
    if(file==null) return null;
    if(await file.length()>20*1024*1024) throw const FormatException('Backup too large');
    return file.readAsBytes();
  }
}
