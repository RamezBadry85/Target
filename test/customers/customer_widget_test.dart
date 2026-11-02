import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:target/features/customers/data/customer_database.dart';
import 'package:target/features/customers/data/local_customer_repository.dart';
import 'package:target/features/customers/domain/customer.dart';
import 'package:target/features/customers/domain/customer_repository.dart';
import 'package:target/features/customers/presentation/customers_page.dart';
import 'customer_repository_test.dart' show draft;

class NoReports implements CustomerReports {
  @override
  Future<Uint8List> xlsx(List<Customer> customers, {required bool arabic}) =>
      throw UnimplementedError();
  @override
  Future<Uint8List> pdf(
    List<Customer> customers, {
    required bool arabic,
    required String filters,
    required DateTime generatedAt,
  }) => throw UnimplementedError();
}

Widget app(CustomerModule module, {String locale = 'ar'}) => MaterialApp(
  locale: Locale(locale),
  supportedLocales: const [Locale('ar'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(
    body: SingleChildScrollView(
      child: CustomersPage(openModule: () async => module),
    ),
  ),
);
void main() {
  late LocalCustomerRepository repo;
  late CustomerModule module;
  setUp(() async {
    repo = LocalCustomerRepository(
      await openCustomerDatabase(newDatabaseFactoryMemory(), 'widget.db'),
    );
    module = CustomerModule(repo, NoReports());
  });
  tearDown(() async => repo.close());
  for (final width in [360.0, 1440.0]) {
    testWidgets('Arabic customers renders RTL at $width without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => repo.save(draft()));
      await tester.pumpWidget(app(module));
      await tester.pumpAndSettle();
      expect(find.text('مؤسسة الاختبار'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('قائمة العملاء'))),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('add form validates and saves a customer locally', (
    tester,
  ) async {
    await tester.pumpWidget(app(module));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-customer')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('customer-name')),
      'عميل من النموذج',
    );
    final phone = find.byKey(const ValueKey('contact-0-phone'));
    await tester.ensureVisible(phone);
    await tester.enterText(phone, '01055556666');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('save-customer'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(save);
      await repo.all();
    });
    await tester.pumpAndSettle();
    expect(
      (await tester.runAsync(repo.all))!.single.data.name,
      'عميل من النموذج',
    );
    expect(await tester.runAsync(repo.pendingChanges), hasLength(1));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'English customer workspace is LTR and searching updates matches',
    (tester) async {
      await tester.runAsync(() => repo.save(draft(name: 'Customer Alpha')));
      await tester.pumpWidget(app(module, locale: 'en'));
      await tester.pumpAndSettle();
      expect(
        Directionality.of(tester.element(find.text('Customer list'))),
        TextDirection.ltr,
      );
      await tester.enterText(
        find.byKey(const ValueKey('customer-search')),
        'missing',
      );
      await tester.pumpAndSettle();
      expect(find.text('Customer Alpha'), findsNothing);
    },
  );
}
