import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import '../../providers/auth_provider.dart';

/// Profile step: Upload 1 to 8 profile photos from device.
class PhotosSelectionScreen extends StatefulWidget {
  const PhotosSelectionScreen({super.key});

  @override
  State<PhotosSelectionScreen> createState() => _PhotosSelectionScreenState();
}

class _PhotosSelectionScreenState extends State<PhotosSelectionScreen> {
  final List<String> _photos = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final existing = context.read<AuthProvider>().currentUser?.profilePhotos;
    if (existing != null && existing.isNotEmpty) {
      _photos.addAll(existing);
    }
  }

  Future<void> _pickPhoto(int index) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          if (index < _photos.length) {
            _photos[index] = picked.path;
          } else {
            _photos.add(picked.path);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting photo: $e')),
      );
    }
  }

  void _removePhoto(int index) {
    setState(() {
      if (index < _photos.length) {
        _photos.removeAt(index);
      }
    });
  }

  Future<void> _continue() async {
    if (_photos.isEmpty) return;
    setState(() => _isLoading = true);
    await context.read<AuthProvider>().setPhotos(_photos);
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pushNamed(context, Routes.dob);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 4,
      totalSteps: 7,
      title: 'Add your best photos',
      subtitle: 'Upload at least 1 photo to continue. You can add up to 8 photos.',
      continueEnabled: _photos.isNotEmpty,
      busy: _isLoading,
      onContinue: _continue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: 8,
            itemBuilder: (context, index) {
              final hasPhoto = index < _photos.length;
              final photoPath = hasPhoto ? _photos[index] : null;

              return GestureDetector(
                onTap: () => _pickPhoto(index),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.rovlo.card,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(
                      color: hasPhoto
                          ? AppColors.primary
                          : context.rovlo.textSecondary.withValues(alpha: 0.2),
                      width: hasPhoto ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radius - 2),
                          child: hasPhoto
                              ? _buildImage(photoPath!)
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo_outlined,
                                      color: AppColors.primary,
                                      size: 26,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      index == 0 ? 'Main Photo*' : 'Add',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: index == 0
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: index == 0
                                            ? AppColors.primary
                                            : context.rovlo.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      if (hasPhoto)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removePhoto(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      if (index == 0 && hasPhoto)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Main',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ).animate(delay: (40 * index).ms).fadeIn().scale(),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            '* At least 1 photo is required. Clear & high quality photos get 4x more connections!',
            style: TextStyle(
              fontSize: 12,
              color: context.rovlo.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String path) {
    Widget broken(BuildContext _, Object __, StackTrace? ___) => const ColoredBox(
          color: Color(0x14000000),
          child: Center(child: Icon(Icons.broken_image_outlined)),
        );
    if (path.startsWith('http') || kIsWeb) {
      return Image.network(path,
          fit: BoxFit.cover, cacheWidth: 900, errorBuilder: broken);
    }
    // Phone-camera photos are 4000+ px wide: decode them at screen size.
    return Image.file(File(path),
        fit: BoxFit.cover, cacheWidth: 900, errorBuilder: broken);
  }
}
