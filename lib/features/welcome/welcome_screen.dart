import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/rovlo_logo.dart';
import '../../core/widgets/video_background.dart';
import '../auth/social_auth_screen.dart';

/// First screen: looping video (with animated-gradient fallback), the Rovlo
/// wordmark centred, Create Account + Sign In, and Terms & Conditions.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VideoBackground(
        assetPath: AppConstants.welcomeVideoAsset,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 3),
                Column(
                  children: [
                    const RovloLogo(fontSize: 64)
                        .animate()
                        .fadeIn(duration: 700.ms, delay: 150.ms)
                        .slideY(begin: 0.2, curve: Curves.easeOutCubic),
                    const SizedBox(height: 12),
                    const Text(
                      AppConstants.tagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        letterSpacing: 0.3,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 700.ms, delay: 450.ms)
                        .slideY(begin: 0.3),
                  ],
                ),
                const Spacer(flex: 4),
                _CreateAccountButton()
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 700.ms)
                    .slideY(begin: 0.4, curve: Curves.easeOutCubic),
                const SizedBox(height: 14),
                _SignInButton()
                    .animate()
                    .fadeIn(duration: 800.ms, delay: 850.ms)
                    .scaleXY(begin: 0.9, end: 1.0, curve: Curves.easeOutBack)
                    .slideY(begin: 0.15, end: 0.0, curve: Curves.easeOutQuad),
                const SizedBox(height: 22),
                const _TermsText()
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 1000.ms),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateAccountButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => Navigator.pushNamed(context, Routes.phone),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        child: const Text('Create Account'),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: () => Navigator.pushNamed(
          context,
          Routes.socialAuth,
          arguments: const SocialAuthArgs(isSignIn: true),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color.fromARGB(255, 255, 255, 255),
          backgroundColor: Colors.transparent,
          side: BorderSide(
              color: const Color.fromARGB(4, 255, 255, 255)
                  .withValues(alpha: 0.35),
              width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text('Sign In'),
      ),
    );
  }
}

class _TermsText extends StatelessWidget {
  const _TermsText();

  @override
  Widget build(BuildContext context) {
    const linkStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );
    return Text.rich(
      TextSpan(
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 12.5,
          height: 1.5,
        ),
        children: [
          const TextSpan(text: 'By continuing you agree to our '),
          TextSpan(
            text: 'Terms & Conditions',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _showLegal(context, 'Terms & Conditions'),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _showLegal(context, 'Privacy Policy'),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  void _showLegal(BuildContext context, String title) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Text(
              'This is placeholder legal copy for Rovlo. Replace it with your '
              'final $title before shipping.\n\n'
              'Rovlo helps travellers discover, plan and share journeys. By '
              'using the app you agree to travel responsibly, respect local '
              'laws and communities, and to our handling of your data as '
              'described in the Privacy Policy.\n\n'
              'For the complete, up-to-date document visit '
              '${AppConstants.termsUrl}.',
              style: TextStyle(height: 1.6, color: context.textSecondaryColor),
            ),
          ],
        ),
      ),
    );
  }
}

extension on BuildContext {
  Color get textSecondaryColor =>
      Theme.of(this).textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ??
      Colors.grey;
}
