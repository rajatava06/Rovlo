import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A Hotlist event, loaded from the `events` table (filled by the
/// `sync-events` Edge Function from Google Events / Ticketmaster, or added by
/// an admin).
class HotEvent {
  const HotEvent({
    required this.id,
    required this.title,
    required this.category,
    required this.city,
    required this.venue,
    required this.date,
    required this.time,
    required this.imageUrl,
    required this.themeColor,
    required this.price,
    required this.attending,
    required this.description,
    required this.lineup,
    required this.districtUrl,
    required this.googleUrl,
    this.ticketUrl,
    this.tags = const [],
    this.rating,
    this.startsAt,
    this.latitude,
    this.longitude,
    this.isFeatured = false,
    this.source = 'admin',
  });

  final String id;
  final String title;
  final String category;
  final String city;
  final String venue;
  final String date;
  final String time;
  final String imageUrl;
  final Color themeColor;
  final String price;

  /// Empty when unknown (we never invent attendance numbers).
  final String attending;
  final String description;
  final List<String> lineup;
  final String districtUrl;
  final String googleUrl;
  final String? ticketUrl;
  final List<String> tags;
  final double? rating;
  final DateTime? startsAt;
  final double? latitude;
  final double? longitude;
  final bool isFeatured;
  final String source;

  static const Map<String, Color> _categoryColors = {
    'Nightlife': Color(0xFF8B5CF6),
    'Live Music': Color(0xFF00A6FB),
    'Festivals': Color(0xFFFF5722),
    'Comedy': Color(0xFFFFB800),
    'Food & Drink': Color(0xFFEC4899),
    'Art & Culture': Color(0xFFD97706),
    'Sports': Color(0xFF10B981),
  };

  static Color _parseColor(String? hex, String category) {
    if (hex != null && hex.startsWith('#') && hex.length == 7) {
      final v = int.tryParse(hex.substring(1), radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
    return _categoryColors[category] ?? const Color(0xFF2196F3);
  }

  factory HotEvent.fromRow(Map<String, dynamic> r) {
    List<String> strings(dynamic v) =>
        (v as List<dynamic>? ?? const <dynamic>[]).map((e) => e.toString()).toList();

    final category = (r['category'] as String?) ?? 'Events';
    final startsAt = DateTime.tryParse(r['starts_at'] as String? ?? '')?.toLocal();

    var date = (r['date_label'] as String?)?.trim() ?? '';
    if (date.isEmpty && startsAt != null) {
      date = DateFormat('EEE, dd MMM yyyy').format(startsAt);
    }
    if (date.isEmpty) date = 'Date to be announced';

    var time = (r['time_label'] as String?)?.trim() ?? '';
    if (time.isEmpty && startsAt != null && (startsAt.hour != 0 || startsAt.minute != 0)) {
      time = DateFormat('h:mm a').format(startsAt);
    }

    final city = (r['city'] as String?) ?? '';
    final venue = (r['venue'] as String?)?.trim();
    final address = (r['address'] as String?)?.trim();
    final title = (r['title'] as String?) ?? 'Event';
    final query = Uri.encodeComponent('$title $city');

    return HotEvent(
      id: r['id'] as String,
      title: title,
      category: category,
      city: city,
      venue: (venue != null && venue.isNotEmpty)
          ? (address != null && address.isNotEmpty && !address.startsWith(venue)
              ? '$venue, $address'
              : (address != null && address.isNotEmpty ? address : venue))
          : (address ?? city),
      date: date,
      time: time,
      imageUrl: (r['image_url'] as String?) ?? '',
      themeColor: _parseColor(r['theme_color'] as String?, category),
      price: (r['price_text'] as String?)?.trim().isNotEmpty == true
          ? (r['price_text'] as String).trim()
          : 'See tickets',
      attending: (r['attending_text'] as String?) ?? '',
      description: (r['description'] as String?)?.trim().isNotEmpty == true
          ? (r['description'] as String).trim()
          : 'Details for this event are on the organiser\'s page.',
      lineup: strings(r['lineup']),
      districtUrl: (r['district_url'] as String?) ??
          'https://www.google.com/search?q=site:district.in+$query',
      googleUrl: (r['google_url'] as String?) ??
          'https://www.google.com/search?q=$query+tickets',
      ticketUrl: r['ticket_url'] as String?,
      tags: strings(r['tags']),
      rating: (r['rating'] as num?)?.toDouble(),
      startsAt: startsAt,
      latitude: (r['lat'] as num?)?.toDouble(),
      longitude: (r['lng'] as num?)?.toDouble(),
      isFeatured: r['is_featured'] as bool? ?? false,
      source: (r['source'] as String?) ?? 'admin',
    );
  }
}
