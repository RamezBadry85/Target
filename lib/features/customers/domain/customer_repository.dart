import 'dart:typed_data';
import 'customer.dart';

abstract interface class CustomerActivityRecorder {
  Future<void> addActivity(
    String customerId,
    int expectedRevision,
    ActivityType type,
    String text,
    DateTime occurredAt, {
    String? sourceReference,
  });
}

abstract interface class CustomerRepository
    implements CustomerActivityRecorder {
  Stream<List<Customer>> watchAll();
  Future<List<Customer>> all();
  Future<Customer> save(
    CustomerDraft draft, {
    String? id,
    int? expectedRevision,
  });
  Future<Customer> setArchived(String id, int expectedRevision, bool archived);
  Future<List<CustomerActivity>> activities(String customerId);
  Future<Uint8List> backup();

  /// Restore only into an empty workspace; never silently overwrite newer data.
  Future<void> restore(Uint8List bytes);
  Future<void> close();
}

abstract interface class CustomerReports {
  Future<Uint8List> xlsx(List<Customer> customers, {required bool arabic});
  Future<Uint8List> pdf(
    List<Customer> customers, {
    required bool arabic,
    required String filters,
    required DateTime generatedAt,
  });
}

class CustomerModule {
  const CustomerModule(this.repository, this.reports);
  final CustomerRepository repository;
  final CustomerReports reports;
}
