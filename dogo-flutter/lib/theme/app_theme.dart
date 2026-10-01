import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Charte graphique officielle DoGo extraite de charte_graphique.png
class AppTheme {
  // --- PALETTE DE COULEURS ---
  static const Color primary = Color(0xFFAC7F5E);      // Marron Camel emblématique
  static const Color primaryDark = Color(0xFF8E6445);
  static const Color secondary = Color(0xFFE6A823);    // Jaune moutarde / Doré
  static const Color tertiary = Color(0xFFF5E8D3);     // Crème / Beige clair
  static const Color background = Color(0xFFFBF9F6);   // Fond clair chaleureux
  static const Color surface = Color(0xFFFFFFFF);      // Blanc pur carte
  static const Color success = Color(0xFF34C759);      // Vert succès / confirmation
  static const Color textDark = Color(0xFF1E1E1E);     // Texte principal
  static const Color textMuted = Color(0xFF757575);    // Texte secondaire / description

  // --- THÈME MATERIAL 3 ---
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: background,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textDark,
      ),
      textTheme: textTheme.copyWith(
        // Titre : 32px / 26px, typographie Inter
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: textDark,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: textDark,
          letterSpacing: -0.4,
        ),
        // Sous-titre : 13px, typographie Inter
        titleSmall: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textMuted,
        ),
        // Contenu / Body : 12px / 14px, typographie Inter
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textMuted,
          height: 1.5,
        ),
        // Montant : 24px, typographie Inter
        headlineSmall: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          // Bouton large : taille écriture 16px, border-radius 30px (selon charte)
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
