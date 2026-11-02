import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';

/// Pure byte generation: never downloads fonts or uses network services.
class CustomerReportExporter implements CustomerReports {
  CustomerReportExporter({required this.regularFont, required this.boldFont});
  final Uint8List regularFont, boldFont;
  static const headersEn = [
    'Customer ID',
    'Name',
    'Type',
    'Contacts',
    'Phone',
    'Alternative phone',
    'Email',
    'Address',
    'Governorate',
    'City',
    'Area',
    'Classification',
    'Business sector',
    'Representative ID',
    'Status',
    'Potential value',
    'Credit limit',
    'Currency',
    'Notes',
    'Created (UTC)',
    'Updated (UTC)',
    'Archived (UTC)',
    'Revision',
    'Synchronization',
  ];
  static const headersAr = [
    'معرف العميل',
    'الاسم',
    'النوع',
    'جهات الاتصال',
    'الهاتف',
    'هاتف بديل',
    'البريد الإلكتروني',
    'العنوان',
    'المحافظة',
    'المدينة',
    'المنطقة',
    'التصنيف',
    'قطاع الأعمال',
    'معرف المندوب',
    'الحالة',
    'القيمة المحتملة',
    'الحد الائتماني',
    'العملة',
    'ملاحظات',
    'تاريخ الإنشاء (UTC)',
    'تاريخ التحديث (UTC)',
    'تاريخ الأرشفة (UTC)',
    'الإصدار',
    'المزامنة',
  ];
  static String typeLabel(CustomerType t, bool ar) => ar
      ? [
          'مستشفى',
          'عيادة',
          'مركز طبي',
          'جامعة',
          'جهة صحية حكومية',
          'جهة صحية خاصة',
          'موزع',
          'منظمة أخرى',
        ][t.index]
      : [
          'Hospital',
          'Clinic',
          'Medical center',
          'University',
          'Government healthcare',
          'Private healthcare',
          'Distributor',
          'Other organization',
        ][t.index];
  static String statusLabel(CustomerStatus s, bool ar) => ar
      ? ['محتمل', 'نشط', 'غير نشط'][s.index]
      : ['Prospect', 'Active', 'Inactive'][s.index];
  static String syncLabel(CustomerSyncStatus s, bool ar) => ar
      ? [
          'محفوظ محلياً',
          'محفوظ محلياً · بانتظار المزامنة',
          'تمت المزامنة',
          'خطأ في المزامنة',
          'تعارض · يلزم التدخل',
        ][s.index]
      : [
          'Saved locally',
          'Saved locally · Pending synchronization',
          'Synchronized',
          'Synchronization error',
          'Conflict · Review required',
        ][s.index];
  static List<Object?> values(Customer c, bool ar) {
    final d = c.data;
    return [
      c.id,
      d.name,
      typeLabel(d.type, ar),
      d.contacts.map((p) => p.name).join('\n'),
      d.contacts.map((p) => p.phone).join('\n'),
      d.contacts.map((p) => p.alternativePhone).join('\n'),
      d.contacts.map((p) => p.email).join('\n'),
      d.address,
      d.governorate,
      d.city,
      d.area,
      d.classification,
      d.businessSector,
      d.assignedRepresentativeId,
      statusLabel(d.status, ar),
      d.potentialMinor / 100,
      d.creditLimitMinor == null ? null : d.creditLimitMinor! / 100,
      d.currency,
      d.notes,
      c.createdAt,
      c.updatedAt,
      c.archivedAt,
      c.revision,
      syncLabel(c.syncStatus, ar),
    ];
  }

