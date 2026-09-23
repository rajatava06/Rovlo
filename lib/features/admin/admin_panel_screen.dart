import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/keyboard_inset.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_notification.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../services/user_repository.dart';
import 'support_inbox.dart';

/// Admin Panel — restricted to accounts listed in the `admin_emails` table.
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late final UserRepository _repo;
  late final NotificationService _notificationService;
  late final TabController _tabController;
  bool _hasSupport = false;

  List<AppUser> _users = [];
  Set<String> _adminEmails = <String>{};
  String? _loadError;
  List<AdminNotification> _notifications = [];
  Map<String, int> _stats = const {};
  String _query = '';
  String _filterStatus = 'All'; // 'All', 'Active', 'Blocked'
  bool _loading = true;

  // Push Notification Form State
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  NotificationType _selectedType = NotificationType.announcement;
  String _selectedTarget = 'All Users';
  bool _sendingNotification = false;

  @override
  void initState() {
    super.initState();
    _hasSupport = context.read<AuthProvider>().isSupportAgent;
    _tabController = TabController(length: _hasSupport ? 3 : 2, vsync: this);
    _repo = context.read<AuthProvider>().users;
    _notificationService = NotificationService();
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final users = await _repo.getAllUsers();
      final stats = await _repo.stats();
      final notifications = await _notificationService.getNotifications();
      final admins = await _repo.adminEmails();

      if (!mounted) return;
      setState(() {
        _users = users;
        _stats = stats;
        _notifications = notifications;
        _adminEmails = admins;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load admin data. Check your connection and that '
            'your email is listed in admin_emails.\n($e)';
        _loading = false;
      });
    }
  }

  List<AppUser> get _filteredUsers {
    var list = _users;

    if (_filterStatus == 'Active') {
      list = list.where((u) => !u.isBlocked && !u.isPaused).toList();
    } else if (_filterStatus == 'Blocked') {
      list = list.where((u) => u.isBlocked).toList();
    }

    if (_query.trim().isEmpty) return list;

    final q = _query.toLowerCase().trim();
    return list.where((u) {
      return u.displayName.toLowerCase().contains(q) ||
          (u.email ?? '').toLowerCase().contains(q) ||
          (u.phoneNumber ?? '').contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<AuthProvider>().isAdmin;
    if (!isAdmin) return const _AccessDenied();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryPeach = isDark ? AppColors.primaryVibrantDark : AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Roster',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Export Roster JSON',
            onPressed: _exportJson,
            icon: const Icon(Icons.ios_share),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryPeach,
          labelColor: primaryPeach,
          unselectedLabelColor: isDark ? Colors.white70 : AppColors.lightTextSecondary,
          tabs: [
            const Tab(icon: Icon(Icons.people_alt_outlined), text: 'User Roster'),
            const Tab(icon: Icon(Icons.notifications_active_outlined), text: 'Push Notification'),
            if (_hasSupport) const Tab(icon: Icon(Icons.support_agent), text: 'Support'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : KeyboardAvoiding(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUserRosterTab(context, primaryPeach),
                      _buildPushNotificationTab(context, primaryPeach),
                      if (_hasSupport) const SupportInbox(),
                    ],
                  ),
                ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: User Management & Active Roster
  // ---------------------------------------------------------------------------
  Widget _buildUserRosterTab(BuildContext context, Color primaryPeach) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _StatsGrid(stats: _stats),
          const SizedBox(height: 20),
          
          // Search & Filter controls
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search by name, email or phone…',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All', 'All (${_users.length})', primaryPeach),
                const SizedBox(width: 8),
                _filterChip('Active', 'Active (${_stats['active'] ?? 0})', Colors.green),
                const SizedBox(width: 8),
                _filterChip('Blocked', 'Blocked (${_stats['blocked'] ?? 0})', Colors.red),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'User Roster (${_filteredUsers.length})',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              Text(
                'Tap user to view profile',
                style: TextStyle(
                  color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_filteredUsers.isEmpty)
            _EmptyUsersState()
          else
            for (var i = 0; i < _filteredUsers.length; i++)
              _UserTile(
                user: _filteredUsers[i],
                isAdminUser: _adminEmails.contains((_filteredUsers[i].email ?? '').toLowerCase()),
                onChanged: _load,
                repo: _repo,
              ).animate(delay: (35 * i).ms).fadeIn().slideX(begin: 0.05),
        ],
      ),
    );
  }

  Widget _filterChip(String status, String label, Color accentColor) {
    final isSelected = _filterStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filterStatus = status),
      selectedColor: accentColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? accentColor : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? accentColor : Colors.grey.withValues(alpha: 0.3),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: Push Custom Notification
  // ---------------------------------------------------------------------------
  Widget _buildPushNotificationTab(BuildContext context, Color primaryPeach) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.rovlo.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryPeach.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.send_rounded, color: primaryPeach, size: 24),
                    const SizedBox(width: 10),
                    const Text(
                      'Push Custom Notification',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Sends an in-app broadcast to all users, plus a push notification to devices that allowed them.',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),

                // Notification Title
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Notification Title',
                    hintText: 'e.g. 🚀 Special Offer / App Update',
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 14),

                // Notification Message Body
                TextField(
                  controller: _bodyController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Message Body',
                    hintText: 'Type your broadcast message for Rovlo users...',
                    prefixIcon: Icon(Icons.message_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Type & Category Selector
                const Text(
                  'Notification Category',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: NotificationType.values.map((type) {
                    final selected = _selectedType == type;
                    return ChoiceChip(
                      label: Text(_typeLabel(type)),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedType = type),
                      selectedColor: primaryPeach.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: selected ? primaryPeach : null,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Target Audience
                Row(
                  children: [
                    const Text(
                      'Target Audience: ',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _selectedTarget,
                      items: const [
                        DropdownMenuItem(value: 'All Users', child: Text('All Users')),
                        DropdownMenuItem(value: 'Active Users', child: Text('Active Users Only')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedTarget = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Quick Presets
                const Text(
                  'Quick Presets:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('Welcome Promo'),
                        onPressed: () {
                          _titleController.text = '✨ Welcome to Rovlo!';
                          _bodyController.text = 'Explore new destinations and connect with amazing fellow travelers today.';
                          setState(() => _selectedType = NotificationType.announcement);
                        },
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.build_rounded, size: 16),
                        label: const Text('System Maintenance'),
                        onPressed: () {
                          _titleController.text = '⚡ Scheduled Maintenance';
                          _bodyController.text = 'Rovlo will undergo brief maintenance tonight to improve performance.';
                          setState(() => _selectedType = NotificationType.update);
                        },
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.verified_user_outlined, size: 16),
                        label: const Text('Security Alert'),
                        onPressed: () {
                          _titleController.text = '🔒 Safety Tip';
                          _bodyController.text = 'Never share personal authentication codes with anyone.';
                          setState(() => _selectedType = NotificationType.alert);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _sendingNotification ? null : _pushNotification,
                    icon: _sendingNotification
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    label: Text(
                      _sendingNotification ? 'Dispatching...' : 'Push Notification Now',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPeach,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Broadcast History Log
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Broadcast History (${_notifications.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (_notifications.isNotEmpty)
                TextButton(
                  onPressed: _clearAllNotifications,
                  child: const Text('Clear All', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_notifications.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Text(
                'No custom notifications pushed yet.',
                style: TextStyle(color: context.rovlo.textSecondary),
              ),
            )
          else
            for (var n in _notifications)
              _NotificationHistoryTile(
                notification: n,
                onDelete: () => _deleteNotification(n.id),
              ),
        ],
      ),
    );
  }

  String _typeLabel(NotificationType type) {
    switch (type) {
      case NotificationType.announcement:
        return '📢 Announcement';
      case NotificationType.alert:
        return '🚨 Alert';
      case NotificationType.promo:
        return '🎁 Promo';
      case NotificationType.update:
        return '⚡ System Update';
    }
  }

  Future<void> _pushNotification() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both title and message body.')),
      );
      return;
    }

    setState(() => _sendingNotification = true);

    final adminEmail = context.read<AuthProvider>().currentUser?.email ?? 'Admin';

    try {
      await _notificationService.sendNotification(
        title: title,
        body: body,
        type: _selectedType,
        targetAudience: _selectedTarget,
        sentBy: adminEmail,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingNotification = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send: $e')),
      );
      return;
    }

    _titleController.clear();
    _bodyController.clear();

    await _load();

    if (!mounted) return;
    setState(() => _sendingNotification = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text('Custom notification "$title" pushed successfully!')),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteNotification(String id) async {
    await _notificationService.deleteNotification(id);
    await _load();
  }

  Future<void> _clearAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History?'),
        content: const Text('Are you sure you want to clear all broadcast logs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _notificationService.clearAll();
      await _load();
    }
  }

  Future<void> _exportJson() async {
    final json = await _repo.exportJson();
    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User roster (JSON) copied to clipboard!')),
    );
  }
}

// -----------------------------------------------------------------------------
// STATS GRID WIDGET
// -----------------------------------------------------------------------------
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final Map<String, int> stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Total Logged In', stats['total'] ?? 0, Icons.group_rounded, AppColors.primary),
      ('Active Users', stats['active'] ?? 0, Icons.bolt_rounded, Colors.green),
      ('Verified Profiles', stats['verified'] ?? 0, Icons.verified_rounded, Colors.blue),
      ('Blocked Accounts', stats['blocked'] ?? 0, Icons.block_rounded, AppColors.error),
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.rovlo.card,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: color.withValues(alpha: 0.15)),
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
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$value',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        label,
                        style: TextStyle(color: context.rovlo.textSecondary, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// USER TILE & DETAILED PROFILE MODAL
// -----------------------------------------------------------------------------
class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.isAdminUser,
    required this.onChanged,
    required this.repo,
  });

  final AppUser user;
  final bool isAdminUser;
  final VoidCallback onChanged;
  final UserRepository repo;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy');
    final isAdmin = isAdminUser;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.rovlo.card,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: user.isBlocked
            ? Border.all(color: AppColors.error.withValues(alpha: 0.6))
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: user.isBlocked
              ? AppColors.error.withValues(alpha: 0.2)
              : AppColors.primary.withValues(alpha: 0.15),
          child: Text(
            user.initials,
            style: TextStyle(
              color: user.isBlocked ? AppColors.error : AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                user.displayName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (user.isVerified) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified, size: 16, color: Colors.blue),
            ],
            if (isAdmin) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ADMIN',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            if (user.isBlocked) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'BLOCKED',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${user.email ?? user.phoneNumber ?? 'No contact'} • Joined ${df.format(user.createdAt)}',
          style: TextStyle(color: context.rovlo.textSecondary, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleAction(context, action),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('View Full Profile'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'block',
              child: Row(
                children: [
                  Icon(
                    user.isBlocked ? Icons.check_circle_outline : Icons.block_outlined,
                    color: user.isBlocked ? Colors.green : Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    user.isBlocked ? 'Unblock Account' : 'Block Account',
                    style: TextStyle(color: user.isBlocked ? Colors.green : Colors.orange),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                  SizedBox(width: 8),
                  Text('Delete User', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showProfileModal(context),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    switch (action) {
      case 'view':
        _showProfileModal(context);
        break;
      case 'block':
        final newBlockedState = !user.isBlocked;
        await repo.setBlocked(user.id, newBlockedState);
        onChanged();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newBlockedState
                    ? '🚫 Account ${user.displayName} blocked.'
                    : '✅ Account ${user.displayName} unblocked.',
              ),
            ),
          );
        }
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete user?'),
            content: Text('This permanently removes ${user.displayName} from the user roster.'),
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
        if (confirm == true) {
          await repo.delete(user.id);
          onChanged();
        }
        break;
    }
  }

  void _showProfileModal(BuildContext context) {
    final df = DateFormat('d MMM yyyy, HH:mm');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.displayName,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (user.isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified, color: Colors.blue, size: 20),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email ?? user.phoneNumber ?? 'No contact',
                        style: TextStyle(color: context.rovlo.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text('ACCOUNT STATUS & DETAILS',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
            const Divider(),
            _detailRow(context, 'User ID', user.id),
            _detailRow(context, 'Email', user.email ?? '—'),
            _detailRow(context, 'Phone Number', user.phoneNumber ?? '—'),
            _detailRow(context, 'Gender', user.gender ?? '—'),
            _detailRow(context, 'Home Base', user.homeBase ?? '—'),
            _detailRow(context, 'Auth Method', user.authMethod.name.toUpperCase()),
            _detailRow(context, 'Profile Complete', user.profileComplete ? 'Yes' : 'No'),
            _detailRow(context, 'Account Status', user.isBlocked ? 'Blocked 🚫' : 'Active ✅'),
            _detailRow(context, 'Joined Date', df.format(user.createdAt)),
            _detailRow(
              context,
              'Interests',
              user.travelInterests.isEmpty ? '—' : user.travelInterests.join(', '),
            ),
            if (user.bio != null && user.bio!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('BIO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.rovlo.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(user.bio!, style: const TextStyle(fontSize: 13, height: 1.4)),
              ),
            ],
            const SizedBox(height: 24),

            // Quick Actions in Modal
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await repo.setBlocked(user.id, !user.isBlocked);
                      onChanged();
                    },
                    icon: Icon(
                      user.isBlocked ? Icons.check_circle : Icons.block,
                      color: Colors.white,
                    ),
                    label: Text(
                      user.isBlocked ? 'Unblock User' : 'Block Profile',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: user.isBlocked ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: context.rovlo.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// NOTIFICATION HISTORY TILE
// -----------------------------------------------------------------------------
class _NotificationHistoryTile extends StatelessWidget {
  const _NotificationHistoryTile({
    required this.notification,
    required this.onDelete,
  });

  final AdminNotification notification;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy, HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.rovlo.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: Text(_iconForType(notification.type), style: const TextStyle(fontSize: 18)),
        ),
        title: Text(notification.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(notification.body, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              'Target: ${notification.targetAudience} • ${df.format(notification.sentAt)}',
              style: TextStyle(color: context.rovlo.textSecondary, fontSize: 11),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
          onPressed: onDelete,
        ),
      ),
    );
  }

  String _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.announcement:
        return '📢';
      case NotificationType.alert:
        return '🚨';
      case NotificationType.promo:
        return '🎁';
      case NotificationType.update:
        return '⚡';
    }
  }
}

class _EmptyUsersState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.group_off_outlined, size: 48, color: context.rovlo.textSecondary),
            const SizedBox(height: 12),
            Text('No users found', style: TextStyle(color: context.rovlo.textSecondary)),
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
            const Text(
              'Access Denied',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
