import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../providers/auth_provider.dart';

/// Verification screen: mock selfie + govt ID upload flow.
class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  bool _isCameraOpen = false;
  bool _selfieTaken = false;
  bool _idUploaded = false;
  bool _submitted = false;

  String? _selfieUrl;
  String? _uploadedFileName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryPeach = isDark ? AppColors.primaryVibrantDark : AppColors.primary;

    if (_isCameraOpen) {
      return _buildCameraViewfinder(context, primaryPeach);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Verified'),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
      ),
      body: _submitted
          ? _buildSuccess(context, primaryPeach)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryPeach, primaryPeach.withValues(alpha: 0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified, color: Colors.white, size: 40),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Blue Tick Verification',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Verify your identity to earn a trusted blue tick on your profile.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: 0.1),
                  const SizedBox(height: 32),

                  // Step 1: Selfie
                  _StepCard(
                    stepNumber: 1,
                    title: 'Take a Selfie',
                    description: _selfieTaken
                        ? 'Selfie captured successfully ✓'
                        : 'Open camera to take a clear photo of your face.',
                    icon: Icons.camera_alt_outlined,
                    isCompleted: _selfieTaken,
                    isEnabled: true,
                    onTap: () {
                      setState(() {
                        _isCameraOpen = true;
                      });
                    },
                    primaryColor: primaryPeach,
                    previewWidget: _selfieUrl != null
                        ? Container(
                            margin: const EdgeInsets.only(top: 10),
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(
                                image: NetworkImage(_selfieUrl!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        : null,
                  ).animate(delay: 100.ms).fadeIn().slideX(begin: 0.1),
                  const SizedBox(height: 16),

                  // Step 2: Government ID
                  _StepCard(
                    stepNumber: 2,
                    title: 'Upload Government ID',
                    description: _idUploaded
                        ? 'Government ID uploaded ✓'
                        : 'Upload a valid government-issued ID (Passport, Aadhaar, License).',
                    icon: Icons.badge_outlined,
                    isCompleted: _idUploaded,
                    isEnabled: _selfieTaken,
                    onTap: () => _showIdUploadOptions(context, primaryPeach),
                    primaryColor: primaryPeach,
                    previewWidget: _uploadedFileName != null
                        ? Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black12,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.file_present_outlined, size: 16, color: primaryPeach),
                                const SizedBox(width: 8),
                                Text(
                                  _uploadedFileName!,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          )
                        : null,
                  ).animate(delay: 200.ms).fadeIn().slideX(begin: 0.1),
                  const SizedBox(height: 32),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_selfieTaken && _idUploaded)
                          ? () async {
                              await context.read<AuthProvider>().setVerified(true);
                              setState(() => _submitted = true);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPeach,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Submit for Verification',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCameraViewfinder(BuildContext context, Color primaryPeach) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Viewfinder background with placeholder/mock pulse
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryPeach, width: 3),
                  ),
                  child: Center(
                    child: const Icon(
                      Icons.person,
                      color: Colors.white24,
                      size: 140,
                    ).animate(onPlay: (controller) => controller.repeat(reverse: true)).fade(duration: 1000.ms),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Center your face inside the circle',
                  style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            child: RovloBackButton(
              onPressed: () => setState(() => _isCameraOpen = false),
              color: Colors.white,
              backgroundColor: Colors.black45,
            ),
          ),
          // Capture controls
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selfieTaken = true;
                      _selfieUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80';
                      _isCameraOpen = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('📸 Selfie captured successfully!')),
                    );
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showIdUploadOptions(BuildContext context, Color primaryPeach) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload Government ID',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload any official document (Passport, Aadhaar, License). Supported formats: PDF, PNG, JPEG.',
                style: TextStyle(fontSize: 13, color: context.rovlo.textSecondary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => _mockUpload(ctx, 'govt_id_document.pdf'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPeach,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.upload_file, color: Colors.white),
                  label: const Text(
                    'Select Document or Image',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _mockUpload(BuildContext context, String fileName) {
    Navigator.pop(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Uploading document...'),
            ],
          ),
        );
      },
    );

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        nav.pop(); // Close loading dialog
        setState(() {
          _idUploaded = true;
          _uploadedFileName = fileName;
        });
        messenger.showSnackBar(
          SnackBar(content: Text('✓ Document uploaded successfully: $fileName')),
        );
      }
    });
  }

  Widget _buildSuccess(BuildContext context, Color primaryPeach) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: primaryPeach.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.verified, color: primaryPeach, size: 56),
            ).animate().scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut, duration: 600.ms),
            const SizedBox(height: 24),
            const Text(
              'Verification Complete! 🎉',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your profile now has a blue verification badge. Other travelers can see that you\'re a verified user.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.rovlo.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPeach,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Back to Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String description;
  final IconData icon;
  final bool isCompleted;
  final bool isEnabled;
  final VoidCallback onTap;
  final Color primaryColor;
  final Widget? previewWidget;

  const _StepCard({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.icon,
    required this.isCompleted,
    required this.isEnabled,
    required this.onTap,
    required this.primaryColor,
    this.previewWidget,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: (isCompleted || !isEnabled) ? null : onTap,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.45,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.green.withValues(alpha: 0.08)
                : (isDark ? AppColors.darkCard : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCompleted ? Colors.green : (isDark ? Colors.white12 : Colors.black12),
              width: isCompleted ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green.withValues(alpha: 0.15)
                          : primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCompleted ? Icons.check : icon,
                      color: isCompleted ? Colors.green : primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Step $stepNumber: $title',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isCompleted ? Colors.green : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.rovlo.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isCompleted && isEnabled)
                    Icon(Icons.arrow_forward_ios, size: 16, color: context.rovlo.textSecondary),
                ],
              ),
              if (previewWidget != null) previewWidget!,
            ],
          ),
        ),
      ),
    );
  }
}
