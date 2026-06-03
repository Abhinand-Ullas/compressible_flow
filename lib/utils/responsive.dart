import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  Responsive  — screen-size utility
//  Reference width: 390 px (iPhone 14 logical pixels)
//  Scale is clamped to a max of 1.5× so desktop never
//  becomes excessively large.
// ─────────────────────────────────────────────
class Responsive {
  // ── Screen dimensions ────────────────────────────────────────────────────
  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  // ── Breakpoints ──────────────────────────────────────────────────────────
  /// Mobile: width < 600
  static bool isMobile(BuildContext context) => screenWidth(context) < 600;

  /// Tablet: 600 ≤ width < 1300
  static bool isTablet(BuildContext context) {
    final w = screenWidth(context);
    return w >= 600 && w < 1300;
  }

  /// Desktop / laptop: width ≥ 1300
  static bool isDesktop(BuildContext context) => screenWidth(context) >= 1300;

  // ── Scale factor ─────────────────────────────────────────────────────────
  /// Returns a scale factor relative to the 390 px reference width,
  /// clamped between 0.85 and 1.5 so values never shrink too much on
  /// very small screens or grow excessively on large ones.
  static double _scale(BuildContext context) =>
      (screenWidth(context) / 390.0).clamp(0.85, 1.5);

  // ── Scale helpers ────────────────────────────────────────────────────────
  /// Scale a font size.
  static double sp(BuildContext context, double base) =>
      base * _scale(context);

  /// Scale a height-based measurement (SizedBox height, container height …).
  static double hp(BuildContext context, double base) =>
      base * _scale(context);

  /// Scale a width-based measurement (SizedBox width, container width …).
  static double wp(BuildContext context, double base) =>
      base * _scale(context);

  /// Scale a padding / spacing value.
  static double pad(BuildContext context, double base) =>
      base * _scale(context);
}
