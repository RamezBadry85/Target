import 'package:flutter_test/flutter_test.dart';
import 'package:target/features/customers/domain/customer.dart';
import 'package:target/features/customers/domain/customer_validation.dart';
import 'customer_repository_test.dart' show draft;

void main() {
  test('required names and contact phone validation', () {
    expect(
      CustomerValidation.errors(CustomerDraft(name: '')),
      containsAll(['name', 'contacts']),
    );
    expect(CustomerValidation.errors(draft(phone: 'bad')), contains('phone'));
    expect(CustomerValidation.errors(draft()), isEmpty);
  });
  test('phone formats include international and Arabic numerals', () {
    expect(CustomerValidation.phone('+20 (10) 1234-5678'), isTrue);
    expect(CustomerValidation.phone('٠١٠١٢٣٤٥٦٧٨'), isTrue);
    expect(CustomerValidation.phone('123'), isFalse);
    expect(CustomerValidation.phone('+1234567890123456'), isFalse);
    expect(normalizePhone('0020 1012345678'), normalizePhone('+20 1012345678'));
  });
  test(
    'email format rejects malformed addresses without requiring optional email',
    () {
      expect(CustomerValidation.email(''), isTrue);
      expect(CustomerValidation.email('user@example.com'), isTrue);
      expect(CustomerValidation.email('bad@'), isFalse);
      expect(CustomerValidation.email('a b@example.com'), isFalse);
    },
  );
  test('decimal currency parsing is exact and bounded', () {
    expect(CustomerValidation.parseMoney('12.05'), 1205);
    expect(CustomerValidation.parseMoney('0.01'), 1);
    expect(CustomerValidation.parseMoney('-1'), isNull);
    expect(CustomerValidation.parseMoney('1.001'), isNull);
    expect(CustomerValidation.parseMoney('NaN'), isNull);
    expect(CustomerValidation.money(1205), '12.05');
  });
  test('contacts are an immutable multi-contact structure', () {
    final d = draft();
    expect(() => d.contacts.clear(), throwsUnsupportedError);
  });
}
