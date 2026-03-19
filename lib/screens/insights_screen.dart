import 'package:flutter/material.dart';

import '../core/theme.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final insights = [
      _Insight(
        Icons.verified_outlined,
        ShadowTheme.success,
        'Verified analysis only',
        'The app now uses values fetched from the live product page. If a price or title cannot be verified, it should say so instead of inventing one.',
      ),
      _Insight(
        Icons.link_outlined,
        ShadowTheme.accent,
        'Use direct product pages',
        'Paste a full product URL from the store. Search result pages and short links are much less reliable for accurate extraction.',
      ),
      _Insight(
        Icons.timeline_outlined,
        ShadowTheme.warning,
        'Timing needs history',
        'Buy-now and wait recommendations are strongest after the app has saved several checks for the same exact URL.',
      ),
      _Insight(
        Icons.notifications_active_outlined,
        ShadowTheme.accentLight,
        'Track important products',
        'Save products you care about so the app can build a verified price history and alert you when the price improves.',
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Insights',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: ShadowTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'How to get more reliable product analysis',
              style: TextStyle(color: ShadowTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ...insights.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ShadowTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ShadowTheme.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, size: 20, color: item.color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: ShadowTheme.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.text,
                            style: const TextStyle(
                              color: ShadowTheme.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Insight {
  const _Insight(this.icon, this.color, this.title, this.text);

  final IconData icon;
  final Color color;
  final String title;
  final String text;
}
