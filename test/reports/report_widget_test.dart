import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:target/features/reports/presentation/reports_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final locale in ['ar', 'en']) {
    testWidgets('report dashboard renders in $locale', (tester) async {
      tester.view.physicalSize = const Size(900, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        locale: Locale(locale),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReportsPage(
              openModule: () async => throw StateError('Smoke test does not export'),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(find.text(locale == 'ar' ? 'مركز التقارير' : 'Reports dashboard'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('XLSX'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
