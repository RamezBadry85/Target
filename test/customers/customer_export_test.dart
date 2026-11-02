import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:target/features/customers/data/customer_report_exporter.dart';
import 'package:target/features/customers/domain/customer.dart';
import 'customer_repository_test.dart' show draft;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CustomerReportExporter exporter;
  final customer = Customer(
    id: 'export-id',
    data: draft(),
    createdAt: DateTime.utc(2024),
    updatedAt: DateTime.utc(2025),
    revision: 1,
  );
  setUpAll(() async {
    final a = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final b = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
    exporter = CustomerReportExporter(
      regularFont: a.buffer.asUint8List(),
      boldFont: b.buffer.asUint8List(),
    );
  });
  for (final arabic in [true, false]) {
    test(
      'XLSX ${arabic ? 'Arabic' : 'English'} preserves text, numeric/date cells and filters',
      () async {
        final bytes = await exporter.xlsx([customer], arabic: arabic);
        expect(bytes.take(2), [80, 75]);
        final book = Excel.decodeBytes(bytes);
        final rows = book['Customers'].rows;
        expect(rows[1][1]!.value, TextCellValue(customer.data.name));
        expect(rows[1][15]!.value, isA<DoubleCellValue>());
        expect(rows[1][19]!.value, isA<DateTimeCellValue>());
        expect(
          rows.first.first!.value,
          TextCellValue(arabic ? 'معرف العميل' : 'Customer ID'),
        );
        final zip = ZipDecoder().decodeBytes(bytes);
        final sheet = utf8.decode(
          zip.findFile('xl/worksheets/sheet1.xml')!.content as List<int>,
        );
        expect(sheet, contains('autoFilter'));
        expect(sheet, contains('A1:X2'));
        expect(sheet, contains('frozen'));
        expect(book['Customers'].isRTL, arabic);
      },
    );
    test(
      'PDF ${arabic ? 'Arabic RTL' : 'English LTR'} embeds fonts and produces A4 pages',
      () async {
        final bytes = await exporter.pdf(
          [customer],
          arabic: arabic,
          filters: arabic ? 'القاهرة' : 'Cairo',
          generatedAt: DateTime.utc(2025),
        );
        final raw = latin1.decode(bytes);
        expect(raw, startsWith('%PDF-'));
        expect(raw, contains('/FontFile2'));
        expect(raw, contains('/ToUnicode'));
        expect(raw, contains('/MediaBox'));
        expect(raw, contains('%%EOF'));
        expect(bytes.length, greaterThan(10000));
      },
    );
  }
  test(
    'empty exports contain headers and valid documents, not fabricated rows',
    () async {
      final bytes = await exporter.xlsx([], arabic: true);
      expect(Excel.decodeBytes(bytes)['Customers'].rows, hasLength(1));
      expect(
        await exporter.pdf(
          [],
          arabic: true,
          filters: '',
          generatedAt: DateTime.utc(2025),
        ),
        isA<Uint8List>(),
      );
    },
  );
  test(
    'XLSX customer text beginning with equals remains text, not a formula',
    () async {
      final c = Customer(
        id: 'formula',
        data: draft(name: '=1+1'),
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
        revision: 1,
      );
      final bytes = await exporter.xlsx([c], arabic: false);
      expect(
        Excel.decodeBytes(bytes)['Customers'].rows[1][1]!.value,
        TextCellValue('=1+1'),
      );
    },
  );
  test(
    'PDF paginates long Arabic notes without dropping the customer',
    () async {
      final d = CustomerDraft(
        name: 'ملاحظات طويلة',
        contacts: draft().contacts,
        notes: List.filled(200, 'ملاحظة عربية ').join(),
      );
      final c = Customer(
        id: 'long',
        data: d,
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
        revision: 1,
      );
      final raw = latin1.decode(
        await exporter.pdf(
          [c, c, c],
          arabic: true,
          filters: 'الكل',
          generatedAt: DateTime.utc(2025),
        ),
      );
      expect(RegExp(r'/Type\s*/Page\b').allMatches(raw).length, greaterThan(1));
    },
  );
}
