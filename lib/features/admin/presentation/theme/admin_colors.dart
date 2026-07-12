import 'package:flutter/material.dart';

/// Admin visual identity — deliberately distinct from the customer app.
/// Dark navy/charcoal with a COOL BLUE accent (no orange, no food imagery).
abstract final class AdminColors {
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF141B2D); // cards
  static const Color inputFill = Color(0xFF0E1524);
  static const Color border = Color(0xFF232B3D);

  static const Color accent = Color(0xFF5B8DEF); // blue — buttons/links
  static const Color accentBright = Color(0xFF6EA8FF);
  static const Color logoTeal = Color(0xFF4FD1C5); // logo mark

  static const Color textPrimary = Color(0xFFE8EDF5);
  static const Color textSecondary = Color(0xFF8A94A6);
  static const Color textHint = Color(0xFF5A6478);

  static const Color danger = Color(0xFFF87171);
  static const Color success = Color(0xFF34D399);
}
