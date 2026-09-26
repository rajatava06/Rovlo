/// One of *my* saved trips (a row of `public.trips`). Other people never get
/// this object — they see the destination/dates on a [Traveler] card.
class Trip {
  const Trip({
    required this.id,
    required this.destination,
    required this.week,
    required this.month,
    required this.year,
    this.lat,
    this.lng,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String destination;
  final String week;
  final String month;
  final String year;
  final double? lat;
  final double? lng;
  final DateTime? startDate;
  final DateTime? endDate;

  /// "2nd Week, Oct 2026"
  String get datesLabel => '$week, $month $year';

  bool get isUpcoming {
    final end = endDate;
    if (end == null) return true;
    final now = DateTime.now();
    return !end.isBefore(DateTime(now.year, now.month, now.day));
  }

  factory Trip.fromRow(Map<String, dynamic> r) => Trip(
        id: r['id'] as String,
        destination: (r['destination'] as String?) ?? '',
        week: (r['travel_week'] as String?) ?? '',
        month: (r['travel_month'] as String?) ?? '',
        year: (r['travel_year'] as String?) ?? '',
        lat: (r['lat'] as num?)?.toDouble(),
        lng: (r['lng'] as num?)?.toDouble(),
        startDate: DateTime.tryParse(r['start_date'] as String? ?? ''),
        endDate: DateTime.tryParse(r['end_date'] as String? ?? ''),
      );
}
