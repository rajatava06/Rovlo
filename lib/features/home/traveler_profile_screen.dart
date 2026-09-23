import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_back_button.dart';
import '../../models/traveler.dart';
import '../../providers/chat_provider.dart';
import '../../services/traveler_repository.dart';

/// Full-screen profile view for a traveler. Shows photos, name, age,
/// verified badge, tags, and about section. Does NOT show home base or location.
class TravelerProfileScreen extends StatefulWidget {
  final Traveler traveler;

  const TravelerProfileScreen({super.key, required this.traveler});

  @override
  State<TravelerProfileScreen> createState() => _TravelerProfileScreenState();
}

class _TravelerProfileScreenState extends State<TravelerProfileScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<String> get _images =>
      widget.traveler.imageUrls.isNotEmpty
          ? widget.traveler.imageUrls
          : [widget.traveler.imageUrl];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Stores the like / save in the database.
  Future<void> _swipe(SwipeKind kind) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final chat = context.read<ChatProvider>();
    final name = widget.traveler.name;
    try {
      final match = await TravelerRepository().swipe(widget.traveler.id, kind);
      if (kind == SwipeKind.like) {
        unawaited(chat.onLiked());
        navigator.pop();
      }
      messenger.showSnackBar(SnackBar(
        content: Text(kind == SwipeKind.save
            ? 'Saved $name to your favorites! 🔖'
            : (match ? "It's a match with $name! 🎉 Say hi in Chats." : 'You liked $name!')),
      ));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save that. Check your connection.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryPeach = isDark ? AppColors.primaryVibrantDark : AppColors.primary;
    final traveler = widget.traveler;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: CustomScrollView(
        slivers: [
          // ── Photo Gallery ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Stack(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.55,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _images.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, index) {
                      return Image.network(
                        _images[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image, size: 60),
                        ),
                      );
                    },
                  ),
                ),
                // Back button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  child: const RovloBackButton(
                    color: Colors.white,
                    backgroundColor: Colors.black45,
                    size: 40,
                    iconSize: 20,
                  ),
                ),
                // Dot indicators
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_images.length, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          // ── Profile Info ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + Age + Verified
                  Row(
                    children: [
                      Text(
                        traveler.nameWithAge,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (traveler.isVerified) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.verified, color: primaryPeach, size: 24),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tags
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: traveler.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: primaryPeach.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.secondary : AppColors.primaryDark,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // About section
                  Text(
                    'About',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    traveler.about.isNotEmpty ? traveler.about : traveler.description,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action buttons: Like and Save. Message is only for matches.
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () => _swipe(SwipeKind.like),
                            icon: const Icon(Icons.favorite, color: Colors.white),
                            label: const Text(
                              'Like',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryPeach,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 52,
                        width: 56,
                        child: OutlinedButton(
                          onPressed: () => _swipe(SwipeKind.save),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: primaryPeach.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: Icon(Icons.bookmark_border, color: primaryPeach),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
