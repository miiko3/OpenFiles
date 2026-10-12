import 'package:flutter/material.dart';
@immutable
class AppColors {
  const AppColors({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceHigh,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.secondary,
    required this.secondarySoft,
    required this.accent,
    required this.accentSoft,
    required this.info,
    required this.success,
    required this.warning,
    required this.danger,
    required this.text,
    required this.textDim,
    required this.textFaint,
    required this.border,
    required this.outline,
    required this.shadow,
    required this.canvas,
  });
  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceHigh;
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color secondary;
  final Color secondarySoft;
  final Color accent;
  final Color accentSoft;
  final Color info;
  final Color success;
  final Color warning;
  final Color danger;
  final Color text;
  final Color textDim;
  final Color textFaint;
  final Color border;
  final Color outline;
  final Color shadow;
  final Color canvas;
  static const light = AppColors(
    brightness: Brightness.light,
    bg: Color(0xFFFAF5EF),
    surface: Color(0xFFFFFDFA),
    surfaceAlt: Color(0xFFF2E9DE),
    surfaceHigh: Color(0xFFFBF3EA),
    primary: Color(0xFFC08163),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFF0DCCE),
    secondary: Color(0xFF7F9079),
    secondarySoft: Color(0xFFDDE4D8),
    accent: Color(0xFFB08D57),
    accentSoft: Color(0xFFEFE2C9),
    info: Color(0xFF6E8CA0),
    success: Color(0xFF7A9A6E),
    warning: Color(0xFFC99A4E),
    danger: Color(0xFFB5645A),
    text: Color(0xFF3B332C),
    textDim: Color(0xFF8C8075),
    textFaint: Color(0xFFB3A697),
    border: Color(0xFFE6DACB),
    outline: Color(0xFFD6C7B4),
    shadow: Color(0x1A6B584A),
    canvas: Color(0xFFF6EFE6),
  );
  static const dark = AppColors(
    brightness: Brightness.dark,
    bg: Color(0xFF171412),
    surface: Color(0xFF211D1A),
    surfaceAlt: Color(0xFF2B2521),
    surfaceHigh: Color(0xFF342D27),
    primary: Color(0xFFDDA183),
    onPrimary: Color(0xFF3A2318),
    primarySoft: Color(0xFF4A3327),
    secondary: Color(0xFFA2B29B),
    secondarySoft: Color(0xFF333C30),
    accent: Color(0xFFD6B98A),
    accentSoft: Color(0xFF453822),
    info: Color(0xFF9BB3C4),
    success: Color(0xFFA3BE93),
    warning: Color(0xFFE0B978),
    danger: Color(0xFFDE8B80),
    text: Color(0xFFEFE7DD),
    textDim: Color(0xFFA3988C),
    textFaint: Color(0xFF7C7268),
    border: Color(0xFF3A322C),
    outline: Color(0xFF4A4038),
    shadow: Color(0x66000000),
    canvas: Color(0xFF1B1715),
  );
  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
abstract final class AppRadius {
  static const xs = BorderRadius.all(Radius.circular(6));
  static const sm = BorderRadius.all(Radius.circular(10));
  static const md = BorderRadius.all(Radius.circular(14));
  static const lg = BorderRadius.all(Radius.circular(20));
  static const xl = BorderRadius.all(Radius.circular(28));
  static const pill = BorderRadius.all(Radius.circular(999));
}
abstract final class AppSpace {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}
abstract final class AppDuration {
  static const fast = Duration(milliseconds: 140);
  static const normal = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 420);
  static const curve = Curves.easeOutCubic;
}
extension AppThemeX on BuildContext {
  AppColors get c => AppColors.of(this);
  TextTheme get t => Theme.of(this).textTheme;
  ColorScheme get scheme => Theme.of(this).colorScheme;
}
