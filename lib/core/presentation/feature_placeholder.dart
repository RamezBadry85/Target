import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

/// Explicit empty state, not simulated business activity.
class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({super.key, required this.icon, this.description});

  final IconData icon;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.extraLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: AppTheme.navy),
                const SizedBox(height: AppSpacing.large),
                Text(
                  strings.emptyTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.medium),
                Text(
                  description ?? strings.emptyBody,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
