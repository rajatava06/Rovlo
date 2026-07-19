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
    if (provider == _Provider.google) {
      // Real Google Sign-In — triggers the native account picker
      setState(() {
        _inFlight = provider;
        _error = null;
      });
      final auth = context.read<AuthProvider>();
      try {
        final user = await auth.signInWithGoogle();
        if (!mounted) return;
        if (user == null) {
          // User cancelled the picker
          setState(() => _inFlight = null);
          return;
        }
        _routeAfterAuth(user);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _inFlight = null;
          _error = e.toString();
        });
      }
      return;
    }

    if (provider == _Provider.demo) {
      // Demo Sign-In
      setState(() {
        _inFlight = provider;
        _error = null;
      });
      final auth = context.read<AuthProvider>();
      try {
        final user = await auth.signInDemo();
        if (!mounted || user == null) return;
        _routeAfterAuth(user);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _inFlight = null;
          _error = e.toString();
        });
      }
      return;
    }

    // Apple: still uses the simulated consent dialog
    final credentials = await _showSimulatedOAuthConsent(context);
    if (credentials == null) {
      setState(() {
        _inFlight = null;
      });
      return;
    }

    setState(() {
      _inFlight = provider;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    try {
      final user = await auth.signInWithApple(
        email: credentials['email'],
        name: credentials['name'],
      );
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

  Future<Map<String, String>?> _showSimulatedOAuthConsent(BuildContext context) {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final titleColor = isDark ? Colors.white : Colors.black87;
        
        return Center(
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 15, spreadRadius: 3),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Address Bar Simulation
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock, size: 12, color: Colors.green.shade600),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'https://appleid.apple.com/auth',
                            style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Icon header
                  Icon(
                    Icons.apple,
                    size: 48,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(height: 12),
                  
                  Text(
                    'Sign in with Apple',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'to continue to Rovlo App',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Inputs
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: titleColor),
                    decoration: InputDecoration(
                      hintText: 'Apple ID Email',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.email_outlined, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: titleColor),
                    decoration: InputDecoration(
                      hintText: 'Display Name (Optional)',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.person_outline, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, null),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final email = emailController.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid email address')),
                            );
                            return;
                          }
                          Navigator.pop(ctx, {
                            'email': email,
                            'name': nameController.text.trim(),
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.white : Colors.black87,
                          foregroundColor: isDark ? Colors.black87 : Colors.white,
                        ),
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
                  if (_appleAvailable) ...[
                    SocialButton.apple(
                      loading: _inFlight == _Provider.apple,
                      onPressed: _inFlight != null
                          ? null
                          : () => _authenticate(_Provider.apple),
                    ).animate(delay: 380.ms).fadeIn().slideY(begin: 0.3),
                    const SizedBox(height: 14),
                  ],
                  // Demo Sign-In Option
                  OutlinedButton(
                    onPressed: _inFlight != null
                        ? null
                        : () => _authenticate(_Provider.demo),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(double.infinity, 54),
                    ),
                    child: _inFlight == _Provider.demo
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.developer_mode_outlined, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Explore with Demo Account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                  ).animate(delay: 450.ms).fadeIn().slideY(begin: 0.3),
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

enum _Provider { google, apple, demo }

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
