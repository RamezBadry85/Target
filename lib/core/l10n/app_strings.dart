import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Centralized foundation strings. Move to ARB generation as copy expands.
class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;
  bool get isArabic => locale.languageCode == 'ar';
  String choose(String ar, String en) => isArabic ? ar : en;

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings)!;

  static const delegate = _AppStringsDelegate();
  String get appName => choose('تارجت', 'Target');
  String get workspace => choose('إدارة المبيعات', 'Sales workspace');
  String get navigation => choose('التنقل', 'Navigation');
  String get language => choose('اللغة', 'Language');
  String get emptyTitle =>
      choose('مساحة عمل جاهزة للتطوير', 'Workspace foundation');
  String get emptyBody => choose(
    'لم تتم إضافة وظائف الأعمال بعد. لا توجد بيانات تشغيلية لعرضها.',
    'Business functionality has not been added yet. No operational data to display.',
  );
  String get dashboardBody => choose(
    'مرحباً بك في تارجت. ستظهر مؤشرات الأداء بعد ربط مصادر البيانات في المراحل القادمة.',
    'Welcome to Target. Performance indicators will appear once data sources are connected in a future phase.',
  );
  String get foundation => choose(
    'المرحلة الأولى · تأسيس التطبيق',
    'Phase 1 · Application foundation',
  );
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture(AppStrings(locale));

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
