import 'package:flutter/material.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/presentation/feature_placeholder.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) => FeaturePlaceholder(
    icon: Icons.dashboard_outlined,
    description: AppStrings.of(context).dashboardBody,
  );
}
