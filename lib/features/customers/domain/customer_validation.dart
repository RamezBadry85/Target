import 'customer.dart';

enum CustomerProblem {
  validation,
  duplicate,
  staleEdit,
  missing,
  storage,
  invalidBackup,
  conflict,
}

class CustomerException implements Exception {
  const CustomerException(
    this.problem, {
    this.fields = const [],
    this.relatedId,
  });
  final CustomerProblem problem;
  final List<String> fields;
  final String? relatedId;
}

abstract final class CustomerValidation {
  static bool phone(String value, {bool optional = false}) =>
      (optional && value.trim().isEmpty) ||
      (RegExp(r'^\+?[0-9٠-٩()\s-]+$').hasMatch(value.trim()) &&
          normalizePhone(value).length >= 7 &&
          normalizePhone(value).length <= 15);
  static bool email(String value) =>
      value.trim().isEmpty ||
      (value.length <= 254 &&
          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim()));
  static int? parseMoney(String text) {
    if (!RegExp(r'^\d{1,12}(\.\d{1,2})?$').hasMatch(text.trim())) return null;
    final parts = text.trim().split('.');
    return int.parse(parts.first) * 100 +
        (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  }

  static String money(int value) =>
      '${value ~/ 100}.${(value % 100).toString().padLeft(2, '0')}';
  static List<String> errors(CustomerDraft d) {
    final errors = <String>[];
    if (d.name.trim().length < 2 || d.name.length > 200) errors.add('name');
    if (d.contacts.isEmpty || d.contacts.length > 50) errors.add('contacts');
    final ids = <String>{};
    for (final c in d.contacts) {
      if (c.id.isEmpty || !ids.add(c.id)) errors.add('contacts');
      if (!phone(c.phone) || !phone(c.alternativePhone, optional: true)) {
        errors.add('phone');
      }
      if (!email(c.email)) errors.add('email');
      if (c.name.length > 200) errors.add('contactName');
    }
    if (d.potentialMinor < 0 ||
        d.potentialMinor > 99999999999999 ||
        (d.creditLimitMinor != null &&
            (d.creditLimitMinor! < 0 ||
                d.creditLimitMinor! > 99999999999999))) {
      errors.add('money');
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(d.currency)) errors.add('currency');
    if ([
          d.address,
          d.governorate,
          d.city,
          d.area,
          d.classification,
          d.businessSector,
          d.assignedRepresentativeId,
        ].any((v) => v.length > 500) ||
        d.notes.length > 10000) {
      errors.add('length');
    }
    return errors.toSet().toList();
  }

  static void validate(CustomerDraft d) {
    final fields = errors(d);
    if (fields.isNotEmpty) {
      throw CustomerException(CustomerProblem.validation, fields: fields);
    }
  }

  static bool duplicate(CustomerDraft a, CustomerDraft b) {
    if (normalizeText(a.name) == normalizeText(b.name) &&
        normalizeText(a.governorate) == normalizeText(b.governorate) &&
        normalizeText(a.city) == normalizeText(b.city)) {
      return true;
    }
    final phones = a.contacts
        .expand((c) => [c.phone, c.alternativePhone])
        .map(normalizePhone)
        .where((p) => p.isNotEmpty)
        .toSet();
    final emails = a.contacts
        .map((c) => c.email.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    return b.contacts.any(
      (c) =>
          [c.phone, c.alternativePhone]
              .map(normalizePhone)
              .any((p) => p.isNotEmpty && phones.contains(p)) ||
          (c.email.isNotEmpty && emails.contains(c.email.trim().toLowerCase())),
    );
  }
}
