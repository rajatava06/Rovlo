import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import '../../providers/auth_provider.dart';

/// Profile step: capture date of birth. Must be 16+.
class DobScreen extends StatefulWidget {
  const DobScreen({super.key});

  @override
  State<DobScreen> createState() => _DobScreenState();
}

class _DobScreenState extends State<DobScreen> {
  DateTime? _selectedDate;
  String? _error;

  bool get _valid => _selectedDate != null && _calculateAge(_selectedDate!) >= 16;

  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      helpText: 'Select your date of birth',
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.primaryVibrantDark,
                    onPrimary: Colors.white,
                    surface: AppColors.darkSurface,
                  )
                : const ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final age = _calculateAge(picked);
      setState(() {
        _selectedDate = picked;
        if (age < 16) {
          _error = 'You must be at least 16 years old to use Rovlo.';
        } else {
          _error = null;
        }
      });
    }
  }

  Future<void> _continue() async {
    if (_selectedDate == null) return;
    await context.read<AuthProvider>().setDob(_selectedDate!.toIso8601String());
    if (!mounted) return;
    Navigator.pushNamed(context, Routes.travel);
  }

  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryPeach = isDark ? AppColors.primaryVibrantDark : AppColors.primary;

    return OnboardingScaffold(
      step: 5,
      totalSteps: 7,
      title: 'When were you born?',
      subtitle: 'We use this to verify your age. You must be 16 or older.',
      continueEnabled: _valid,
      onContinue: _continue,
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedDate != null
                      ? primaryPeach
                      : (isDark ? Colors.white24 : Colors.black12),
                  width: _selectedDate != null ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cake_outlined,
                    color: _selectedDate != null ? primaryPeach : Colors.grey,
                  ),
                  const SizedBox(width: 14),
                  Text(
                    _selectedDate != null
                        ? _formatDate(_selectedDate!)
                        : 'Tap to select your date of birth',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: _selectedDate != null ? FontWeight.w600 : FontWeight.w400,
                      color: _selectedDate != null
                          ? (isDark ? Colors.white : Colors.black87)
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_selectedDate != null && _error == null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Age: ${_calculateAge(_selectedDate!)} years — You\'re good to go!',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
