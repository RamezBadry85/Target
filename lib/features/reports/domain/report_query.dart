import '../../customers/domain/customer.dart';

enum ReportKind {
  directory,
  location,
  classification,
  activities,
  visits,
  calls,
}

class ReportTable {
  ReportTable(
    this.title,
    this.headers,
    this.rows,
    this.generatedAt,
    this.filters, {
    int? recordCount,
  }) : recordCount = recordCount ?? rows.length;
  final int recordCount;
  final String title, filters;
  final List<String> headers;
  final List<List<Object?>> rows;
  final DateTime generatedAt;
}

class ReportQuery {
  const ReportQuery({
    this.from,
    this.until,
    this.governorate = '',
    this.city = '',
    this.classification = '',
    this.type,
    this.status,
    this.activityType,
    this.archived,
  });
  final DateTime? from, until;
  final String governorate, city, classification;
  final CustomerType? type;
  final CustomerStatus? status;
  final ActivityType? activityType;
  final bool? archived;
  bool dateMatches(DateTime date) =>
      (from == null || !date.isBefore(from!)) &&
      (until == null || date.isBefore(until!));
  List<Customer> customers(
    Iterable<Customer> records, {
    bool applyDates = true,
  }) =>
      records
          .where(
            (c) =>
                (archived == null || archived == c.archived) &&
                (governorate.isEmpty ||
                    normalizeText(governorate) ==
                        normalizeText(c.data.governorate)) &&
                (city.isEmpty ||
                    normalizeText(city) == normalizeText(c.data.city)) &&
                (classification.isEmpty ||
                    normalizeText(classification) ==
                        normalizeText(c.data.classification)) &&
                (type == null || type == c.data.type) &&
                (status == null || status == c.data.status) &&
                (!applyDates || dateMatches(c.createdAt)),
          )
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  String describe(bool ar) {
    const customerTypesAr = [
      'مستشفى', 'عيادة', 'مركز طبي', 'جامعة', 'جهة صحية حكومية',
      'جهة صحية خاصة', 'موزع', 'منظمة أخرى',
    ];
    const customerTypesEn = [
      'Hospital', 'Clinic', 'Medical center', 'University',
      'Government healthcare', 'Private healthcare', 'Distributor', 'Other organization',
    ];
    const statusesAr = ['محتمل', 'نشط', 'غير نشط'];
    const statusesEn = ['Prospect', 'Active', 'Inactive'];
    const activitiesAr = [
      'زيارة', 'مكالمة', 'اجتماع', 'متابعة', 'عرض سعر (سجل وصفي)',
      'بيع (سجل وصفي)', 'تحصيل (سجل وصفي)', 'ملاحظة',
    ];
    const activitiesEn = [
      'Visit', 'Call', 'Meeting', 'Follow-up', 'Quotation (log only)',
      'Sale (log only)', 'Collection (log only)', 'Note',
    ];
    final typeLabel = type == null
        ? '*'
        : (ar ? customerTypesAr : customerTypesEn)[type!.index];
    final statusLabel = status == null
        ? '*'
        : (ar ? statusesAr : statusesEn)[status!.index];
    final activityLabel = activityType == null
        ? '*'
        : (ar ? activitiesAr : activitiesEn)[activityType!.index];
    final archiveLabel = archived == null
        ? '*'
        : archived!
        ? (ar ? 'مؤرشف' : 'Archived')
        : (ar ? 'غير مؤرشف' : 'Not archived');
    return [
      ar
          ? 'التواريخ: إنشاء العميل / حدوث النشاط؛ النهاية غير شاملة'
          : 'Dates: customer creation / activity occurrence; end exclusive',
      '${from?.toUtc().toIso8601String() ?? "—"} / ${until?.toUtc().toIso8601String() ?? "—"}',
      '${ar ? "المحافظة / المدينة / التصنيف" : "Governorate / city / classification"}: $governorate / $city / $classification',
      '${ar ? "نوع العميل / الحالة / النشاط / الأرشيف" : "Customer type / status / activity / archive"}: $typeLabel / $statusLabel / $activityLabel / $archiveLabel',
    ].join(' · ');
  }
}
