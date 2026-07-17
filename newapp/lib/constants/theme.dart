/// BioPod - shared UI palette and theme.
///
/// This is the single source of truth for the app's colours. The palette
/// originated on the Health Score Calculator screen (a calm, clinical
/// "checkup" look) and is reused everywhere so every screen reads as one app.
///
/// Prefer these named colours over hardcoded `Color(0x...)` / `Colors.*`
/// literals in screens, and prefer `Theme.of(context).colorScheme.*` for
/// widget defaults that [buildAppTheme] already wires up (AppBar, buttons,
/// inputs, etc.).

library;

import 'package:flutter/material.dart';

/// The clinical accent palette, plus the status colours used for health
/// score / risk grading. Kept as plain `static const` so it can be used in
/// `const` widget constructors.
class AppColors {
  const AppColors._();

  // ── Core clinical palette ──────────────────────────────────────────────

  /// Page background — a very light blue-white.
  static const Color background = Color(0xFFF4F9FB);

  /// Card / surface background.
  static const Color card = Colors.white;

  /// Primary accent — teal. Buttons, active borders, key icons.
  static const Color primary = Color(0xFF0091A6);

  /// Strong heading text — dark navy-teal.
  static const Color heading = Color(0xFF0F3B4C);

  /// Secondary / helper text — muted grey-teal.
  static const Color subtle = Color(0xFF5B7784);

  /// Hairline borders and inactive track fills.
  static const Color border = Color(0xFFE2ECF0);

  // ── Status / grading colours ───────────────────────────────────────────
  // Shared red → yellow → green scale for scores, risk levels and trends.

  /// Good / low-risk / on-track.
  static const Color good = Color(0xFF43A047);

  /// Caution / medium-risk.
  static const Color warn = Color(0xFFFDD835);

  /// Alert / high-risk.
  static const Color bad = Color(0xFFE53935);

  /// Ordered palette for multi-series charts (e.g. systolic vs diastolic on
  /// one axis). Every entry is drawn from the clinical colours above so charts
  /// read as part of the same system. Index into it by series number; a
  /// single-series chart should just use [primary].
  static const List<Color> series = [primary, heading, good, bad, subtle];

  /// Maps a normalised value `t` (0..1) onto the red → yellow → green scale.
  /// Used by the score gauge and anywhere a continuous grade is shown.
  static Color grade(double t) {
    if (t <= 0.5) {
      return Color.lerp(bad, warn, (t / 0.5).clamp(0.0, 1.0))!;
    }
    return Color.lerp(warn, good, ((t - 0.5) / 0.5).clamp(0.0, 1.0))!;
  }
}

/// The application-wide [ThemeData]. Seeds Material 3 from [AppColors.primary]
/// so stock widgets (AppBar, FilledButton, inputs, etc.) inherit the clinical
/// look, then pins the surfaces and text roles to the exact palette values.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: AppColors.card,
    error: AppColors.bad,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    cardColor: AppColors.card,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      labelStyle: TextStyle(color: AppColors.subtle),
      helperStyle: TextStyle(color: AppColors.subtle),
    ),
  );
}
