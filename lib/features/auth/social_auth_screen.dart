import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/rovlo_logo.dart';
import '../../core/widgets/social_auth_buttons.dart';
import '../../core/widgets/video_background.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';

/// Arguments controlling how the social-auth screen behaves.
class SocialAuthArgs {
  const SocialAuthArgs({required this.isSignIn});

  /// true  -> "Sign In": go straight here from Welcome, land on Home after.
  /// false -> "Create Account": reached after phone verification, continues
  ///          into the profile-setup steps afterwards.
  final bool isSignIn;
}

class SocialAuthScreen extends StatefulWidget {
  const SocialAuthScreen({super.key, required this.args});

  final SocialAuthArgs args;

  @override
  State<SocialAuthScreen> createState() => _SocialAuthScreenState();
}

class _SocialAuthScreenState extends State<SocialAuthScreen> {
  _Provider? _inFlight;
  String? _error;

  bool get _isSignIn => widget.args.isSignIn;

  bool get _appleAvailable {
    // Show Apple sign-in on Apple platforms; also offered on web so the
    // "Sign in with Apple JS" flow can be wired up later.
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> _authenticate(_Provider provider) async {
    setState(() {
      _inFlight = provider;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    try {
      final user = provider == _Provider.google
          ? await auth.signInWithGoogle()
          : await auth.signInWithApple();
      if (!mounted || user == null) return;
      _routeAfterAuth(user);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _inFlight = null;
        _error = e.toString();
      });
    }
  }

  void _routeAfterAuth(AppUser user) {
    if (_isSignIn) {
      // Sign-in: always go straight to home — user already has an account.
      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.home,
        (route) => false,
      );
    } else {
      // Create Account: continue with profile setup (name -> gender -> dob -> travel).
      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.name,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VideoBackground(
        assetPath: AppConstants.signInVideoAsset,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const Spacer(flex: 2),
                  const RovloLogo(fontSize: 44)
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.2),
                  const SizedBox(height: 16),
                  Text(
                    _isSignIn
                        ? 'Welcome back'
                        : 'One tap to secure your account',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ).animate(delay: 120.ms).fadeIn(),
                  const SizedBox(height: 8),
                  Text(
                    _isSignIn
                        ? 'Sign in with the account you used before.'
                        : 'Link Google or Apple to keep your trips safe and '
                            'synced.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14.5,
                      height: 1.4,
                    ),
                  ).animate(delay: 200.ms).fadeIn(),
                  const Spacer(flex: 3),
                  SocialButton.google(
                    loading: _inFlight == _Provider.google,
                    onPressed: _inFlight != null
                        ? null
                        : () => _authenticate(_Provider.google),
                  ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.3),
                  const SizedBox(height: 14),
                  if (_appleAvailable)
                    SocialButton.apple(
                      loading: _inFlight == _Provider.apple,
                      onPressed: _inFlight != null
                          ? null
                          : () => _authenticate(_Provider.apple),
                    ).animate(delay: 380.ms).fadeIn().slideY(begin: 0.3),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBanner(message: _error!),
                  ],
                  const Spacer(flex: 2),
                  Text(
                    'Secured with end-to-end encryption',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _Provider { google, apple }

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Colors.black87, fontSize: 13)),
          ),
        ],
      ),
    ).animate().shake(hz: 3, duration: 400.ms);
  }
}
