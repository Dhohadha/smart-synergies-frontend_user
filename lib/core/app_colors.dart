import 'package:flutter/material.dart';

class AppColors {
  // Production-level Status Colors
  static const Color cyan = Color(0xFF00B4D8);
  static const Color blue = Color(0xFF0077B6);
  static const Color teal = Color(0xFF48CAE4);
  static const Color green = Color(0xFF2DCE89);
  static const Color red = Color(0xFFF5365C);
  static const Color yellow = Color(0xFFFBBC05);
  static const Color orange = Color(0xFFFB6340);

  // Dark Mode Palette (Rich & Deep)
  static const Color background = Color(0xFF0B1426);
  static const Color surface = Color(0xFF162036);
  static const Color glassBg = Color(0x1A1E293B);
  static const Color glassBorder = Color(0x2600B4D8);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF475569);
  static const Color navBg = Color(0xFF0F172A);
  static const Color navBorder = Color(0x1A00B4D8);

  // Light Mode Palette (Clean & Airy)
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color glassBgLight = Color(0x0D0077B6);
  static const Color glassBorderLight = Color(0x1A00B4D8);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textMutedLight = Color(0xFF94A3B8);
  static const Color navBgLight = Color(0xFFFFFFFF);
  static const Color navBorderLight = Color(0x0D00B4D8);

  static Color getBackground(bool isDark) =>
      isDark ? background : backgroundLight;
  static Color getSurface(bool isDark) => isDark ? surface : surfaceLight;
  static Color getGlassBg(bool isDark) => isDark ? glassBg : glassBgLight;
  static Color getGlassBorder(bool isDark) =>
      isDark ? glassBorder : glassBorderLight;
  static Color getTextPrimary(bool isDark) =>
      isDark ? textPrimary : textPrimaryLight;
  static Color getTextSecondary(bool isDark) =>
      isDark ? textSecondary : textSecondaryLight;
  static Color getTextMuted(bool isDark) => isDark ? textMuted : textMutedLight;
  static Color getNavBg(bool isDark) => isDark ? navBg : navBgLight;
  static Color getNavBorder(bool isDark) => isDark ? navBorder : navBorderLight;
}
