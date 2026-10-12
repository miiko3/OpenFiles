import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tokens.dart';
abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light);
  static ThemeData dark() => _build(AppColors.dark);
  static ThemeData _build(AppColors c) {
    final scheme = ColorScheme(
      brightness: c.brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primarySoft,
      onPrimaryContainer: c.text,
      secondary: c.secondary,
      onSecondary: c.brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF1B2419),
      secondaryContainer: c.secondarySoft,
      onSecondaryContainer: c.text,
      tertiary: c.accent,
      onTertiary: c.brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF2A2014),
      tertiaryContainer: c.accentSoft,
      onTertiaryContainer: c.text,
      error: c.danger,
      onError: c.brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF34100C),
      errorContainer: c.danger.withValues(alpha: 0.16),
      onErrorContainer: c.text,
      surface: c.surface,
      onSurface: c.text,
      surfaceContainerLowest: c.bg,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surfaceAlt,
      surfaceContainerHigh: c.surfaceHigh,
      surfaceContainerHighest: c.surfaceHigh,
      onSurfaceVariant: c.textDim,
      outline: c.outline,
      outlineVariant: c.border,
      shadow: c.shadow,
      scrim: c.shadow,
      inverseSurface: c.text,
      onInverseSurface: c.bg,
      inversePrimary: c.secondary,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );
    final textTheme = _textTheme(c, base.textTheme);
    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lg,
          side: BorderSide(color: c.border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        systemOverlayStyle: c.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        dragHandleColor: c.outline,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lg,
          side: BorderSide(color: c.border),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.md,
          side: BorderSide(color: c.border),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: AppRadius.md,
              side: BorderSide(color: c.border),
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceAlt,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: c.textFaint),
        labelStyle: textTheme.bodyMedium?.copyWith(color: c.textDim),
        border: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: c.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: c.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: c.danger, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.surfaceAlt,
          foregroundColor: c.text,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          side: BorderSide(color: c.outline),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.sm),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.textDim,
          highlightColor: c.primary.withValues(alpha: 0.10),
          hoverColor: c.primary.withValues(alpha: 0.07),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceAlt,
        selectedColor: c.primarySoft,
        side: BorderSide(color: c.border),
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pill),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(BorderSide(color: c.border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.md),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.text,
          borderRadius: AppRadius.sm,
        ),
        textStyle: TextStyle(color: c.bg, fontSize: 12),
        waitDuration: const Duration(milliseconds: 500),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.text,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: c.bg),
        actionTextColor: c.primary,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        insetPadding: const EdgeInsets.all(12),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.primarySoft,
        elevation: 0,
        height: 66,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.primarySoft,
        selectedIconTheme: IconThemeData(color: c.primary),
        unselectedIconTheme: IconThemeData(color: c.textDim),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: c.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: c.textDim,
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        iconColor: c.textDim,
        textColor: c.text,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: c.textDim),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.primary,
        unselectedLabelColor: c.textDim,
        indicatorColor: c.primary,
        dividerColor: c.border,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: textTheme.labelLarge,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        inactiveTrackColor: c.border,
        thumbColor: c.primary,
        overlayColor: c.primary.withValues(alpha: 0.12),
        trackHeight: 5,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.border,
        ),
        trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(c.onPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: c.outline, width: 1.6),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surfaceAlt,
        circularTrackColor: c.surfaceAlt,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(c.outline),
        radius: const Radius.circular(3),
        thickness: WidgetStatePropertyAll(6),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        collapsedShape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        iconColor: c.textDim,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }
  static TextTheme _textTheme(AppColors c, TextTheme base) {
    TextStyle s(double size, FontWeight w, {double? h, double? ls, Color? col}) =>
        TextStyle(
          fontSize: size,
          fontWeight: w,
          height: h,
          letterSpacing: ls,
          color: col ?? c.text,
        );
    return base.copyWith(
      displayLarge: s(34, FontWeight.w700, h: 1.15, ls: -0.8),
      displayMedium: s(28, FontWeight.w700, h: 1.2, ls: -0.6),
      displaySmall: s(24, FontWeight.w700, h: 1.25, ls: -0.4),
      headlineLarge: s(22, FontWeight.w700, h: 1.3, ls: -0.3),
      headlineMedium: s(20, FontWeight.w700, h: 1.35, ls: -0.2),
      headlineSmall: s(18, FontWeight.w700, h: 1.4),
      titleLarge: s(17, FontWeight.w700, h: 1.35, ls: -0.1),
      titleMedium: s(15.5, FontWeight.w600, h: 1.35),
      titleSmall: s(14, FontWeight.w600, h: 1.4),
      bodyLarge: s(15, FontWeight.w400, h: 1.5),
      bodyMedium: s(13.5, FontWeight.w400, h: 1.5),
      bodySmall: s(12.5, FontWeight.w400, h: 1.45, col: c.textDim),
      labelLarge: s(13.5, FontWeight.w600, h: 1.2),
      labelMedium: s(12, FontWeight.w600, h: 1.2, col: c.textDim),
      labelSmall: s(11, FontWeight.w600, h: 1.2, col: c.textDim),
    );
  }
}
