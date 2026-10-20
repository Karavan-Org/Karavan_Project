import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../commercant/commercant_main_nav.dart';
import '../courtier/courtier_main_nav.dart';
import '../grossiste/grossiste_main_nav.dart';
import '../models/role_acteur.dart';
import '../services/auth_service.dart';
import '../services/session_storage_service.dart';
import '../services/tab_storage_helper.dart';
import '../services/url_route_helper.dart';
import '../widgets/karavan_logo.dart';
import 'onboarding_screen.dart';

/// Animation officielle de lancement de Karavan.
///
/// Trois flux lumineux (le corridor, les commerçants, les grossistes) traversent
/// une carte logistique, convergent et tracent l'emblème « K » ; le nœud du groupe
/// s'allume, une onde se propage, puis le nom Karavan se révèle.
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
  Future<UtilisateurProfil?>? _restaurerSessionFuture;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );

    _restaurerSessionFuture = AuthService.instance.restaurerSession();
    _controller.forward();

    // Lors d'un rafraîchissement d'un onglet ciblé (commercant, grossiste, courtier),
    // restaurer immédiatement l'espace dès la réponse de session pour une réactivité instantanée
    final espaceImmediat = _detecterEspaceDepuisUrl();
    if (espaceImmediat != null) {
      _restaurerSessionFuture?.whenComplete(() {
        if (mounted && !_hasNavigated) {
          Future.delayed(const Duration(milliseconds: 350), _naviguerVersAccueil);
        }
      });
    }

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _naviguerVersAccueil();
      }
    });
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
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _KaravanSplashPainter.fond,
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _KaravanSplashPainter(progress: _controller.value),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// Progression locale d'une phase [debut, fin] de la timeline globale.
double _phase(double p, double debut, double fin) => ((p - debut) / (fin - debut)).clamp(0.0, 1.0);

/// Un flux lumineux : il arrive du bord de l'écran puis trace un trait de l'emblème.
class _Flux {
  final Path approche; // coordonnées écran
  final Path trait; // coordonnées de l'emblème (boîte 100 × 100)
  final Color couleur;
  final double debutApproche, finApproche, finTrait;

  const _Flux(this.approche, this.trait, this.couleur, this.debutApproche, this.finApproche, this.finTrait);
}

class _KaravanSplashPainter extends CustomPainter {
  final double progress; // 0.0 -> 1.0

  _KaravanSplashPainter({required this.progress});

  static const Color fond = Color(0xFF0D0B09);
  static const Color ivoire = Color(0xFFF7F2ED);
  static const Color sable = Color(0xFFBFAF9F);

  late double _l, _h, _taille, _cx, _cyDepart, _cyFinal;

  double get _remontee => Curves.easeInOutCubic.transform(_phase(progress, 0.62, 0.80));

  /// Centre courant de l'emblème (il remonte quand le nom apparaît).
  Offset get _centreEmbleme => Offset(_cx, ui.lerpDouble(_cyDepart, _cyFinal, _remontee)!);

  double get _echelleEmbleme => 1.0 - 0.14 * _remontee;

  Offset _versEcran(Offset pointBoite) =>
      _centreEmbleme + (pointBoite - const Offset(50, 50)) * (_taille * _echelleEmbleme / 100);

  @override
  void paint(Canvas canvas, Size size) {
    _l = size.width;
    _h = size.height;
    _taille = (size.shortestSide * 0.40).clamp(120.0, 170.0);
    _cx = _l / 2;
    _cyDepart = _h * 0.47;
    _cyFinal = _h / 2 - 54;

    _fond(canvas, size);
    _grille(canvas, size);

    final flux = _flux();
    for (final f in flux) {
      _approche(canvas, f);
    }
    _onde(canvas);
    _embleme(canvas, flux);
    for (final f in flux) {
      _teteDeTrait(canvas, f);
    }
    _marque(canvas);
  }

  // ---------------------------------------------------------------- Décor

