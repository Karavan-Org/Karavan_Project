import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'karavan_logo.dart';
import 'portefeuille_3d_widget.dart';

/// Composant Portefeuille Neumorphique / Soft 3D Glass
/// Reproduit fidèlement le design Soft UI avec relief doux, double ombre lumineuse,
/// animation 3D immersive du portefeuille Karavan (cuir, billets FCFA, carte Platinum, mobile money),
/// pilules concaves d'informations, bouton gradient avec flèche circulaire
/// et boutons squircles rapides d'opérateurs, tout en respectant scrupuleusement la charte Karavan.
class ZonePortefeuilleNeumorphic extends StatelessWidget {
  final String titre;
  final String? sousTitre;
  final String montantSolde;
  final String? infoSequestre;
  final IconData? iconeInfo;
  final String texteBoutonAction;
  final VoidCallback? onTapAction;
  final List<Color>? couleurBouton;
  final List<Widget>? squirclesRapides;
  final String? titreSquirclesRapides;
  final bool compact;
  final bool afficherAnimation3D;

  const ZonePortefeuilleNeumorphic({
    super.key,
    required this.titre,
    this.sousTitre,
    required this.montantSolde,
    this.infoSequestre,
    this.iconeInfo,
    required this.texteBoutonAction,
    this.onTapAction,
    this.couleurBouton,
    this.squirclesRapides,
    this.titreSquirclesRapides,
    this.compact = false,
    this.afficherAnimation3D = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cercles d'ambiance 3D organiques en arrière-plan
        Positioned(
          top: -15,
          left: -15,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.bordureForte.withValues(alpha: 0.45),
                  AppTheme.creme.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -15,
          right: -10,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.bordureForte.withValues(alpha: 0.35),
                  AppTheme.creme.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),

        // Cadre principal Portefeuille Neumorphique / Soft 3D
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 18 : 24),
          decoration: BoxDecoration(
            color: AppTheme.couleurCarte(context),
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppTheme.estSombre(context)
                  ? const [
                      AppTheme.darkSurfaceHaute,
                      AppTheme.darkSurface,
                      AppTheme.darkSurfaceBasse,
                    ]
                  : const [
                      Color(0xFFFFFFFF),
                      AppTheme.surfaceDouce,
                      AppTheme.surfaceDouce,
                    ],
              stops: const [0.0, 0.65, 1.0],
            ),
            border: Border.all(
              color: AppTheme.couleurBordureForte(context),
              width: 2.0,
            ),
            boxShadow: [
              // Reflet supérieur gauche discret, adapté à la luminosité du thème.
              BoxShadow(
                color: AppTheme.estSombre(context)
                    ? Colors.white.withValues(alpha: 0.035)
                    : Colors.white,
                offset: const Offset(-7, -7),
                blurRadius: 16,
                spreadRadius: 2,
              ),
              // Ombre portée inférieure droite douce et tactile
              const BoxShadow(
                color: Color(0x182C241E),
                offset: Offset(9, 16),
                blurRadius: 26,
                spreadRadius: 0,
              ),
              // Lueur d'ambiance chaude subtile
              const BoxShadow(
                color: Color(0x0C84173A),
                offset: Offset(0, 4),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Animation 3D Matérielle & Légère du Portefeuille Karavan
              if (afficherAnimation3D) ...[
                Portefeuille3dWidget(
                  compact: compact,
                  hauteur: compact ? 120 : 155,
                ),
                SizedBox(height: compact ? 6 : 10),
              ] else ...[
                // Emblème 3D en squircle pillow : logo Karavan (repli)
                Container(
                  width: compact ? 56 : 68,
                  height: compact ? 56 : 68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(compact ? 18 : 22),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppTheme.estSombre(context)
                          ? const [AppTheme.darkSurfaceHaute, AppTheme.darkSurface]
                          : const [Colors.white, AppTheme.surfaceDouce],
                    ),
                    border: Border.all(color: AppTheme.couleurBordureForte(context), width: 2.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.estSombre(context)
                            ? Colors.white.withValues(alpha: 0.035)
                            : Colors.white,
                        offset: const Offset(-4, -4),
                        blurRadius: 10,
                      ),
                      const BoxShadow(
                        color: Color(0x1E2C241E),
                        offset: Offset(4, 9),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(compact ? 16 : 20),
                    child: Image.asset(
                      KaravanLogo.asset,
                      fit: BoxFit.cover,
                      cacheWidth: 200,
                    ),
                  ),
                ),
                SizedBox(height: compact ? 12 : 16),
              ],

              // Titre & Sous-titre
              Text(
                titre,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 17 : 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.couleurTexte(context),
                  letterSpacing: -0.3,
                ),
              ),

              if (sousTitre != null) ...[
                const SizedBox(height: 3),
                Text(
                  sousTitre!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.couleurTexteAttenue(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              SizedBox(height: compact ? 10 : 14),

              // Solde imposant et net
              Text(
                montantSolde,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 26 : 32,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.couleurTexte(context),
                  letterSpacing: -0.6,
                ),
              ),

              // Pilule d'information concave (style champ de saisie de la référence)
              if (infoSequestre != null) ...[
                SizedBox(height: compact ? 12 : 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.couleurSurfaceDouce(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.couleurBordure(context),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0E2C241E),
                        offset: Offset(0, 2),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.couleurCarte(context),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12000000),
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          iconeInfo ?? Icons.verified_user_rounded,
                          size: 15,
                          color: AppTheme.couleurAccent(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          infoSequestre!,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.couleurTexte(context),
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: compact ? 14 : 18),

              // Bouton d'action principal avec pilule dégradée et flèche circulaire (identique au bouton Login)
              GestureDetector(
                onTap: onTapAction,
                child: Container(
                  width: double.infinity,
                  height: compact ? 46 : 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(compact ? 23 : 26),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    colors: AppTheme.estSombre(context)
                        ? const [AppTheme.darkPrimaryDark, AppTheme.darkPrimaryDark, AppTheme.darkPrimaryDark]
                        : (couleurBouton ?? const [AppTheme.bissap, AppTheme.bissapProfond, AppTheme.bissapProfond]),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F000000),
                        offset: Offset(0, 8),
                        blurRadius: 12,
                        
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 28), // Équilibre visuel pour centrer le texte
                      Expanded(
                        child: Text(
                          texteBoutonAction,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.estSombre(context)
                                ? AppTheme.texteSur(AppTheme.darkPrimaryDark)
                                : Colors.white,
                            fontSize: compact ? 13 : 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      Container(
                        width: compact ? 28 : 32,
                        height: compact ? 28 : 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: compact ? 15 : 17,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Squircles d'actions rapides (style Google, Discord, Facebook en bas de la maquette)
              if (squirclesRapides != null && squirclesRapides!.isNotEmpty) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: Divider(color: AppTheme.couleurBordure(context), thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        titreSquirclesRapides ?? "OPÉRATEURS DISPONIBLES",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: AppTheme.couleurTexteAttenue(context),
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppTheme.couleurBordure(context), thickness: 1)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: squirclesRapides!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Constructeur pour un squircle rapide d'opérateur ou d'action (comme les icônes rondes/squircles du bas)
  static Widget buildSquircleRapide({
    required BuildContext context,
    required Widget child,
    required String label,
    required VoidCallback onTap,
    Color? couleurBordure,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.couleurCarte(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: couleurBordure ?? AppTheme.couleurBordureForte(context),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.white,
                  offset: Offset(-3, -3),
                  blurRadius: 8,
                ),
                BoxShadow(
                  color: Color(0x182C241E),
                  offset: Offset(3, 6),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Center(child: child),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
            style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
              color: AppTheme.couleurTexteAttenue(context),
          ),
        ),
      ],
    );
  }
}

