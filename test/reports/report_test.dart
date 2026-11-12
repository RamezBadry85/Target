import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:target/features/reports/domain/report_query.dart';
import 'package:target/features/reports/data/report_builder.dart';
import 'package:target/features/reports/data/report_exporter.dart';
import 'package:target/features/customers/domain/customer.dart';
import '../customers/customer_repository_test.dart' show draft;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final customer=Customer(id:'fixture-customer',data:draft(),createdAt:DateTime.utc(2025,1,2),updatedAt:DateTime.utc(2025,1,3),revision:1);
  final activities=[for(final type in ActivityType.values) CustomerActivity(id:type.name,customerId:customer.id,type:type,text:'اختبار عَرَبِيّ / English fixture',occurredAt:DateTime.utc(2025,1,4),createdAt:DateTime.utc(2025,1,4))];
  late ReportExporter exporter;
  setUpAll(()async{
    final fonts=await Future.wait([rootBundle.load('assets/fonts/Amiri-Regular.ttf'),rootBundle.load('assets/fonts/Amiri-Bold.ttf')]);
    exporter=ReportExporter(fonts[0].buffer.asUint8List(),fonts[1].buffer.asUint8List());
  });
  test('date bounds are inclusive-start/exclusive-end and apply to occurrences for activities',(){
    final q=ReportQuery(from:DateTime.utc(2025,1,4),until:DateTime.utc(2025,1,5));
    expect(buildReport(ReportKind.directory,q,[customer],activities,arabic:true,generatedAt:DateTime.utc(2025)).rows,isEmpty);
    expect(buildReport(ReportKind.activities,q,[customer],activities,arabic:true,generatedAt:DateTime.utc(2025)).rows,hasLength(8));
    expect(ReportQuery(until:DateTime.utc(2025,1,4)).dateMatches(DateTime.utc(2025,1,4)),isFalse);
  });
  test('location, classification, archive and activity category filters are real',(){
    for(final query in [const ReportQuery(governorate:'other'),const ReportQuery(city:'other'),const ReportQuery(classification:'other'),const ReportQuery(type:CustomerType.hospital),const ReportQuery(archived:true)]) {
      expect(buildReport(ReportKind.directory,query,[customer],activities,arabic:true,generatedAt:DateTime.utc(2025)).rows,isEmpty);
    }
    expect(buildReport(ReportKind.visits,const ReportQuery(),[customer],activities,arabic:true,generatedAt:DateTime.utc(2025)).rows,hasLength(2));
    expect(buildReport(ReportKind.calls,const ReportQuery(activityType:ActivityType.phoneCall),[customer],activities,arabic:true,generatedAt:DateTime.utc(2025)).rows,hasLength(1));
    final grouped=buildReport(ReportKind.location,const ReportQuery(),[customer],activities,arabic:true,generatedAt:DateTime.utc(2025));
    expect(grouped.rows.single.last,1);expect(grouped.recordCount,1);
  });
  for(final arabic in [true,false]) {
    for(final kind in ReportKind.values) {
      test('actual XLSX/PDF ${kind.name} Arabic=$arabic',()async{
        final report=buildReport(kind,const ReportQuery(),[customer],activities,arabic:arabic,generatedAt:DateTime.utc(2025,1,5));
        final xlsx=await exporter.xlsx(report,arabic:arabic);
        final book=Excel.decodeBytes(xlsx);
        expect(book['Records'].rows.length,report.rows.length+1);
        expect(book['Records'].isRTL,arabic);
        expect(book['Report'].rows[2][1]!.value,IntCellValue(report.rows.length));
        final zip=ZipDecoder().decodeBytes(xlsx);
        final xml=utf8.decode(zip.findFile('xl/worksheets/sheet1.xml')!.content as List<int>);
        expect(xml,contains('autoFilter'));expect(xml,contains('frozen'));
        final pdf=await exporter.pdf(report,arabic:arabic);
        expect(latin1.decode(pdf),startsWith('%PDF-'));
        expect(latin1.decode(pdf),contains('/FontFile2'));
        final path=Platform.environment['TARGET_REPORT_SAMPLES'];
        if(path!=null) {
          final directory=Directory(path)..createSync(recursive:true);
          File('${directory.path}/${kind.name}_${arabic?'ar':'en'}.xlsx').writeAsBytesSync(xlsx);
          File('${directory.path}/${kind.name}_${arabic?'ar':'en'}.pdf').writeAsBytesSync(pdf);
        }
      });
    }
  }
  test('large Arabic activity report paginates without truncating source rows',()async{
    final rows=List.generate(150,(i)=>['سجل $i',List.filled(20,'نص عَرَبِيّ متصل للاختبار ').join()]);
    final report=ReportTable('اختبار كبير',['العميل','الوصف'],rows,DateTime.utc(2025),'اختبار');
    final raw=latin1.decode(await exporter.pdf(report,arabic:true));
    expect(RegExp(r'/Type\s*/Page\b').allMatches(raw).length,greaterThan(5));
    expect(report.rows,hasLength(150));
    final path=Platform.environment['TARGET_REPORT_SAMPLES'];
    if(path!=null) File('$path/large_ar.pdf').writeAsBytesSync(latin1.encode(raw));
  });
}
