import 'package:flutter/material.dart';

/// Composant Portefeuille Neumorphique / Soft 3D Glass
/// Reproduit fidèlement le design Soft UI avec relief doux, double ombre lumineuse,
/// squircle 3D emblématique DoGo, pilules concaves d'informations, bouton gradient avec flèche circulaire
/// et boutons squircles rapides d'opérateurs, tout en respectant scrupuleusement la charte DoGo.
class ZonePortefeuilleNeumorphic extends StatelessWidget {
  final String titre;
  final String? sousTitre;
  final String montantSolde;
  final String? infoSequestre;
  final IconData? iconeInfo;
  final String texteBoutonAction;
  final VoidCallback? onTapAction;
  final List<Color>? couleurBouton;
  final List<Color>? couleurEmbleme;
  final List<Widget>? squirclesRapides;
  final String? titreSquirclesRapides;
  final bool compact;

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
    this.couleurEmbleme,
    this.squirclesRapides,
    this.titreSquirclesRapides,
    this.compact = false,
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
                  const Color(0xFFEADBCE).withValues(alpha: 0.45),
                  const Color(0xFFFAF7F2).withValues(alpha: 0.0),
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
                  const Color(0xFFE2CBB7).withValues(alpha: 0.35),
                  const Color(0xFFFAF7F2).withValues(alpha: 0.0),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFFAF6F1),
                Color(0xFFF6EFE6),
              ],
              stops: [0.0, 0.65, 1.0],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.95),
              width: 2.0,
            ),
            boxShadow: const [
              // Reflet supérieur gauche blanc pur (effet lumineux spéculaire)
              BoxShadow(
                color: Colors.white,
                offset: Offset(-7, -7),
                blurRadius: 16,
                spreadRadius: 2,
              ),
              // Ombre portée inférieure droite douce et tactile
              BoxShadow(
                color: Color(0x184A3319),
                offset: Offset(9, 16),
                blurRadius: 26,
                spreadRadius: 0,
              ),
              // Lueur d'ambiance chaude subtile
              BoxShadow(
                color: Color(0x0C7D4F27),
                offset: Offset(0, 4),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Emblème 3D en squircle pillow (style flamme DoGo 3D)
              Container(
                width: compact ? 56 : 68,
                height: compact ? 56 : 68,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(compact ? 18 : 22),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFF4ECE2),
                    ],
                  ),
                  border: Border.all(color: Colors.white, width: 2.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.white,
                      offset: Offset(-4, -4),
                      blurRadius: 10,
                    ),
                    BoxShadow(
                      color: Color(0x1E4A3319),
                      offset: Offset(4, 9),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Center(
                  child: CustomPaint(
                    painter: _Dogo3DEmblemPainter(couleurs: couleurEmbleme),
                    size: Size(compact ? 30 : 38, compact ? 34 : 42),
                  ),
                ),
              ),

              SizedBox(height: compact ? 12 : 16),

              // Titre & Sous-titre
              Text(
                titre,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 17 : 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF2C241E),
                  letterSpacing: -0.3,
                ),
              ),

              if (sousTitre != null) ...[
                const SizedBox(height: 3),
                Text(
                  sousTitre!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8C7E74),
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
                  color: const Color(0xFF2C241E),
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
                    color: const Color(0xFFF7F2EC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0E3A2412),
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
                          color: Colors.white,
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
                          color: const Color(0xFF9E6738),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          infoSequestre!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5A493B),
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
                      colors: couleurBouton ??
                          const [
                            Color(0xFFB87333),
                            Color(0xFF915123),
                            Color(0xFF753812),
                          ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (couleurBouton?.last ?? const Color(0xFF753812))
                            .withValues(alpha: 0.40),
                        offset: const Offset(0, 8),
                        blurRadius: 18,
                        spreadRadius: 0,
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
                            color: Colors.white,
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
                    const Expanded(child: Divider(color: Color(0xFFE5DDD3), thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        titreSquirclesRapides ?? "OPÉRATEURS DISPONIBLES",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: Color(0xFFA09285),
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: Color(0xFFE5DDD3), thickness: 1)),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: couleurBordure ?? Colors.white,
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.white,
                  offset: Offset(-3, -3),
                  blurRadius: 8,
                ),
                BoxShadow(
                  color: Color(0x184A3319),
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
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5A493B),
          ),
        ),
      ],
    );
  }
}

/// Peintre vectoriel 3D reproduisant le style de l'emblème ondulé en relief (Rubans superposés)
/// adapté à la palette chaude & prestigieuse de DoGo.
class _Dogo3DEmblemPainter extends CustomPainter {
  final List<Color>? couleurs;

  const _Dogo3DEmblemPainter({this.couleurs});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Couleurs par défaut (Warm Terracotta / Golden Amber / Ivory DoGo)
    final col1 = couleurs != null && couleurs!.isNotEmpty
        ? couleurs![0]
        : const Color(0xFFFFFFFF);
    final col2 = couleurs != null && couleurs!.length > 1
        ? couleurs![1]
        : const Color(0xFFE5A100);
    final col3 = couleurs != null && couleurs!.length > 2
        ? couleurs![2]
        : const Color(0xFF9E5C23);

    // 1. Vaguelette supérieure (claire, en relief)
    final path1 = Path()
      ..moveTo(w * 0.45, h * 0.05)
      ..cubicTo(w * 0.65, h * 0.05, w * 0.90, h * 0.22, w * 0.85, h * 0.38)
      ..cubicTo(w * 0.80, h * 0.48, w * 0.65, h * 0.45, w * 0.55, h * 0.35)
      ..cubicTo(w * 0.42, h * 0.22, w * 0.35, h * 0.15, w * 0.45, h * 0.05)
      ..close();

    final paint1 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          col1,
          const Color(0xFFEBDDCB),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path1, paint1);

    // 2. Vaguelette centrale (Ambre dorée vibrante)
    final path2 = Path()
      ..moveTo(w * 0.25, h * 0.25)
      ..cubicTo(w * 0.45, h * 0.22, w * 0.82, h * 0.38, w * 0.75, h * 0.60)
      ..cubicTo(w * 0.70, h * 0.72, w * 0.52, h * 0.68, w * 0.38, h * 0.52)
      ..cubicTo(w * 0.22, h * 0.38, w * 0.18, h * 0.30, w * 0.25, h * 0.25)
      ..close();

    final paint2 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          col2,
          const Color(0xFFD48800),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path2, paint2);

    // 3. Vaguelette inférieure (Terracotta foncée / Bronze)
    final path3 = Path()
      ..moveTo(w * 0.18, h * 0.50)
      ..cubicTo(w * 0.35, h * 0.45, w * 0.72, h * 0.62, w * 0.60, h * 0.88)
      ..cubicTo(w * 0.52, h * 0.98, w * 0.36, h * 0.95, w * 0.28, h * 0.80)
      ..cubicTo(w * 0.14, h * 0.65, w * 0.10, h * 0.58, w * 0.18, h * 0.50)
      ..close();

    final paint3 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          col3,
          const Color(0xFF6B3614),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path3, paint3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

