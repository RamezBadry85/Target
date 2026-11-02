import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:target/app/app_destination.dart';
import 'package:target/core/errors/app_failure.dart';
import 'package:target/core/l10n/app_strings.dart';
import 'package:target/core/presentation/responsive_layout.dart';

void main() {
  test('all ten feature destinations have unique stable identifiers', () {
    final destinations = AppDestination.all((_) {});
    expect(destinations, hasLength(10));
    expect(destinations.map((item) => item.id).toSet(), hasLength(10));
    expect(destinations.first.id, 'dashboard');
    expect(destinations.last.id, 'settings');
  });

  test('foundation copy supports Arabic and English', () {
    const arabic = AppStrings(Locale('ar'));
    const english = AppStrings(Locale('en'));
    expect(arabic.appName, 'تارجت');
    expect(english.appName, 'Target');
    for (final destination in AppDestination.all((_) {})) {
      expect(destination.label(arabic), isNotEmpty);
      expect(destination.label(english), isNotEmpty);
    }
  });

  test('sidebar breakpoint includes the desktop boundary', () {
    expect(ResponsiveLayout.usesSidebar(360), isFalse);
    expect(ResponsiveLayout.usesSidebar(800), isFalse);
    expect(ResponsiveLayout.usesSidebar(1099), isFalse);
    expect(ResponsiveLayout.usesSidebar(1100), isTrue);
    expect(ResponsiveLayout.usesSidebar(1440), isTrue);
  });

  test('failure contract exposes a code without infrastructure details', () {
    const failure = AppFailure(FailureKind.storage);
    expect(failure.kind, FailureKind.storage);
    expect(failure, isA<Exception>());
  });
}
