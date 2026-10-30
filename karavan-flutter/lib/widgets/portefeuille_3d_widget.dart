import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animation 3D ultra-optimisée du Portefeuille Karavan
/// Intègre :
/// 1. Portefeuille en cuir Bissap / Camel avec surpiqûres sellier et fermoir doré
/// 2. Billets de banque FCFA (10 000 & 5 000 FCFA) en relief
/// 3. Carte Bancaire VIP Karavan Platinum avec puce EMV dorée et NFC
/// 4. Entrée d'argent Mobile Money (Smartphone stylisé + flux de pièces d'or)
/// 5. Haute performance : compositing GPU, RepaintBoundary, 60 FPS garanti
class Portefeuille3dWidget extends StatefulWidget {
  final bool compact;
  final double? hauteur;
  final bool interactif;
  final VoidCallback? onTap;

  const Portefeuille3dWidget({
    super.key,
    this.compact = false,
    this.hauteur,
    this.interactif = true,
    this.onTap,
  });

  @override
  State<Portefeuille3dWidget> createState() => _Portefeuille3dWidgetState();
}

class _Portefeuille3dWidgetState extends State<Portefeuille3dWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Variables pour l'interaction tilt 3D tactile / souris
  double _tiltX = 0.0;
  double _tiltY = 0.0;
  bool _estSurvole = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(PointerEvent event, Size size) {
    if (!widget.interactif) return;
    final dx = (event.localPosition.dx / size.width) - 0.5;
    final dy = (event.localPosition.dy / size.height) - 0.5;
    setState(() {
      _tiltY = dx * 0.28;
      _tiltX = -dy * 0.22;
      _estSurvole = true;
    });
  }

  void _onExit() {
    if (!widget.interactif) return;
    setState(() {
      _tiltX = 0.0;
      _tiltY = 0.0;
      _estSurvole = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double baseHauteur = widget.hauteur ?? (widget.compact ? 135.0 : 175.0);
    final double baseLargeur = widget.compact ? 290.0 : 330.0;

    return RepaintBoundary(
      child: Center(
        child: SizedBox(
          height: baseHauteur,
          width: baseLargeur,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return MouseRegion(
                onHover: (e) => _onHover(e, size),
                onExit: (_) => _onExit(),
                child: GestureDetector(
                  onTap: widget.onTap,
                  onPanUpdate: (details) {
                    if (!widget.interactif) return;
                    setState(() {
                      _tiltY = (_tiltY + details.delta.dx * 0.005).clamp(-0.35, 0.35);
                      _tiltX = (_tiltX - details.delta.dy * 0.005).clamp(-0.30, 0.30);
                    });
                  },
                  onPanEnd: (_) => _onExit(),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final double t = _controller.value;
                      // Lévitation sinusoïdale douce et reposante (60 FPS)
                      final double floatY = math.sin(t * 2 * math.pi) * (widget.compact ? 3.0 : 4.5);
                      final double floatRot = math.sin(t * 2 * math.pi) * 0.02;

                      final Matrix4 matrix = Matrix4.identity()
                        ..setEntry(3, 2, 0.0016) // Perspective 3D
                        ..rotateX(_tiltX + (floatRot * 0.5))
                        ..rotateY(_tiltY + (floatRot * 0.8));

                      return Transform.translate(
                        offset: Offset(0.0, floatY),
                        child: AnimatedScale(
                          scale: _estSurvole ? 1.03 : 1.0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: matrix,
                            child: _construireScene(context, t),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _construireScene(BuildContext context, double t) {
    final bool isDark = AppTheme.estSombre(context);
    final double scale = widget.compact ? 0.82 : 1.0;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // 0. Ombre portée douce au sol
        Positioned(
          bottom: 4 * scale,
          child: Container(
            width: 220 * scale,
            height: 16 * scale,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : const Color(0xFF2C241E))
                      .withValues(alpha: isDark ? 0.45 : 0.22),
                  blurRadius: 18 * scale,
                  spreadRadius: 3 * scale,
                ),
              ],
            ),
          ),
        ),

        // 1. SOURCE MOBILE : Smartphone stylisé émettant du Mobile Money
        Positioned(
          left: 12 * scale,
          top: 18 * scale,
          child: _construireSmartphone(scale, t, isDark),
        ),

        // 2. FLUX DE PIÈCES D'OR VOYAGEANT VERS LE PORTEFEUILLE
        _construireFluxPieces(scale, t),

        // 3. LE PORTEFEUILLE EN CUIR KARAVAN AVEC BILLETS ET CARTE
        Positioned(
          right: 18 * scale,
          child: _construirePortefeuilleCuir(scale, t, isDark),
        ),
      ],
    );
  }

  /// 1. Le Smartphone stylisé (source Mobile Money)
  Widget _construireSmartphone(double scale, double t, bool isDark) {
    final double pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
    final double w = 70 * scale;
    final double h = 110 * scale;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..rotateZ(-0.06)
        ..rotateY(0.18),
      child: Container(
        width: w,
        height: h,
        padding: EdgeInsets.all(4 * scale),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14 * scale),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2A3644),
              Color(0xFF141C24),
              Color(0xFF0D1217),
            ],
          ),
          border: Border.all(
            color: const Color(0xFF5A728A).withValues(alpha: 0.6),
            width: 1.5 * scale,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              offset: Offset(2 * scale, 6 * scale),
              blurRadius: 12 * scale,
            ),
          ],
        ),
        child: Column(
          children: [
            // Écouteur supérieur
            Container(
              width: 18 * scale,
              height: 3 * scale,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 5 * scale),

            // Écran avec notification
            Expanded(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 4 * scale),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9 * scale),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0E2238),
                      Color(0xFF081422),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icône mobile money avec pulsation
                    Container(
                      padding: EdgeInsets.all(4 * scale),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFEEA823).withValues(alpha: 0.20 + (pulse * 0.15)),
                        border: Border.all(
                          color: const Color(0xFFEEA823).withValues(alpha: 0.8),
                          width: 1.0,
                        ),
                      ),
                      child: Icon(
                        Icons.phone_android_rounded,
                        color: const Color(0xFFEEA823),
                        size: 16 * scale,
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    Text(
                      "MOBILE",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 7.5 * scale,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      "+ FCFA",
                      style: TextStyle(
                        color: const Color(0xFF34C759),
                        fontSize: 8.5 * scale,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    // Ondes de transmission radar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildWaveDot(1, pulse),
                        SizedBox(width: 3 * scale),
                        _buildWaveDot(2, pulse),
                        SizedBox(width: 3 * scale),
                        _buildWaveDot(3, pulse),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveDot(int index, double pulse) {
    final double op = ((pulse + index * 0.3) % 1.0);
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF34C759).withValues(alpha: 0.3 + (op * 0.7)),
      ),
    );
  }

  /// 2. Flux animé de pièces d'or
  Widget _construireFluxPieces(double scale, double t) {
    return Positioned(
      left: 78 * scale,
      top: 32 * scale,
      right: 140 * scale,
      bottom: 45 * scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Pièce 1
          _buildJetonPiece(scale, (t + 0.00) % 1.0),
          // Pièce 2
          _buildJetonPiece(scale, (t + 0.33) % 1.0),
          // Pièce 3
          _buildJetonPiece(scale, (t + 0.66) % 1.0),
        ],
      ),
    );
  }

  Widget _buildJetonPiece(double scale, double progress) {
    // Courbe parabolique fluide du téléphone au portefeuille
    const double startX = 0.0;
    final double endX = 70.0 * scale;
    final double curX = startX + (endX - startX) * progress;

    // Hauteur de trajectoire en arche
    final double arcY = -math.sin(progress * math.pi) * (20.0 * scale);
    final double curY = (progress * 15.0 * scale) + arcY;

    // Échelle et rotation de la pièce
    final double coinScale = (0.7 + 0.35 * math.sin(progress * math.pi)) * scale;
    final double coinRot = progress * 4 * math.pi;
    final double opacity = math.sin(progress * math.pi).clamp(0.0, 1.0);

    return Positioned(
      left: curX,
      top: curY,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: coinRot,
          child: Transform.scale(
            scale: coinScale,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFFFFEE88),
                    Color(0xFFEEA823),
                    Color(0xFFB57408),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFFFFFAAA),
                  width: 1.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66EEA823),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  "K",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF533100),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 3. Le Portefeuille en cuir Karavan avec Billets et Carte Bancaire
  Widget _construirePortefeuilleCuir(double scale, double t, bool isDark) {
    final double w = 155 * scale;
    final double h = 115 * scale;

    return SizedBox(
      width: w,
      height: h + (24 * scale),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // A. RABAT ARRIÈRE EN CUIR BISSAP (Fond)
          Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18 * scale),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF9E4B5E), // Cuir Bissap Karavan
                  Color(0xFF752E3E),
                  Color(0xFF561A28),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFC78494).withValues(alpha: 0.5),
                width: 1.5 * scale,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  offset: Offset(4 * scale, 8 * scale),
                  blurRadius: 14 * scale,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(4 * scale),
              child: _buildSurpiqure(scale),
            ),
          ),

          // B. BILLET 10 000 FCFA (Émeraude BCEAO)
          Positioned(
            top: 2 * scale,
            right: 18 * scale,
            child: Transform.translate(
              offset: Offset(0.0, -14 * scale),
              child: Transform.rotate(
                angle: -0.05,
                alignment: Alignment.bottomLeft,
                child: _buildBillet10000(scale),
              ),
            ),
          ),

          // C. BILLET 5 000 FCFA (Ocre sahélien BCEAO)
          Positioned(
            top: 8 * scale,
            right: 28 * scale,
            child: Transform.translate(
              offset: Offset(0.0, -8 * scale),
              child: Transform.rotate(
                angle: 0.04,
                alignment: Alignment.bottomLeft,
                child: _buildBillet5000(scale),
              ),
            ),
          ),

          // D. CARTE BANCAIRE KARAVAN PLATINUM (3D VIP)
          Positioned(
            top: 14 * scale,
            left: 10 * scale,
            child: Transform.translate(
              offset: Offset(0.0, -10 * scale),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..rotateZ(-0.11)
                  ..rotateY(0.12),
                child: _buildCartePlatinum(scale),
              ),
            ),
          ),

          // E. RABAT AVANT EN CUIR (Poche avant avec fermoir doré)
          Positioned(
            bottom: 0,
            child: Container(
              width: w,
              height: h * 0.76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(18 * scale),
                  bottomRight: Radius.circular(18 * scale),
                  topLeft: Radius.circular(8 * scale),
                  topRight: Radius.circular(8 * scale),
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF883547), // Teinte riche Bissap
                    Color(0xFF6B2232),
                    Color(0xFF4C1521),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFFD694A4).withValues(alpha: 0.6),
                  width: 1.5 * scale,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    offset: Offset(0, -3 * scale),
                    blurRadius: 8 * scale,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Surpiqûre sellier
                  Padding(
                    padding: EdgeInsets.all(4 * scale),
                    child: _buildSurpiqure(scale),
                  ),

                  // Fermoir bouton pression doré au centre
                  Positioned(
                    top: 10 * scale,
                    child: Container(
                      width: 22 * scale,
                      height: 22 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [
                            Color(0xFFFFF099),
                            Color(0xFFEEA823),
                            Color(0xFF996305),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFFFFF8D0),
                          width: 1.2 * scale,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x66EEA823),
                            offset: Offset(0, 2 * scale),
                            blurRadius: 5 * scale,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 7 * scale,
                          height: 7 * scale,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF623E00),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Monogramme Karavan embossé
                  Positioned(
                    bottom: 12 * scale,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: const Color(0xFFEEA823).withValues(alpha: 0.85),
                          size: 13 * scale,
                        ),
                        SizedBox(width: 4 * scale),
                        Text(
                          "KARAVAN GARANTI",
                          style: TextStyle(
                            fontSize: 8.5 * scale,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            color: const Color(0xFFFFF0D0).withValues(alpha: 0.90),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Surpiqûre sellier décorative
  Widget _buildSurpiqure(double scale) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14 * scale),
        border: Border.all(
          color: const Color(0xFFF3C594).withValues(alpha: 0.35),
          width: 0.8 * scale,
        ),
      ),
    );
  }

  /// Billet de 10 000 FCFA
  Widget _buildBillet10000(double scale) {
    final double w = 110 * scale;
    final double h = 48 * scale;

    return Container(
      width: w,
      height: h,
      padding: EdgeInsets.symmetric(horizontal: 5 * scale, vertical: 3 * scale),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4 * scale),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E7D59), // Vert Émeraude BCEAO
            Color(0xFF1B5339),
            Color(0xFF103A26),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF62C296).withValues(alpha: 0.7),
          width: 0.8 * scale,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            offset: Offset(1 * scale, 3 * scale),
            blurRadius: 5 * scale,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "BCEAO · UEMOA",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 6 * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                "10 000",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 7.5 * scale,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Bande holographique
              Container(
                width: 14 * scale,
                height: 18 * scale,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0x99A8FFD6),
                      Color(0x99FFE88D),
                      Color(0x99A8FFD6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                "FCFA",
                style: TextStyle(
                  color: const Color(0xFFB4F3D6),
                  fontSize: 8.5 * scale,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Billet de 5 000 FCFA
  Widget _buildBillet5000(double scale) {
    final double w = 100 * scale;
    final double h = 44 * scale;

    return Container(
      width: w,
      height: h,
      padding: EdgeInsets.symmetric(horizontal: 5 * scale, vertical: 3 * scale),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4 * scale),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFD48B3B), // Ocre Sahélien BCEAO
            Color(0xFFA5631D),
            Color(0xFF703E0B),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFC588).withValues(alpha: 0.7),
          width: 0.8 * scale,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            offset: Offset(1 * scale, 3 * scale),
            blurRadius: 5 * scale,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "BCEAO",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 6 * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                "5 000",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 7.5 * scale,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              "FCFA",
              style: TextStyle(
                color: const Color(0xFFFFE0BA),
                fontSize: 8 * scale,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Carte Bancaire Karavan Platinum VIP
  Widget _buildCartePlatinum(double scale) {
    final double w = 115 * scale;
    final double h = 68 * scale;

    return Container(
      width: w,
      height: h,
      padding: EdgeInsets.all(6 * scale),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7 * scale),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2B333E), // Platinum métallisé
            Color(0xFF181E25),
            Color(0xFF0F1216),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF869AB2).withValues(alpha: 0.7),
          width: 1.0 * scale,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            offset: Offset(3 * scale, 6 * scale),
            blurRadius: 9 * scale,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // En-tête : Puce EMV & NFC
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Puce EMV dorée
              Container(
                width: 14 * scale,
                height: 11 * scale,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFDF6D),
                      Color(0xFFD6941C),
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 7 * scale,
                    height: 5 * scale,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF6B4500), width: 0.5),
                    ),
                  ),
                ),
              ),
              // Symbole NFC
              Icon(
                Icons.contactless_rounded,
                color: Colors.white70,
                size: 13 * scale,
              ),
            ],
          ),

          // Marque
          Row(
            children: [
              Text(
                "KARAVAN",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 7.5 * scale,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(width: 4 * scale),
              Text(
                "PLATINUM",
                style: TextStyle(
                  color: const Color(0xFFEEA823),
                  fontSize: 6 * scale,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          // Numéro masqué & Pastilles réseau
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "•••• 8420",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 7 * scale,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
              // Cercles entrelacés (style réseau bancaire)
              Row(
                children: [
                  Container(
                    width: 9 * scale,
                    height: 9 * scale,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFEB001B),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(-3 * scale, 0),
                    child: Container(
                      width: 9 * scale,
                      height: 9 * scale,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFF79E1B),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
