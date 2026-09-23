import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass.dart';
import '../../models/hot_event.dart';
import '../../services/events_repository.dart';

class EventDetailsScreen extends StatefulWidget {
  final HotEvent event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  bool _isSaved = false;
  final EventsRepository _repo = EventsRepository();

  @override
  void initState() {
    super.initState();
    _repo.savedIds().then((ids) {
      if (mounted) setState(() => _isSaved = ids.contains(widget.event.id));
    });
  }

  Future<void> _toggleSaved() async {
    HapticFeedback.selectionClick();
    final next = !_isSaved;
    setState(() => _isSaved = next);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.setSaved(widget.event.id, next);
      messenger.showSnackBar(SnackBar(
        content: Text(next ? 'Saved to your Hotlist ✓' : 'Removed from Hotlist'),
        duration: const Duration(milliseconds: 900),
      ));
    } catch (_) {
      if (mounted) setState(() => _isSaved = !next);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update. Check your connection.')),
      );
    }
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    final messenger = ScaffoldMessenger.of(context);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not open the link.')));
    }
  }

  Future<void> _openDirections() async {
    final e = widget.event;
    final q = (e.latitude != null && e.longitude != null)
        ? '${e.latitude},${e.longitude}'
        : Uri.encodeComponent('${e.venue} ${e.city}');
    await _open('https://www.google.com/maps/search/?api=1&query=$q');
  }

  /// Name of the ticket seller, taken from the event's own booking link.
  static String _platformName(String url) {
    final host = (Uri.tryParse(url)?.host ?? '').toLowerCase();
    const known = <String, String>{
      'district.in': 'District',
      'bookmyshow': 'BookMyShow',
      'bookmy.show': 'BookMyShow',
      'bms.app.link': 'BookMyShow',
      'ticketmaster': 'Ticketmaster',
      'insider.in': 'Insider',
      'paytm': 'Paytm Insider',
      'eventbrite': 'Eventbrite',
      'bandsintown': 'Bandsintown',
      'viagogo': 'Viagogo',
      'ticketgenie': 'TicketGenie',
      'events.com': 'Events.com',
      'indiax.com': 'IndiaX',
    };
    for (final e in known.entries) {
      if (host.contains(e.key)) return e.value;
    }
    final parts = host.replaceFirst('www.', '').split('.');
    if (parts.isEmpty || parts.first.isEmpty) return 'the seller';
    return parts.first[0].toUpperCase() + parts.first.substring(1);
  }

  /// Opens the original seller's page. Events without a known seller link fall
  /// back to a Google search for the event, and the button says so.
  Future<void> _book() async {
    HapticFeedback.mediumImpact();
    final e = widget.event;
    final url = (e.ticketUrl != null && e.ticketUrl!.isNotEmpty) ? e.ticketUrl! : e.googleUrl;
    await _open(url);
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSec = context.rovlo.textSecondary;

    return Scaffold(
      body: Stack(
        children: [
          // ── Fixed Top-To-Bottom Event Theme Glow in Background ──────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    event.themeColor.withValues(alpha: isDark ? 0.42 : 0.28),
                    event.themeColor.withValues(alpha: isDark ? 0.16 : 0.08),
                    isDark ? AppColors.darkBackground : AppColors.lightBackground,
                  ],
                  stops: const [0.0, 0.42, 0.85],
                ),
              ),
            ),
          ),

          // ── Scrollable Event Body ─────────────────────────────────────────
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Hero Image App Bar
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                stretch: true,
                backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GlassCircleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    tooltip: 'Back',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                actions: [
                  Center(
                    child: GlassCircleButton(
                      icon: _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      iconColor: _isSaved ? event.themeColor : Colors.white,
                      tooltip: 'Save',
                      onPressed: _toggleSaved,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Center(
                    child: GlassCircleButton(
                      icon: Icons.share_outlined,
                      tooltip: 'Copy link',
                      onPressed: () async {
                        final link = event.ticketUrl ?? event.googleUrl;
                        await Clipboard.setData(ClipboardData(
                          text: '${event.title} — ${event.date}\n$link',
                        ));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Event link copied to clipboard! 📋')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      event.imageUrl.isEmpty
                          ? Container(
                              color: event.themeColor.withValues(alpha: 0.35),
                              child: const Icon(Icons.celebration_outlined, size: 64, color: Colors.white70),
                            )
                          : CachedNetworkImage(
                              imageUrl: event.imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: event.themeColor.withValues(alpha: 0.3),
                                child: const Icon(Icons.event, size: 64),
                              ),
                            ),
                      // Scrim
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black38,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.75),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      // Floating Badges on Hero
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Row(
                          children: [
                            GlassBadge(
                              label: event.category.toUpperCase(),
                              fontSize: 11,
                            ),
                            const SizedBox(width: 8),
                            if (event.rating != null)
                              GlassBadge(
                                label: '${event.rating}',
                                icon: Icons.star_rounded,
                                iconColor: Colors.amber,
                                fontSize: 12,
                                horizontalPadding: 10,
                              ),
                            const Spacer(),
                            if (event.attending.isNotEmpty)
                              GlassBadge(
                                label: event.attending,
                                fontSize: 12,
                                horizontalPadding: 10,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Event Information List
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event Title
                      Text(
                        event.title,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ).animate().fadeIn().slideY(begin: 0.08),

                      const SizedBox(height: 16),

                      // Tags Row
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: event.tags.map((t) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: event.themeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: event.themeColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      // Date & Time Block
                      _InfoCard(
                        icon: Icons.calendar_month_outlined,
                        iconColor: event.themeColor,
                        title: event.date,
                        subtitle: event.time.isEmpty ? 'Time to be announced' : event.time,
                      ),

                      const SizedBox(height: 12),

                      // Venue & Location Block
                      _InfoCard(
                        icon: Icons.location_on_outlined,
                        iconColor: event.themeColor,
                        title: event.venue,
                        subtitle: '${event.city} • Tap for directions',
                        trailingAction: TextButton(
                          onPressed: _openDirections,
                          child: const Text('Directions'),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // About Event Description (Fetched from District / Google)
                      Text(
                        'About This Event',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        event.description,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.65,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Artist Lineup
                      if (event.lineup.isNotEmpty) ...[
                        Text(
                          'Featured Lineup & Artists',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 90,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: event.lineup.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 14),
                            itemBuilder: (ctx, i) {
                              final artist = event.lineup[i];
                              return Column(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: event.themeColor.withValues(alpha: 0.2),
                                    child: Text(
                                      artist.substring(0, 1),
                                      style: TextStyle(
                                        color: event.themeColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    artist,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // District Badge & Booking Guarantee Note
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.verified_user_outlined, color: event.themeColor, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Booked on the seller\'s own site',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Rovlo lists events found on Google Events and ticketing partners. Always check the details with the organiser before you pay.',
                                    style: TextStyle(fontSize: 11.5, color: textSec),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Fixed Bottom Booking Bar ──────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A).withValues(alpha: 0.95)
                    : AppColors.lightBackground.withValues(alpha: 0.97),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Price per ticket',
                          style: TextStyle(
                            fontSize: 11,
                            color: textSec,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.price,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: event.themeColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _book,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: event.themeColor,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: event.themeColor.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.confirmation_num_outlined, size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  (event.ticketUrl != null && event.ticketUrl!.isNotEmpty)
                                      ? 'Book on ${_platformName(event.ticketUrl!)}'
                                      : 'Find tickets on Google',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailingAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailingAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.rovlo.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (trailingAction != null) trailingAction!,
        ],
      ),
    );
  }
}
