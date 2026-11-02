import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/customers/presentation/customers_page.dart';
import '../features/sales/presentation/sales_page.dart';
import '../features/quotations/presentation/quotations_page.dart';
import '../features/opportunities/presentation/opportunities_page.dart';
import '../features/follow_ups/presentation/follow_ups_page.dart';
import '../features/sales_targets/presentation/sales_targets_page.dart';
import '../features/collections/presentation/collections_page.dart';
import '../features/reports/presentation/reports_page.dart';
import '../features/settings/presentation/settings_page.dart';

class AppDestination {
  const AppDestination({required this.id, required this.arabic,
    required this.english, required this.icon, required this.page});
  final String id;
  final String arabic;
  final String english;
  final IconData icon;
  final Widget page;

  String label(AppStrings strings) => strings.choose(arabic, english);

  static List<AppDestination> all(ValueChanged<Locale> onLocaleChanged) => [
    AppDestination(id: 'dashboard', arabic: 'لوحة التحكم', english: 'Dashboard', icon: Icons.dashboard_outlined, page: const DashboardPage()),
    AppDestination(id: 'customers', arabic: 'العملاء', english: 'Customers', icon: Icons.people_outline, page: const CustomersPage()),
    AppDestination(id: 'sales', arabic: 'المبيعات', english: 'Sales', icon: Icons.receipt_long_outlined, page: const SalesPage()),
    AppDestination(id: 'quotations', arabic: 'عروض الأسعار', english: 'Quotations', icon: Icons.request_quote_outlined, page: const QuotationsPage()),
    AppDestination(id: 'opportunities', arabic: 'الفرص البيعية', english: 'Opportunities', icon: Icons.trending_up, page: const OpportunitiesPage()),
    AppDestination(id: 'follow_ups', arabic: 'المتابعات', english: 'Follow-ups', icon: Icons.event_note_outlined, page: const FollowUpsPage()),
    AppDestination(id: 'sales_targets', arabic: 'أهداف المبيعات', english: 'Sales targets', icon: Icons.flag_outlined, page: const SalesTargetsPage()),
    AppDestination(id: 'collections', arabic: 'التحصيلات', english: 'Collections', icon: Icons.account_balance_wallet_outlined, page: const CollectionsPage()),
    AppDestination(id: 'reports', arabic: 'التحليلات والتقارير', english: 'Analytics & reports', icon: Icons.bar_chart_outlined, page: const ReportsPage()),
    AppDestination(id: 'settings', arabic: 'الإعدادات', english: 'Settings', icon: Icons.settings_outlined, page: SettingsPage(onLocaleChanged: onLocaleChanged)),
  ];
}
