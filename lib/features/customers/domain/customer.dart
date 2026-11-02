enum CustomerType {
  hospital,
  clinic,
  medicalCenter,
  university,
  government,
  privateHealthcare,
  distributor,
  other,
}

enum CustomerStatus { prospect, active, inactive }

enum CustomerSyncStatus { local, pending, synchronized, error, conflict }

enum ActivityType {
  visit,
  phoneCall,
  meeting,
  followUp,
  quotation,
  sale,
  collection,
  note,
}

class CustomerContact {
  const CustomerContact({
    required this.id,
    required this.name,
    required this.phone,
    this.alternativePhone = '',
    this.email = '',
  });
  final String id;
  final String name;
  final String phone;
  final String alternativePhone;
  final String email;
}

/// Money is stored as integer hundredths, never binary floating point.
class CustomerDraft {
  CustomerDraft({
    required this.name,
    this.type = CustomerType.other,
    List<CustomerContact> contacts = const [],
    this.address = '',
    this.governorate = '',
    this.city = '',
    this.area = '',
    this.classification = '',
    this.businessSector = '',
    this.assignedRepresentativeId = '',
    this.status = CustomerStatus.prospect,
    this.potentialMinor = 0,
    this.creditLimitMinor,
    this.currency = 'EGP',
    this.notes = '',
  }) : contacts = List.unmodifiable(contacts);
  final String name;
  final CustomerType type;
  final List<CustomerContact> contacts;
  final String address, governorate, city, area, classification, businessSector;
  final String assignedRepresentativeId;
  final CustomerStatus status;
  final int potentialMinor;
  final int? creditLimitMinor;
  final String currency, notes;
}

class Customer {
  const Customer({
    required this.id,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
    this.archivedAt,
    this.remoteVersion,
    this.syncStatus = CustomerSyncStatus.pending,
  });
  final String id;
  final CustomerDraft data;
  final DateTime createdAt, updatedAt;
  final DateTime? archivedAt;
  final int revision;
  final String? remoteVersion;
  final CustomerSyncStatus syncStatus;
  bool get archived => archivedAt != null;
}

class CustomerActivity {
  const CustomerActivity({
    required this.id,
    required this.customerId,
    required this.type,
    required this.text,
    required this.occurredAt,
    required this.createdAt,
    this.sourceReference,
  });
  final String id, customerId, text;
  final ActivityType type;
  final DateTime occurredAt, createdAt;
  final String? sourceReference;
}

enum CustomerSort { name, newest, updated, potential }

class CustomerQuery {
  const CustomerQuery({
    this.search = '',
    this.governorate = '',
    this.city = '',
    this.type,
    this.classification = '',
    this.archived = false,
    this.sort = CustomerSort.name,
    this.descending = false,
  });
  final String search, governorate, city, classification;
  final CustomerType? type;
  final bool archived, descending;
  final CustomerSort sort;

  List<Customer> apply(Iterable<Customer> records) {
    final needle = normalizeText(search);
    final result = records.where((c) {
      final d = c.data;
      return c.archived == archived &&
          (governorate.isEmpty ||
              normalizeText(d.governorate) == normalizeText(governorate)) &&
          (city.isEmpty || normalizeText(d.city) == normalizeText(city)) &&
          (type == null || d.type == type) &&
          (classification.isEmpty ||
              normalizeText(d.classification) ==
                  normalizeText(classification)) &&
          (needle.isEmpty ||
              normalizeText(
                [
                  c.id,
                  d.name,
                  d.governorate,
                  d.city,
                  d.area,
                  ...d.contacts.expand((p) => [p.name, p.phone, p.email]),
                ].join(' '),
              ).contains(needle));
    }).toList();
    result.sort((a, b) {
      final compared = switch (sort) {
        CustomerSort.name => normalizeText(
          a.data.name,
        ).compareTo(normalizeText(b.data.name)),
        CustomerSort.newest => b.createdAt.compareTo(a.createdAt),
        CustomerSort.updated => b.updatedAt.compareTo(a.updatedAt),
        CustomerSort.potential => b.data.potentialMinor.compareTo(
          a.data.potentialMinor,
        ),
      };
      final stable = compared == 0 ? a.id.compareTo(b.id) : compared;
      return descending ? -stable : stable;
    });
    return result;
  }
}

String normalizeText(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
    .replaceAll(RegExp(r'\s+'), ' ');
String normalizePhone(String value) {
  var digits = value.replaceAll(RegExp(r'[^0-9٠-٩]'), '');
  for (var i = 0; i < 10; i++) {
    digits = digits.replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i');
  }
  return digits.startsWith('00') ? digits.substring(2) : digits;
}
