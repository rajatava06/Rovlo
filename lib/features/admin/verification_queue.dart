import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/verification_service.dart';

/// Admin tab: people who sent an Aadhaar + face photo and wait for a decision.
/// Approve = they get the blue tick. Either way the photos are deleted.
class VerificationQueue extends StatefulWidget {
  const VerificationQueue({super.key});

  @override
  State<VerificationQueue> createState() => _VerificationQueueState();
}

class _VerificationQueueState extends State<VerificationQueue> {
  final VerificationService _service = VerificationService.instance;
  List<VerificationRequest> _items = const [];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final list = await _service.queue();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load verification requests.\n'
            '(run supabase/schema.sql if you have not yet)';
        _loading = false;
      });
    }
  }

  Future<void> _decide(VerificationRequest r, {required bool approve}) async {
    String? note;
    if (!approve) {
      note = await _askReason(r);
      if (note == null) return; // cancelled
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Approve verification?'),
          content: Text('${r.name} will get the blue tick.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve')),
          ],
        ),
      );
      if (ok != true) return;
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(r.userId));
    try {
      await _service.review(r.userId, approve: approve, note: note);
      if (!mounted) return;
      setState(() {
        _items = _items.where((x) => x.userId != r.userId).toList();
        _busy.remove(r.userId);
      });
      messenger.showSnackBar(SnackBar(
        content: Text(approve ? '${r.name} is now verified ✓' : '${r.name} was rejected.'),
      ));
    } on VerificationException catch (e) {
      if (mounted) setState(() => _busy.remove(r.userId));
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      _load();
    }
  }

  Future<String?> _askReason(VerificationRequest r) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject ${r.name}?'),
        content: TextField(
          controller: controller,
          maxLength: 160,
          decoration: const InputDecoration(
            hintText: 'Reason shown to the user (e.g. photo is blurry)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Icon(Icons.verified_outlined, size: 64, color: context.rovlo.textSecondary),
                const SizedBox(height: 12),
                Center(
                  child: Text('No verification requests waiting.',
                      style: TextStyle(color: context.rovlo.textSecondary)),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: _items.length,
              itemBuilder: (context, i) => _RequestCard(
                request: _items[i],
                service: _service,
                busy: _busy.contains(_items[i].userId),
                onApprove: () => _decide(_items[i], approve: true),
                onReject: () => _decide(_items[i], approve: false),
              ),
            ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.service,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final VerificationRequest request;
  final VerificationService service;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.primaryVibrantDark
        : AppColors.primary;
    final photo = request.photoUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.rovlo.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage:
                    (photo != null && photo.isNotEmpty) ? CachedNetworkImageProvider(photo) : null,
                child: (photo == null || photo.isEmpty) ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(
                      '${request.email ?? ''}  ·  ${DateFormat('d MMM, h:mm a').format(request.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: context.rovlo.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (request.profilePhotos.isNotEmpty || (photo != null && photo.isNotEmpty)) ...[
            Text('Profile photos',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.rovlo.textSecondary)),
            const SizedBox(height: 6),
            SizedBox(
              height: 72,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final url in (request.profilePhotos.isNotEmpty
                      ? request.profilePhotos
                      : [photo!]))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          width: 60,
                          height: 72,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const ColoredBox(color: Colors.black12, child: SizedBox(width: 60)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(child: _PhotoBox(label: 'Straight selfie', path: request.frontPath, service: service)),
              const SizedBox(width: 10),
              Expanded(
                child: _PhotoBox(
                  label: request.challenge.isEmpty ? 'Pose selfie' : 'Pose: ${request.challenge}',
                  path: request.posePath,
                  service: service,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Approve only if both selfies are the same person as the profile photos and '
            'the pose was really done.',
            style: TextStyle(fontSize: 11.5, color: context.rovlo.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: Colors.red.shade400,
                    side: BorderSide(color: Colors.red.shade300),
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: busy ? null : onApprove,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: primary,
                    elevation: 0,
                  ),
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.verified, size: 18, color: Colors.white),
                  label: const Text('Approve',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A private photo: fetches a short-lived signed link, tap to zoom.
class _PhotoBox extends StatefulWidget {
  const _PhotoBox({required this.label, required this.path, required this.service});

  final String label;
  final String path;
  final VerificationService service;

  @override
  State<_PhotoBox> createState() => _PhotoBoxState();
}

class _PhotoBoxState extends State<_PhotoBox> {
  late Future<String> _url = widget.service.signedUrl(widget.path);

  void _open(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        AspectRatio(
          aspectRatio: 0.85,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FutureBuilder<String>(
              future: _url,
              builder: (context, snap) {
                if (snap.hasError) {
                  return InkWell(
                    onTap: () => setState(() => _url = widget.service.signedUrl(widget.path)),
                    child: const ColoredBox(
                      color: Colors.black12,
                      child: Center(child: Icon(Icons.refresh)),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const ColoredBox(
                    color: Colors.black12,
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final url = snap.data!;
                return GestureDetector(
                  onTap: () => _open(url),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Colors.black12,
                      child: Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
