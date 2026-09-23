import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/widgets/keyboard_inset.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../profile/verify_screen.dart';
import '../profile/rovlo_plus_screen.dart';
import '../profile/emergency_contacts_screen.dart';
import 'saved_tab.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final PageController _pageController = PageController();
  int _currentPhotoPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showEditProfile(BuildContext context, AuthProvider provider, AppUser user) {
    final nameController = TextEditingController(text: user.name ?? '');
    final bioController = TextEditingController(text: user.bio ?? '');
    final homeBaseController = TextEditingController(text: user.homeBase ?? '');
    String selectedAvatar = user.photoUrl ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final primaryPeach = isDark ? AppColors.primaryVibrantDark : AppColors.primary;

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: KeyboardInset.of(context) + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Profile',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Profile Picture',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: primaryPeach, width: 2),
                            image: DecorationImage(
                              image: (selectedAvatar.isEmpty || selectedAvatar.startsWith('http'))
                                  ? NetworkImage(selectedAvatar.isNotEmpty
                                      ? selectedAvatar
                                      : 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80')
                                  : FileImage(File(selectedAvatar)) as ImageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final ImagePicker picker = ImagePicker();
                                  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                                  if (image != null) {
                                    setModalState(() {
                                      selectedAvatar = image.path;
                                    });
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('📸 Selected image from device gallery')),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.photo_library_outlined, size: 18),
                                label: const Text('Choose from Gallery'),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final ImagePicker picker = ImagePicker();
                                  final XFile? image = await picker.pickImage(source: ImageSource.camera);
                                  if (image != null) {
                                    setModalState(() {
                                      selectedAvatar = image.path;
                                    });
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('📸 Captured photo from camera!')),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                                label: const Text('Take Photo'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        hintText: 'Display Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: bioController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'About Me / Bio',
                        prefixIcon: Icon(Icons.info_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: homeBaseController,
                      decoration: const InputDecoration(
                        hintText: 'Home Base (e.g. Mumbai, India)',
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          final photos = List<String>.from(user.profilePhotos);
                          if (selectedAvatar != user.photoUrl) {
                            photos.remove(selectedAvatar);
                            photos.insert(0, selectedAvatar);
                          }
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await provider.updateProfile(
                              name: nameController.text,
                              bio: bioController.text,
                              photoUrl: selectedAvatar,
                              profilePhotos: photos,
                              homeBase: homeBaseController.text.trim().isNotEmpty
                                  ? homeBaseController.text.trim()
                                  : null,
                            );
                            if (context.mounted) Navigator.pop(context);
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Profile updated successfully!')),
                            );
                          } catch (_) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Could not save your profile. Check your connection.')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPeach,
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _formatDob(String dobIso) {
    try {
      final dt = DateTime.parse(dobIso);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dobIso;
    }
  }

  void _triggerSOS(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text(
                'EMERGENCY SOS',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'This will share your location with authorities and nearby travelers. Do you wish to trigger the SOS alert?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.red,
                    content: Text(
                      '🚨 Simulated Alert Sent! Location shared with emergency services.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text(
                'TRIGGER SOS',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handlePhotoAction(BuildContext context, AuthProvider provider, AppUser user, String action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _handlePhotoActionInner(context, provider, user, action);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update your photos. Check your connection.')),
      );
    }
  }

  Future<void> _handlePhotoActionInner(BuildContext context, AuthProvider provider, AppUser user, String action) async {
    final ImagePicker picker = ImagePicker();
    
    if (action == 'gallery') {
      final photos = List<String>.from(user.profilePhotos);
      if (photos.length >= 5) return;
      
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        photos.add(image.path);
        await provider.updateProfile(
          profilePhotos: photos,
          photoUrl: user.photoUrl ?? image.path,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('📸 Added photo from gallery!')),
          );
        }
      }
    } else if (action == 'camera') {
      final photos = List<String>.from(user.profilePhotos);
      if (photos.length >= 5) return;
      
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        photos.add(image.path);
        await provider.updateProfile(
          profilePhotos: photos,
          photoUrl: user.photoUrl ?? image.path,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('📸 Captured photo from camera!')),
          );
        }
      }
    } else if (action == 'pin') {
      final photos = List<String>.from(user.effectivePhotos);
      if (photos.isEmpty || _currentPhotoPage >= photos.length) return;
      
      final pinned = photos.removeAt(_currentPhotoPage);
      photos.insert(0, pinned);
      
      await provider.updateProfile(
        profilePhotos: photos,
        photoUrl: pinned,
      );
      
      setState(() {
        _currentPhotoPage = 0;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📌 Pinned photo as primary profile picture!')),
      );
    } else if (action == 'delete') {
      final photos = List<String>.from(user.effectivePhotos);
      if (photos.isEmpty || _currentPhotoPage >= photos.length) return;
      
      photos.removeAt(_currentPhotoPage);
      final newPrimary = photos.isNotEmpty ? photos.first : '';
      
      await provider.updateProfile(
        profilePhotos: photos,
        photoUrl: newPrimary.isNotEmpty ? newPrimary : null,
      );
      
      setState(() {
        if (_currentPhotoPage >= photos.length && _currentPhotoPage > 0) {
          _currentPhotoPage = photos.length - 1;
        }
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentPhotoPage);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ Deleted photo successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuthProvider>();
    final user = provider.currentUser;
    if (user == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryPeach = isDark ? AppColors.primaryVibrantDark : AppColors.primary;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Row(
            children: [
              Text(
                'Profile',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
              ),
              const Spacer(),
              // SOS emergency button
              GestureDetector(
                onTap: () => _triggerSOS(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.emergency_share, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.pushNamed(context, Routes.settings),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Swipable Photo Carousel Header (Matches Card style) ──
          SizedBox(
            height: 340,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // PageView of photos
                  if (user.effectivePhotos.isEmpty)
                    Container(
                      color: isDark ? AppColors.darkCard : Colors.grey.shade200,
                      child: Center(
                        child: Icon(Icons.person, size: 80, color: primaryPeach.withValues(alpha: 0.5)),
                      ),
                    )
                  else
                    PageView.builder(
                      controller: _pageController,
                      itemCount: user.effectivePhotos.length,
                      onPageChanged: (page) {
                        setState(() {
                          _currentPhotoPage = page;
                        });
                      },
                      itemBuilder: (context, index) {
                        final photo = user.effectivePhotos[index];
                        if (photo.startsWith('http')) {
                          return Image.network(
                            photo,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.broken_image, size: 50),
                            ),
                          );
                        } else {
                          return Image.file(
                            File(photo),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.broken_image, size: 50),
                            ),
                          );
                        }
                      },
                    ),

                  // Shadow Overlay (Bottom and Top)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                          stops: const [0.0, 0.25, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Horizontal Indicators at top
                  if (user.effectivePhotos.length > 1)
                    Positioned(
                      top: 16,
                      left: 20,
                      right: 20,
                      child: Row(
                        children: List.generate(user.effectivePhotos.length, (i) {
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: 3,
                              decoration: BoxDecoration(
                                color: _currentPhotoPage == i
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                  // Name & Info overlay at bottom left
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 80, // Leave space for completion percentage on right
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (user.isVerified) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, color: Colors.blue, size: 20),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email ?? user.phoneNumber ?? '',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                        if (user.gender != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            user.gender!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Completion percentage overlay (bottom right)
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: CustomPaint(
                              painter: _CompletionRingPainter(
                                progress: user.profileCompletionPercent,
                                color: Colors.white,
                                bgColor: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                          Text(
                            '${(user.profileCompletionPercent * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top right: Action popup three-dot menu button
                  Positioned(
                    top: 24,
                    right: 12,
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
                      color: isDark ? AppColors.darkCard : Colors.white,
                      onSelected: (value) => _handlePhotoAction(context, provider, user, value),
                      itemBuilder: (context) {
                        final count = user.effectivePhotos.length;
                        return [
                          if (count < 5) ...[
                            const PopupMenuItem(
                              value: 'gallery',
                              child: Row(
                                children: [
                                  Icon(Icons.photo_library_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Add from Gallery'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'camera',
                              child: Row(
                                children: [
                                  Icon(Icons.camera_alt_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Take Photo'),
                                ],
                              ),
                            ),
                          ],
                          if (count > 0) ...[
                            const PopupMenuItem(
                              value: 'pin',
                              child: Row(
                                children: [
                                  Icon(Icons.push_pin_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Pin as Primary'),
                                ],
                              ),
                            ),
                          ],
                          if (count > 0) ...[
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                  SizedBox(width: 8),
                                  Text('Delete Photo', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ];
                      },
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 20),

          // DOB & Home Base info
          if (user.dob != null || user.homeBase != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: context.rovlo.card,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                children: [
                  if (user.dob != null)
                    Row(
                      children: [
                        Icon(Icons.cake_outlined, color: primaryPeach, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          'Born: ${_formatDob(user.dob!)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  if (user.dob != null && user.homeBase != null)
                    const SizedBox(height: 10),
                  if (user.homeBase != null)
                    Row(
                      children: [
                        Icon(Icons.home_outlined, color: primaryPeach, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          'Home Base: ${user.homeBase}',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

          // About / Bio section
          const _SectionLabel('About Me'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.rovlo.card,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: Text(
              user.bio != null && user.bio!.isNotEmpty
                  ? user.bio!
                  : 'Add a small bio of yourself. Let fellow travelers know who you are!',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                fontStyle: user.bio != null && user.bio!.isNotEmpty ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Edit Profile button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => _showEditProfile(context, provider, user),
              icon: Icon(Icons.edit_outlined, color: primaryPeach, size: 18),
              label: Text(
                'Edit Profile',
                style: TextStyle(color: primaryPeach, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: primaryPeach.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Saved Profiles button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedTab()),
              ),
              icon: const Icon(Icons.bookmark_outline, color: Colors.white, size: 18),
              label: const Text(
                'Saved Profiles & Trips',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (user.travelInterests.isNotEmpty) ...[
            const _SectionLabel('Travel interests'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final interest in user.travelInterests)
                  Chip(
                    label: Text(interest),
                    backgroundColor: primaryPeach.withValues(alpha: 0.12),
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      color: isDark ? AppColors.secondary : AppColors.primaryDark,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          const _SectionLabel('Account'),
          const SizedBox(height: 10),
          _MenuTile(
            icon: Icons.verified_outlined,
            label: 'Verify (Blue Tick)',
            highlight: !user.isVerified,
            trailing: user.isVerified
                ? const Icon(Icons.verified, color: Colors.blue, size: 20)
                : null,
            onTap: () {
              if (user.isVerified) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('You are already verified! ✓')),
                );
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const VerifyScreen()));
              }
            },
          ),
          _MenuTile(
            icon: Icons.star_rounded,
            label: 'Rovlo Plus',
            highlight: true,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RovloPlusScreen())),
          ),
          _MenuTile(
            icon: Icons.contact_phone_outlined,
            label: 'Emergency Contacts',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyContactsScreen())),
          ),
          _MenuTile(
            icon: Icons.settings_outlined,
            label: 'Settings & appearance',
            onTap: () => Navigator.pushNamed(context, Routes.settings),
          ),
          _MenuTile(
            icon: Icons.notifications_none,
            label: 'Notifications',
            onTap: () => _soon(context),
          ),
          _MenuTile(
            icon: Icons.help_outline,
            label: 'Help & support',
            onTap: () => _soon(context),
          ),

          if (provider.isAdmin) ...[
            const SizedBox(height: 24),
            const _SectionLabel('Admin'),
            const SizedBox(height: 10),
            _MenuTile(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Admin panel',
              highlight: true,
              onTap: () => Navigator.pushNamed(context, Routes.admin),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmSignOut(context, provider),
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text('Sign out', style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await provider.togglePauseAccount();
                if (!context.mounted) return;
                final isPaused = provider.currentUser?.isPaused ?? false;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isPaused
                          ? '⏸️ Account paused. Your profile is hidden from discovery.'
                          : '▶️ Account resumed! You are visible again.',
                    ),
                  ),
                );
              },
              icon: Icon(
                user.isPaused ? Icons.play_arrow : Icons.pause_circle_outline,
                color: Colors.orange,
              ),
              label: Text(
                user.isPaused ? 'Resume Account' : 'Pause Account',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.orange),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _confirmDeleteAccount(context, provider),
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              label: const Text('Delete Account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon')),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, AuthProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await provider.signOut();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, Routes.welcome, (r) => false);
  }

  Future<void> _confirmDeleteAccount(BuildContext context, AuthProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to permanently delete your account? This action cannot be undone and all your trips, messages, and matches will be lost forever.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.deleteAccount();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete your account. Check your connection and try again.')),
      );
      return;
    }
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, Routes.welcome, (r) => false);
    messenger.showSnackBar(
      const SnackBar(content: Text('Your account has been deleted.')),
    );
  }
}

/// Custom painter for the circular completion ring around the avatar.
class _CompletionRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;

  const _CompletionRingPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    // Background circle
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CompletionRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: context.rovlo.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryPeach = isDark ? AppColors.primaryVibrantDark : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: highlight
            ? primaryPeach.withValues(alpha: 0.10)
            : context.rovlo.card,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          leading: Icon(icon, color: highlight ? primaryPeach : null),
          title: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: highlight ? (isDark ? AppColors.secondary : AppColors.primaryDark) : null,
            ),
          ),
          trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
          onTap: onTap,
        ),
      ),
    );
  }
}


