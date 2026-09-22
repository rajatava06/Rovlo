import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import '../../providers/auth_provider.dart';

/// Profile step: capture date of birth with custom 3-column scroll wheel.
/// Must be 16+.
class DobScreen extends StatefulWidget {
  const DobScreen({super.key});

  @override
  State<DobScreen> createState() => _DobScreenState();
}

class _DobScreenState extends State<DobScreen> {
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  late final List<int> _days;
  late final List<int> _years;

  int _selectedMonthIndex = 3; // Apr (0-indexed)
  int _selectedDay = 10;
  int _selectedYear = 2005;

  late final FixedExtentScrollController _monthController;
  late final FixedExtentScrollController _dayController;
  late final FixedExtentScrollController _yearController;

  @override
  void initState() {
    super.initState();
    _days = List.generate(31, (i) => i + 1);
    final currentYear = DateTime.now().year;
    _years = List.generate(currentYear - 1930 + 1, (i) => 1930 + i);

    final existingDob = context.read<AuthProvider>().currentUser?.dob;
    if (existingDob != null) {
      final parsed = DateTime.tryParse(existingDob);
      if (parsed != null) {
        _selectedMonthIndex = parsed.month - 1;
        _selectedDay = parsed.day;
        _selectedYear = parsed.year;
      }
    }

    _monthController = FixedExtentScrollController(initialItem: _selectedMonthIndex);
    _dayController = FixedExtentScrollController(initialItem: _days.indexOf(_selectedDay));
    _yearController = FixedExtentScrollController(initialItem: _years.indexOf(_selectedYear));
  }

  @override
  void dispose() {
    _monthController.dispose();
    _dayController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  DateTime get _selectedDate => DateTime(
        _selectedYear,
        _selectedMonthIndex + 1,
        _selectedDay.clamp(1, _getDaysInMonth(_selectedYear, _selectedMonthIndex + 1)),
      );

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  bool get _valid => _calculateAge(_selectedDate) >= 16;

  Future<void> _continue() async {
    if (!_valid) return;
    await context.read<AuthProvider>().setDob(_selectedDate.toIso8601String());
    if (!mounted) return;
    Navigator.pushNamed(context, Routes.travel);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final unselectedTextColor = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : const Color(0xFFA0AEC0);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : const Color(0xFFCBD5E1);

    final maxDays = _getDaysInMonth(_selectedYear, _selectedMonthIndex + 1);

    return OnboardingScaffold(
      step: 5,
      totalSteps: 7,
      title: 'When were you born?',
      subtitle: 'We use this to verify your age. You must be 16 or older.',
      continueEnabled: _valid,
      onContinue: _continue,
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Custom 3-column wheel date picker matching editorial mock
          Center(
            child: SizedBox(
              height: 200,
              child: Stack(
                children: [
                  // Center selection divider lines
                  Center(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: dividerColor, width: 1.2),
                          bottom: BorderSide(color: dividerColor, width: 1.2),
                        ),
                      ),
                    ),
                  ),

                  // 3 Wheel Columns
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Month Column
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: _monthController,
                          itemExtent: 52,
                          selectionOverlay: const SizedBox.shrink(),
                          onSelectedItemChanged: (idx) {
                            setState(() {
                              _selectedMonthIndex = idx;
                            });
                          },
                          children: _months.map((m) {
                            final isSelected = _months.indexOf(m) == _selectedMonthIndex;
                            return Center(
                              child: Text(
                                m,
                                style: GoogleFonts.newsreader(
                                  fontSize: 26,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                  color: isSelected ? selectedTextColor : unselectedTextColor,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // Day Column
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: _dayController,
                          itemExtent: 52,
                          selectionOverlay: const SizedBox.shrink(),
                          onSelectedItemChanged: (idx) {
                            setState(() {
                              _selectedDay = _days[idx].clamp(1, maxDays);
                            });
                          },
                          children: _days.map((d) {
                            final isSelected = d == _selectedDay;
                            return Center(
                              child: Text(
                                d.toString().padLeft(2, '0'),
                                style: GoogleFonts.newsreader(
                                  fontSize: 26,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                  color: isSelected ? selectedTextColor : unselectedTextColor,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // Year Column
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: _yearController,
                          itemExtent: 52,
                          selectionOverlay: const SizedBox.shrink(),
                          onSelectedItemChanged: (idx) {
                            setState(() {
                              _selectedYear = _years[idx];
                            });
                          },
                          children: _years.map((y) {
                            final isSelected = y == _selectedYear;
                            return Center(
                              child: Text(
                                y.toString(),
                                style: GoogleFonts.newsreader(
                                  fontSize: 26,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                  color: isSelected ? selectedTextColor : unselectedTextColor,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Underage warning if applicable
          if (!_valid)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You must be at least 16 years old to join Rovlo.',
                      style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
