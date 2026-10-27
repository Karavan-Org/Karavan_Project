import 'package:flutter/material.dart';

class AppTheme {
  // --- PALETTE GRAPHIQUE HISTORIQUE DOGO ---
  static const Color primary = Color(0xFFAC7F5E);
  static const Color primaryDark = Color(0xFF8E6445);
  static const Color secondary = Color(0xFFE6A823);
  static const Color tertiary = Color(0xFFF5E8D3);
  static const Color background = Color(0xFFFBF9F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF34C759);
  static const Color textDark = Color(0xFF1E1E1E);
  static const Color textPrimary = textDark;
  static const Color textMuted = Color(0xFF757575);
  static const Color encre = Color(0xFF2C241E);
  static const Color bordure = Color(0xFFEDE5DC);
  static const Color bordureForte = Color(0xFFE2D8CF);
  static const Color surfaceDouce = Color(0xFFF7F2EB);
  static const Color danger = Color(0xFFC0392B);
  static const Color avertissement = Color(0xFFD97706);

  // Alias conserv?s pour les ?crans ajout?s depuis le changement de charte.
  static const Color bissap = primary;
  static const Color bissapProfond = primaryDark;
  static const Color olive = success;
  static const Color oliveProfond = Color(0xFF278A3D);
  static const Color oliveClair = Color(0xFFE8F7EC);
  static const Color oliveBordure = Color(0xFFB8E6C4);
  static const Color rose = tertiary;
  static const Color roseClair = Color(0xFFFAF3E9);
  static const Color doreKaravan = Color(0xFFF2A832);
  static const Color ocre = secondary;
  static const Color ocreProfond = Color(0xFF9A6C08);
  static const Color ocreClair = Color(0xFFFFF5D8);
  static const Color ocreBordure = Color(0xFFEED99F);
  static const Color terre = encre;
  static const Color terreDouce = Color(0xFF5C5149);
  static const Color creme = background;
  static const Color textePale = Color(0xFFAAA095);
  static const Color dangerProfond = Color(0xFF8E2419);
  static const Color dangerClair = Color(0xFFFBE8E5);
  static const Color dangerBordure = Color(0xFFF2C2BB);

  // --- PALETTE MODE SOMBRE (charte camel historique) ---
  static const Color darkBackground = Color(0xFF141210);
  static const Color darkSurfaceBasse = Color(0xFF1B1815);
  static const Color darkSurface = Color(0xFF201B17);
  static const Color darkSurfaceHaute = Color(0xFF2A231E);
  static const Color darkSurfaceDouce = Color(0xFF2B2520);
  static const Color darkBordure = Color(0xFF382F28);
  static const Color darkBordureForte = Color(0xFF4C4037);
  static const Color darkTextPrimary = Color(0xFFF7F2ED);
  static const Color darkTextMuted = Color(0xFFAAA095);
  static const Color darkPrimary = Color(0xFFC5956E);
  static const Color darkPrimaryDark = Color(0xFFAD7F5C);
  static const Color darkPrimaryContainer = Color(0xFF38291E);
  static const Color darkOlive = Color(0xFF65C77C);
  static const Color darkOliveSurface = Color(0xFF1C3022);
  static const Color darkOcreSurface = Color(0xFF382F1E);
  static const Color darkDanger = Color(0xFFEF7B6E);
  static const Color darkDangerSurface = Color(0xFF4A1A15);

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

  /// Terre en clair, blanc cassé en sombre
  static Color couleurEncre(BuildContext context) =>
      estSombre(context) ? darkTextPrimary : encre;

  /// Couleur secondaire du texte (descriptions, sous-titres, dates)
  static Color couleurTexteAttenue(BuildContext context) =>
      estSombre(context) ? darkTextMuted : textMuted;

  /// Accent camel pour textes, liens et icônes
  static Color couleurAccent(BuildContext context) =>
      estSombre(context) ? darkPrimary : primary;

