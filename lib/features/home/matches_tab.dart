import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/traveler.dart';
import '../../providers/auth_provider.dart';

class MatchesTab extends StatefulWidget {
  const MatchesTab({super.key});

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab> {
  int _cardIndex = 0;
  final List<Traveler> _myMatches = [];
  final List<Traveler> _swipeDeck = List.from(SampleTravelers.list);

  void _likeTraveler(Traveler traveler) {
    setState(() {
      _myMatches.add(traveler);
      _cardIndex++;
    });
    _showMatchCelebration(traveler);
  }

  void _passTraveler() {
    setState(() {
      _cardIndex++;
    });
  }

  void _showMatchCelebration(Traveler traveler) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryPeach = isDark ? AppColors.primaryVibrantDark : AppColors.primary;
        final user = context.read<AuthProvider>().currentUser;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'It\'s a Match! 🎉',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: primaryPeach,
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.bounceOut),
                const SizedBox(height: 12),
                Text(
                  'You and ${traveler.name} liked each other\'s plans.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                // Side-by-side Avatar bubble overlays
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // User avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        color: primaryPeach,
                        image: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(user.photoUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                          ? null
                          : Center(
                              child: Text(
                                user?.initials ?? 'R',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.favorite, color: Colors.red, size: 32)
                        .animate(onPlay: (controller) => controller.repeat())
                        .scale(duration: 800.ms, begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), curve: Curves.easeInOut),
                    const SizedBox(width: 12),
                    // Matched traveler avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        image: DecorationImage(
                          image: NetworkImage(traveler.imageUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Starting chat with ${traveler.name}!')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPeach,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Send Message',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Keep Exploring',
                    style: TextStyle(color: primaryPeach),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecColor = context.rovlo.textSecondary;
    final primaryPeach = isDark ? AppColors.primaryVibrantDark : AppColors.primary;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text(
              'Matches',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
            ),
          ),

          // Matches row (Avatars)
          if (_myMatches.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'YOUR MATCHES (${_myMatches.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: textSecColor,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _myMatches.length,
                itemBuilder: (context, index) {
                  final matchedTraveler = _myMatches[index];
                  return Container(
                    margin: const EdgeInsets.only(right: 14),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundImage: NetworkImage(matchedTraveler.imageUrl),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isDark ? AppColors.darkSurface : Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          matchedTraveler.name,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 24),
          ],

          // Swipe Card area
          Expanded(
            child: _cardIndex >= _swipeDeck.length
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: textSecColor),
                          const SizedBox(height: 16),
                          const Text(
                            'No more profiles to swipe!',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Check back later to find more companion travelers.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textSecColor),
                          ),
                        ],
                      ),
                    ),
                  )
                : Builder(
                    builder: (context) {
                      final currentTraveler = _swipeDeck[_cardIndex];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      currentTraveler.imageUrl,
                                      fit: BoxFit.cover,
                                    ),
                                    // Location & Date Badge
                                    Positioned(
                                      top: 16,
                                      right: 16,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.95),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.calendar_today, size: 12, color: AppColors.accent),
                                            const SizedBox(width: 4),
                                            Text(
                                              'In ${currentTraveler.location}: ${currentTraveler.dateRange}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.accent,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Info bottom overlay
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Colors.transparent, Colors.black87],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  '${currentTraveler.name}, ${currentTraveler.age}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 26,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                if (currentTraveler.isVerified) ...[
                                                  const SizedBox(width: 8),
                                                  const CircleAvatar(
                                                    radius: 9,
                                                    backgroundColor: Colors.white,
                                                    child: Icon(Icons.check, size: 11, color: AppColors.primary),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              currentTraveler.description,
                                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                                            ),
                                            const SizedBox(height: 12),
                                            // Tags
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.6),
                                                    borderRadius: BorderRadius.circular(16),
                                                    border: Border.all(color: Colors.white24),
                                                  ),
                                                  child: Text(
                                                    currentTraveler.tags[0],
                                                    style: const TextStyle(color: Colors.white, fontSize: 11),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.secondary,
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  child: Text(
                                                    currentTraveler.tags[1],
                                                    style: const TextStyle(color: AppColors.lightTextPrimary, fontSize: 11),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Swipe action buttons
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // Pass (Dislike)
                                    GestureDetector(
                                      onTap: _passTraveler,
                                      child: Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isDark ? AppColors.darkCard : Colors.grey.withValues(alpha: 0.1),
                                        ),
                                        child: const Icon(Icons.close, color: Colors.grey, size: 28),
                                      ),
                                    ),
                                    // Like (Heart)
                                    GestureDetector(
                                      onTap: () => _likeTraveler(currentTraveler),
                                      child: Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: primaryPeach,
                                          boxShadow: [
                                            BoxShadow(
                                              color: primaryPeach.withValues(alpha: 0.3),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            )
                                          ],
                                        ),
                                        child: const Icon(Icons.favorite, color: Colors.white, size: 28),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
