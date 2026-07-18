import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

/// Three-tier subscription plan screen.
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
        title: const Text('Rovlo Plus'),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                    'Get more out of Rovlo with premium features.',
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
              subtitle: '🎁 Limited Time Offer',
              price: '₹0',
              originalPrice: '₹199',
              period: 'limited offer',
              features: const [
                'Basic profile',
                'View nearby travelers',
                'Limited messages per day',
                'Standard map access',
              ],
              isCurrentPlan: currentTier == 'free',
              color: Colors.grey.shade600,
              onSelect: () => _selectPlan(context, provider, 'free'),
            ).animate(delay: 100.ms).fadeIn().slideX(begin: 0.1),
            const SizedBox(height: 16),

            // Plus Tier (Updated from 99 to 199)
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
              onSelect: () => _selectPlan(context, provider, 'plus199'),
            ).animate(delay: 200.ms).fadeIn().slideX(begin: 0.1),
            const SizedBox(height: 16),

            // Premium Tier
            _PlanCard(
              title: 'Premium',
              price: '₹299',
              period: '/month',
              features: const [
                'Everything in Plus',
                'Unlimited likes',
                'Profile boost (2x visibility)',
                'Travel companion matching',
                'Priority customer support',
                'Ad-free experience',
              ],
              isCurrentPlan: currentTier == 'plus299',
              color: Colors.amber.shade700,
              onSelect: () => _selectPlan(context, provider, 'plus299'),
            ).animate(delay: 300.ms).fadeIn().slideX(begin: 0.1),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _selectPlan(BuildContext context, AuthProvider provider, String tier) async {
    await provider.setSubscriptionTier(tier);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tier == 'free'
            ? 'Switched to Free plan.'
            : 'Subscribed to ${tier == 'plus199' ? 'Plus' : 'Premium'} plan! 🎉'),
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
