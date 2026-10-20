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

  // --- PALETTE MODE SOMBRE (Harmonisée avec l'univers Camel de DoGo) ---
  static const Color darkBackground = Color(0xFF141210);      // Fond anthracite très chaud
  static const Color darkSurface = Color(0xFF201B17);         // Surface cartes / dialogue
  static const Color darkSurfaceDouce = Color(0xFF2B2520);    // Fond doux pastilles / sélecteurs
  static const Color darkBordure = Color(0xFF382F28);         // Bordure subtile sombre
  static const Color darkBordureForte = Color(0xFF4C4037);    // Bordure marquée sombre
  static const Color darkTextPrimary = Color(0xFFF7F2ED);     // Texte principal blanc cassé
  static const Color darkTextMuted = Color(0xFFAAA095);       // Texte secondaire chaud
  static const Color darkPrimary = Color(0xFFC5956E);         // Camel relevé pour contraste sombre
  static const Color darkPrimaryDark = Color(0xFFAD7F5C);

  // --- HELPERS CONTEXTUELS DYNAMIQUES SELON LE THÈME ---
  static bool estSombre(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color couleurFond(BuildContext context) =>
      estSombre(context) ? darkBackground : background;

  static Color couleurSurface(BuildContext context) =>
      estSombre(context) ? darkSurface : surface;

  static Color couleurCarte(BuildContext context) =>
      estSombre(context) ? darkSurface : Colors.white;

  static Color couleurSurfaceDouce(BuildContext context) =>
      estSombre(context) ? darkSurfaceDouce : surfaceDouce;

  static Color couleurBordure(BuildContext context) =>
      estSombre(context) ? darkBordure : bordure;

  static Color couleurBordureForte(BuildContext context) =>
      estSombre(context) ? darkBordureForte : bordureForte;

  /// Couleur principale du texte (titres, libellés forts, valeurs clés)
  static Color couleurTexte(BuildContext context) =>
      estSombre(context) ? darkTextPrimary : textDark;

  /// Brun encre en clair, blanc cassé en sombre
  static Color couleurEncre(BuildContext context) =>
      estSombre(context) ? darkTextPrimary : encre;

  /// Couleur secondaire du texte (descriptions, sous-titres, dates)
  static Color couleurTexteAttenue(BuildContext context) =>
      estSombre(context) ? darkTextMuted : textMuted;

  /// Accent camel pour textes et icônes
  static Color couleurAccent(BuildContext context) =>
      estSombre(context) ? darkPrimary : const Color(0xFF9E6738);

  // --- TYPOGRAPHIE ADAPTATIVE (Design System Inter officiel DoGo) ---
  static TextStyle styleTitreGrand(BuildContext context, {FontWeight graisse = FontWeight.w800, Color? couleur}) =>
      TextStyle(
        fontFamily: police,
        fontSize: 20,
        fontWeight: graisse,
        color: couleur ?? couleurTexte(context),
        letterSpacing: -0.3,
        height: 1.25,
      );

  static TextStyle styleTitreMoyen(BuildContext context, {FontWeight graisse = FontWeight.w700, Color? couleur}) =>
      TextStyle(
        fontFamily: police,
        fontSize: 16,
        fontWeight: graisse,
        color: couleur ?? couleurTexte(context),
        letterSpacing: -0.2,
      );

  static TextStyle styleTitrePetit(BuildContext context, {FontWeight graisse = FontWeight.w700, Color? couleur}) =>
      TextStyle(
        fontFamily: police,
        fontSize: 14,
        fontWeight: graisse,
        color: couleur ?? couleurTexte(context),
      );

  static TextStyle styleCorps(BuildContext context, {FontWeight graisse = FontWeight.w400, Color? couleur, double taille = 13}) =>
      TextStyle(
        fontFamily: police,
        fontSize: taille,
        fontWeight: graisse,
        color: couleur ?? couleurTexte(context),
        height: 1.45,
      );

  static TextStyle styleCorpsAttenue(BuildContext context, {FontWeight graisse = FontWeight.w400, Color? couleur, double taille = 12}) =>
      TextStyle(
        fontFamily: police,
        fontSize: taille,
        fontWeight: graisse,
        color: couleur ?? couleurTexteAttenue(context),
        height: 1.4,
      );

  static TextStyle styleEtiquette(BuildContext context, {FontWeight graisse = FontWeight.w600, Color? couleur, double taille = 11.5}) =>
      TextStyle(
        fontFamily: police,
        fontSize: taille,
        fontWeight: graisse,
        color: couleur ?? couleurTexte(context),
      );

  static TextStyle stylePrix(BuildContext context, {double taille = 14, FontWeight graisse = FontWeight.w800, Color? couleur}) =>
      TextStyle(
        fontFamily: police,
        fontSize: taille,
        fontWeight: graisse,
        color: couleur ?? (estSombre(context) ? darkPrimary : primary),
        letterSpacing: -0.2,
      );

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
      // Contenu / Body : 13px, typographie Inter
      bodyMedium: inter(13, FontWeight.w400, textDark, hauteur: 1.5),
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

  // --- THÈME MATERIAL 3 SOMBRE ---
  static ThemeData get darkTheme {
    TextStyle inter(double taille, FontWeight graisse, Color couleur, {double espacement = 0, double? hauteur}) =>
        TextStyle(fontFamily: police, fontSize: taille, fontWeight: graisse, color: couleur, letterSpacing: espacement, height: hauteur);

    final textTheme = TextTheme(
      displayLarge: inter(32, FontWeight.w800, darkTextPrimary, espacement: -0.8, hauteur: 1.15),
      displayMedium: inter(28, FontWeight.w800, darkTextPrimary, espacement: -0.6, hauteur: 1.15),
      displaySmall: inter(26, FontWeight.w700, darkTextPrimary, espacement: -0.5, hauteur: 1.2),
      headlineLarge: inter(28, FontWeight.w700, darkTextPrimary, espacement: -0.5, hauteur: 1.2),
      headlineMedium: inter(26, FontWeight.w700, darkTextPrimary, espacement: -0.4, hauteur: 1.2),
      headlineSmall: inter(24, FontWeight.w700, darkPrimary, espacement: -0.3),
      titleLarge: inter(20, FontWeight.w700, darkTextPrimary, espacement: -0.3, hauteur: 1.25),
      titleMedium: inter(16, FontWeight.w600, darkTextPrimary, espacement: -0.1, hauteur: 1.3),
      titleSmall: inter(13, FontWeight.w500, darkTextMuted),
      bodyLarge: inter(15, FontWeight.w400, darkTextPrimary, hauteur: 1.45),
      bodyMedium: inter(13, FontWeight.w400, darkTextPrimary, hauteur: 1.5),
      bodySmall: inter(12, FontWeight.w400, darkTextMuted, hauteur: 1.4),
      labelLarge: inter(14, FontWeight.w600, darkTextPrimary),
      labelMedium: inter(12, FontWeight.w600, darkTextPrimary),
      labelSmall: inter(11, FontWeight.w600, darkTextMuted, espacement: 0.1),
    );

    final rond = RoundedRectangleBorder(borderRadius: BorderRadius.circular(rayonM));

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: police,
      primaryTextTheme: ThemeData.dark().primaryTextTheme.apply(fontFamily: police),
      scaffoldBackgroundColor: darkBackground,
      canvasColor: darkBackground,
      cardColor: darkSurface,
      splashFactory: InkSparkle.splashFactory,
      highlightColor: darkPrimary.withValues(alpha: 0.12),
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF38291E),
        onPrimaryContainer: Color(0xFFF3DEC8),
        secondary: secondary,
        onSecondary: Color(0xFF261900),
        secondaryContainer: Color(0xFF4A3600),
        onSecondaryContainer: Color(0xFFFFE082),
        tertiary: darkPrimaryDark,
        tertiaryContainer: Color(0xFF33251B),
        error: Color(0xFFEF5350),
        errorContainer: Color(0xFF4E1616),
        surface: darkSurface,
        onSurface: darkTextPrimary,
        onSurfaceVariant: darkTextMuted,
        surfaceTint: Colors.transparent,
        surfaceContainerLowest: Color(0xFF161311),
        surfaceContainerLow: Color(0xFF1B1714),
        surfaceContainer: darkSurface,
        surfaceContainerHigh: Color(0xFF26201B),
        surfaceContainerHighest: darkSurfaceDouce,
        outline: darkBordureForte,
        outlineVariant: darkBordure,
        shadow: Colors.black,
        inverseSurface: Color(0xFFF5EFEB),
        onInverseSurface: Color(0xFF1E1A17),
        inversePrimary: primaryDark,
      ),
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: darkTextPrimary, size: 24),
      dividerTheme: const DividerThemeData(color: darkBordure, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkTextPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: Colors.black,
        centerTitle: false,
        titleSpacing: 20,
        iconTheme: const IconThemeData(color: darkTextPrimary, size: 24),
        titleTextStyle: inter(19, FontWeight.w700, darkTextPrimary, espacement: -0.4),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rayonL),
          side: const BorderSide(color: darkBordure),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: darkPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: rond,
        titleTextStyle: inter(15, FontWeight.w600, darkTextPrimary, espacement: -0.1),
        subtitleTextStyle: inter(13, FontWeight.w400, darkTextMuted, hauteur: 1.4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: darkSurface,
        filled: true,
        hintStyle: inter(14, FontWeight.w400, const Color(0xFF7E7368)),
        labelStyle: inter(14, FontWeight.w500, darkTextMuted),
        floatingLabelStyle: inter(14, FontWeight.w600, darkPrimary),
        prefixIconColor: darkPrimary,
        suffixIconColor: darkTextMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rayonM),
          borderSide: const BorderSide(color: darkBordure),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rayonM),
          borderSide: const BorderSide(color: darkBordure),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rayonM),
          borderSide: const BorderSide(color: darkPrimary, width: 1.5),
        ),
        errorStyle: inter(12, FontWeight.w500, const Color(0xFFEF5350)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF382F28),
          disabledForegroundColor: const Color(0xFF736558),
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 56),
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
          backgroundColor: darkPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          textStyle: inter(15, FontWeight.w700, Colors.white, espacement: -0.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkPrimary,
          side: const BorderSide(color: darkPrimary, width: 1.5),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: inter(16, FontWeight.w600, darkPrimary, espacement: -0.1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rayonS)),
          textStyle: inter(14, FontWeight.w700, darkPrimary),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(highlightColor: darkPrimary.withValues(alpha: 0.12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: darkPrimary,
        foregroundColor: Colors.white,
        elevation: 4,
        highlightElevation: 8,
        extendedTextStyle: inter(15, FontWeight.w700, Colors.white, espacement: -0.1),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurface,
        selectedColor: darkPrimary,
        secondarySelectedColor: darkPrimary,
        disabledColor: darkSurfaceDouce,
        checkmarkColor: Colors.white,
        side: const BorderSide(color: darkBordureForte),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        labelStyle: inter(13, FontWeight.w600, darkTextPrimary),
        secondaryLabelStyle: inter(13, FontWeight.w700, Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rayonXL)),
        titleTextStyle: inter(19, FontWeight.w800, darkTextPrimary, espacement: -0.4, hauteur: 1.25),
        contentTextStyle: inter(14, FontWeight.w400, darkTextMuted, hauteur: 1.5),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        modalBackgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
        dragHandleColor: darkBordureForte,
        dragHandleSize: Size(44, 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(rayonXL)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2A231E),
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rayonM)),
        contentTextStyle: inter(14, FontWeight.w500, Colors.white, hauteur: 1.35),
        actionTextColor: secondary,
        closeIconColor: Colors.white70,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rayonM),
          side: const BorderSide(color: darkBordure),
        ),
        textStyle: inter(14, FontWeight.w500, darkTextPrimary),
      ),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(darkSurface),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: const Color(0xFF2A231E), borderRadius: BorderRadius.circular(10)),
        textStyle: inter(12, FontWeight.w600, Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: darkPrimary,
        unselectedLabelColor: darkTextMuted,
        indicatorColor: darkPrimary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: darkBordure,
        labelStyle: inter(14, FontWeight.w700, darkPrimary),
        unselectedLabelStyle: inter(14, FontWeight.w500, darkTextMuted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFF38291E),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => inter(11.5, s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              s.contains(WidgetState.selected) ? darkPrimary : darkTextMuted),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? darkPrimary : darkTextMuted),
        ),
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: darkSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: darkPrimary,
        linearTrackColor: Color(0xFF38291E),
        circularTrackColor: Colors.transparent,
        linearMinHeight: 6,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? darkPrimary : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: darkBordureForte, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? darkPrimary : darkBordureForte,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? darkPrimary : const Color(0xFF4A4036),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: darkPrimary,
        inactiveTrackColor: Color(0xFF38291E),
        thumbColor: darkPrimary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: darkPrimary,
        selectionColor: darkPrimary.withValues(alpha: 0.28),
        selectionHandleColor: darkPrimary,
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

/// Extension sur BuildContext pour accéder directement aux couleurs et styles adaptatifs
extension DogoThemeExtension on BuildContext {
  bool get estSombre => AppTheme.estSombre(this);
  Color get couleurFond => AppTheme.couleurFond(this);
  Color get couleurSurface => AppTheme.couleurSurface(this);
  Color get couleurCarte => AppTheme.couleurCarte(this);
  Color get couleurSurfaceDouce => AppTheme.couleurSurfaceDouce(this);
  Color get couleurBordure => AppTheme.couleurBordure(this);
  Color get couleurBordureForte => AppTheme.couleurBordureForte(this);
  Color get couleurTexte => AppTheme.couleurTexte(this);
  Color get couleurEncre => AppTheme.couleurEncre(this);
  Color get couleurTexteAttenue => AppTheme.couleurTexteAttenue(this);
  Color get couleurAccent => AppTheme.couleurAccent(this);
  TextTheme get typographie => Theme.of(this).textTheme;
}

