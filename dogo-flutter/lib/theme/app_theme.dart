import 'package:flutter/material.dart';

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
  static const Color textPrimary = textDark;           // Alias texte principal
  static const Color textMuted = Color(0xFF757575);    // Texte secondaire / description

  // --- TEINTES DÉRIVÉES (déjà présentes dans les écrans, centralisées ici) ---
  static const Color encre = Color(0xFF2C241E);        // Brun très foncé : titres, snackbars
  static const Color bordure = Color(0xFFEDE5DC);      // Contour des cartes et champs
  static const Color bordureForte = Color(0xFFE2D8CF); // Contour au survol / séparation marquée
  static const Color surfaceDouce = Color(0xFFF7F2EB); // Fond des pastilles et zones secondaires
  static const Color danger = Color(0xFFC0392B);       // Erreur / annulation
  static const Color avertissement = Color(0xFFD97706);

  /// Famille Inter embarquée (pubspec.yaml) : toutes les graisses 400 à 900.
  static const String police = 'Inter';

  // --- RAYONS ---
  static const double rayonS = 12;
  static const double rayonM = 16;
  static const double rayonL = 20;
  static const double rayonXL = 28;

  // --- OMBRES (chaudes, teintées de brun plutôt que noires) ---
  static const List<BoxShadow> ombreDouce = [
    BoxShadow(color: Color(0x0F46321E), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x0546321E), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> ombreFlottante = [
    BoxShadow(color: Color(0x1F46321E), blurRadius: 28, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x0A46321E), blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// Dégradé camel de la marque (boutons d'action forts, bandeaux).
  static const LinearGradient degradePrimaire = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB98A66), primaryDark],
  );

  // --- THÈME MATERIAL 3 ---
  static ThemeData get lightTheme {
    // Inter se lit mieux avec un interlettrage serré : les valeurs Material (0,25 à 0,5) l'aèrent trop.
    TextStyle inter(double taille, FontWeight graisse, Color couleur, {double espacement = 0, double? hauteur}) =>
        TextStyle(fontFamily: police, fontSize: taille, fontWeight: graisse, color: couleur, letterSpacing: espacement, height: hauteur);

    final textTheme = TextTheme(
      // Titre : 32px / 26px, typographie Inter
      displayLarge: inter(32, FontWeight.w800, textDark, espacement: -0.8, hauteur: 1.15),
      displayMedium: inter(28, FontWeight.w800, textDark, espacement: -0.6, hauteur: 1.15),
      displaySmall: inter(26, FontWeight.w700, textDark, espacement: -0.5, hauteur: 1.2),
      headlineLarge: inter(28, FontWeight.w700, textDark, espacement: -0.5, hauteur: 1.2),
      headlineMedium: inter(26, FontWeight.w700, textDark, espacement: -0.4, hauteur: 1.2),
      // Montant : 24px, typographie Inter
      headlineSmall: inter(24, FontWeight.w700, primary, espacement: -0.3),
      titleLarge: inter(20, FontWeight.w700, textDark, espacement: -0.3, hauteur: 1.25),
      titleMedium: inter(16, FontWeight.w600, textDark, espacement: -0.1, hauteur: 1.3),
      // Sous-titre : 13px, typographie Inter
      titleSmall: inter(13, FontWeight.w500, textMuted),
      bodyLarge: inter(15, FontWeight.w400, textDark, hauteur: 1.45),
      // Contenu / Body : 12px / 14px, typographie Inter
      bodyMedium: inter(13, FontWeight.w400, textMuted, hauteur: 1.5),
      bodySmall: inter(12, FontWeight.w400, textMuted, hauteur: 1.4),
      labelLarge: inter(14, FontWeight.w600, textDark),
      labelMedium: inter(12, FontWeight.w600, textDark),
      labelSmall: inter(11, FontWeight.w600, textMuted, espacement: 0.1),
    );

    final rond = RoundedRectangleBorder(borderRadius: BorderRadius.circular(rayonM));

    return ThemeData(
      useMaterial3: true,
      // Typographie globale Inter pour l'ensemble de l'application
      fontFamily: police,
      primaryTextTheme: ThemeData.light().primaryTextTheme.apply(fontFamily: police),
      scaffoldBackgroundColor: background,
      canvasColor: background,
      splashFactory: InkSparkle.splashFactory,
      highlightColor: primary.withValues(alpha: 0.06),
      // Les surfaces M3 sont toutes fixées : sans cela dialogues, menus et chips prennent une teinte lavande.
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: tertiary,
        onPrimaryContainer: primaryDark,
        secondary: secondary,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFFCEFD2),
        onSecondaryContainer: Color(0xFF7A5300),
        tertiary: primaryDark,
        tertiaryContainer: tertiary,
        error: danger,
        errorContainer: Color(0xFFFDECEA),
        surface: background,
        onSurface: textDark,
        onSurfaceVariant: textMuted,
        surfaceTint: Colors.transparent,
        surfaceContainerLowest: surface,
        surfaceContainerLow: Color(0xFFFDFBF8),
        surfaceContainer: surface,
        surfaceContainerHigh: surface,
        surfaceContainerHighest: surfaceDouce,
        outline: bordureForte,
        outlineVariant: bordure,
        shadow: Color(0xFF46321E),
        inverseSurface: encre,
        onInverseSurface: Colors.white,
        inversePrimary: Color(0xFFE9C9A8),
      ),
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: textDark, size: 24),
      dividerTheme: const DividerThemeData(color: bordure, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: const Color(0x3346321E),
        centerTitle: false,
        titleSpacing: 20,
        iconTheme: const IconThemeData(color: textDark, size: 24),
        titleTextStyle: inter(19, FontWeight.w700, textDark, espacement: -0.4),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rayonL),
          side: const BorderSide(color: bordure),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: rond,
        titleTextStyle: inter(15, FontWeight.w600, textDark, espacement: -0.1),
        subtitleTextStyle: inter(13, FontWeight.w400, textMuted, hauteur: 1.4),
      ),
      // Seule la forme est fixée : les couleurs d'état (repos, focus camel, erreur) viennent du colorScheme,
      // et les champs intégrés dans un conteneur sur mesure (border: InputBorder.none) restent sans contour.
      inputDecorationTheme: InputDecorationTheme(
        fillColor: surface,
        hintStyle: inter(14, FontWeight.w400, const Color(0xFFA09486)),
        labelStyle: inter(14, FontWeight.w500, textMuted),
        floatingLabelStyle: inter(14, FontWeight.w600, primary),
        prefixIconColor: primary,
        suffixIconColor: textMuted,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(rayonM)),
        errorStyle: inter(12, FontWeight.w500, danger),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE4D9CE),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 56),
          // Bouton large : taille écriture 16px, border-radius 30px (selon charte)
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: inter(16, FontWeight.w700, Colors.white, espacement: -0.1),
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          textStyle: inter(15, FontWeight.w700, Colors.white, espacement: -0.1),
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
          textStyle: inter(16, FontWeight.w600, primary, espacement: -0.1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rayonS)),
          textStyle: inter(14, FontWeight.w700, primary),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(highlightColor: primary.withValues(alpha: 0.08)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        highlightElevation: 8,
        extendedTextStyle: inter(15, FontWeight.w700, Colors.white, espacement: -0.1),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primary,
        secondarySelectedColor: primary,
        disabledColor: surfaceDouce,
        checkmarkColor: Colors.white,
        side: const BorderSide(color: bordureForte),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        labelStyle: inter(13, FontWeight.w600, textDark),
        secondaryLabelStyle: inter(13, FontWeight.w700, Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: const Color(0x3346321E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rayonXL)),
        titleTextStyle: inter(19, FontWeight.w800, textDark, espacement: -0.4, hauteur: 1.25),
        contentTextStyle: inter(14, FontWeight.w400, const Color(0xFF5A493B), hauteur: 1.5),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
        dragHandleColor: bordureForte,
        dragHandleSize: Size(44, 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(rayonXL)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: encre,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rayonM)),
        contentTextStyle: inter(14, FontWeight.w500, Colors.white, hauteur: 1.35),
        actionTextColor: secondary,
        closeIconColor: Colors.white70,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: const Color(0x3346321E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rayonM),
          side: const BorderSide(color: bordure),
        ),
        textStyle: inter(14, FontWeight.w500, textDark),
      ),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surface),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: encre, borderRadius: BorderRadius.circular(10)),
        textStyle: inter(12, FontWeight.w600, Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textMuted,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: bordure,
        labelStyle: inter(14, FontWeight.w700, primary),
        unselectedLabelStyle: inter(14, FontWeight.w500, textMuted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: tertiary,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => inter(11.5, s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              s.contains(WidgetState.selected) ? primary : textMuted),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? primary : textMuted),
        ),
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Color(0x3346321E),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: tertiary,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 6,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: bordureForte, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : bordureForte,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : const Color(0xFFDCD2C8),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: tertiary,
        thumbColor: primary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: 0.22),
        selectionHandleColor: primary,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: const Color(0xFFE53935),
        textStyle: inter(10, FontWeight.w700, Colors.white),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
