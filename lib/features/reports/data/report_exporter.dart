import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';
import '../../customers/data/pdf_text_chunks.dart';
import '../domain/report_query.dart';

class ReportExporter {
  ReportExporter(this.regularFont, this.boldFont);
  final Uint8List regularFont, boldFont;
  Future<Uint8List> xlsx(ReportTable report, {required bool arabic}) async {
    final book = Excel.createExcel();
    book.rename('Sheet1', 'Records');
    final sheet = book['Records'];
    sheet.isRTL = arabic;
    sheet.appendRow(report.headers.map(TextCellValue.new).toList());
    for (final row in report.rows) {
      sheet.appendRow(row.map<CellValue?>((v)=> switch(v) {
        null => null, int() => IntCellValue(v), double() => DoubleCellValue(v),
        DateTime() => DateTimeCellValue.fromDateTime(v.toUtc()), _ => TextCellValue(v.toString()),
      }).toList());
    }
    for (var col = 0; col < report.headers.length; col++) {
      sheet.setColumnWidth(col, 30);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col,rowIndex:0)).cellStyle = CellStyle(bold:true, fontColorHex:ExcelColor.white, backgroundColorHex:ExcelColor.fromHexString('FF142D4E'));
      for (var row = 1; row <= report.rows.length; row++) {
        final value = report.rows[row-1][col];
        if (value is double) { sheet.cell(CellIndex.indexByColumnRow(columnIndex:col,rowIndex:row)).cellStyle = CellStyle(numberFormat:NumFormat.custom(formatCode:'#,##0.00')); }
        if (value is DateTime) { sheet.cell(CellIndex.indexByColumnRow(columnIndex:col,rowIndex:row)).cellStyle = CellStyle(numberFormat:NumFormat.custom(formatCode:'yyyy-mm-dd hh:mm')); }
      }
    }
    final summary = book['Report'];
    summary.isRTL = arabic;
    for (final row in [
      [arabic ? 'التقرير' : 'Report', report.title],
      [arabic ? 'تاريخ الإنشاء UTC' : 'Generated UTC', report.generatedAt.toIso8601String()],
      [arabic ? 'عدد صفوف التقرير' : 'Report row count', report.rows.length.toString()],
      [arabic ? 'عدد السجلات' : 'Record count', report.recordCount.toString()],
      [arabic ? 'عوامل التصفية' : 'Filters', report.filters],
    ]) { summary.appendRow(row.map(TextCellValue.new).toList()); }
    summary.cell(CellIndex.indexByString('B2')).value = DateTimeCellValue.fromDateTime(report.generatedAt);
    summary.cell(CellIndex.indexByString('B2')).cellStyle = CellStyle(numberFormat:NumFormat.custom(formatCode:'yyyy-mm-dd hh:mm'));
    summary.cell(CellIndex.indexByString('B3')).value = IntCellValue(report.rows.length);
    summary.cell(CellIndex.indexByString('B4')).value = IntCellValue(report.recordCount);
    summary.setColumnWidth(0,28); summary.setColumnWidth(1,80);
    final archive = ZipDecoder().decodeBytes(book.encode()!);
    final output = Archive();
    for (final file in archive.files) {
      if (file.name == 'xl/worksheets/sheet1.xml') {
        final xml = XmlDocument.parse(utf8.decode(file.content as List<int>));
        final root = xml.rootElement;
        for(final old in root.findElements('sheetViews').toList()) { old.remove(); }
        final views = XmlDocument.parse('<sheetViews><sheetView workbookViewId="0" rightToLeft="${arabic ? 1 : 0}"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>').rootElement.copy();
        final first = root.childElements.firstWhere((e)=>['sheetFormatPr','cols','sheetData'].contains(e.name.local));
        root.children.insert(root.children.indexOf(first), views);
        final lastColumn = String.fromCharCode(64 + report.headers.length);
        final data = root.findElements('sheetData').first;
        root.children.insert(root.children.indexOf(data)+1, XmlElement(XmlName('autoFilter'), [XmlAttribute(XmlName('ref'),'A1:$lastColumn${report.rows.length+1}')]));
        final bytes = utf8.encode(xml.toXmlString());
        output.addFile(ArchiveFile(file.name,bytes.length,bytes));
      } else { output.addFile(file); }
    }
    return Uint8List.fromList(ZipEncoder().encode(output)!);
  }
  Future<Uint8List> pdf(ReportTable report, {required bool arabic}) async {
    final document = pw.Document();
    final navy = PdfColor.fromHex('#142D4E');
    document.addPage(pw.MultiPage(
      pageFormat:PdfPageFormat.a4, maxPages:10000,
      textDirection:arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      theme:pw.ThemeData.withFont(base:pw.Font.ttf(ByteData.sublistView(regularFont)),bold:pw.Font.ttf(ByteData.sublistView(boldFont))),
      header:(context)=>pw.Container(color:navy,padding:const pw.EdgeInsets.all(10),child:pw.Text(report.title,style:pw.TextStyle(color:PdfColors.white,fontSize:16))),
      footer:(context)=>pw.Text('${context.pageNumber} / ${context.pagesCount}',style:const pw.TextStyle(fontSize:9)),
      build:(context)=>[
        pw.Text('${report.generatedAt.toIso8601String()} · ${arabic ? "عدد الصفوف" : "Rows"}: ${report.rows.length} · ${arabic ? "عدد السجلات" : "Records"}: ${report.recordCount}'),
        for(final chunk in pdfTextChunks(report.filters)) pw.Text(chunk,style:const pw.TextStyle(fontSize:9)),
        if(report.rows.isEmpty) pw.Text(arabic ? 'لا توجد سجلات' : 'No records'),
        for(var row=0;row<report.rows.length;row++) ...[
          pw.Header(level:2,text:'${row+1}'),
          pw.Table(border:pw.TableBorder.all(color:PdfColors.grey300),columnWidths:{0:const pw.FlexColumnWidth(1),1:const pw.FlexColumnWidth(2)},children:[
            for(var col=0;col<report.headers.length;col++)
              for(final chunk in pdfTextChunks(display(report.rows[row][col]).isEmpty ? '—' : display(report.rows[row][col])))
                pw.TableRow(children:[
                  pw.Padding(padding:const pw.EdgeInsets.all(5),child:pw.Text(report.headers[col],style:pw.TextStyle(fontWeight:pw.FontWeight.bold,fontSize:10))),
                  pw.Padding(padding:const pw.EdgeInsets.all(5),child:pw.Text(chunk,style:const pw.TextStyle(fontSize:10))),
                ]),
          ]),
        ],
      ],
    ));
    return document.save();
  }
  String display(Object? value) => value is DateTime ? value.toUtc().toIso8601String() : value?.toString() ?? '';
}
