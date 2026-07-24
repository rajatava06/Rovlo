import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'checkout_screen.dart';

/// Three-tier subscription plan screen with Payment checkout integration.
class RovloPlusScreen extends StatelessWidget {
  const RovloPlusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryPeach = isDark ? AppColors.primaryVibrantDark : AppColors.primary;
    final provider = context.watch<AuthProvider>();
    final currentTier = provider.currentUser?.subscriptionTier ?? 'free';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rovlo Plus', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark ? AppColors.sunsetGradient : AppColors.brandGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.white, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Upgrade Your Experience',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unlock unlimited traveler matches & VIP perks.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.1),
            const SizedBox(height: 28),

            // Free Tier
            _PlanCard(
              title: 'Free',
              subtitle: '🎁 Basic Traveler Access',
              price: '₹0',
              period: 'forever',
              features: const [
                'Basic profile',
                'View nearby travelers',
                'Limited messages per day',
                'Standard map access',
              ],
              isCurrentPlan: currentTier == 'free',
              color: Colors.grey.shade600,
              onSelect: () => _openPaymentModal(context, provider, 'free', 'Free Plan', 0),
            ).animate(delay: 100.ms).fadeIn().slideX(begin: 0.1),
            const SizedBox(height: 16),

            // Plus Tier (₹199)
            _PlanCard(
              title: 'Plus',
              price: '₹199',
              period: '/month',
              features: const [
                'Everything in Free',
                'Priority matching',
                'Read receipts in chats',
                'See who liked you',
                'Advanced filters',
              ],
              isCurrentPlan: currentTier == 'plus199',
              color: primaryPeach,
              isPopular: true,
              onSelect: () => _openPaymentModal(context, provider, 'plus199', 'Plus Tier', 199),
            ).animate(delay: 200.ms).fadeIn().slideX(begin: 0.1),
            const SizedBox(height: 16),

            // Premium Tier (₹499 / mo)
            _PlanCard(
              title: 'Premium VIP',
              price: '₹499',
              period: '/month',
              features: const [
                'Everything in Plus',
                'Unlimited likes & instant match',
                'Profile boost (5x visibility)',
                'Travel companion matching',
                'Priority 24/7 customer support',
                'Ad-free experience',
              ],
              isCurrentPlan: currentTier == 'plus499' || currentTier == 'plus299',
              color: Colors.amber.shade700,
              onSelect: () => _openPaymentModal(context, provider, 'plus499', 'Premium VIP Tier', 499),
            ).animate(delay: 300.ms).fadeIn().slideX(begin: 0.1),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _openPaymentModal(
    BuildContext context,
    AuthProvider provider,
    String tier,
    String planName,
    int amount,
  ) {
    if (amount == 0) {
      provider.setSubscriptionTier('free');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Switched to Free plan.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          tier: tier,
          planName: planName,
          amount: amount,
        ),
      ),
    );
  }
}

class _PaymentModal extends StatefulWidget {
  final String planName;
  final int amount;
  final VoidCallback onPaymentSuccess;

  const _PaymentModal({
    required this.planName,
    required this.amount,
    required this.onPaymentSuccess,
  });

  @override
  State<_PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<_PaymentModal> {
  String _selectedMethod = 'upi';
  final _upiController = TextEditingController(text: 'traveler@upi');
  final _cardNumberController = TextEditingController(text: '4532 •••• •••• 8892');
  bool _processing = false;

  @override
  void dispose() {
    _upiController.dispose();
    _cardNumberController.dispose();
    super.dispose();
  }

  Future<void> _payNow() async {
    setState(() => _processing = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    widget.onPaymentSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Complete Payment',
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.planName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '₹${widget.amount} / month',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Select Payment Method',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 12),

          // Payment Options
          RadioListTile<String>(
            value: 'upi',
            groupValue: _selectedMethod,
            onChanged: (val) => setState(() => _selectedMethod = val!),
            title: const Row(
              children: [
                Icon(Icons.qr_code_2, color: Colors.purple),
                SizedBox(width: 10),
                Text('UPI (GPay / PhonePe / Paytm)', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (_selectedMethod == 'upi')
            Padding(
              padding: const EdgeInsets.only(left: 48, right: 16, bottom: 12),
              child: TextField(
                controller: _upiController,
                decoration: const InputDecoration(
                  labelText: 'UPI ID',
                  hintText: 'username@upi',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
              ),
            ),

          RadioListTile<String>(
            value: 'card',
            groupValue: _selectedMethod,
            onChanged: (val) => setState(() => _selectedMethod = val!),
            title: const Row(
              children: [
                Icon(Icons.credit_card, color: Colors.blue),
                SizedBox(width: 10),
                Text('Credit / Debit Card', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (_selectedMethod == 'card')
            Padding(
              padding: const EdgeInsets.only(left: 48, right: 16, bottom: 12),
              child: TextField(
                controller: _cardNumberController,
                decoration: const InputDecoration(
                  labelText: 'Card Number',
                  prefixIcon: Icon(Icons.payment),
                ),
              ),
            ),

          RadioListTile<String>(
            value: 'netbanking',
            groupValue: _selectedMethod,
            onChanged: (val) => setState(() => _selectedMethod = val!),
            title: const Row(
              children: [
                Icon(Icons.account_balance, color: Colors.green),
                SizedBox(width: 10),
                Text('Net Banking', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _processing ? null : _payNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _processing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      'Pay ₹${widget.amount} & Activate',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String price;
  final String? originalPrice;
  final String period;
  final List<String> features;
  final bool isCurrentPlan;
  final Color color;
  final bool isPopular;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.title,
    this.subtitle,
    required this.price,
    this.originalPrice,
    required this.period,
    required this.features,
    required this.isCurrentPlan,
    required this.color,
    this.isPopular = false,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCurrentPlan ? color : (isDark ? Colors.white12 : Colors.black12),
              width: isCurrentPlan ? 2.5 : 1,
            ),
            boxShadow: isCurrentPlan
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  RichText(
                    text: TextSpan(
                      children: [
                        if (originalPrice != null)
                          TextSpan(
                            text: '$originalPrice ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                              color: isDark ? Colors.white38 : Colors.black38,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        TextSpan(
                          text: price,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        TextSpan(
                          text: ' $period',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.rovlo.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: color, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            f,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: isCurrentPlan ? null : onSelect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCurrentPlan ? Colors.grey : color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isCurrentPlan ? 'Current Plan' : 'Select Plan',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isPopular)
          Positioned(
            top: -2,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'POPULAR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
