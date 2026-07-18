class Traveler {
  final String name;
  final int age;
  final String imageUrl;
  final List<String> imageUrls;
  final String location;
  final String dateRange;
  final List<String> tags;
  final bool isVerified;
  final String description;
  final String about;

  const Traveler({
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
  });
}

class SampleTravelers {
  static const List<Traveler> list = [
    Traveler(
      name: 'Julian',
      age: 28,
      imageUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=800&q=80',
      imageUrls: [
        'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=800&q=80',
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=800&q=80',
        'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?auto=format&fit=crop&w=800&q=80',
      ],
      location: 'Bali',
      dateRange: '2nd Week, Oct',
      tags: ['Backpacker', 'Networking'],
      isVerified: true,
      description: 'Love exploring volcanic hikes and finding hidden beach coves. Let\'s grab a coffee!',
      about: 'Hey! I\'m Julian, a freelance photographer from Berlin. I\'ve been traveling Southeast Asia for the last 6 months and Bali has stolen my heart. I love exploring volcanic hikes, finding hidden beach coves, and trying the local warungs. Always down for a sunrise trek or a sunset surf session. Let\'s connect!',
    ),
    Traveler(
      name: 'Elena',
      age: 31,
      imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=800&q=80',
      imageUrls: [
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=800&q=80',
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=800&q=80',
        'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=800&q=80',
      ],
      location: 'Bali',
      dateRange: '3rd Week, Oct',
      tags: ['Digital Nomad', 'Sightseeing'],
      isVerified: true,
      description: 'UX designer working remotely. Looking to connect with other creators and explore cafes.',
      about: 'Ciao! I\'m Elena, a UX designer from Milan working remotely while exploring the world. Currently based in Bali for a couple of months, bouncing between coworking spaces and beach cafés. I love discovering hidden art galleries, local food markets, and meeting fellow creative souls. If you know a great spot for espresso, let\'s chat!',
    ),
    Traveler(
      name: 'Mark & Suzi',
      age: 26,
      imageUrl: 'https://images.unsplash.com/photo-1488161628813-04466f872be2?auto=format&fit=crop&w=800&q=80',
      imageUrls: [
        'https://images.unsplash.com/photo-1488161628813-04466f872be2?auto=format&fit=crop&w=800&q=80',
        'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=800&q=80',
        'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=800&q=80',
      ],
      location: 'Bali',
      dateRange: '2nd Week, Oct',
      tags: ['Foodies', 'Group Hanging'],
      isVerified: false,
      description: 'Traveling couple eager to try the best local warungs and surf spot highlights.',
      about: 'We\'re Mark & Suzi, a travel-obsessed couple from Sydney! We quit our jobs 3 months ago to chase our dream of eating our way across Asia. In Bali, we\'re all about the best nasi goreng, secret surf spots, and making friends over sunset drinks. If you\'re up for a food crawl or a group beach day, hit us up!',
    ),
    Traveler(
      name: 'Sophia',
      age: 24,
      imageUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=800&q=80',
      imageUrls: [
        'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=800&q=80',
        'https://images.unsplash.com/photo-1502823403499-6ccfcf4fb453?auto=format&fit=crop&w=800&q=80',
        'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?auto=format&fit=crop&w=800&q=80',
      ],
      location: 'Bali',
      dateRange: '3rd Week, Oct',
      tags: ['Adventure', 'Surfing'],
      isVerified: true,
      description: 'Always seeking the next adrenaline rush. Down for scuba diving or scooter trips.',
      about: 'Hey there! I\'m Sophia from São Paulo, an adventure junkie and ocean lover. Whether it\'s catching waves at dawn, scuba diving with manta rays, or renting a scooter to explore rice terraces — I\'m always in. Bali is my happy place and I\'m here for the thrill. Let\'s plan something epic together!',
    ),
    Traveler(
      name: 'Mateo',
      age: 27,
      imageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=800&q=80',
      imageUrls: [
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=800&q=80',
        'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=800&q=80',
      ],
      location: 'Barcelona, Spain',
      dateRange: '2nd Week, Oct',
      tags: ['Sightseeing', 'Digital Nomad'],
      isVerified: true,
      description: 'Strolling through Gothic Quarter, photographing architecture, and eating tapas.',
      about: 'Hola! I\'m Mateo, a photographer from Madrid. Currently exploring Barcelona\'s vibrant culture, architecture, and food scene. Down for beach walks, exploring Gaudi sites, or sharing some delicious tapas in El Born. Let\'s explore!',
    ),
    Traveler(
      name: 'Yuki',
      age: 29,
      imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=800&q=80',
      imageUrls: [
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=800&q=80',
        'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=800&q=80',
      ],
      location: 'Kyoto, Japan',
      dateRange: '3rd Week, Oct',
      tags: ['Backpacker', 'Nature'],
      isVerified: false,
      description: 'Chasing fall foliage, visiting temples, and drinking green tea.',
      about: 'Hi! I\'m Yuki, a traveler who loves traditional architecture and quiet nature hikes. Exploring Kyoto\'s temples and gardens during this beautiful autumn season. Let\'s grab matcha tea and explore the bamboo groves together!',
    ),
  ];
}
