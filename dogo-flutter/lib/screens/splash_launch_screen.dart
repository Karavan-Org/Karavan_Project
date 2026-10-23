import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../commercant/commercant_main_nav.dart';
import '../courtier/courtier_main_nav.dart';
import '../grossiste/grossiste_main_nav.dart';
import '../models/role_acteur.dart';
import '../services/auth_service.dart';
import '../services/session_storage_service.dart';
import '../services/tab_storage_helper.dart';
import '../services/url_route_helper.dart';
import 'onboarding_screen.dart';

/// Animation officielle de lancement de Karavan, construite sur les calques du logo.
///
/// La dune se dessine en vagues de sable chaud, la silhouette nomade en émerge et tend la main ;
/// des paillettes dorées s'en élèvent et les trois étoiles éclosent avec rebond,
/// puis le nom Karavan se révèle avec un éclat doré sous les couleurs officielles du Design System.
/// Une pause de contemplation finale (~850 ms) permet de lire confortablement tous les éléments réunis.
class SplashLaunchScreen extends StatefulWidget {
  final String? routeInitiale;

  const SplashLaunchScreen({super.key, this.routeInitiale});

  @override
  State<SplashLaunchScreen> createState() => _SplashLaunchScreenState();
}

class _SplashLaunchScreenState extends State<SplashLaunchScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _hasNavigated = false;
  bool _calquesDemandes = false;
  Future<UtilisateurProfil?>? _restaurerSessionFuture;

  bool get _estEnTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  /// Durée totale ajustée à 3200 ms : animation fluide jusqu'à ~2350 ms,
  /// suivie d'un temps de pause de contemplation de ~850 ms pour bien lire tous les éléments réunis.
  static const Duration _dureeAnimation = Duration(milliseconds: 3200);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _estEnTest ? const Duration(milliseconds: 100) : _dureeAnimation,
    );

    // Restauration de session en arrière-plan pendant que l'animation joue
    _restaurerSessionFuture = AuthService.instance.restaurerSession();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _naviguerVersAccueil();
      }
    });

    if (_estEnTest) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_calquesDemandes) return;
    _calquesDemandes = true;
    for (final nom in _calques) {
      precacheImage(AssetImage('$_dossierCalques/$nom.png'), context);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _detecterEspaceDepuisUrl() {
    try {
      // 1. Détection prioritaire par l'URL propre à cet onglet (hash #/espace ou pathname /espace)
      final urlEspace = detecterEspaceUrlOnglet();
      if (urlEspace != null && urlEspace.isNotEmpty) {
        return urlEspace.toLowerCase();
      }

      // 2. Détection par la route initiale transmise par le routeur
      if (widget.routeInitiale != null && widget.routeInitiale!.isNotEmpty) {
        final r = widget.routeInitiale!.toLowerCase();
        if (r.contains('courtier')) return 'courtier';
        if (r.contains('grossiste')) return 'grossiste';
        if (r.contains('commercant')) return 'commercant';
      }

      // 3. Détection par le stockage isolé propre à cet onglet (sessionStorage web)
      final sessionOnglet = getSessionStorageItem('dogo_tab_espace');
      if (sessionOnglet != null && sessionOnglet.isNotEmpty) {
        return sessionOnglet.toLowerCase();
      }

      // 4. Détection par Uri.base (fallback)
      final fragment = Uri.base.fragment.toLowerCase();
      final path = Uri.base.path.toLowerCase();
      if (fragment.contains('courtier') || path.contains('courtier')) return 'courtier';
      if (fragment.contains('grossiste') || path.contains('grossiste')) return 'grossiste';
      if (fragment.contains('commercant') || path.contains('commercant')) return 'commercant';
    } catch (_) {}
    return null;
  }

  Future<void> _naviguerVersAccueil() async {
    if (_hasNavigated) return;
    _hasNavigated = true;

    if (_restaurerSessionFuture != null) {
      try {
        await _restaurerSessionFuture;
      } catch (_) {}
    }

    if (!mounted) return;

    // 1. Détection prioritaire par l'URL (ex: #/courtier, #/commercant, #/grossiste)
    String? espaceCible = _detecterEspaceDepuisUrl();

    // 2. Si l'URL n'a pas de fragment explicite, lire l'espace persisté lors de la navigation
    espaceCible ??= await SessionStorageService.instance.lireDernierEspace();

    if (!mounted) return;

    final profil = AuthService.instance.profilActuel;
    final bool estConnecte = AuthService.instance.estConnecte && profil != null;
    Widget destination;

    if (estConnecte) {
      // Utilisateur authentifié : respecte la session connectée et son rôle
      switch (profil.roleActeur) {
        case RoleActeur.grossiste:
          destination = const GrossisteMainNav();
          definirRouteWeb('/grossiste');
          break;
        case RoleActeur.courtier:
          destination = const CourtierMainNav();
          definirRouteWeb('/courtier');
          break;
        case RoleActeur.commercant:
          destination = const CommercantMainNav();
          definirRouteWeb('/commercant');
          break;
      }
    } else {
      // Session absente, expirée ou révoquée :
      // Écran d'accueil/onboarding adapté au rôle cible de l'onglet
      final roleCible = switch (espaceCible) {
        'grossiste' => RoleActeur.grossiste,
        'courtier' => RoleActeur.courtier,
        _ => RoleActeur.commercant,
      };
      destination = OnboardingScreen(initialRole: roleCible);
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppTheme.estSombre(context);
    final Color fond = isDark ? AppTheme.darkBackground : AppTheme.creme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: fond,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // Permet de passer l'animation au tap si l'utilisateur est pressé
            if (_controller.value > 0.25) {
              _naviguerVersAccueil();
            }
          },
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => _Scene(
                  progress: _controller.value,
                  isDark: isDark,
                ),
              ),
              // Bouton discret "Passer" apparaissant subtilement à mi-parcours
              Positioned(
                top: MediaQuery.paddingOf(context).top + 12,
                right: 18,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final double op = ((_controller.value - 0.35) / 0.18).clamp(0.0, 0.75);
                    if (op <= 0) return const SizedBox.shrink();
                    return Opacity(
                      opacity: op,
                      child: TextButton.icon(
                        onPressed: _naviguerVersAccueil,
                        icon: Text(
                          "Passer",
                          style: TextStyle(
                            fontFamily: AppTheme.police,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                          ),
                        ),
                        label: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Progression locale d'une phase [debut, fin] de la timeline globale.
double _phase(double p, double debut, double fin) => ((p - debut) / (fin - debut)).clamp(0.0, 1.0);

/// Calques du logo Karavan, tous découpés dans le cadre officiel de 799 × 575 px.
const String _dossierCalques = 'assets/images/karavan';
const List<String> _calques = ['dune', 'silhouette', 'etoile_gauche', 'etoile_droite', 'etoile_grande', 'nom'];
const Size _cadre = Size(799, 575);

// Repères dans le cadre du logo.
const Offset _main = Offset(556, 148);
const Offset _centreGrande = Offset(557, 58);
const Offset _centreGauche = Offset(513, 111);
const Offset _centreDroite = Offset(606, 99);
const double _basSilhouette = 316; // ligne d'où la silhouette émerge
const double _hautNom = 425; // au-dessus : l'emblème ; en dessous : le nom

class _Scene extends StatelessWidget {
  final double progress;
  final bool isDark;

  const _Scene({required this.progress, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final ecran = MediaQuery.sizeOf(context);
    final largeur = math.min(ecran.width * 0.82, 340.0);
    final echelle = largeur / _cadre.width;

    // L'emblème est d'abord centré seul, puis remonte avec élégance pour laisser place au nom.
    // L'élévation s'achève à 0.64 pour laisser un temps de contemplation final de 0.74 à 1.00.
    final remontee = Curves.easeInOutCubic.transform(_phase(progress, 0.48, 0.64));
    final decalageEmbleme = (1 - remontee) * (_cadre.height - _hautNom) * echelle / 2;

    // Le slogan apparaît entre 0.64 et 0.74 et reste pleinement visible jusqu'à la fin.
    final signature = Curves.easeOut.transform(_phase(progress, 0.64, 0.74));

    final Color couleurEncre = isDark ? AppTheme.darkTextPrimary : AppTheme.encre;
    final Color couleurSlogan = isDark ? AppTheme.darkPrimary : AppTheme.primaryDark;

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _HaloPainter(progress: progress, isDark: isDark),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: largeur,
                height: _cadre.height * echelle,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(0, decalageEmbleme),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _dune(),
                            _silhouette(echelle, couleurEncre),
                            _poussiereDoree(echelle),
                            _etoile('etoile_gauche', _centreGauche, 0.35),
                            _etoile('etoile_droite', _centreDroite, 0.39),
                            _etoile('etoile_grande', _centreGrande, 0.44, scintille: true),
                          ],
                        ),
                      ),
                    ),
                    _nom(couleurEncre),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Opacity(
                opacity: signature,
                child: Transform.translate(
                  offset: Offset(0, (1 - signature) * 8),
                  child: Text(
                    'ACHAT GROUPÉ INTERNATIONAL',
                    style: TextStyle(
                      fontFamily: AppTheme.police,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3.5,
                      color: couleurSlogan,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _image(String nom) =>
      Image.asset('$_dossierCalques/$nom.png', fit: BoxFit.fill, gaplessPlayback: true);

  /// Balayage gauche → droite à bord adouci, borné à la zone [x0, x1] du cadre.
  static Widget _balayage(double t, double x0, double x1, Widget child) {
    if (t >= 1) return child;
    const flou = 0.08;
    final front = (x0 / _cadre.width) + ((x1 - x0) / _cadre.width + flou) * t;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => LinearGradient(
        colors: const [Colors.white, Colors.white, Colors.transparent],
        stops: [0, (front - flou).clamp(0.0, 1.0), front.clamp(0.0, 1.0)],
      ).createShader(r),
      child: child,
    );
  }

  /// La dune (dégradé bissap → rose poudre) se dessine comme une douce vague.
  Widget _dune() {
    final t = Curves.easeInOutCubic.transform(_phase(progress, 0.02, 0.24));
    if (t <= 0) return const SizedBox.shrink();
    return Positioned.fill(
      child: Transform.translate(
        offset: Offset(0, (1 - t) * 10),
        child: _balayage(t, 185, 600, _image('dune')),
      ),
    );
  }

  /// La silhouette émerge de la dune, vêtue des couleurs de notre charte graphique.
  Widget _silhouette(double echelle, Color couleur) {
    final t = Curves.easeOutCubic.transform(_phase(progress, 0.15, 0.38));
    if (t <= 0) return const SizedBox.shrink();
    return Positioned.fill(
      child: ClipRect(
        clipper: _CoupeHaute(_basSilhouette * echelle),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 180 * echelle),
          child: Opacity(
            opacity: Curves.easeOut.transform(_phase(progress, 0.15, 0.28)),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(couleur, BlendMode.srcIn),
              child: _image('silhouette'),
            ),
          ),
        ),
      ),
    );
  }

  /// Fines paillettes dorées qui s'élèvent de la main tendue vers les étoiles.
  Widget _poussiereDoree(double echelle) {
    final t = _phase(progress, 0.28, 0.52);
    if (t <= 0 || t >= 1) return const SizedBox.shrink();
    return Positioned.fill(
      child: CustomPaint(
        painter: _PaillettesPainter(t: t, echelle: echelle, isDark: isDark),
      ),
    );
  }

  /// Une étoile éclot (rotation + rebond élastique) ; la grande scintille avec majesté.
  Widget _etoile(String nom, Offset centre, double debut, {bool scintille = false}) {
    final t = _phase(progress, debut, debut + 0.15);
    if (t <= 0) return const SizedBox.shrink();
    var taille = Curves.elasticOut.transform(t);
    if (scintille && progress > 0.58) {
      taille *= 1 + 0.08 * math.sin(_phase(progress, 0.58, 1.0) * math.pi * 3);
    }
    final pivot = Alignment(centre.dx / _cadre.width * 2 - 1, centre.dy / _cadre.height * 2 - 1);
    return Positioned.fill(
      child: Opacity(
        opacity: (t * 3).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: (1 - Curves.easeOutCubic.transform(t)) * -math.pi / 2,
          alignment: pivot,
          child: Transform.scale(scale: taille, alignment: pivot, child: _image(nom)),
        ),
      ),
    );
  }

  /// Le nom KARAVAN se révèle de gauche à droite, puis un reflet doré traverse les lettres.
  Widget _nom(Color couleur) {
    final t = Curves.easeOutCubic.transform(_phase(progress, 0.52, 0.68));
    if (t <= 0) return const SizedBox.shrink();
    final reflet = _phase(progress, 0.62, 0.74);
    return Positioned.fill(
      child: Opacity(
        opacity: Curves.easeOut.transform(_phase(progress, 0.52, 0.62)),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: _balayage(
            t,
            0,
            _cadre.width,
            Stack(
              fit: StackFit.expand,
              children: [
                ColorFiltered(
                  colorFilter: ColorFilter.mode(couleur, BlendMode.srcIn),
                  child: _image('nom'),
                ),
                if (reflet > 0 && reflet < 1)
                  ShaderMask(
                    blendMode: BlendMode.srcATop,
                    shaderCallback: (r) {
                      final x = -0.3 + 1.6 * Curves.easeInOut.transform(reflet);
                      return LinearGradient(
                        colors: [
                          AppTheme.secondary.withValues(alpha: 0),
                          AppTheme.secondary.withValues(alpha: 0.95),
                          AppTheme.primary.withValues(alpha: 0.85),
                          AppTheme.secondary.withValues(alpha: 0),
                        ],
                        stops: [
                          (x - 0.14).clamp(0.0, 1.0),
                          (x - 0.04).clamp(0.0, 1.0),
                          (x + 0.04).clamp(0.0, 1.0),
                          (x + 0.14).clamp(0.0, 1.0),
                        ],
                      ).createShader(r);
                    },
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(couleur, BlendMode.srcIn),
                      child: _image('nom'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ne garde que ce qui est au-dessus de [bas] : la silhouette sort de la dune.
class _CoupeHaute extends CustomClipper<Rect> {
  final double bas;

  _CoupeHaute(this.bas);

  @override
  Rect getClip(Size size) => Rect.fromLTRB(-size.width, -size.height, size.width * 2, bas);

  @override
  bool shouldReclip(_CoupeHaute old) => old.bas != bas;
}

/// Halo chaleureux derrière l'emblème : bissap et rose poudre (ocre en thème sombre).
class _HaloPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _HaloPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final force = 0.35 * _phase(progress, 0.0, 0.25) +
        0.65 * _phase(progress, 0.40, 0.64) * (1 - 0.20 * _phase(progress, 0.74, 1.0));
    if (force <= 0) return;
    final centre = Offset(size.width / 2, size.height * 0.44);
    final rayon = size.shortestSide * 0.75;
    final Color teinte = isDark ? AppTheme.secondary : AppTheme.primary;
    canvas.drawCircle(
      centre,
      rayon,
      Paint()
        ..shader = ui.Gradient.radial(centre, rayon, [
          teinte.withValues(alpha: (isDark ? 0.14 : 0.16) * force),
          AppTheme.tertiary.withValues(alpha: (isDark ? 0.04 : 0.07) * force),
          teinte.withValues(alpha: 0.0),
        ], [0.0, 0.55, 1.0]),
    );
  }

  @override
  bool shouldRepaint(_HaloPainter old) =>
      old.progress != progress || old.isDark != isDark;
}

/// Paillettes dorées : de la main vers les étoiles aux couleurs de notre Design System.
class _PaillettesPainter extends CustomPainter {
  final double t;
  final double echelle;
  final bool isDark;

  _PaillettesPainter({required this.t, required this.echelle, required this.isDark});

  static const _cibles = [
    _centreGauche,
    _centreDroite,
    _centreGrande,
    Offset(540, 30),
    Offset(640, 70),
    Offset(585, 120),
    Offset(500, 70),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const Color orBrillant = AppTheme.secondary;
    final Color orDoux = isDark ? AppTheme.darkPrimary : AppTheme.primary;

    for (var i = 0; i < _cibles.length; i++) {
      final local = ((t - i * 0.06) / 0.6).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;
      final e = Curves.easeOutCubic.transform(local);
      final cible = _cibles[i];
      final controle = Offset((_main.dx + cible.dx) / 2 + (i.isEven ? -18 : 18), _main.dy - 10);
      final u = 1 - e;
      final p = (_main * (u * u) + controle * (2 * u * e) + cible * (e * e)) * echelle;
      final alpha = math.sin(local * math.pi);
      final rayon = (1.6 + (i % 3) * 0.6) * echelle * 2.4;
      canvas.drawCircle(
        p,
        rayon * 2.6,
        Paint()
          ..color = orDoux.withValues(alpha: 0.35 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(p, rayon, Paint()..color = orBrillant.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(_PaillettesPainter old) =>
      old.t != t || old.echelle != echelle || old.isDark != isDark;
}
