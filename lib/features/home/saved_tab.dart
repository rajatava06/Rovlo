import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/traveler.dart';
import 'traveler_profile_screen.dart';

/// Saved Profiles & Trips screen.
class SavedTab extends StatelessWidget {
  const SavedTab({super.key});

  @override
  Widget build(BuildContext context) {
    final savedProfiles = SampleTravelers.list.take(3).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Profiles & Trips', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profiles you bookmarked from your feed live here.',
                style: TextStyle(color: context.rovlo.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: savedProfiles.length,
                  itemBuilder: (context, index) {
                    final traveler = savedProfiles[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TravelerProfileScreen(traveler: traveler),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.rovlo.card,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                traveler.imageUrl,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 70,
                                  height: 70,
                                  color: Colors.grey,
                                  child: const Icon(Icons.person),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '${traveler.name}, ${traveler.age}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (traveler.isVerified) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.verified, color: Colors.blue, size: 16),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          traveler.location,
                                          style: TextStyle(
                                            color: context.rovlo.textSecondary,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    traveler.about.isNotEmpty ? traveler.about : traveler.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: context.rovlo.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.bookmark, color: AppColors.primary),
                          ],
                        ),
                      ).animate(delay: (60 * index).ms).fadeIn().slideY(begin: 0.1),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