  /// Olive lisible en texte (validation, étapes terminées)
  static Color couleurSucces(BuildContext context) =>
      estSombre(context) ? darkOlive : success;

  /// Ocre lisible en texte / icône (points d'attention)
  static Color couleurAttention(BuildContext context) =>
      estSombre(context) ? ocre : avertissement;

  /// Rouge lisible pour les actions et alertes selon le mode actif.
  static Color couleurDanger(BuildContext context) =>
      estSombre(context) ? darkDanger : danger;

  static Color couleurFondSucces(BuildContext context) =>
      estSombre(context) ? darkOliveSurface : oliveClair;

  static Color couleurFondDanger(BuildContext context) =>
      estSombre(context) ? darkDangerSurface : dangerClair;

  /// Règle de lisibilité : texte blanc sur bissap, olive et terre ; texte terre sur rose et ocre.
  static Color texteSur(Color fond) => fond.computeLuminance() > 0.4 ? terre : Colors.white;

  /// Couleur d'accent utilisable en texte / icône sur fond clair (l'ocre et l'olive passent en profond).
  static Color lisibleSurClair(Color c) {
    if (c == ocre) return ocreProfond;
    if (c == olive) return oliveProfond;
    return c.computeLuminance() > 0.3 ? terreDouce : c;
  }

  /// Bandeau de navigation (terre sombre) et ses contenus
  static Color couleurBandeauNavigation(BuildContext context) =>
      estSombre(context) ? const Color(0xFF140D0B) : terre;

  // --- TYPOGRAPHIE INTER OFFICIELLE DOGO ---
  static TextStyle styleTitreGrand(BuildContext context, {FontWeight graisse = FontWeight.w700, Color? couleur}) =>
      TextStyle(
        fontFamily: policeTitre,
        fontSize: 20,
        fontWeight: graisse,
        color: couleur ?? couleurTexte(context),
        height: 1.25,
      );

  static TextStyle styleTitreMoyen(BuildContext context, {FontWeight graisse = FontWeight.w700, Color? couleur}) =>
      TextStyle(
        fontFamily: policeTitre,
        fontSize: 16,
        fontWeight: graisse,
        color: couleur ?? couleurTexte(context),
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
        color: couleur ?? couleurTexte(context),
      );

  /// Noto Sans embarquée (pubspec.yaml) : graisses 400 à 800.
  static const String police = 'Inter';

  /// Noto Serif embarquée : graisses 600 à 800, pour les titres et en-têtes.
  static const String policeTitre = 'Inter';

  // --- RAYONS ---
  static const double rayonS = 12;
  static const double rayonM = 16;
  static const double rayonL = 20;
  static const double rayonXL = 28;

