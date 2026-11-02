import 'dart:async';
import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/presentation/responsive_layout.dart';
import '../core/theme/app_theme.dart';
import 'app_destination.dart';
import 'customer_dependencies.dart';
import '../features/customers/domain/customer_repository.dart';

/// Session-only UI state. Business state belongs in feature controllers/use cases.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.onLocaleChanged,
    this.openCustomers,
  });
  final Future<CustomerModule> Function()? openCustomers;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  final _customers = CustomerDependencies();
  @override
  void dispose() {
    unawaited(_customers.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final destinations = AppDestination.all(
      widget.onLocaleChanged,
      openCustomers: widget.openCustomers ?? _customers.open,
    );
    final selected = destinations[_selectedIndex];

    Widget navigation({required bool drawer}) => SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.appName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(strings.workspace),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.small),
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final destination = destinations[index];
                return ListTile(
                  key: ValueKey('nav-${destination.id}'),
                  selected: index == _selectedIndex,
                  selectedTileColor: AppTheme.background,
                  leading: Icon(destination.icon),
                  title: Text(destination.label(strings)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onTap: () {
                    if (drawer) Navigator.of(context).pop();
                    setState(() => _selectedIndex = index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = ResponsiveLayout.usesSidebar(constraints.maxWidth);
        return Scaffold(
          appBar: AppBar(
            title: Text(selected.label(strings)),
            actions: [
              PopupMenuButton<String>(
                tooltip: strings.language,
                icon: const Icon(Icons.language),
                onSelected: (code) => widget.onLocaleChanged(Locale(code)),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'ar', child: Text('العربية')),
                  PopupMenuItem(value: 'en', child: Text('English')),
                ],
              ),
              const SizedBox(width: AppSpacing.small),
            ],
          ),
          drawer: desktop ? null : Drawer(child: navigation(drawer: true)),
          body: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (desktop) ...[
                  SizedBox(
                    width: 280,
                    child: Material(
                      color: Colors.white,
                      child: navigation(drawer: false),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(
                      constraints.maxWidth < ResponsiveLayout.compactBreakpoint
                          ? AppSpacing.medium
                          : AppSpacing.extraLarge,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          strings.foundation,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: AppSpacing.large),
                        KeyedSubtree(
                          key: ValueKey(selected.id),
                          child: selected.page,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
