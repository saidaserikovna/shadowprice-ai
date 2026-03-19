import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/brand_logo.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_finishBoot());
  }

  Future<void> _finishBoot() async {
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) {
      return;
    }
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _ready ? widget.child : const _SplashView(),
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D1118),
              ShadowTheme.background,
              Color(0xFF101624),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              BrandLogo(size: 96, showWordmark: true),
              SizedBox(height: 14),
              Text(
                'Real-time marketplace price intelligence',
                style: TextStyle(
                  color: ShadowTheme.textSecondary,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 28),
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: ShadowTheme.accentLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
