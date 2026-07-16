import 'dart:ui';

/// A travel destination shown in the Explore feed.
class Destination {
  const Destination({
    required this.name,
    required this.country,
    required this.category,
    required this.rating,
    required this.priceFrom,
    required this.gradient,
    required this.emoji,
    required this.blurb,
  });

  final String name;
  final String country;
  final String category;
  final double rating;
  final int priceFrom;
  final List<Color> gradient;
  final String emoji;
  final String blurb;
}

/// Sample content so the app looks alive out of the box. Swap for real API
/// data when a backend is connected.
class SampleData {
  SampleData._();

  static const List<String> categories = [
    'Trending',
    'Beaches',
    'Mountains',
    'Cities',
    'Adventure',
    'Wellness',
  ];

  static const List<Destination> destinations = [
    Destination(
      name: 'Santorini',
      country: 'Greece',
      category: 'Beaches',
      rating: 4.9,
      priceFrom: 780,
      gradient: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
      emoji: '🏖️',
      blurb: 'Whitewashed cliffs, blue domes and unreal sunsets over the Aegean.',
    ),
    Destination(
      name: 'Kyoto',
      country: 'Japan',
      category: 'Cities',
      rating: 4.8,
      priceFrom: 1120,
      gradient: [Color(0xFFcc2b5e), Color(0xFF753a88)],
      emoji: '⛩️',
      blurb: 'Temples, tea houses and cherry blossoms in the old capital.',
    ),
    Destination(
      name: 'Banff',
      country: 'Canada',
      category: 'Mountains',
      rating: 4.9,
      priceFrom: 940,
      gradient: [Color(0xFF11998e), Color(0xFF38ef7d)],
      emoji: '🏔️',
      blurb: 'Turquoise lakes and snow-capped peaks in the Canadian Rockies.',
    ),
    Destination(
      name: 'Marrakech',
      country: 'Morocco',
      category: 'Adventure',
      rating: 4.7,
      priceFrom: 560,
      gradient: [Color(0xFFf46b45), Color(0xFFeea849)],
      emoji: '🕌',
      blurb: 'Bustling souks, riads and gateway to the Sahara dunes.',
    ),
    Destination(
      name: 'Bali',
      country: 'Indonesia',
      category: 'Wellness',
      rating: 4.8,
      priceFrom: 690,
      gradient: [Color(0xFF00b09b), Color(0xFF96c93d)],
      emoji: '🌴',
      blurb: 'Rice terraces, surf breaks and serene yoga retreats.',
    ),
    Destination(
      name: 'Reykjavík',
      country: 'Iceland',
      category: 'Adventure',
      rating: 4.7,
      priceFrom: 1010,
      gradient: [Color(0xFF396afc), Color(0xFF2948ff)],
      emoji: '🌌',
      blurb: 'Chase the northern lights, waterfalls and geothermal spas.',
    ),
  ];
}
