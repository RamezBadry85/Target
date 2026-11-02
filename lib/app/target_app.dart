import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme/app_theme.dart';
import 'app_shell.dart';
import '../features/customers/domain/customer_repository.dart';

class TargetApp extends StatefulWidget {
  const TargetApp({super.key, this.openCustomers});
  final Future<CustomerModule> Function()? openCustomers;

  @override
  State<TargetApp> createState() => _TargetAppState();
}

class _TargetAppState extends State<TargetApp> {
  Locale _locale = const Locale('ar');

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    onGenerateTitle: (context) => AppStrings.of(context).appName,
    theme: AppTheme.light,
    locale: _locale,
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      AppStrings.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: AppShell(
      openCustomers: widget.openCustomers,
      onLocaleChanged: (locale) => setState(() => _locale = locale),
    ),
  );
}
