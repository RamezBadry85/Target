import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:target/app/target_app.dart';

void main() {
  testWidgets('startup defaults to Arabic RTL and an honest empty state', (tester) async {
    await tester.pumpWidget(const TargetApp());
    await tester.pumpAndSettle();
    final context = tester.element(find.text('لوحة التحكم'));
    expect(Localizations.localeOf(context).languageCode, 'ar');
    expect(Directionality.of(context), TextDirection.rtl);
    expect(find.text('مساحة عمل جاهزة للتطوير'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 800.0, 1440.0]) {
    testWidgets('navigation and layout at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const TargetApp());
      await tester.pumpAndSettle();
      final desktop = width >= 1100;
      expect(find.byType(DrawerButton), desktop ? findsNothing : findsOneWidget);
      if (!desktop) {
        final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
        scaffold.openDrawer();
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('nav-customers')));
      await tester.pumpAndSettle();
      expect(find.text('العملاء'), desktop ? findsNWidgets(2) : findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('all modules are reachable; English switches direction', (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TargetApp());
    await tester.pumpAndSettle();
    for (final id in [
      'dashboard', 'customers', 'sales', 'quotations', 'opportunities',
      'follow_ups', 'sales_targets', 'collections', 'reports', 'settings',
    ]) {
      final item = find.byKey(ValueKey('nav-$id'));
      await tester.ensureVisible(item);
      await tester.tap(item);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Language'));
    expect(Localizations.localeOf(context).languageCode, 'en');
    expect(Directionality.of(context), TextDirection.ltr);
    expect(find.text('Settings'), findsNWidgets(2));
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(Directionality.of(tester.element(find.text('اللغة'))), TextDirection.rtl);
  });

  testWidgets('compact landscape supports large text without overflow', (tester) async {
    tester.view.physicalSize = const Size(568, 320);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const TargetApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
