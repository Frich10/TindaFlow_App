import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kBlue = Color(0xFF0B6EFD);
const kBlueDark = Color(0xFF0A4FA8);
const kText = Color(0xFF0B3C85);
const kMuted = Color(0xFF8A9BB5);
const kBg = Color(0xFFF4F9FD);
const kGreen = Color(0xFF1FA84C);
const kRed = Color(0xFFEF4444);
const kOrange = Color(0xFFFF8A1F);
const kPurple = Color(0xFF8B5CF6);
const kFieldBorder = Color(0xFF4C9AFF);

const kBlueTint = Color(0xFFE6F0FF);
const kGreenTint = Color(0xFFDFF5E8);
const kRedTint = Color(0xFFFDE3E3);
const kOrangeTint = Color(0xFFFFEBD6);
const kPurpleTint = Color(0xFFEDE5FF);

/// Compact text style helper (font family comes from the theme -> Poppins).
TextStyle ts(double size, {FontWeight w = FontWeight.w500, Color c = kText, double? h}) =>
    TextStyle(fontSize: size, fontWeight: w, color: c, height: h);

BoxDecoration cardDeco({Color color = Colors.white, Color? border, double r = 10, bool shadow = false}) =>
    BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(r),
      border: border == null ? null : Border.all(color: border),
      boxShadow: shadow
          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))]
          : null,
    );

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: kBlue, primary: kBlue, surface: Colors.white),
    scaffoldBackgroundColor: kBg,
  );
  return base.copyWith(
    textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(bodyColor: kText, displayColor: kText),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
