import 'package:flutter/material.dart';

class HotEvent {
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
  final String attending;
  final String description;
  final List<String> lineup;
  final String districtUrl;
  final String googleUrl;
  final List<String> tags;
  final double rating;

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
    this.tags = const [],
    this.rating = 4.8,
  });
}

class SampleHotEvents {
  static const List<HotEvent> list = [
    HotEvent(
      id: 'evt_1',
      title: 'Neon Odyssey: Electronic Rooftop Sundowner',
      category: 'Nightlife',
      city: 'Bengaluru',
      venue: 'Skyline Terrace Lounge, UB City, Bengaluru',
      date: 'Sat, 28 Oct 2026',
      time: '6:30 PM onwards',
      imageUrl:
          'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=900&q=80',
      themeColor: Color(0xFF8B5CF6), // Neon Purple
      price: '₹799 onwards',
      attending: '2.4k attending',
      description:
          'Step into a pulsating wonderland of progressive house and melodic techno above the skyline. Featuring world-class laser mapping, artisanal craft cocktails, and an unforgettable rooftop sunset experience under the stars.',
      lineup: ['DJ Artifex', 'Luna Sol', 'Komorebi Sound', 'Vortex Duo'],
      districtUrl: 'https://district.in/events/neon-odyssey-bengaluru',
      googleUrl:
          'https://www.google.com/search?q=Neon+Odyssey+Electronic+Rooftop+UB+City+Bengaluru+tickets',
      tags: ['🔥 Trending', 'Filling Fast', 'Exclusive'],
      rating: 4.9,
    ),
    HotEvent(
      id: 'evt_2',
      title: 'Sunburn Coastal Arena 2026',
      category: 'Festivals',
      city: 'Goa',
      venue: 'Vagator Beachfront Arena, North Goa',
      date: 'Fri, 14 Nov 2026',
      time: '4:00 PM to 2:00 AM',
      imageUrl:
          'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=900&q=80',
      themeColor: Color(0xFFFF5722), // Sunset Coral
      price: '₹1,999 onwards',
      attending: '5.8k attending',
      description:
          'India’s premier beach festival returns with massive multi-genre stages, immersive audio-visual pyrotechnics, flea markets, and international headliners right on the shores of Vagator.',
      lineup: ['Lost Frequencies', 'KSHMR', 'Anish Sood', 'Dualist Inquiry'],
      districtUrl: 'https://district.in/events/sunburn-coastal-goa',
      googleUrl:
          'https://www.google.com/search?q=Sunburn+Coastal+Arena+Goa+2026+booking',
      tags: ['🔥 Mega Event', 'Must Visit', 'Phase 1 Out'],
      rating: 4.9,
    ),
    HotEvent(
      id: 'evt_3',
      title: 'Echoes of Earth: Eco Music & Art Fest',
      category: 'Live Music',
      city: 'Bengaluru',
      venue: 'Embassy Riding Apparel & Greens, Bengaluru',
      date: 'Sun, 22 Nov 2026',
      time: '3:00 PM to 11:30 PM',
      imageUrl:
          'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?auto=format&fit=crop&w=900&q=80',
      themeColor: Color(0xFF10B981), // Emerald Green
      price: '₹1,299',
      attending: '3.1k attending',
      description:
          'Celebrated as India’s greenest music festival, Echoes of Earth brings together over 40 global artists, giant interactive art installations built from recycled materials, and sustainable food stalls.',
      lineup: ['Tinariwen', 'Jordan Rakei', 'Peter Cat Recording Co.', 'Prateek Kuhad'],
      districtUrl: 'https://district.in/events/echoes-of-earth-bengaluru',
      googleUrl:
          'https://www.google.com/search?q=Echoes+of+Earth+Eco+Music+Fest+Bengaluru',
      tags: ['🌿 Eco Fest', 'Family Friendly', 'Art Installations'],
      rating: 4.8,
    ),
    HotEvent(
      id: 'evt_4',
      title: 'Midnight Laugh Riot: All-Star Standup Comedy',
      category: 'Comedy',
      city: 'Mumbai',
      venue: 'The Habitat, Khar West, Mumbai',
      date: 'Fri, 31 Oct 2026',
      time: '9:30 PM to 11:30 PM',
      imageUrl:
          'https://images.unsplash.com/photo-1585699324551-f6c309eedeca?auto=format&fit=crop&w=900&q=80',
      themeColor: Color(0xFFFFB800), // Amber Gold
      price: '₹499',
      attending: '820 attending',
      description:
          'An intimate, uncensored late-night comedy showcase featuring top tier comedians testing brand new jokes alongside special secret headliners from Bollywood and OTT specials.',
      lineup: ['Samay Raina', 'Urooj Ashfaq', 'Zakir Khan (Special)', 'Abhishek Upmanyu'],
      districtUrl: 'https://district.in/events/midnight-laugh-riot-mumbai',
      googleUrl:
          'https://www.google.com/search?q=Midnight+Laugh+Riot+The+Habitat+Mumbai+tickets',
      tags: ['😂 Sold Out Fast', 'Age 18+', 'Cocktails Included'],
      rating: 4.7,
    ),
    HotEvent(
      id: 'evt_5',
      title: 'Tokyo Cyberwave & Underground Jazz Night',
      category: 'Live Music',
      city: 'Tokyo',
      venue: 'Blue Note Tokyo, Minato City, Tokyo',
      date: 'Sat, 07 Nov 2026',
      time: '8:00 PM onwards',
      imageUrl:
          'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=900&q=80',
      themeColor: Color(0xFF00D2FF), // Cyber Cyan
      price: '¥4,500 (~₹2,490)',
      attending: '1.5k attending',
      description:
          'Experience a sonic fusion of traditional Japanese folk instruments, neo-Tokyo synthesizer jazz, and immersive visual projection mapping at the world-famous Blue Note Tokyo.',
      lineup: ['Hiromi Uehara Quintet', 'Tokyo Sound Collective', 'DJ Krush'],
      districtUrl: 'https://district.in/events/tokyo-cyberwave-jazz',
      googleUrl:
          'https://www.google.com/search?q=Tokyo+Cyberwave+Underground+Jazz+Blue+Note+tickets',
      tags: ['🍸 Premium Table', 'Intimate', 'World Class'],
      rating: 5.0,
    ),
    HotEvent(
      id: 'evt_6',
      title: 'Barcelona Tapas & Sunset Wine Crawl',
      category: 'Food & Drink',
      city: 'Barcelona',
      venue: 'Gothic Quarter & El Born, Barcelona',
      date: 'Sun, 15 Nov 2026',
      time: '5:30 PM to 9:30 PM',
      imageUrl:
          'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
      themeColor: Color(0xFFEC4899), // Rose Pink
      price: '€45 (~₹3,990)',
      attending: '950 attending',
      description:
          'Guided culinary expedition through the historic stone alleyways of Barcelona. Taste authentic Catalan tapas, regional sparkling cava, and reserve wines paired by local sommeliers.',
      lineup: ['Chef Marc Costa', 'Bodega Maestros', 'Tapas Guide Jordi'],
      districtUrl: 'https://district.in/events/barcelona-tapas-wine-crawl',
      googleUrl:
          'https://www.google.com/search?q=Barcelona+Tapas+and+Sunset+Wine+Crawl+El+Born',
      tags: ['🍷 Tasting Included', 'English & Spanish', 'Walking Tour'],
      rating: 4.9,
    ),
    HotEvent(
      id: 'evt_7',
      title: 'Delhi Heritage Moonlight Walk & Acoustic Sitar',
      category: 'Art & Culture',
      city: 'Delhi NCR',
      venue: 'Sunder Nursery Heritage Amphitheatre, New Delhi',
      date: 'Fri, 20 Nov 2026',
      time: '6:00 PM to 9:00 PM',
      imageUrl:
          'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?auto=format&fit=crop&w=900&q=80',
      themeColor: Color(0xFFD97706), // Royal Amber
      price: '₹350',
      attending: '1.1k attending',
      description:
          'Walk along the illuminated Mughal monuments of Sunder Nursery under the full moon, followed by a mesmerizing live sitar & tabla performance by classical masters with warm masala chai.',
      lineup: ['Ustad Shujaat Khan', 'Acoustic Ragas Ensemble'],
      districtUrl: 'https://district.in/events/delhi-heritage-moonlight-walk',
      googleUrl:
          'https://www.google.com/search?q=Delhi+Heritage+Moonlight+Walk+Sunder+Nursery+tickets',
      tags: ['🌙 Full Moon Special', 'Serene', 'Chai Included'],
      rating: 4.8,
    ),
  ];
}
