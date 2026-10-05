import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/traveler.dart';
import '../../services/traveler_repository.dart';
import 'traveler_profile_screen.dart';

/// Saved Profiles & Trips screen.
class SavedTab extends StatefulWidget {
  const SavedTab({super.key});

  @override
  State<SavedTab> createState() => _SavedTabState();
}

class _SavedTabState extends State<SavedTab> {
  List<Traveler> _saved = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final list = await TravelerRepository().saved();
      if (!mounted) return;
      setState(() => _saved = list);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedProfiles = _saved;
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
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _failed
                        ? Center(
                            child: TextButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Could not load. Tap to retry'),
                            ),
                          )
                        : savedProfiles.isEmpty
                            ? Center(
                                child: Text(
                                  'Nothing saved yet.\nTap the bookmark on a profile to keep it here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: context.rovlo.textSecondary),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _load,
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
                                cacheWidth: 210,
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
                                        traveler.nameWithAge,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
