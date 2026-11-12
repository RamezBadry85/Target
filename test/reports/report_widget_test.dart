import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:target/features/customers/data/customer_database.dart';
import 'package:target/features/customers/data/local_customer_repository.dart';
import 'package:target/features/customers/domain/customer_repository.dart';
import 'package:target/features/reports/presentation/reports_page.dart';
import '../customers/customer_repository_test.dart' show draft;
import '../customers/customer_widget_test.dart' show NoReports;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalCustomerRepository repository;
  late CustomerModule module;

  setUp(() async {
    repository = LocalCustomerRepository(
      await openCustomerDatabase(newDatabaseFactoryMemory(), 'report-widget'),
    );
    await repository.save(draft());
    module = CustomerModule(repository, NoReports());
  });
  tearDown(() => repository.close());

  testWidgets('report dashboard previews real filtered rows and all-record override', (tester) async {
    tester.view.physicalSize = const Size(900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: SingleChildScrollView(child: ReportsPage(openModule: () async => module))),
    ));
    await tester.pumpAndSettle();
    final governorateField = find.widgetWithText(TextField, 'المحافظة');
    expect(governorateField, findsOneWidget);
    await tester.enterText(governorateField, 'الجيزة');
    await tester.tap(find.text('معاينة / تحديث'));
    await tester.pumpAndSettle();
    expect(find.text('مؤسسة الاختبار'), findsNothing);
    expect(find.textContaining('عدد صفوف التقرير: 0'), findsOneWidget);

    await tester.tap(find.text('كل السجلات (تجاهل عوامل التصفية)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('معاينة / تحديث'));
    await tester.pumpAndSettle();
    expect(find.text('مؤسسة الاختبار'), findsOneWidget);
    expect(find.textContaining('عدد صفوف التقرير: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
