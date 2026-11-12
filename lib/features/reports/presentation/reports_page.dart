import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/files/document_files.dart';
import '../../customers/domain/customer.dart';
import '../../customers/domain/customer_repository.dart';
import '../../customers/data/local_customer_repository.dart';
import '../../customers/data/customer_codec.dart';
import '../domain/report_query.dart';
import '../data/report_exporter.dart';
import '../data/report_builder.dart';
import '../../customers/data/customer_report_exporter.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, this.openModule});
  final Future<CustomerModule> Function()? openModule;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}
class _ReportsPageState extends State<ReportsPage> {
  final _governorate = TextEditingController(), _city = TextEditingController(), _classification = TextEditingController();
  ReportKind _kind = ReportKind.directory;
  CustomerType? _type;
  ActivityType? _activity;
  bool? _archived;
  bool _all = false, _busy = false;
  DateTimeRange? _dates;
  ReportTable? _preview;
  String? _message;
  bool get ar => Localizations.localeOf(context).languageCode == 'ar';
  String t(String arabic, String english) => ar ? arabic : english;
  @override
  void dispose() { _governorate.dispose(); _city.dispose(); _classification.dispose(); super.dispose(); }
  Future<void> _run(String? format) async {
    setState(() { _busy = true; _message = null; });
    try {
      final module = await widget.openModule!();
      List<Customer> customers;
      List<CustomerActivity> activities;
      if(module.repository is LocalCustomerRepository) {
        final snapshot = await (module.repository as LocalCustomerRepository).completeSnapshot();
        final payload = snapshot['payload']! as Map<String,Object?>;
        customers = (payload['customers']! as List<Object?>).map((row)=>CustomerCodec.read(Map<String,Object?>.from(((row! as Map<Object?,Object?>)['value'])! as Map<Object?,Object?>))).toList();
        activities = (payload['customer_activities']! as List<Object?>).map((row)=>CustomerCodec.readActivity(Map<String,Object?>.from(((row! as Map<Object?,Object?>)['value'])! as Map<Object?,Object?>))).toList();
      } else {
        customers = await module.repository.all();
        activities = [for(final list in await Future.wait(customers.map((c)=>module.repository.activities(c.id)))) ...list];
      }
      final query = _all ? const ReportQuery() : ReportQuery(
        governorate:_governorate.text.trim(),city:_city.text.trim(),classification:_classification.text.trim(),
        type:_type,activityType:_activity,archived:_archived,
        from:_dates?.start.toUtc(),until:_dates == null ? null : DateTime(_dates!.end.year,_dates!.end.month,_dates!.end.day+1).toUtc(),
      );
      final report = buildReport(_kind,query,customers,activities,arabic:ar,generatedAt:DateTime.now());
      if(format != null) {
        final fonts = await Future.wait([rootBundle.load('assets/fonts/Amiri-Regular.ttf'),rootBundle.load('assets/fonts/Amiri-Bold.ttf')]);
        final exporter = ReportExporter(fonts[0].buffer.asUint8List(),fonts[1].buffer.asUint8List());
        final bytes = format == 'pdf' ? await exporter.pdf(report,arabic:ar) : await exporter.xlsx(report,arabic:ar);
        final saved = await DocumentFiles.save(bytes,'Target_${_kind.name}_${report.generatedAt.millisecondsSinceEpoch}',format);
        if(!saved) { if(mounted) setState(()=>_message=t('تم إلغاء الحفظ','Save cancelled')); return; }
      }
      if(mounted) setState(() { _preview = report; _message = format == null ? null : t('تم تسليم التقرير إلى نظام الحفظ','Report handed to the save system'); });
    } catch(error) { if(mounted) setState(()=>_message=t('تعذر إنشاء التقرير. أعد المحاولة.','Could not create report. Please retry.')); }
    finally { if(mounted) setState(()=>_busy=false); }
  }
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text(t('مركز التقارير','Reports dashboard'),style:Theme.of(context).textTheme.headlineSmall),
    Text(t('تقارير من البيانات المحلية الفعلية فقط. الأنشطة سجلات وصفية وليست معاملات بيع أو تحصيل.','Reports use actual local records only. Activities are descriptive logs, not sales or collection transactions.')),
    const SizedBox(height:16),
    DropdownButtonFormField<ReportKind>(initialValue:_kind,isExpanded:true,items:ReportKind.values.map((k)=>DropdownMenuItem(value:k,child:Text(reportTitle(k,ar)))).toList(),onChanged:_busy?null:(v)=>setState(()=>_kind=v!)),
    const SizedBox(height:16),
    Wrap(spacing:12,runSpacing:12,children:[
      for(final entry in [(_governorate,t('المحافظة','Governorate')),(_city,t('المدينة','City')),(_classification,t('التصنيف','Classification'))])
        SizedBox(width:240,child:TextField(controller:entry.$1,enabled:!_busy,decoration:InputDecoration(labelText:entry.$2))),
      SizedBox(width:240,child:DropdownButtonFormField<CustomerType>(decoration:InputDecoration(labelText:t('نوع العميل','Customer type')),items:[DropdownMenuItem(child:Text(t('الكل','All'))),...CustomerType.values.map((v)=>DropdownMenuItem(value:v,child:Text(CustomerReportExporter.typeLabel(v,ar))))],onChanged:_busy?null:(v)=>setState(()=>_type=v))),
      SizedBox(width:240,child:DropdownButtonFormField<ActivityType>(decoration:InputDecoration(labelText:t('نوع النشاط','Activity type')),items:[DropdownMenuItem(child:Text(t('الكل','All'))),...ActivityType.values.map((v)=>DropdownMenuItem(value:v,child:Text(activityLabel(v,ar))))],onChanged:_busy?null:(v)=>setState(()=>_activity=v))),
      SizedBox(width:240,child:DropdownButtonFormField<bool>(decoration:InputDecoration(labelText:t('الأرشفة','Archive')),items:[DropdownMenuItem(child:Text(t('الكل','All'))),DropdownMenuItem(value:false,child:Text(t('غير مؤرشف','Not archived'))),DropdownMenuItem(value:true,child:Text(t('مؤرشف','Archived')))],onChanged:_busy?null:(v)=>setState(()=>_archived=v))),
      OutlinedButton(onPressed:_busy?null:() async { final dates=await showDateRangePicker(context:context,firstDate:DateTime(2000),lastDate:DateTime(2100),initialDateRange:_dates); if(dates!=null && mounted) setState(()=>_dates=dates); },child:Text(_dates==null?t('الفترة الزمنية','Date range'):'${_dates!.start.toIso8601String().substring(0,10)} — ${_dates!.end.toIso8601String().substring(0,10)}')),
      if(_dates!=null) TextButton(onPressed:_busy?null:()=>setState(()=>_dates=null),child:Text(t('مسح الفترة','Clear dates'))),
    ]),
    Text(t('الفترة تطبق على تاريخ إنشاء العملاء أو تاريخ حدوث النشاط؛ تشمل يوم النهاية.','Dates filter customer creation or activity occurrence and include the final selected day.')),
    SwitchListTile(value:_all,onChanged:_busy?null:(v)=>setState(()=>_all=v),title:Text(t('كل السجلات (تجاهل عوامل التصفية)','All records (ignore filters)'))),
    Wrap(spacing:12,runSpacing:12,children:[
      OutlinedButton(onPressed:_busy || widget.openModule==null?null:()=>_run(null),child:Text(t('معاينة / تحديث','Preview / refresh'))),
      for(final format in ['xlsx','pdf']) FilledButton(onPressed:_busy || widget.openModule==null?null:()=>_run(format),child:Text(format.toUpperCase())),
    ]),
    if(_busy) const LinearProgressIndicator(),
    if(_message!=null) Text(_message!),
    if(_preview!=null) ...[
      Text('${_preview!.title} · ${t("عدد صفوف التقرير","Report rows")}: ${_preview!.rows.length}'),
      Text(_preview!.filters),
      Text(t('المعاينة تعرض أول ٢٠ صفاً؛ التصدير يشمل جميع النتائج.','Preview shows the first 20 rows; export includes every result.')),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(columns:_preview!.headers.map((h)=>DataColumn(label:Text(h))).toList(),rows:_preview!.rows.take(20).map((row)=>DataRow(cells:row.map((v)=>DataCell(SizedBox(width:160,child:Text(v?.toString()??'',maxLines:3,overflow:TextOverflow.ellipsis)))).toList())).toList())),
    ],
  ]);
}
