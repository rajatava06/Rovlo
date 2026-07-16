import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Placeholder "Saved trips" tab — ready to be wired to real saved data.
class SavedTab extends StatelessWidget {
  const SavedTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text('Saved trips',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Your bookmarked destinations live here.',
                style: TextStyle(color: context.rovlo.textSecondary)),
            const Spacer(),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                    child: const Icon(Icons.bookmark_border,
                        size: 44, color: AppColors.primary),
                  ).animate().scale(duration: 400.ms, curve: Curves.easeOut),
                  const SizedBox(height: 16),
                  const Text('No saved trips yet',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Tap the heart on a destination to save it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.rovlo.textSecondary)),
                ],
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
