import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import '../../providers/auth_provider.dart';
import 'social_auth_screen.dart';

/// Account-creation step 1: capture the user's phone number, then verify via
/// a 6-digit OTP (demo code: 123456).
class PhoneNumberScreen extends StatefulWidget {
  const PhoneNumberScreen({super.key});

  @override
  State<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends State<PhoneNumberScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  String _dialCode = '+91';
  bool _otpSent = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  bool get _phoneValid => _phoneController.text.trim().length >= 7;

  String get _fullNumber => '$_dialCode ${_phoneController.text.trim()}';

  Future<void> _sendOtp() async {
    final auth = context.read<AuthProvider>();
    await auth.requestOtp(_fullNumber);
    if (!mounted) return;
    setState(() {
      _otpSent = true;
      _error = null;
    });
  }

  Future<void> _verify() async {
    setState(() => _error = null);
    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyOtp(_otpController.text.trim());
    if (!mounted) return;
    if (ok) {
      // Phone verified — continue to Google/Apple to finish creating the
      // account, then the profile steps.
      Navigator.pushReplacementNamed(
        context,
        Routes.socialAuth,
        arguments: const SocialAuthArgs(isSignIn: false),
      );
    } else {
      setState(() => _error = 'Incorrect code. Try 123456 in demo mode.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!_otpSent) {
      return OnboardingScaffold(
        step: 1,
        totalSteps: 5,
        title: "What's your number?",
        subtitle:
            "We'll text you a code to verify it's really you. Standard rates "
            'may apply.',
        continueEnabled: _phoneValid,
        busy: auth.busy,
        continueLabel: 'Send code',
        onContinue: _sendOtp,
        child: _PhoneField(
          controller: _phoneController,
          dialCode: _dialCode,
          onDialCodeChanged: (code) => setState(() => _dialCode = code),
          onChanged: () => setState(() {}),
        ),
      );
    }

    return OnboardingScaffold(
      step: 1,
      totalSteps: 5,
      title: 'Enter the code',
      subtitle: 'We sent a 6-digit code to $_fullNumber.',
      continueEnabled: _otpController.text.trim().length == 6,
      busy: auth.busy,
      continueLabel: 'Verify',
      onContinue: _verify,
      onBack: () => setState(() => _otpSent = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PinCodeTextField(
            appContext: context,
            length: 6,
            controller: _otpController,
            keyboardType: TextInputType.number,
            animationType: AnimationType.fade,
            enableActiveFill: true,
            onChanged: (_) => setState(() => _error = null),
            pinTheme: PinTheme(
              shape: PinCodeFieldShape.box,
              borderRadius: BorderRadius.circular(12),
              fieldHeight: 56,
              fieldWidth: 46,
              activeColor: AppColors.primary,
              selectedColor: AppColors.primary,
              inactiveColor: context.rovlo.textSecondary.withValues(alpha: 0.3),
              activeFillColor: context.rovlo.card,
              selectedFillColor: context.rovlo.card,
              inactiveFillColor: context.rovlo.card,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Didn\'t get it? ',
                  style: TextStyle(color: context.rovlo.textSecondary)),
              TextButton(
                onPressed: auth.busy ? null : _sendOtp,
                child: const Text('Resend'),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Demo mode: use code 123456',
                    style: TextStyle(
                        color: context.rovlo.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(),
        ],
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.dialCode,
    required this.onDialCodeChanged,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String dialCode;
  final ValueChanged<String> onDialCodeChanged;
  final VoidCallback onChanged;

  static const List<String> _dialCodes = [
    '+91', '+1', '+44', '+61', '+65', '+971', '+81', '+49', '+33', '+55',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          height: 58,
          decoration: BoxDecoration(
            color: context.rovlo.card,
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: dialCode,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              items: _dialCodes
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => v == null ? null : onDialCodeChanged(v),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            autofocus: true,
            onChanged: (_) => onChanged(),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ],
            decoration: const InputDecoration(hintText: 'Phone number'),
          ),
        ),
      ],
    );
  }
}
