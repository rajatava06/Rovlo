/// A traveller as shown to *other* users (Discover, Map, Saved, Chat headers).
///
/// Built from the privacy-safe rows returned by the `discover_travelers`,
/// `nearby_travelers` and `my_saved_travelers` database functions — email,
/// phone and exact coordinates are never part of it.
class Traveler {
  const Traveler({
    required this.id,
    required this.name,
    required this.age,
    required this.imageUrl,
    this.imageUrls = const [],
    required this.location,
    required this.dateRange,
    required this.tags,
    required this.isVerified,
    required this.description,
    this.about = '',
    this.latitude,
    this.longitude,
    this.distanceKm,
  });

  final String id;
  final String name;

  /// 0 when the traveller has no (valid) date of birth.
  final int age;
  final String imageUrl;
  final List<String> imageUrls;
  final String location;
  final String dateRange;
  final List<String> tags;
  final bool isVerified;
  final String description;
  final String about;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;

  /// "Julian, 28" — or just "Julian" when the age is unknown.
  String get nameWithAge => age > 0 ? '$name, $age' : name;

  String get distanceLabel {
    final d = distanceKm;
    if (d == null) return '';
    if (d < 1) return '${(d * 1000).round()} m away';
    return '${d.toStringAsFixed(d < 10 ? 1 : 0)} km away';
  }

  static String avatarFallback(String seed) =>
      'https://api.dicebear.com/7.x/initials/png?seed=${Uri.encodeComponent(seed)}';

  /// Builds a traveller from a database row. Works for all three RPCs — fields
  /// that a given RPC does not return are simply null.
  factory Traveler.fromRow(Map<String, dynamic> row) {
    List<String> strings(dynamic v) =>
        (v as List<dynamic>? ?? const <dynamic>[]).map((e) => e.toString()).toList();

    final name = (row['name'] as String?)?.trim();
    final displayName = (name == null || name.isEmpty) ? 'Traveller' : name;
    final photos = strings(row['profile_photos']);
    final main = (row['photo_url'] as String?) ?? '';
    final all = photos.isNotEmpty ? photos : (main.isNotEmpty ? [main] : <String>[]);
    final bio = (row['bio'] as String?)?.trim() ?? '';

    String pick(List<String?> candidates, String fallback) {
      for (final c in candidates) {
        if (c != null && c.trim().isNotEmpty) return c.trim();
      }
      return fallback;
    }

    return Traveler(
      id: row['id'] as String,
      name: displayName,
      age: (row['age'] as num?)?.toInt() ?? 0,
      imageUrl: all.isNotEmpty ? all.first : avatarFallback(displayName),
      imageUrls: all,
      location: pick([
        row['trip_destination'] as String?,
        row['city'] as String?,
        row['home_base'] as String?,
      ], 'Somewhere out there'),
      dateRange: (row['trip_dates'] as String?) ?? '',
      tags: strings(row['travel_interests']).take(3).toList(),
      isVerified: row['is_verified'] as bool? ?? false,
      description: bio,
      about: bio,
      latitude: (row['lat'] as num?)?.toDouble(),
      longitude: (row['lng'] as num?)?.toDouble(),
      distanceKm: (row['distance_km'] as num?)?.toDouble(),
    );
  }
}