  void _fond(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(_cx, _h * 0.42),
          size.longestSide * 0.75,
          const [Color(0xFF221C16), Color(0xFF14110E), fond],
          const [0.0, 0.45, 1.0],
        ),
    );
  }

  /// Carte logistique en pointillés, révélée depuis le centre ; l'onde du nœud l'illumine au passage.
  void _grille(Canvas canvas, Size size) {
    final apparition = Curves.easeOut.transform(_phase(progress, 0.0, 0.30));
    if (apparition <= 0) return;

    const pas = 24.0;
    const niveaux = 8;
    final seaux = List.generate(niveaux, (_) => <Offset>[]);
    final centre = Offset(_cx, _h * 0.44);
    final portee = size.longestSide * 0.55;
    final rayonOnde = _rayonOnde(0);
    final forceOnde = 1.0 - _phase(progress, 0.60, 0.92);

    final decalX = (_l % pas) / 2;
    final decalY = (_h % pas) / 2;
    for (double y = decalY; y < _h; y += pas) {
      for (double x = decalX; x < _l; x += pas) {
        final p = Offset(x, y);
        final d = (p - centre).distance;
        var a = (1.0 - d / portee).clamp(0.0, 1.0);
        a = a * a * apparition * 0.55;
        if (rayonOnde != null) {
          final ecart = (d - rayonOnde).abs();
          a += math.max(0.0, 1.0 - ecart / 34) * 0.9 * forceOnde;
        }
        final niveau = (a.clamp(0.0, 1.0) * (niveaux - 1)).round();
        if (niveau > 0) seaux[niveau].add(p);
      }
    }
    for (var n = 1; n < niveaux; n++) {
      if (seaux[n].isEmpty) continue;
      canvas.drawPoints(
        ui.PointMode.points,
        seaux[n],
        Paint()
          ..color = ivoire.withValues(alpha: 0.16 * n / (niveaux - 1))
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// Rayon de l'onde de convergence (null hors de sa durée de vie).
  double? _rayonOnde(double retard) {
    final t = _phase(progress, 0.58 + retard, 0.92);
    if (t <= 0 || t >= 1) return null;
    return 12 + Curves.easeOutCubic.transform(t) * math.max(_l, _h) * 0.7;
  }

  // ---------------------------------------------------------------- Flux

  List<_Flux> _flux() {
    // Les trajectoires visent la position de départ de l'emblème (avant sa remontée).
    Offset ancre(Offset b) => Offset(_cx, _cyDepart) + (b - const Offset(50, 50)) * (_taille / 100);
    final basFut = ancre(KaravanEmblemePainter.futBas);
    final pointeHaut = ancre(KaravanEmblemePainter.pointeHaut);
    final pointeBas = ancre(KaravanEmblemePainter.pointeBas);

    return [
      // Corridor doré : monte depuis le bas-gauche
      _Flux(
        Path()
          ..moveTo(-40, _h * 0.92)
          ..cubicTo(_l * 0.10, _h * 0.80, basFut.dx - 6, basFut.dy + _h * 0.20, basFut.dx, basFut.dy),
        KaravanEmblemePainter.cheminFut(),
        KaravanEmblemePainter.or,
        0.04, 0.34, 0.50,
      ),
      // Flux camel (commerçants) : descend depuis le haut-droit
      _Flux(
        Path()
          ..moveTo(_l + 40, _h * 0.10)
          ..cubicTo(_l * 0.95, _h * 0.20, pointeHaut.dx + 60, pointeHaut.dy - 70, pointeHaut.dx, pointeHaut.dy),
        KaravanEmblemePainter.cheminBrasHaut(),
        KaravanEmblemePainter.camel,
        0.09, 0.38, 0.54,
      ),
      // Flux vert (grossistes) : remonte depuis le bas-droit
      _Flux(
        Path()
          ..moveTo(_l + 40, _h * 0.80)
          ..cubicTo(_l * 0.90, _h * 0.74, pointeBas.dx + 60, pointeBas.dy + 64, pointeBas.dx, pointeBas.dy),
        KaravanEmblemePainter.cheminBrasBas(),
        KaravanEmblemePainter.vert,
        0.14, 0.42, 0.58,
      ),
    ];
  }

  void _approche(Canvas canvas, _Flux f) {
    final t = _phase(progress, f.debutApproche, f.finApproche);
    final effacement = 1.0 - _phase(progress, f.finApproche, f.finApproche + 0.20);
    if (t <= 0 || effacement <= 0) return;

    final metrique = f.approche.computeMetrics().first;
    final longueur = metrique.length;

    // Route en pointillés : l'itinéraire apparaît avant le passage du flux
    final routeVisible = Curves.easeOut.transform(_phase(progress, f.debutApproche - 0.02, f.debutApproche + 0.10));
    final pointilles = Path();
    for (double d = 0; d < longueur; d += 11) {
      pointilles.addPath(metrique.extractPath(d, math.min(d + 4, longueur)), Offset.zero);
    }
    canvas.drawPath(
      pointilles,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = f.couleur.withValues(alpha: 0.22 * routeVisible * effacement),
    );

    // Traînée lumineuse effilée
    final position = longueur * Curves.easeInOutCubic.transform(t);
    const traine = 150.0;
    const segments = 14;
    for (var i = 0; i < segments; i++) {
      final a = position - traine * (1 - i / segments);
      final b = position - traine * (1 - (i + 1) / segments);
      if (b <= 0) continue;
      final k = (i + 1) / segments;
      canvas.drawPath(
        metrique.extractPath(math.max(0, a), b),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 0.8 + 2.6 * k
          ..color = f.couleur.withValues(alpha: 0.85 * k * k * effacement),
      );
    }

    if (t < 1) {
      _eclat(canvas, metrique.getTangentForOffset(position)!.position, f.couleur, 1.0);
    }
  }

  void _eclat(Canvas canvas, Offset p, Color couleur, double force) {
    canvas.drawCircle(
      p,
      14,
      Paint()
        ..color = couleur.withValues(alpha: 0.55 * force)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(p, 3.2, Paint()..color = Colors.white.withValues(alpha: 0.95 * force));
  }

  /// Tête lumineuse qui accompagne le tracé de chaque trait de l'emblème.
  void _teteDeTrait(Canvas canvas, _Flux f) {
    final t = _phase(progress, f.finApproche, f.finTrait);
    if (t <= 0 || t >= 1) return;
    final tete = _versEcran(KaravanEmblemePainter.tete(f.trait, Curves.easeInOutCubic.transform(t)));
    _eclat(canvas, tete, f.couleur, 1.0 - t * 0.4);
  }

  // ---------------------------------------------------------------- Emblème

  void _onde(Canvas canvas) {
    final noeud = _versEcran(KaravanEmblemePainter.centreNoeud);

    // Éclair de convergence
    final eclair = _phase(progress, 0.56, 0.60) * (1.0 - _phase(progress, 0.60, 0.76));
    if (eclair > 0) {
      canvas.drawCircle(
        noeud,
        _taille * 0.9,
        Paint()
          ..shader = ui.Gradient.radial(noeud, _taille * 0.9, [
            KaravanEmblemePainter.or.withValues(alpha: 0.38 * eclair),
            KaravanEmblemePainter.or.withValues(alpha: 0.0),
          ]),
      );
    }

    for (final retard in const [0.0, 0.08]) {
      final rayon = _rayonOnde(retard);
      if (rayon == null) continue;
      final tr = _phase(progress, 0.58 + retard, 0.92);
      canvas.drawCircle(
        noeud,
        rayon,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = retard == 0 ? 1.6 : 1.0
          ..color = ivoire.withValues(alpha: 0.30 * (1 - tr)),
      );
    }
  }

  void _embleme(Canvas canvas, List<_Flux> flux) {
    double trace(_Flux f) => Curves.easeInOutCubic.transform(_phase(progress, f.finApproche, f.finTrait));

    final fut = trace(flux[0]);
    if (fut <= 0) return;

    // Halo : monte pendant le tracé, culmine à la convergence, puis se pose
    final halo = progress < 0.62
        ? 0.55 + 0.45 * _phase(progress, 0.50, 0.62)
        : 1.0 - 0.8 * Curves.easeOut.transform(_phase(progress, 0.62, 0.90));

    final cote = _taille * _echelleEmbleme;
    final c = _centreEmbleme;

    // Ombre portée discrète
    canvas.drawOval(
      Rect.fromCenter(center: c + Offset(0, cote * 0.58), width: cote * 0.7, height: cote * 0.10),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45 * _phase(progress, 0.50, 0.70))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.save();
    canvas.translate(c.dx - cote / 2, c.dy - cote / 2);
    KaravanEmblemePainter(
      fut: fut,
      brasHaut: trace(flux[1]),
      brasBas: trace(flux[2]),
      noeud: _phase(progress, 0.56, 0.68),
      halo: halo,
    ).paint(canvas, Size.square(cote));
    canvas.restore();
  }

  // ---------------------------------------------------------------- Nom et signature

  void _marque(Canvas canvas) {
    if (progress < 0.68) return;

    final cote = _taille * _echelleEmbleme;
    final taillePolice = (_taille * 0.22).clamp(28.0, 38.0);
    final espacement = taillePolice * 0.22;
    final hautMot = _centreEmbleme.dy + cote / 2 + 30;

    // Mise en page lettre par lettre (révélation décalée)
    const mot = 'KARAVAN';
    final lettres = [
      for (var i = 0; i < mot.length; i++)
        TextPainter(
          text: TextSpan(text: mot[i], style: _style(taillePolice, FontWeight.w800, ivoire)),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final largeur = lettres.fold<double>(0, (s, tp) => s + tp.width) + espacement * (lettres.length - 1);
    var x = _cx - largeur / 2;

    // Reflet balayant le mot une fois posé
    final balayage = _phase(progress, 0.88, 1.0);
    final xReflet = ui.lerpDouble(_cx - largeur, _cx + largeur, Curves.easeInOut.transform(balayage))!;

    for (var i = 0; i < lettres.length; i++) {
      final t = Curves.easeOutCubic.transform(_phase(progress, 0.68 + i * 0.016, 0.80 + i * 0.016));
      if (t > 0) {
        final peinture = Paint();
        if (balayage > 0 && balayage < 1) {
          peinture.shader = ui.Gradient.linear(
            Offset(xReflet - 40, 0),
            Offset(xReflet + 40, 0),
            [ivoire, Colors.white, ivoire],
            const [0.0, 0.5, 1.0],
          );
        } else {
          peinture.color = ivoire.withValues(alpha: t);
        }
        final tp = TextPainter(
          text: TextSpan(
            text: mot[i],
            style: _style(taillePolice, FontWeight.w800, null).copyWith(foreground: peinture),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x, hautMot + (1 - t) * 16));
      }
      x += lettres[i].width + espacement;
    }

    // Filet tricolore : le corridor et les deux flux réunis
    final hautFilet = hautMot + lettres.first.height + 14;
    final filet = Curves.easeOutCubic.transform(_phase(progress, 0.78, 0.90));
    if (filet > 0) {
      final demi = 22 * filet;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(_cx - demi, hautFilet, _cx + demi, hautFilet + 2.5),
          const Radius.circular(2),
        ),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(_cx - demi, 0),
            Offset(_cx + demi, 0),
            const [KaravanEmblemePainter.camel, KaravanEmblemePainter.or, KaravanEmblemePainter.vert],
            const [0.0, 0.5, 1.0],
          ),
      );
    }

    // Signature
    final signature = Curves.easeOut.transform(_phase(progress, 0.82, 0.96));
    if (signature > 0) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'ACHAT GROUPÉ INTERNATIONAL',
          style: _style(11, FontWeight.w600, sable.withValues(alpha: signature)).copyWith(letterSpacing: 3.2),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_cx - tp.width / 2, hautFilet + 16 + (1 - signature) * 6));
    }
  }

  TextStyle _style(double taille, FontWeight graisse, Color? couleur) => TextStyle(
        fontFamily: 'Inter',
        fontSize: taille,
        fontWeight: graisse,
        color: couleur,
        height: 1.0,
      );

  @override
  bool shouldRepaint(covariant _KaravanSplashPainter old) => old.progress != progress;
}
