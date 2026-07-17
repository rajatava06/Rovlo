class Traveler {
  final String name;
  final int age;
  final String imageUrl;
  final String location;
  final String dateRange;
  final List<String> tags;
  final bool isVerified;
  final String description;

  const Traveler({
    required this.name,
    required this.age,
    required this.imageUrl,
    required this.location,
    required this.dateRange,
    required this.tags,
    required this.isVerified,
    required this.description,
  });
}

class SampleTravelers {
  static const List<Traveler> list = [
    Traveler(
      name: 'Julian',
      age: 28,
      imageUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=800&q=80',
      location: 'Bali',
      dateRange: 'Oct 12-20',
      tags: ['Backpacker', 'Networking'],
      isVerified: true,
      description: 'Love exploring volcanic hikes and finding hidden beach coves. Let\'s grab a coffee!',
    ),
    Traveler(
      name: 'Elena',
      age: 31,
      imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=800&q=80',
      location: 'Bali',
      dateRange: 'Oct 15-25',
      tags: ['Digital Nomad', 'Sightseeing'],
      isVerified: true,
      description: 'UX designer working remotely. Looking to connect with other creators and explore cafes.',
    ),
    Traveler(
      name: 'Mark & Suzi',
      age: 26,
      imageUrl: 'https://images.unsplash.com/photo-1488161628813-04466f872be2?auto=format&fit=crop&w=800&q=80',
      location: 'Bali',
      dateRange: 'Oct 10-18',
      tags: ['Foodies', 'Group Hanging'],
      isVerified: false,
      description: 'Traveling couple eager to try the best local warungs and surf spot highlights.',
    ),
    Traveler(
      name: 'Sophia',
      age: 24,
      imageUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=800&q=80',
      location: 'Bali',
      dateRange: 'Oct 18-28',
      tags: ['Adventure', 'Surfing'],
      isVerified: true,
      description: 'Always seeking the next adrenaline rush. Down for scuba diving or scooter trips.',
    ),
  ];
}
