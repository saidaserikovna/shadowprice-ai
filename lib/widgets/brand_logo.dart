import 'package:flutter/material.dart';

import '../core/theme.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 84,
    this.showWordmark = false,
    this.centered = true,
  });

  final double size;
  final bool showWordmark;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ShadowTheme.accentLight,
            ShadowTheme.accent,
            Color(0xFF06B6D4),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: ShadowTheme.accent.withValues(alpha: 0.22),
            blurRadius: size * 0.28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: size * 0.16,
            right: size * 0.14,
            child: Container(
              width: size * 0.2,
              height: size * 0.2,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Text(
              'S',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.52,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
              ),
            ),
          ),
        ],
      ),
    );

    if (!showWordmark) {
      return logo;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        logo,
        SizedBox(height: size * 0.22),
        const Text(
          'ShadowPrice AI',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ShadowTheme.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
      ],
    );
  }
}
