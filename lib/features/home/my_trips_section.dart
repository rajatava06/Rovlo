import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/trip.dart';
import '../../services/traveler_repository.dart';

/// "My Trips" on the profile: the trips I saved from Discover → Going to…
/// Other travellers heading to the same place see me because of these.
class MyTripsSection extends StatefulWidget {
  const MyTripsSection({super.key});

  @override
  State<MyTripsSection> createState() => _MyTripsSectionState();
}

class _MyTripsSectionState extends State<MyTripsSection> {
  final TravelerRepository _repo = TravelerRepository();
  List<Trip> _trips = const [];

  @override
  void initState() {
    super.initState();
    TravelerRepository.tripsRevision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    TravelerRepository.tripsRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final trips = await _repo.myTrips();
      if (mounted) setState(() => _trips = trips);
    } catch (_) {
      // Offline: keep what we have.
    }
  }

  Future<void> _remove(Trip trip) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.deleteTrip(trip.id);
      messenger.showSnackBar(
        SnackBar(content: Text('Removed your trip to ${trip.destination}')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not remove the trip. Check your connection.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_trips.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryVibrantDark : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      decoration: BoxDecoration(
        color: context.rovlo.card,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flight_takeoff_rounded, color: primary, size: 18),
              const SizedBox(width: 10),
              const Text(
                'My Trips',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final trip in _trips)
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.destination,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            trip.datesLabel,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: context.rovlo.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove trip',
                    onPressed: () => _remove(trip),
                    icon: Icon(Icons.close_rounded,
                        size: 18, color: context.rovlo.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