  // --- OMBRES (teintées de terre plutôt que noires) ---
  static const List<BoxShadow> ombreDouce = [
    BoxShadow(color: Color(0x0F2C241E), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x052C241E), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> ombreFlottante = [
    BoxShadow(color: Color(0x1F2C241E), blurRadius: 28, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x0A2C241E), blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// Dégradé bissap de la marque (boutons d'action forts, bandeaux d'en-tête).
  static const LinearGradient degradePrimaire = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB98A66), primaryDark],
  );

  /// Dégradé terre (cartes sombres : portefeuille, bandeaux de suivi).
  static const LinearGradient degradeTerre = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4A4036), encre, Color(0xFF2A231E)],
  );

  // --- THÈME MATERIAL 3 ---
  static ThemeData get lightTheme => _theme(
        sombre: false,
        fond: background,
        carte: surface,
        douce: surfaceDouce,
        bord: bordure,
        bordFort: bordureForte,
        texte: textDark,
        attenue: textMuted,
        accent: primary,
        scheme: const ColorScheme.light(
          primary: primary,
        onPrimary: Colors.white,
          primaryContainer: tertiary,
          onPrimaryContainer: primaryDark,
          secondary: secondary,
          onSecondary: terre,
          secondaryContainer: Color(0xFFFFF3D2),
          onSecondaryContainer: Color(0xFF5A4210),
          tertiary: tertiary,
          onTertiary: textDark,
          tertiaryContainer: tertiary,
          onTertiaryContainer: primaryDark,
          error: danger,
          errorContainer: dangerClair,
          surface: background,
          onSurface: textDark,
          onSurfaceVariant: textMuted,
          surfaceTint: Colors.transparent,
          surfaceContainerLowest: surface,
          surfaceContainerLow: Color(0xFFFDF9F6),
          surfaceContainer: surface,
          surfaceContainerHigh: surface,
          surfaceContainerHighest: surfaceDouce,
          outline: bordureForte,
          outlineVariant: bordure,
          shadow: encre,
          inverseSurface: encre,
          onInverseSurface: Colors.white,
          inversePrimary: primaryDark,
        ),
      );

  // --- THÈME MATERIAL 3 SOMBRE ---
  static ThemeData get darkTheme => _theme(
        sombre: true,
        fond: darkBackground,
        carte: darkSurface,
        douce: darkSurfaceDouce,
        bord: darkBordure,
        bordFort: darkBordureForte,
        texte: darkTextPrimary,
        attenue: darkTextMuted,
        accent: darkPrimary,
        scheme: const ColorScheme.dark(
          primary: darkPrimary,
        onPrimary: terre,
          primaryContainer: darkPrimaryContainer,
          onPrimaryContainer: Color(0xFFF8D3DE),
          secondary: ocre,
          onSecondary: terre,
          secondaryContainer: darkOcreSurface,
          onSecondaryContainer: Color(0xFFF6E2AA),
          tertiary: darkOlive,
          onTertiary: Color(0xFF1C1F05),
          tertiaryContainer: darkOliveSurface,
          onTertiaryContainer: Color(0xFFDDE4A6),
          error: darkDanger,
          errorContainer: darkDangerSurface,
          surface: darkSurface,
          onSurface: darkTextPrimary,
          onSurfaceVariant: darkTextMuted,
          surfaceTint: Colors.transparent,
          surfaceContainerLowest: Color(0xFF150E0C),
          surfaceContainerLow: darkSurfaceBasse,
          surfaceContainer: darkSurface,
          surfaceContainerHigh: darkSurfaceHaute,
          surfaceContainerHighest: darkSurfaceDouce,
          outline: darkBordureForte,
          outlineVariant: darkBordure,
          shadow: Colors.black,
          inverseSurface: creme,
          onInverseSurface: terre,
          inversePrimary: bissapProfond,
        ),
      );

  static ThemeData _theme({
    required bool sombre,
    required Color fond,
    required Color carte,
    required Color douce,
    required Color bord,
    required Color bordFort,
    required Color texte,
    required Color attenue,
    required Color accent,
    required ColorScheme scheme,
  }) {
    TextStyle sans(double taille, FontWeight graisse, Color couleur, {double espacement = 0, double? hauteur}) =>
        TextStyle(fontFamily: police, fontSize: taille, fontWeight: graisse, color: couleur, letterSpacing: espacement, height: hauteur);
    TextStyle serif(double taille, FontWeight graisse, Color couleur, {double espacement = 0, double? hauteur}) =>
        TextStyle(fontFamily: policeTitre, fontSize: taille, fontWeight: graisse, color: couleur, letterSpacing: espacement, height: hauteur);

    final textTheme = TextTheme(
      // Titres : Inter
      displayLarge: serif(32, FontWeight.w800, texte, espacement: -0.4, hauteur: 1.15),
      displayMedium: serif(28, FontWeight.w800, texte, espacement: -0.3, hauteur: 1.15),
      displaySmall: serif(26, FontWeight.w700, texte, espacement: -0.2, hauteur: 1.2),
      headlineLarge: serif(28, FontWeight.w700, texte, espacement: -0.2, hauteur: 1.2),
      headlineMedium: serif(26, FontWeight.w700, texte, espacement: -0.2, hauteur: 1.2),
      // Montant : 24px
      headlineSmall: sans(24, FontWeight.w700, texte, espacement: -0.3),
      titleLarge: serif(20, FontWeight.w700, texte, hauteur: 1.25),
      // Corps et libellés : Noto Sans
      titleMedium: sans(16, FontWeight.w600, texte, hauteur: 1.3),
      titleSmall: sans(13, FontWeight.w500, attenue),
      bodyLarge: sans(15, FontWeight.w400, texte, hauteur: 1.45),
      bodyMedium: sans(13, FontWeight.w400, texte, hauteur: 1.5),
      bodySmall: sans(12, FontWeight.w400, attenue, hauteur: 1.4),
      labelLarge: sans(14, FontWeight.w600, texte),
      labelMedium: sans(12, FontWeight.w600, texte),
      labelSmall: sans(11, FontWeight.w600, attenue, espacement: 0.1),
    );

    final rond = RoundedRectangleBorder(borderRadius: BorderRadius.circular(rayonM));
    final ombre = sombre ? Colors.black : const Color(0x332C241E);
    const blanc = Colors.white;
    final onAccent = texteSur(accent);

    return ThemeData(
      useMaterial3: true,
      brightness: sombre ? Brightness.dark : Brightness.light,
      fontFamily: police,
      primaryTextTheme: (sombre ? ThemeData.dark() : ThemeData.light()).primaryTextTheme.apply(fontFamily: police),
      scaffoldBackgroundColor: fond,
      canvasColor: fond,
      cardColor: carte,
      splashFactory: InkSparkle.splashFactory,
      highlightColor: texte.withValues(alpha: sombre ? 0.10 : 0.05),
      // Les surfaces M3 sont toutes fixées : sans cela dialogues, menus et chips prennent une teinte lavande.
      colorScheme: scheme,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: texte, size: 24),
      dividerTheme: DividerThemeData(color: bord, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: fond,
        foregroundColor: texte,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: ombre,
        centerTitle: false,
        titleSpacing: 20,
        iconTheme: IconThemeData(color: texte, size: 24),
        actionsIconTheme: IconThemeData(color: texte, size: 24),
        titleTextStyle: serif(19, FontWeight.w700, texte),
      ),
      cardTheme: CardThemeData(
        color: carte,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rayonL),
          side: BorderSide(color: bord),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: texte,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: rond,
        titleTextStyle: sans(15, FontWeight.w600, texte),
        subtitleTextStyle: sans(13, FontWeight.w400, attenue, hauteur: 1.4),
      ),
      // Seule la forme est fixée en clair : les couleurs d'état (repos, focus bissap, erreur) viennent du colorScheme,
      // et les champs intégrés dans un conteneur sur mesure (border: InputBorder.none) restent sans contour.
      inputDecorationTheme: sombre
          ? InputDecorationTheme(
              fillColor: carte,
              filled: true,
              hintStyle: sans(14, FontWeight.w400, const Color(0xFF8D7A73)),
              labelStyle: sans(14, FontWeight.w500, attenue),
              floatingLabelStyle: sans(14, FontWeight.w600, texte),
              prefixIconColor: attenue,
              suffixIconColor: attenue,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(rayonM), borderSide: BorderSide(color: bord)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(rayonM), borderSide: BorderSide(color: bord)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(rayonM),
                borderSide: BorderSide(color: texte, width: 1.5),
              ),
              errorStyle: sans(12, FontWeight.w500, darkDanger),
            )
          : InputDecorationTheme(
              fillColor: surface,
              hintStyle: sans(14, FontWeight.w400, textePale),
              labelStyle: sans(14, FontWeight.w500, textMuted),
              floatingLabelStyle: sans(14, FontWeight.w600, terre),
              prefixIconColor: textMuted,
              suffixIconColor: textMuted,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(rayonM)),
              errorStyle: sans(12, FontWeight.w500, danger),
            ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          disabledBackgroundColor: sombre ? darkBordure : const Color(0xFFE8D6DB),
          disabledForegroundColor: sombre ? const Color(0xFF85706A) : blanc,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 56),
          // Bouton large : taille écriture 16px, border-radius 30px
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          textStyle: sans(16, FontWeight.w700, onAccent),
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(blanc.withValues(alpha: 0.12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          textStyle: sans(15, FontWeight.w700, onAccent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: texte,
          side: BorderSide(color: texte, width: 1.5),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          textStyle: sans(16, FontWeight.w600, texte),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: texte,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rayonS)),
          textStyle: sans(14, FontWeight.w700, texte),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(highlightColor: texte.withValues(alpha: sombre ? 0.10 : 0.06)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: 4,
        highlightElevation: 8,
        extendedTextStyle: sans(15, FontWeight.w700, onAccent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: carte,
        selectedColor: ocre,
        secondarySelectedColor: ocre,
        disabledColor: douce,
        checkmarkColor: terre,
        side: BorderSide(color: bordFort),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        labelStyle: sans(13, FontWeight.w600, texte),
        secondaryLabelStyle: sans(13, FontWeight.w700, terre),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: carte,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: ombre,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rayonXL)),
        titleTextStyle: serif(19, FontWeight.w700, texte, hauteur: 1.25),
        contentTextStyle: sans(14, FontWeight.w400, sombre ? attenue : terreDouce, hauteur: 1.5),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: carte,
        modalBackgroundColor: carte,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
        dragHandleColor: bordFort,
        dragHandleSize: const Size(44, 5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(rayonXL)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: sombre ? darkSurfaceHaute : terre,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rayonM)),
        contentTextStyle: sans(14, FontWeight.w500, blanc, hauteur: 1.35),
        actionTextColor: rose,
        closeIconColor: Colors.white70,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: carte,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: ombre,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rayonM),
          side: BorderSide(color: bord),
        ),
        textStyle: sans(14, FontWeight.w500, texte),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(carte),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: sombre ? darkSurfaceHaute : terre, borderRadius: BorderRadius.circular(10)),
        textStyle: sans(12, FontWeight.w600, blanc),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: texte,
        unselectedLabelColor: attenue,
        indicatorColor: sombre ? const Color(0xFF38291E) : tertiary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: bord,
        labelStyle: sans(14, FontWeight.w700, texte),
        unselectedLabelStyle: sans(14, FontWeight.w500, attenue),
      ),
      // Navigation DoGo classique
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: sombre ? darkSurface : surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: tertiary,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => sans(11.5, s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              s.contains(WidgetState.selected) ? primary : (sombre ? darkTextMuted : textMuted)),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? primary : (sombre ? darkTextMuted : textMuted)),
        ),
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: sombre ? darkSurface : surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: ombre,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        // Olive : progression des groupes
        color: sombre ? darkPrimary : primary,
        linearTrackColor: sombre ? const Color(0xFF38291E) : tertiary,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 6,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? (sombre ? darkOlive : olive) : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(blanc),
        side: BorderSide(color: bordFort, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? (sombre ? darkOlive : olive) : bordFort,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(blanc),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? (sombre ? darkOlive : olive) : (sombre ? darkBordureForte : const Color(0xFFDCCAC1)),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: texte,
        inactiveTrackColor: bordFort,
        thumbColor: ocre,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: texte,
        selectionColor: ocre.withValues(alpha: sombre ? 0.35 : 0.45),
        selectionHandleColor: ocre,
      ),
      // Rose poudre : notifications (texte terre sur rose)
      badgeTheme: BadgeThemeData(
        backgroundColor: rose,
        textColor: terre,
        textStyle: sans(10, FontWeight.w700, terre),
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
  Color get couleurSucces => AppTheme.couleurSucces(this);
  Color get couleurAttention => AppTheme.couleurAttention(this);
  TextTheme get typographie => Theme.of(this).textTheme;
}
