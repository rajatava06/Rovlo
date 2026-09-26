import 'package:flutter_test/flutter_test.dart';
import 'package:rovlo/models/traveler.dart';
import 'package:rovlo/providers/chat_provider.dart';

void main() {
  test('a shared location survives encode → parse', () {
    final text = SharedLocation.encode(22.572646, 88.363902);
    expect(text, 'rovlo-loc:22.57265,88.36390');
    final loc = SharedLocation.tryParse(text)!;
    expect(loc.lat, closeTo(22.57265, 1e-9));
    expect(loc.lng, closeTo(88.36390, 1e-9));
  });

  test('negative coordinates work', () {
    final loc = SharedLocation.tryParse(SharedLocation.encode(-33.8688, -151.2093))!;
    expect(loc.lat, -33.8688);
    expect(loc.lng, -151.2093);
  });

  test('ordinary text and bad values are not locations', () {
    expect(SharedLocation.tryParse('hello'), isNull);
    expect(SharedLocation.tryParse('rovlo-loc:abc,def'), isNull);
    expect(SharedLocation.tryParse('rovlo-loc:95.0,10.0'), isNull); // lat > 90
    expect(SharedLocation.tryParse('see rovlo-loc:10.0,10.0 here'), isNull);
  });

  test('the chat list shows a friendly preview', () {
    expect(SharedLocation.previewFor(SharedLocation.encode(1, 2)), '📍 Location');
    expect(SharedLocation.previewFor('hi there'), 'hi there');
  });

  test('"last live" label', () {
    // covered by the model: just now / minutes / hours / days
    final now = DateTime.now();
    String label(Duration ago) => _label(now.subtract(ago));
    expect(label(const Duration(seconds: 20)), 'just now');
    expect(label(const Duration(minutes: 12)), '12 min ago');
    expect(label(const Duration(hours: 1, minutes: 5)), '1 hour ago');
    expect(label(const Duration(hours: 3)), '3 hours ago');
    expect(label(const Duration(days: 2, hours: 1)), '2 days ago');
  });
}

String _label(DateTime at) => Traveler(
      id: 'x',
      name: 'x',
      age: 0,
      imageUrl: '',
      location: '',
      dateRange: '',
      tags: const [],
      isVerified: false,
      description: '',
      locationUpdatedAt: at,
    ).lastLiveLabel;
