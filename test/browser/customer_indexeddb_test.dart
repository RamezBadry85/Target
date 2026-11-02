@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast_web/sembast_web.dart';
import 'package:target/features/customers/data/customer_database.dart';
import 'package:target/features/customers/data/local_customer_repository.dart';
import 'package:target/features/customers/domain/customer.dart';

void main() {
  test(
    'IndexedDB retains offline customer/outbox after close and reopen',
    () async {
      final path = 'target-browser-${DateTime.now().microsecondsSinceEpoch}';
      var repo = LocalCustomerRepository(
        await openCustomerDatabase(databaseFactoryWeb, path),
      );
      final c = await repo.save(
        CustomerDraft(
          name: 'اختبار المتصفح',
          contacts: [
            const CustomerContact(
              id: 'browser-contact',
              name: 'اختبار',
              phone: '01011112222',
            ),
          ],
        ),
      );
      await repo.close();
      repo = LocalCustomerRepository(
        await openCustomerDatabase(databaseFactoryWeb, path),
      );
      expect((await repo.all()).single.id, c.id);
      expect((await repo.pendingChanges()).single.customerId, c.id);
      await repo.close();
      await databaseFactoryWeb.deleteDatabase(path);
    },
  );
}
