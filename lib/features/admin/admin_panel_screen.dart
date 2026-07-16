import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_repository.dart';

/// Admin Panel — restricted to accounts whose email is listed in
/// [AppConstants.adminEmails]. Lets an admin view the user roster, search,
/// block / unblock, delete and export.
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  late final UserRepository _repo;
  List<AppUser> _users = [];
  Map<String, int> _stats = const {};
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = context.read<AuthProvider>().users;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final users = await _repo.getAllUsers();
    final stats = await _repo.stats();
    if (!mounted) return;
    setState(() {
      _users = users;
      _stats = stats;
      _loading = false;
    });
  }

  List<AppUser> get _filtered {
    if (_query.isEmpty) return _users;
    final q = _query.toLowerCase();
    return _users.where((u) {
      return u.displayName.toLowerCase().contains(q) ||
          (u.email ?? '').toLowerCase().contains(q) ||
          (u.phoneNumber ?? '').contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<AuthProvider>().isAdmin;
    if (!isAdmin) return const _AccessDenied();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Export JSON',
            onPressed: _export,
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _StatsRow(stats: _stats),
                  const SizedBox(height: 20),
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search users…',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Users (${_filtered.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_filtered.isEmpty)
                    _EmptyUsers()
                  else
                    for (var i = 0; i < _filtered.length; i++)
                      _UserTile(
                        user: _filtered[i],
                        onChanged: _load,
                        repo: _repo,
                      )
                          .animate(delay: (40 * i).ms)
                          .fadeIn()
                          .slideX(begin: 0.08),
                ],
              ),
            ),
    );
  }

  Future<void> _export() async {
    final json = await _repo.exportJson();
    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User data (JSON) copied to clipboard')),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final Map<String, int> stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Total users', stats['total'] ?? 0, Icons.group, AppColors.primary),
      ('Completed', stats['complete'] ?? 0, Icons.verified, AppColors.success),
      ('New today', stats['newToday'] ?? 0, Icons.today, AppColors.secondary),
      ('Blocked', stats['blocked'] ?? 0, Icons.block, AppColors.error),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        for (final (label, value, icon, color) in items)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.rovlo.card,
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$value',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    Text(label,
                        style: TextStyle(
                            color: context.rovlo.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.onChanged,
    required this.repo,
  });

  final AppUser user;
  final VoidCallback onChanged;
  final UserRepository repo;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.rovlo.card,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: user.isBlocked
            ? Border.all(color: AppColors.error.withValues(alpha: 0.5))
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: user.isBlocked
              ? AppColors.error.withValues(alpha: 0.2)
              : AppColors.primary.withValues(alpha: 0.15),
          child: Text(user.initials,
              style: TextStyle(
                  color: user.isBlocked ? AppColors.error : AppColors.primary,
                  fontWeight: FontWeight.w700)),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(user.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (AppConstants.isAdminEmail(user.email))
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.shield, size: 14, color: AppColors.primary),
              ),
            if (user.isBlocked)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('BLOCKED',
                    style: TextStyle(
                        color: AppColors.error,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        subtitle: Text(
          '${user.email ?? user.phoneNumber ?? 'no contact'} • joined ${df.format(user.createdAt)}',
          style: TextStyle(color: context.rovlo.textSecondary, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handle(context, action),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'view', child: Text('View details')),
            PopupMenuItem(
              value: 'block',
              child: Text(user.isBlocked ? 'Unblock' : 'Block'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
        onTap: () => _showDetails(context),
      ),
    );
  }

  Future<void> _handle(BuildContext context, String action) async {
    switch (action) {
      case 'view':
        _showDetails(context);
      case 'block':
        await repo.setBlocked(user.id, !user.isBlocked);
        onChanged();
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete user?'),
            content: Text(
                'This permanently removes ${user.displayName} from the roster.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (ok == true) {
          await repo.delete(user.id);
          onChanged();
        }
    }
  }

  void _showDetails(BuildContext context) {
    final df = DateFormat('d MMM yyyy, HH:mm');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.displayName,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _detail('User ID', user.id),
            _detail('Email', user.email ?? '—'),
            _detail('Phone', user.phoneNumber ?? '—'),
            _detail('Gender', user.gender ?? '—'),
            _detail('Auth method', user.authMethod.name),
            _detail('Profile complete', user.profileComplete ? 'Yes' : 'No'),
            _detail('Status', user.isBlocked ? 'Blocked' : 'Active'),
            _detail('Joined', df.format(user.createdAt)),
            _detail(
              'Interests',
              user.travelInterests.isEmpty
                  ? '—'
                  : user.travelInterests.join(', '),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(label,
                  style: TextStyle(
                      color: context.rovlo.textSecondary,
                      fontWeight: FontWeight.w500)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyUsers extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.group_off,
                size: 48, color: context.rovlo.textSecondary),
            const SizedBox(height: 12),
            Text('No users yet',
                style: TextStyle(color: context.rovlo.textSecondary)),
            const SizedBox(height: 4),
            Text('Accounts appear here as people sign up.',
                style: TextStyle(
                    color: context.rovlo.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            const Text('Access denied',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'This account does not have admin privileges.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.rovlo.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
