import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import '../../providers/auth_provider.dart';

/// Final profile step: pick travel interests in a 2-column grid layout.
class TravelPreferencesScreen extends StatefulWidget {
  const TravelPreferencesScreen({super.key});

  @override
  State<TravelPreferencesScreen> createState() =>
      _TravelPreferencesScreenState();
}

class _TravelPreferencesScreenState extends State<TravelPreferencesScreen> {
  static const List<String> _interests = [
    'Beaches',
    'Mountains',
    'City breaks',
    'Road Trips',
    'Backpacking',
    'Luxury Stays',
    'Food & Wine',
    'Culture & History',
    'Adventure sports',
    'Wildlife & nature',
    'Nightlife',
    'Wellness & Spa',
    'Solo travel',
    'Family friendly',
  ];

  final Set<String> _selected = {
    'Beaches',
    'Mountains',
    'City breaks',
    'Road Trips',
    'Backpacking',
    'Luxury Stays',
    'Food & Wine',
  };

  @override
  void initState() {
    super.initState();
    final existing = context.read<AuthProvider>().currentUser?.travelInterests;
    if (existing != null && existing.isNotEmpty) {
      _selected.clear();
      _selected.addAll(existing);
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return OnboardingScaffold(
      step: 6,
      totalSteps: 7,
      title: 'What kind of traveller are you?',
      subtitle:
          'Pick at least 3. We\'ll use these to suggest trips you\'ll love.',
      continueEnabled: _valid,
      busy: context.watch<AuthProvider>().busy,
      continueLabel: _valid
          ? 'Finish(${_selected.length})'
          : 'Pick ${3 - _selected.length} more',
      onContinue: _finish,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in _interests)
                  SizedBox(
                    width: cardWidth,
                    child: _TravellerChip(
                      label: item,
                      selected: _selected.contains(item),
                      isDark: isDark,
                      onTap: () {
                        setState(() {
                          if (_selected.contains(item)) {
                            _selected.remove(item);
                          } else {
                            _selected.add(item);
                          }
                        });
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TravellerChip extends StatelessWidget {
  const _TravellerChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF309AE1);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? primaryBlue
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? primaryBlue
                : (isDark
                    ? Colors.white12
                    : const Color(0xFFE2E8F0)),
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check,
              size: 16,
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
