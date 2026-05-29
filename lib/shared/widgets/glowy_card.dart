import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Reusable glassmorphism card with optional inner glow
class GlowyCard extends StatelessWidget {
  final Widget child;
  final Color? glowColor;
  final double borderRadius;
  final double glowBlur;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const GlowyCard({
    super.key,
    required this.child,
    this.glowColor,
    this.borderRadius = 16.0,
    this.glowBlur = 18.0,
    this.padding,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = AppDecorations.glassCard(
      glowColor: glowColor ?? AppColors.violetGlow,
      borderRadius: borderRadius,
      glowBlur: glowBlur,
    );

    Widget card = Container(
      width: width,
      height: height,
      decoration: decoration,
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );

    if (onTap != null) {
      card = GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

/// Accent gradient card (violet → green gradient)
class AccentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const AccentCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      decoration: AppDecorations.accentCard(),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
    if (onTap != null) {
      card = GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}
