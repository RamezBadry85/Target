import '../domain/customer.dart';

abstract final class CustomerCodec {
  static Map<String, Object?> draft(CustomerDraft d) => {
    'name': d.name.trim(),
    'type': d.type.name,
    'contacts': d.contacts
        .map(
          (c) => {
            'id': c.id,
            'name': c.name.trim(),
            'phone': c.phone.trim(),
            'alternativePhone': c.alternativePhone.trim(),
            'email': c.email.trim(),
          },
        )
        .toList(),
    'address': d.address.trim(),
    'governorate': d.governorate.trim(),
    'city': d.city.trim(),
    'area': d.area.trim(),
    'classification': d.classification.trim(),
    'businessSector': d.businessSector.trim(),
    'assignedRepresentativeId': d.assignedRepresentativeId.trim(),
    'status': d.status.name,
    'potentialMinor': d.potentialMinor,
    'creditLimitMinor': d.creditLimitMinor,
    'currency': d.currency,
    'notes': d.notes.trim(),
  };
  static CustomerDraft readDraft(Map<String, Object?> m) => CustomerDraft(
    name: m['name'] as String,
    type: CustomerType.values.byName(m['type'] as String),
    contacts: (m['contacts'] as List<Object?>).map((raw) {
      final c = Map<String, Object?>.from(raw as Map<Object?, Object?>);
      return CustomerContact(
        id: c['id'] as String,
        name: c['name'] as String,
        phone: c['phone'] as String,
        alternativePhone: c['alternativePhone'] as String? ?? '',
        email: c['email'] as String? ?? '',
      );
    }).toList(),
    address: m['address'] as String? ?? '',
    governorate: m['governorate'] as String? ?? '',
    city: m['city'] as String? ?? '',
    area: m['area'] as String? ?? '',
    classification: m['classification'] as String? ?? '',
    businessSector: m['businessSector'] as String? ?? '',
    assignedRepresentativeId: m['assignedRepresentativeId'] as String? ?? '',
    status: CustomerStatus.values.byName(m['status'] as String),
    potentialMinor: m['potentialMinor'] as int,
    creditLimitMinor: m['creditLimitMinor'] as int?,
    currency: m['currency'] as String,
    notes: m['notes'] as String? ?? '',
  );
  static Map<String, Object?> customer(Customer c) => {
    'id': c.id,
    'data': draft(c.data),
    'createdAt': c.createdAt.toUtc().toIso8601String(),
    'updatedAt': c.updatedAt.toUtc().toIso8601String(),
    'archivedAt': c.archivedAt?.toUtc().toIso8601String(),
    'revision': c.revision,
    'remoteVersion': c.remoteVersion,
    'syncStatus': c.syncStatus.name,
  };
  static Customer read(Map<String, Object?> m) => Customer(
    id: m['id'] as String,
    data: readDraft(
      Map<String, Object?>.from(m['data'] as Map<Object?, Object?>),
    ),
    createdAt: DateTime.parse(m['createdAt'] as String).toUtc(),
    updatedAt: DateTime.parse(m['updatedAt'] as String).toUtc(),
    archivedAt: m['archivedAt'] == null
        ? null
        : DateTime.parse(m['archivedAt'] as String).toUtc(),
    revision: m['revision'] as int,
    remoteVersion: m['remoteVersion'] as String?,
    syncStatus: CustomerSyncStatus.values.byName(m['syncStatus'] as String),
  );
  static Map<String, Object?> activity(CustomerActivity a) => {
    'id': a.id,
    'customerId': a.customerId,
    'type': a.type.name,
    'text': a.text,
    'occurredAt': a.occurredAt.toUtc().toIso8601String(),
    'createdAt': a.createdAt.toUtc().toIso8601String(),
    'sourceReference': a.sourceReference,
  };
  static CustomerActivity readActivity(Map<String, Object?> m) =>
      CustomerActivity(
        id: m['id'] as String,
        customerId: m['customerId'] as String,
        type: ActivityType.values.byName(m['type'] as String),
        text: m['text'] as String,
        occurredAt: DateTime.parse(m['occurredAt'] as String).toUtc(),
        createdAt: DateTime.parse(m['createdAt'] as String).toUtc(),
        sourceReference: m['sourceReference'] as String?,
      );
}
