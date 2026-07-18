import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import '../../providers/auth_provider.dart';

/// Profile step: capture gender.
class GenderScreen extends StatefulWidget {
  const GenderScreen({super.key});

  @override
  State<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends State<GenderScreen> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = context.read<AuthProvider>().currentUser?.gender;
  }

  Future<void> _continue() async {
    if (_selected == null) return;
    await context.read<AuthProvider>().setGender(_selected!);
    if (!mounted) return;
    Navigator.pushNamed(context, Routes.dob);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 3,
      totalSteps: 6,
      title: 'How do you identify?',
      subtitle: 'Helps us tailor recommendations. You can change this later.',
      continueEnabled: _selected != null,
      onContinue: _continue,
      child: Column(
        children: [
          for (var i = 0; i < AppConstants.genderOptions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GenderTile(
                label: AppConstants.genderOptions[i],
                selected: _selected == AppConstants.genderOptions[i],
                onTap: () => setState(
                    () => _selected = AppConstants.genderOptions[i]),
              ).animate(delay: (60 * i).ms).fadeIn().slideX(begin: 0.1),
            ),
        ],
      ),
    );
  }
}

class _GenderTile extends StatelessWidget {
  const _GenderTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : context.rovlo.card,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: selected
              ? AppColors.primary
              : context.rovlo.textSecondary.withValues(alpha: 0.15),
          width: selected ? 1.8 : 1,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        onTap: onTap,
        title: Text(label,
            style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
        trailing: AnimatedScale(
          scale: selected ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: const Icon(Icons.check_circle, color: AppColors.primary),
        ),
      ),
    );
  }
}
