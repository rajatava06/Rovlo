import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
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

            // Free
            _PlanCard(
              title: 'Free',
              subtitle: '🎁 Everything you need to start',
              price: '₹0',
              period: 'forever',
              features: const [
                'Basic profile',
                'See travelers on the map',
                'Chat with people who accept your request',
                'Standard map access',
              ],
              isCurrentPlan: currentTier == 'free',
              color: Colors.grey.shade600,
              onSelect: () {},
            ).animate(delay: 100.ms).fadeIn().slideX(begin: 0.1),
            const SizedBox(height: 16),

            // Plus (₹199)
            _PlanCard(
              title: 'Plus',
              price: '₹199',
              period: '/month',
              features: const [
                'Everything in Free',
                'Priority matching',
                'See who liked you',
                'Advanced filters',
              ],
              isCurrentPlan: currentTier == 'plus199',
              comingSoon: !AppConstants.paymentsEnabled && currentTier != 'plus199',
              color: primaryPeach,
              isPopular: true,
              onSelect: () => _openPaymentModal(context, provider, 'plus199', 'Plus', 199),
            ).animate(delay: 200.ms).fadeIn().slideX(begin: 0.1),
            const SizedBox(height: 16),

            // Advanced (₹499)
            _PlanCard(
              title: 'Advanced',
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
              comingSoon: !AppConstants.paymentsEnabled &&
                  currentTier != 'plus499' &&
                  currentTier != 'plus299',
              color: Colors.amber.shade700,
              onSelect: () => _openPaymentModal(context, provider, 'plus499', 'Advanced', 499),
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
    if (!AppConstants.paymentsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paid plans are coming soon. ⭐')),
      );
      return;
    }
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
  final bool comingSoon;
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
    this.comingSoon = false,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final card = Stack(
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

    if (!comingSoon) return card;

    // Paid plans that are not on sale yet: slightly blurred, not tappable.
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: 0.7,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 2.4, sigmaY: 2.4),
            child: IgnorePointer(child: card),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withValues(alpha: 0.72) : Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color, width: 1.6),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 14),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_clock, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                'COMING SOON',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
