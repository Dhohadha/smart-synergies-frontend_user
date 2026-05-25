import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final double borderRadius;
  final List<BoxShadow>? extraShadows;
  final Color? bgColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderColor,
    this.borderRadius = 20,
    this.extraShadows,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor ?? (isDark ? AppColors.surface : Colors.white),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.surface, AppColors.surface.withValues(alpha: 0.8)]
              : [Colors.white, Colors.white.withValues(alpha: 0.95)],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
            color: borderColor ??
                AppColors.getGlassBorder(isDark)
                    .withValues(alpha: isDark ? 0.2 : 0.1),
            width: 1.2),
        boxShadow: extraShadows ??
            [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.4)
                    : Colors.blueGrey.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -2,
              )
            ],
      ),
      child: child,
    );
  }
}
