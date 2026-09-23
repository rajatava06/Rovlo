import 'package:flutter/material.dart';
import '../../core/widgets/keyboard_inset.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

/// Full-Page Payment & Checkout Screen with Razorpay / Stripe integration readiness.
class CheckoutScreen extends StatefulWidget {
  final String tier;
  final String planName;
  final int amount;

  const CheckoutScreen({
    super.key,
    required this.tier,
    required this.planName,
    required this.amount,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _selectedMethod = 'razorpay';
  bool _isProcessing = false;

  final TextEditingController _merchantAccountController =
      TextEditingController(text: 'rzp_live_rovlo_merchant_884');
  final TextEditingController _upiController =
      TextEditingController(text: 'traveler@upi');
  final TextEditingController _cardNumberController =
      TextEditingController(text: '4532 8921 0042 8892');
  final TextEditingController _cardHolderController =
      TextEditingController(text: 'RAJVATAVA DAS');
  final TextEditingController _expiryController =
      TextEditingController(text: '08/29');
  final TextEditingController _cvvController =
      TextEditingController(text: '884');

  @override
  void dispose() {
    _merchantAccountController.dispose();
    _upiController.dispose();
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);

    // Simulate real gateway handshake (Razorpay / Stripe / UPI)
    await Future.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;

    final provider = context.read<AuthProvider>();
    await provider.setSubscriptionTier(widget.tier);

    if (!mounted) return;
    setState(() => _isProcessing = false);

    Navigator.pop(context); // Return from checkout
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green.shade700,
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '🎉 Payment Verified via ${_selectedMethod.toUpperCase()}! Subscribed to ${widget.planName} (₹${widget.amount}/mo).',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryPeach = isDark ? AppColors.primaryVibrantDark : AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock, size: 14, color: Colors.green),
                SizedBox(width: 4),
                Text(
                  '256-bit SSL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: KeyboardAvoiding(
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Summary Hero Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark ? AppColors.sunsetGradient : AppColors.brandGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: primaryPeach.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            widget.planName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Monthly Plan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹${widget.amount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '/ month (incl. GST)',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Merchant Account Setup Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.rovlo.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryPeach.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_outlined, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Razorpay / Stripe Merchant Account',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Direct payments will be deposited into your specified account key:',
                      style: TextStyle(fontSize: 12, color: context.rovlo.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _merchantAccountController,
                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        hintText: 'Enter Razorpay Key ID (rzp_live_...) or Stripe Key',
                        prefixIcon: const Icon(Icons.key, size: 16),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Select Payment Gateway',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              // 1. Razorpay Gateway Option
              _PaymentOptionTile(
                value: 'razorpay',
                groupValue: _selectedMethod,
                onChanged: (v) => setState(() => _selectedMethod = v!),
                icon: Icons.flash_on,
                iconColor: Colors.blue.shade700,
                title: 'Razorpay Gateway',
                subtitle: 'UPI, Credit/Debit, Netbanking, Wallets',
                badgeText: 'RECOMMENDED',
              ),

              // 2. Stripe Gateway Option
              _PaymentOptionTile(
                value: 'stripe',
                groupValue: _selectedMethod,
                onChanged: (v) => setState(() => _selectedMethod = v!),
                icon: Icons.credit_card,
                iconColor: Colors.indigo,
                title: 'Stripe Global Checkout',
                subtitle: 'International Cards & Apple Pay / Google Pay',
              ),

              // 3. Direct UPI Option
              _PaymentOptionTile(
                value: 'upi',
                groupValue: _selectedMethod,
                onChanged: (v) => setState(() => _selectedMethod = v!),
                icon: Icons.qr_code_2,
                iconColor: Colors.purple,
                title: 'Direct UPI (GPay / PhonePe / Paytm)',
                subtitle: 'Instant payment via any UPI app',
              ),
              if (_selectedMethod == 'upi')
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 4),
                  child: Column(
                    children: [
                      TextField(
                        controller: _upiController,
                        decoration: const InputDecoration(
                          labelText: 'Your Virtual Payment Address (VPA)',
                          hintText: 'username@upi',
                          prefixIcon: Icon(Icons.alternate_email, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

              // 4. Credit / Debit Card Option
              _PaymentOptionTile(
                value: 'card',
                groupValue: _selectedMethod,
                onChanged: (v) => setState(() => _selectedMethod = v!),
                icon: Icons.payment,
                iconColor: Colors.teal,
                title: 'Credit / Debit Card',
                subtitle: 'Visa, MasterCard, RuPay, Amex',
              ),
              if (_selectedMethod == 'card')
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 4),
                  child: Column(
                    children: [
                      TextField(
                        controller: _cardNumberController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Card Number',
                          prefixIcon: Icon(Icons.credit_card, size: 18),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _expiryController,
                              decoration: const InputDecoration(
                                labelText: 'Expiry (MM/YY)',
                                prefixIcon: Icon(Icons.date_range, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _cvvController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'CVV',
                                prefixIcon: Icon(Icons.lock_outline, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 28),

              // Pay Now CTA Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: _isProcessing
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Processing Gateway Order...',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        )
                      : Text(
                          'Pay ₹${widget.amount} & Activate Now',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: context.rovlo.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Encrypted checkout. Cancel anytime from settings.',
                      style: TextStyle(fontSize: 12, color: context.rovlo.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _PaymentOptionTile extends StatelessWidget {
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badgeText;

  const _PaymentOptionTile({
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.08)
            : context.rovlo.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : (isDark ? Colors.white10 : Colors.black12),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badgeText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.rovlo.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
