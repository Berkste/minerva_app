import 'package:flutter/material.dart';

/// The Minerva palette.
///
/// The brand is built on three notes: a saturated purple for anything the user
/// must act on, a soft pink for accents, and generous white space in between.
class AppColors {
  const AppColors._();

  // --- Brand ---------------------------------------------------------------
  static const Color purple = Color(0xFF7B4DFF);
  static const Color pink = Color(0xFFFFB6C1);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightPurple = Color(0xFFF3E8FF);

  // --- Derived tints -------------------------------------------------------
  /// Lighter end of the primary gradient (buttons, logo, highlights).
  static const Color purpleLight = Color(0xFFA88BFF);

  /// Page background: barely-there lilac so white cards read as elevated.
  static const Color background = Color(0xFFFBF9FF);

  /// Hairlines and card borders.
  static const Color border = Color(0xFFEDE7F8);

  // --- Text ----------------------------------------------------------------
  static const Color textPrimary = Color(0xFF2E2A3B);
  static const Color textSecondary = Color(0xFF8B86A0);
  static const Color textTertiary = Color(0xFFB4AFC4);

  // --- Status --------------------------------------------------------------
  static const Color success = Color(0xFF7B4DFF);

  // --- Gradients -----------------------------------------------------------
  /// Primary call-to-action gradient, used on every filled button.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [purple, purpleLight],
  );

  /// Pink-to-purple wash used by the logo mark and hero banners.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [pink, purple],
  );

  /// Very soft background wash for the splash screen and hero cards.
  static const LinearGradient softGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF6EFFF), Color(0xFFFFF1F5)],
  );

  /// Soft shadow shared by every card in the app.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: purple.withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}