  @override
  Future<Uint8List> xlsx(
    List<Customer> customers, {
    required bool arabic,
  }) async {
    final book = Excel.createExcel();
    book.rename('Sheet1', 'Customers');
    final sheet = book['Customers'];
    sheet.isRTL = arabic;
    final headers = arabic ? headersAr : headersEn;
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    for (final customer in customers) {
      sheet.appendRow(
        values(customer, arabic)
            .map<CellValue?>(
              (v) => switch (v) {
                null => null,
                int() => IntCellValue(v),
                double() => DoubleCellValue(v),
                DateTime() => DateTimeCellValue.fromDateTime(v.toUtc()),
                _ => TextCellValue(v.toString()),
              },
            )
            .toList(),
      );
    }
    for (var col = 0; col < headers.length; col++) {
      sheet.setColumnWidth(col, col == 18 ? 55 : 24);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
          .cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: ExcelColor.fromHexString('FF142D4E'),
      );
      for (var row = 1; row <= customers.length; row++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );
        if (col == 15 || col == 16)
          cell.cellStyle = CellStyle(
            numberFormat: NumFormat.custom(formatCode: '#,##0.00'),
          );
        if (col >= 19 && col <= 21 && cell.value != null)
          cell.cellStyle = CellStyle(
            numberFormat: NumFormat.custom(formatCode: 'yyyy-mm-dd hh:mm'),
          );
      }
    }
    // excel 4 exposes RTL but not AutoFilter/frozen headings. Add standard OOXML
    // without formulas or external links; normal Excel sorting/filtering works.
    final archive = ZipDecoder().decodeBytes(book.encode()!);
    final output = Archive();
    for (final file in archive.files) {
      if (file.name == 'xl/worksheets/sheet1.xml') {
        final document = XmlDocument.parse(
          utf8.decode(file.content as List<int>),
        );
        final root = document.rootElement;
        final views = root.findElements('sheetViews').firstOrNull;
        final view = views?.findElements('sheetView').firstOrNull;
        view?.children.add(
          XmlElement(XmlName('pane'), [
            XmlAttribute(XmlName('ySplit'), '1'),
            XmlAttribute(XmlName('topLeftCell'), 'A2'),
            XmlAttribute(XmlName('state'), 'frozen'),
          ]),
        );
        final filter = XmlElement(XmlName('autoFilter'), [
          XmlAttribute(XmlName('ref'), 'A1:X${customers.length + 1}'),
        ]);
        final data = root.findElements('sheetData').first;
        root.children.insert(root.children.indexOf(data) + 1, filter);
        final bytes = utf8.encode(document.toXmlString());
        output.addFile(ArchiveFile(file.name, bytes.length, bytes));
      } else {
        output.addFile(file);
      }
    }
    return Uint8List.fromList(ZipEncoder().encode(output)!);
  }

  @override
  Future<Uint8List> pdf(
    List<Customer> customers, {
    required bool arabic,
    required String filters,
    required DateTime generatedAt,
  }) async {
    final regular = pw.Font.ttf(ByteData.sublistView(regularFont));
    final bold = pw.Font.ttf(ByteData.sublistView(boldFont));
    final navy = PdfColor.fromHex('#142D4E');
    final document = pw.Document(
      title: arabic ? 'تقرير العملاء' : 'Customer report',
      author: 'Target',
      compress: false,
    );
    final direction = arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final headers = arabic ? headersAr : headersEn;
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        maxPages: 10000,
        textDirection: direction,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        header: (context) => pw.Container(
          color: navy,
          padding: const pw.EdgeInsets.all(10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                arabic ? 'تارجت | تقرير العملاء' : 'Target | Customer report',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Text(
          '${arabic ? 'صفحة' : 'Page'} ${context.pageNumber} / ${context.pagesCount}',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 9),
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          pw.Text(
            '${arabic ? 'تاريخ التقرير' : 'Generated'}: ${generatedAt.toUtc().toIso8601String()}',
          ),
          pw.Text(
            '${arabic ? 'عدد العملاء' : 'Customer count'}: ${customers.length}',
          ),
          pw.Text('${arabic ? 'عوامل التصفية' : 'Filters'}: $filters'),
          pw.SizedBox(height: 16),
          if (customers.isEmpty)
            pw.Text(arabic ? 'لا توجد سجلات' : 'No records'),
          for (final c in customers) ...[
            pw.Header(level: 1, text: c.data.name),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  repeat: true,
                  decoration: pw.BoxDecoration(color: navy),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        arabic ? 'الحقل' : 'Field',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        arabic ? 'القيمة' : 'Value',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                for (var i = 0; i < headers.length; i++)
                  ..._rows(headers[i], _display(values(c, arabic)[i]), arabic),
              ],
            ),
            pw.SizedBox(height: 16),
          ],
        ],
      ),
    );
    return document.save();
  }

  String _display(Object? value) => switch (value) {
    null => '—',
    DateTime() => value.toUtc().toIso8601String(),
    double() => value.toStringAsFixed(2),
    _ => value.toString(),
  };
  List<pw.TableRow> _rows(String label, String value, bool arabic) {
    // Bound individual row heights even for long notes or 50 contacts.
    final chunks = <String>[];
    for (var start = 0; start < value.length; start += 240) {
      chunks.add(
        value.substring(start, (start + 240).clamp(0, value.length).toInt()),
      );
    }
    if (chunks.isEmpty) chunks.add('—');
    return [
      for (final chunk in chunks)
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(chunk, style: const pw.TextStyle(fontSize: 10)),
            ),
          ],
        ),
    ];
  }
}
