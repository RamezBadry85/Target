import 'dart:async';
import 'customer_dependencies.dart';
import '../features/customers/data/local_customer_repository.dart';
import '../core/logging/app_logger.dart';
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
  bool _localeChanged = false;
  final _dependencies = CustomerDependencies();
  Future<CustomerModule>? _module;
  Future<CustomerModule> _open() => _module ??= _initialize();
  Future<CustomerModule> _initialize() async {
    try { return await (widget.openCustomers?.call() ?? _dependencies.open()); }
    catch (_) { _module = null; rethrow; }
  }
  @override
  void initState() {
    super.initState();
    unawaited(_loadLocale());
  }
  Future<void> _loadLocale() async {
    try {
      final repo = (await _open()).repository;
      if (repo is LocalCustomerRepository) {
        final settings = await repo.readSettings();
        if (mounted && !_localeChanged && ['ar', 'en'].contains(settings['locale'])) setState(() => _locale = Locale(settings['locale']! as String));
      }
    } catch (error, stack) { AppLogger.error('Could not load preferences',error,stack); }
  }
  Future<void> _changeLocale(Locale locale) async {
    _localeChanged = true;
    setState(() => _locale = locale);
    try {
      final repo = (await _open()).repository;
      if (repo is LocalCustomerRepository) await repo.saveLocale(locale.languageCode);
    } catch (error,stack) { AppLogger.error('Could not save preferences',error,stack); }
  }
  @override
  void dispose() { unawaited(_dependencies.close()); super.dispose(); }


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
      openCustomers: _open,
      onLocaleChanged: (locale) => unawaited(_changeLocale(locale)),
    ),
  );
}
