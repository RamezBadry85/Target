import 'package:flutter/services.dart';
import '../features/customers/data/local_customer_repository.dart';
import '../features/customers/data/open_database.dart';
import '../features/customers/data/customer_report_exporter.dart';
import '../features/customers/domain/customer_repository.dart';

/// One lazily opened database per application shell, not per feature rebuild.
class CustomerDependencies {
  Future<CustomerModule>? _module;
  Future<CustomerModule> open() => _module ??= _open();
  Future<CustomerModule> _open() async {
    try {
      final fonts = await Future.wait([
        rootBundle.load('assets/fonts/Amiri-Regular.ttf'),
        rootBundle.load('assets/fonts/Amiri-Bold.ttf'),
      ]);
      final db = await openLocalCustomerDatabase();
      return CustomerModule(
        LocalCustomerRepository(db),
        CustomerReportExporter(
          regularFont: fonts[0].buffer.asUint8List(),
          boldFont: fonts[1].buffer.asUint8List(),
        ),
      );
    } catch (_) {
      _module = null;
      rethrow;
    }
  }

  Future<void> close() async {
    final module = _module;
    if (module != null) {
      try {
        await (await module).repository.close();
      } catch (_) {
        /* Failed initialization has no open database to close. */
      }
    }
  }
}
