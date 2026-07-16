import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart'; // context.rovlo extension

/// Shared layout for the multi-step profile-setup screens: a progress bar,
/// a title + subtitle, a body, and a pinned primary action at the bottom.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onContinue,
    this.continueLabel = 'Continue',
    this.continueEnabled = true,
    this.busy = false,
    this.onBack,
    this.trailing,
  });

  final int step;
  final int totalSteps;
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onContinue;
  final String continueLabel;
  final bool continueEnabled;
  final bool busy;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final progress = step / totalSteps;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (onBack != null || Navigator.canPop(context))
                    IconButton(
                      onPressed: onBack ?? () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            context.rovlo.card,
                        shape: const CircleBorder(),
                      ),
                    ),
                  const Spacer(),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: context.rovlo.textSecondary
                        .withValues(alpha: 0.15),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Step $step of $totalSteps',
                style: TextStyle(
                  color: context.rovlo.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.15),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: context.rovlo.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ).animate(delay: 80.ms).fadeIn(duration: 400.ms),
              const SizedBox(height: 28),
              Expanded(
                child: SingleChildScrollView(child: child)
                    .animate(delay: 140.ms)
                    .fadeIn(duration: 450.ms),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (continueEnabled && !busy) ? onContinue : null,
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(continueLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
