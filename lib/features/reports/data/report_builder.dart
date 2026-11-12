import '../domain/report_query.dart';
import '../../customers/domain/customer.dart';
import '../../customers/data/customer_report_exporter.dart';

String reportTitle(ReportKind kind, bool ar) => (ar
    ? [
        'دليل العملاء',
        'العملاء حسب المحافظة والمدينة',
        'العملاء حسب النوع والتصنيف',
        'أنشطة العملاء',
        'الزيارات والاجتماعات',
        'المكالمات والمتابعات',
      ]
    : [
        'Customer directory',
        'Customers by governorate and city',
        'Customers by type and classification',
        'Customer activities',
        'Visits and meetings',
        'Calls and follow-ups',
      ])[kind.index];
String activityLabel(ActivityType type, bool ar) => (ar
    ? [
        'زيارة',
        'مكالمة',
        'اجتماع',
        'متابعة',
        'عرض سعر (سجل وصفي)',
        'بيع (سجل وصفي)',
        'تحصيل (سجل وصفي)',
        'ملاحظة',
      ]
    : [
        'Visit',
        'Call',
        'Meeting',
        'Follow-up',
        'Quotation (log only)',
        'Sale (log only)',
        'Collection (log only)',
        'Note',
      ])[type.index];
ReportTable buildReport(
  ReportKind kind,
  ReportQuery query,
  List<Customer> records,
  List<CustomerActivity> activities, {
  required bool arabic,
  required DateTime generatedAt,
}) {
  final isActivity = kind.index >= ReportKind.activities.index;
  final customers = query.customers(records, applyDates: !isActivity);
  final byId = {for (final c in customers) c.id: c};
  final rows = <List<Object?>>[];
  List<String> headers;
  if (isActivity) {
    headers = arabic
        ? ['معرف النشاط', 'العميل', 'النشاط', 'التاريخ UTC', 'الوصف']
        : ['Activity ID', 'Customer', 'Activity', 'Date UTC', 'Description'];
    final selected =
        activities
            .where(
              (a) =>
                  byId.containsKey(a.customerId) &&
                  query.dateMatches(a.occurredAt) &&
                  (query.activityType == null ||
                      a.type == query.activityType) &&
                  (kind != ReportKind.visits ||
                      [
                        ActivityType.visit,
                        ActivityType.meeting,
                      ].contains(a.type)) &&
                  (kind != ReportKind.calls ||
                      [
                        ActivityType.phoneCall,
                        ActivityType.followUp,
                      ].contains(a.type)),
            )
            .toList()
          ..sort((a, b) {
            final date = a.occurredAt.compareTo(b.occurredAt);
            return date == 0 ? a.id.compareTo(b.id) : date;
          });
    for (final a in selected) {
      rows.add([
        a.id,
        byId[a.customerId]!.data.name,
        activityLabel(a.type, arabic),
        a.occurredAt,
        a.text,
      ]);
    }
  } else if (kind == ReportKind.directory) {
    headers = arabic
        ? CustomerReportExporter.headersAr
        : CustomerReportExporter.headersEn;
    for (final c in customers) {
      rows.add(CustomerReportExporter.values(c, arabic));
    }
  } else {
    headers = kind == ReportKind.location
        ? (arabic
              ? ['المحافظة', 'المدينة', 'عدد العملاء']
              : ['Governorate', 'City', 'Customer count'])
        : (arabic
              ? ['النوع', 'التصنيف', 'عدد العملاء']
              : ['Type', 'Classification', 'Customer count']);
    final groups = <String, Map<String, int>>{};
    for (final c in customers) {
      final first = kind == ReportKind.location
          ? c.data.governorate
          : CustomerReportExporter.typeLabel(c.data.type, arabic);
      final second = kind == ReportKind.location
          ? c.data.city
          : c.data.classification;
      final group = groups.putIfAbsent(first, () => <String, int>{});
      group[second] = (group[second] ?? 0) + 1;
    }
    for (final first in groups.keys.toList()..sort()) {
      for (final second in groups[first]!.keys.toList()..sort()) {
        rows.add([first, second, groups[first]![second]]);
      }
    }
  }
  return ReportTable(
    reportTitle(kind, arabic),
    headers,
    rows,
    generatedAt.toUtc(),
    query.describe(arabic),
    recordCount: isActivity ? rows.length : customers.length,
  );
}
