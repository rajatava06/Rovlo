import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart'; // context.rovlo extension
import '../../core/widgets/onboarding_scaffold.dart';
import '../../providers/auth_provider.dart';

/// Final profile step: pick travel interests to complete the profile.
class TravelPreferencesScreen extends StatefulWidget {
  const TravelPreferencesScreen({super.key});

  @override
  State<TravelPreferencesScreen> createState() =>
      _TravelPreferencesScreenState();
}

class _TravelPreferencesScreenState extends State<TravelPreferencesScreen> {
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _selected.addAll(
      context.read<AuthProvider>().currentUser?.travelInterests ??
          const <String>[],
    );
  }

  bool get _valid => _selected.length >= 3;

  Future<void> _finish() async {
    await context
        .read<AuthProvider>()
        .setTravelInterests(_selected.toList());
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, Routes.home, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 5,
      totalSteps: 5,
      title: 'What kind of traveller are you?',
      subtitle:
          'Pick at least 3. We\'ll use these to suggest trips you\'ll love.',
      continueEnabled: _valid,
      busy: context.watch<AuthProvider>().busy,
      continueLabel: _valid
          ? 'Finish (${_selected.length})'
          : 'Pick ${3 - _selected.length} more',
      onContinue: _finish,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < AppConstants.travelInterests.length; i++)
            _InterestChip(
              label: AppConstants.travelInterests[i],
              selected: _selected.contains(AppConstants.travelInterests[i]),
              onTap: () {
                setState(() {
                  final v = AppConstants.travelInterests[i];
                  _selected.contains(v)
                      ? _selected.remove(v)
                      : _selected.add(v);
                });
              },
            ).animate(delay: (30 * i).ms).fadeIn().scale(begin: const Offset(0.9, 0.9)),
        ],
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : context.rovlo.card,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : context.rovlo.textSecondary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 16, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : null,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
