import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show Distance, LatLng;
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/itineraire_service.dart';
import '../services/navigation_live.dart';
import '../theme/app_theme.dart';
import '../services/boussole_service.dart';
import 'itineraire_depot_widgets.dart';
import 'recherche_lieu_sheet.dart';

/// Ouvre, dans un cadre au-dessus de l'écran courant, la carte du dépôt avec navigation en direct
/// depuis la position du commerçant — sans quitter l'application.
Future<void> afficherItineraireDepot(
  BuildContext context, {
  required String nomDepot,
  String? adresse,
  String? lienGoogleMaps,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.92,
      child: ItineraireDepot(
          nomDepot: nomDepot, adresse: adresse, lienGoogleMaps: lienGoogleMaps),
    ),
  );
}

class ItineraireDepot extends StatefulWidget {
  final String nomDepot;
  final String? adresse;
  final String? lienGoogleMaps;

  const ItineraireDepot(
      {super.key, required this.nomDepot, this.adresse, this.lienGoogleMaps});

  @override
  State<ItineraireDepot> createState() => _ItineraireDepotState();
}

/// Déroulé : dépôt localisé → autorisation de la position → point de départ révélé →
/// calcul du chemin → aperçu du trajet avec choix du mode → navigation GPS en direct avec boussole.
enum _Etape {
  depot,
  introuvable,
  autorisation,
  depotSeul,
  recherche,
  refusee,
  indisponible,
  calcul,
  apercu,
  guidage
}

class _ItineraireDepotState extends State<ItineraireDepot>
    with TickerProviderStateMixin {
  static const _bleu = AppTheme.bissap;
  static const _bleuFonce = AppTheme.bissapProfond;
  static const _vert = AppTheme.oliveProfond;
  static const _encre = AppTheme.terre;
  static const _zoomGuidage = 17.5;

  /// Place laissée à l'en-tête, au panneau du bas et à l'étiquette du dépôt lors du cadrage du trajet.
  static const _marges = EdgeInsets.fromLTRB(72, 150, 72, 300);

  final _carte = MapController();
  final _cleEntete = GlobalKey();
  final _clePanneau = GlobalKey();
  late final AnimationController _vol;
  late final AnimationController _pulsation;

  bool _carteprete = false;
  _Etape _etape = _Etape.depot;
  bool _refusDefinitif = false;
  LatLng? _depot;
  LatLng? _moi;
  double? _precision;
  String? _adresseDepart;
  ModeTrajet _mode = ModeTrajet.voiture;
  Itineraire? _itineraire;
  List<double> _cumuls = const [];
  List<double> _cumulsEtapes = const [];
  double _distanceParcourue = 0;
  double _cap = 0;
  double _rotationCarte = 0;
  bool _orientationBoussole = true;
  int _prochaineEtapeIndex = 0;
  double _distanceProchaineEtape = 0;
  bool _recalcul = false;
  bool _suivi = true;
  bool _etapesOuvertes = false;
  ResultatLieu? _lieuRecherche;
  StreamSubscription<Position>? _flux;
  StreamSubscription? _fluxBoussole;

  // Navigation en direct
  SuiviNavigation? _nav;
  late final AnimationController _glisse;
  void Function(double t)? _glisseEtape;

  /// Position et cap affichés (glissent d'une position GPS à la suivante).
  LatLng? _affiche;
  double _capAffiche = 0;
  double? _capBoussole;
  double _vitesse = 0;
  DateTime? _dernierFix;
  int _segmentCourant = 0;
  double _restantMetres = 0;
  double _restantSecondes = 0;

  /// Ce qu'il restait sur le chemin au dernier point où le commerçant le suivait (base de comparaison).
  double _restantSurRouteMetres = 0;
  double _restantSurRouteSecondes = 0;
  bool _horsRoute = false;
  _AvisTrajet? _avis;
  Timer? _avisMinuteur;
  Timer? _verifCheminRapide;

  /// Incrémentée à chaque nouvelle session pour annuler les calculs asynchrones obsolètes.
  int _session = 0;

  @override
  void initState() {
    super.initState();
    _vol = AnimationController(vsync: this);
    _glisse = AnimationController(vsync: this)..addListener(_surGlisse);
    _pulsation = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
    _demarrer();
  }

  @override
  void dispose() {
    _session++;
    _arreterSuivi();
    _verifCheminRapide?.cancel();
    _avisMinuteur?.cancel();
    if (_etape == _Etape.guidage) WakelockPlus.disable().catchError((_) {});
    _glisse.dispose();
    _vol.dispose();
    _pulsation.dispose();
    _carte.dispose();
    super.dispose();
  }

  bool _actif(int session) => mounted && session == _session;

  // ------------------------------------------------------------------ déroulé

  Future<void> _demarrer() async {
    final depot = await ItineraireService.localiserDepot(
        lien: widget.lienGoogleMaps, adresse: widget.adresse);
    if (!mounted) return;
    final depotFinal = depot ?? const LatLng(12.6392, -7.9982);
    setState(() => _depot = depotFinal);
    if (await _positionDejaAutorisee()) {
      await _localiserMoi();
    } else if (mounted) {
      setState(() => _etape = _Etape.autorisation);
    }
  }

  Future<bool> _positionDejaAutorisee() async {
    try {
      final p = await Geolocator.checkPermission();
      return p == LocationPermission.whileInUse ||
          p == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  /// Demande l'autorisation (si besoin), récupère la position GPS puis la révèle sur la carte.
  Future<void> _localiserMoi() async {
    final session = ++_session;
    setState(() => _etape = _Etape.recherche);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (_actif(session)) setState(() => _etape = _Etape.indisponible);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (_actif(session)) {
          setState(() {
            _etape = _Etape.refusee;
            _refusDefinitif = permission == LocationPermission.deniedForever;
          });
        }
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: kIsWeb
            ? WebSettings(
                accuracy: LocationAccuracy.best,
                maximumAge: Duration.zero,
                timeLimit: const Duration(seconds: 20),
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 20),
              ),
      );
      if (!_actif(session)) return;
      final moi = LatLng(p.latitude, p.longitude);
      setState(() {
        _moi = moi;
        _precision = p.accuracy;
        _etape = _Etape.calcul;
      });
      ItineraireService.adresseDe(moi).then((a) {
        if (mounted && a != null) setState(() => _adresseDepart = a);
      });
      final calcul = _calculer(session);
      await _voler(moi, 16.0, duree: const Duration(milliseconds: 1000));
      if (!_actif(session)) return;
      await calcul;
      if (_actif(session) && _itineraire != null) {
        setState(() {
          _etape = _Etape.apercu;
          _distanceParcourue = 0;
          _etapeDepuisParcouru(0);
        });
        await _volerVers(_itineraire!.points,
            duree: const Duration(milliseconds: 900));
      }
    } catch (_) {
      if (_actif(session)) setState(() => _etape = _Etape.indisponible);
    }
  }

  Future<void> _calculer(int session) async {
    final moi = _moi;
    final depot = _depot;
    if (moi == null || depot == null) return;
    final it = await ItineraireService.calculer(moi, depot, _mode);
    if (!_actif(session)) return;
    final cumuls = ItineraireService.cumuls(it.points);
    final cumulsEtapes = ItineraireService.cumulsEtapes(it, cumuls);
    setState(() {
      _itineraire = it;
      _cumuls = cumuls;
      _cumulsEtapes = cumulsEtapes;
    });
  }

  // ------------------------------------------------------------------ NAVIGATION EN DIRECT

  /// Lance la navigation GPS en temps réel : la carte suit le commerçant, tourne avec lui
  /// (cap GPS en roulant, boussole à l'arrêt), le chemin est recalculé s'il en sort et un chemin
  /// plus rapide est recherché régulièrement.
  void _demarrerNavigation() {
    _session++;
    _vol.stop();
    final it = _itineraire;
    if (it == null) return;
    final nav = SuiviNavigation(it);
    _nav = nav;
    final depart = _moi;
    double capInitial = _cap;
    if (depart != null && it.points.length >= 2) {
      capInitial = ItineraireService.cap(depart, it.points[1]);
    }
    setState(() {
      _etape = _Etape.guidage;
      _suivi = true;
      _orientationBoussole = true;
      _cap = capInitial;
      _capAffiche = capInitial;
      _affiche = depart;
      _cumuls = nav.cumuls;
      _cumulsEtapes = ItineraireService.cumulsEtapes(it, nav.cumuls);
      _restantMetres = nav.longueur;
      _restantSecondes = it.dureeSecondes;
      _restantSurRouteMetres = nav.longueur;
      _restantSurRouteSecondes = it.dureeSecondes;
      _distanceParcourue = 0;
      _segmentCourant = 0;
      _horsRoute = false;
      _avis = null;
      _etapeDepuisParcouru(0);
    });
    _demarrerSuiviLive();
    WakelockPlus.enable().catchError((_) {});
    _verifCheminRapide?.cancel();
    _verifCheminRapide = Timer.periodic(
        const Duration(seconds: 45), (_) => _chercherCheminPlusRapide());
    if (depart != null) _appliquerCamera(depart, capInitial, immediat: true);
  }

  /// Arrête la navigation en direct et revient à la vue d'ensemble du parcours.
  void _arreterGuidage() {
    _session++;
    _vol.stop();
    _glisse.stop();
    _arreterSuivi();
    _verifCheminRapide?.cancel();
    _avisMinuteur?.cancel();
    WakelockPlus.disable().catchError((_) {});
    setState(() {
      _etape = _Etape.apercu;
      _orientationBoussole = false;
      _rotationCarte = 0;
      _avis = null;
      _affiche = _moi;
    });
    if (_carteprete) _carte.rotate(0);
    if (_itineraire != null && _itineraire!.points.isNotEmpty) {
      _volerVers(_itineraire!.points, duree: const Duration(milliseconds: 700));
    }
  }

  /// Écoute en continu le GPS (1 position par seconde, précision navigation) et la boussole.
  void _demarrerSuiviLive() {
    _arreterSuivi();
    _suivi = true;
    final LocationSettings reglages;
    if (kIsWeb) {
      reglages = WebSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          maximumAge: Duration.zero);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      reglages = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      reglages = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: false,
      );
    } else {
      reglages = const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0);
    }
    _flux = Geolocator.getPositionStream(locationSettings: reglages)
        .listen(_surPositionLive, onError: (_) {});
    _fluxBoussole = BoussoleService.ecouter((angle) {
      if (mounted) _surOrientationBoussole(angle);
    });
  }

  void _arreterSuivi() {
    _flux?.cancel();
    _flux = null;
    _fluxBoussole?.cancel();
    _fluxBoussole = null;
    _capBoussole = null;
    _suivi = false;
  }

  void _surPositionLive(Position p) {
    if (!mounted) return;
    final pos = LatLng(p.latitude, p.longitude);
    final instant = DateTime.now();
    final vitesse = p.speed.isNaN || p.speed < 0 ? 0.0 : p.speed;
    var cible = pos;
    double? capRoute;
    var surRoute = false;

    final nav = _nav;
    if (nav != null && _etape == _Etape.guidage) {
      final e = nav.mettreAJour(pos, precision: p.accuracy, instant: instant);
      cible = e.position;
      capRoute = e.capRoute;
      surRoute = e.surLaRoute;
      _distanceParcourue = e.parcouru;
      _segmentCourant = e.segment;
      _restantMetres = e.restantMetres;
      _restantSecondes = e.restantSecondes;
      if (e.surLaRoute) {
        _restantSurRouteMetres = e.restantMetres;
        _restantSurRouteSecondes = e.restantSecondes;
      }
      if (e.surLaRoute != !_horsRoute) {
        _horsRoute = !e.surLaRoute;
        if (_horsRoute && !_recalcul) {
          _afficherAvis(const _AvisTrajet(
            titre: "Vous quittez l'itinéraire",
            detail:
                "Continuez : Karavan recalcule le chemin si vous ne revenez pas.",
            couleur: AppTheme.ocreProfond,
            icone: Icons.alt_route_rounded,
          ));
        }
      }
      if (e.doitRecalculer && !_recalcul) {
        nav.signalerRecalcul(instant);
        _recalculerItineraireDepuis(pos);
      }
      _etapeDepuisParcouru(e.parcouru);
    }

    var cap = SuiviNavigation.capPrefere(
      capGps: p.heading,
      vitesse: vitesse,
      capBoussole: _capBoussole,
      capRoute: capRoute,
      surLaRoute: surRoute,
    );
    if (cap == null &&
        _moi != null &&
        ItineraireService.distance(_moi!, pos) >= 3) {
      cap = ItineraireService.cap(_moi!, pos);
    }
    final ecartFix = _dernierFix == null
        ? 1000
        : instant.difference(_dernierFix!).inMilliseconds;
    _dernierFix = instant;
    setState(() {
      _moi = pos;
      _precision = p.accuracy;
      _vitesse = vitesse;
      if (cap != null) _cap = (cap + 360) % 360;
    });
    _glisserVers(
        cible, _cap, Duration(milliseconds: ecartFix.clamp(250, 1200)));
  }

  /// Fait glisser la flèche (et la caméra) jusqu'à la nouvelle position au lieu de la téléporter.
  void _glisserVers(LatLng cible, double cap, Duration duree) {
    final de = _affiche ?? cible;
    final capDe = _capAffiche;
    final ecartCap = ((cap - capDe + 540) % 360) - 180;
    _glisseEtape = (t) {
      _affiche = LatLng(
        de.latitude + (cible.latitude - de.latitude) * t,
        de.longitude + (cible.longitude - de.longitude) * t,
      );
      _capAffiche = (capDe + ecartCap * t + 360) % 360;
      _appliquerCamera(_affiche!, _capAffiche);
    };
    _glisse
      ..duration = duree
      ..forward(from: 0);
  }

  void _surGlisse() {
    _glisseEtape?.call(Curves.linear.transform(_glisse.value));
    if (mounted) setState(() {});
  }

  /// Caméra de navigation : centrée en avant du commerçant (la flèche reste dans le bas de l'écran,
  /// la route à venir est visible), carte tournée dans son sens de marche, zoom selon la vitesse.
  void _appliquerCamera(LatLng pos, double cap, {bool immediat = false}) {
    if (!_suivi || !_carteprete || _vol.isAnimating) return;
    final cibleZoom =
        _vitesse > 12 ? 16.0 : (_vitesse > 5 ? 16.8 : _zoomGuidage);
    final zoom = immediat
        ? cibleZoom
        : _carte.camera.zoom + (cibleZoom - _carte.camera.zoom) * 0.08;
    if (_orientationBoussole && _etape == _Etape.guidage) {
      // La flèche est placée aux 3/4 bas de la zone de carte réellement visible (entre l'en-tête et
      // le panneau, dont la hauteur varie avec les bandeaux) : la route à venir occupe le reste.
      final h = _carte.camera.nonRotatedSize.height;
      final haut = _hauteur(_cleEntete) ?? 90;
      final bas = _hauteur(_clePanneau) ?? 260;
      final decalagePx = haut + (h - bas - haut) * 0.75 - h / 2;
      final metresParPixel = 156543.03392 *
          math.cos(pos.latitude * math.pi / 180) /
          math.pow(2, zoom);
      final avance = decalagePx * metresParPixel;
      final centre = const Distance()
          .offset(pos, avance.abs(), avance >= 0 ? cap : (cap + 180) % 360);
      _carte.moveAndRotate(centre, zoom, -cap);
      _rotationCarte = -cap;
    } else {
      _carte.move(pos, zoom);
    }
  }

  static double? _hauteur(GlobalKey cle) {
    final boite = cle.currentContext?.findRenderObject();
    return boite is RenderBox && boite.hasSize ? boite.size.height : null;
  }

  Future<void> _recalculerItineraireDepuis(LatLng pos) async {
    final depot = _depot;
    if (depot == null || _recalcul) return;
    final ancienSecondes = _restantSurRouteSecondes;
    final ancienMetres = _restantSurRouteMetres;
    setState(() => _recalcul = true);
    _afficherAvis(const _AvisTrajet(
      titre: "Nouvel itinéraire en cours de calcul…",
      couleur: _bleu,
      icone: Icons.sync_rounded,
    ));
    try {
      final it = await ItineraireService.calculer(pos, depot, _mode);
      if (!mounted || _etape != _Etape.guidage) return;
      _adopterItineraire(it);
      if (!it.routier) {
        _afficherAvis(const _AvisTrajet(
          titre: "Itinéraire routier indisponible",
          detail: "Suivez la direction du dépôt indiquée par la ligne.",
          couleur: AppTheme.terreDouce,
          icone: Icons.signal_wifi_bad_rounded,
        ));
        return;
      }
      final cmp = SuiviNavigation.comparer(
          ancienRestantSecondes: ancienSecondes,
          ancienRestantMetres: ancienMetres,
          nouveau: it);
      _afficherAvis(_AvisTrajet(
        titre: "Itinéraire recalculé · ${cmp.libelle}",
        detail: "${ItineraireService.formaterDuree(it.dureeSecondes)} · "
            "${ItineraireService.formaterDistance(it.distanceMetres)} jusqu'au dépôt (${cmp.detailDistance})",
        couleur: cmp.plusLong
            ? AppTheme.ocreProfond
            : (cmp.plusCourt ? _vert : _bleu),
        icone: cmp.plusLong
            ? Icons.trending_up_rounded
            : (cmp.plusCourt
                ? Icons.trending_down_rounded
                : Icons.check_circle_rounded),
      ));
    } finally {
      if (mounted) setState(() => _recalcul = false);
    }
  }

  /// Vérifie périodiquement s'il existe maintenant un chemin nettement plus rapide depuis la position.
  Future<void> _chercherCheminPlusRapide() async {
    final moi = _moi, depot = _depot;
    if (_etape != _Etape.guidage ||
        _recalcul ||
        _horsRoute ||
        moi == null ||
        depot == null) {
      return;
    }
    if (_restantMetres < 400) return;
    final ancienSecondes = _restantSecondes, ancienMetres = _restantMetres;
    final it = await ItineraireService.calculer(moi, depot, _mode);
    if (!mounted || _etape != _Etape.guidage || _recalcul || !it.routier) {
      return;
    }
    if (!SuiviNavigation.estNettementPlusRapide(
        ancienSecondes, it.dureeSecondes)) {
      return;
    }
    final cmp = SuiviNavigation.comparer(
        ancienRestantSecondes: ancienSecondes,
        ancienRestantMetres: ancienMetres,
        nouveau: it);
    _adopterItineraire(it);
    _afficherAvis(_AvisTrajet(
      titre: "Chemin plus rapide trouvé · ${cmp.libelle}",
      detail:
          "Arrivée vers ${_heureArrivee(it.dureeSecondes)} (${cmp.detailDistance})",
      couleur: _vert,
      icone: Icons.bolt_rounded,
    ));
  }

  void _adopterItineraire(Itineraire it) {
    final nav = _nav;
    if (nav == null) return;
    nav.remplacer(it);
    setState(() {
      _itineraire = it;
      _cumuls = nav.cumuls;
      _cumulsEtapes = ItineraireService.cumulsEtapes(it, nav.cumuls);
      _distanceParcourue = 0;
      _segmentCourant = 0;
      _restantMetres = nav.longueur;
      _restantSecondes = it.dureeSecondes;
      _restantSurRouteMetres = nav.longueur;
      _restantSurRouteSecondes = it.dureeSecondes;
      _horsRoute = false;
      _etapeDepuisParcouru(0);
    });
  }

  void _afficherAvis(_AvisTrajet avis) {
    _avisMinuteur?.cancel();
    setState(() => _avis = avis);
    _avisMinuteur = Timer(const Duration(seconds: 7), () {
      if (mounted) setState(() => _avis = null);
    });
  }

  String _heureArrivee(double secondes) {
    final h = DateTime.now().add(Duration(seconds: secondes.round()));
    return "${h.hour.toString().padLeft(2, '0')}h${h.minute.toString().padLeft(2, '0')}";
  }

  /// Boussole : lissée, puis appliquée directement quand c'est elle qui donne le cap (à l'arrêt, à pied).
  void _surOrientationBoussole(double angle) {
    final precedent = _capBoussole;
    _capBoussole =
        precedent == null ? angle : _interpolerAngle(precedent, angle, 0.25);
    if (_vitesse >= 2.5 || _etape != _Etape.guidage) return;
    final ecart = ((_capBoussole! - _cap + 540) % 360) - 180;
    if (ecart.abs() < 1.5) return;
    setState(() {
      _cap = _capBoussole!;
      if (!_glisse.isAnimating) _capAffiche = _cap;
    });
    if (!_glisse.isAnimating && (_affiche ?? _moi) != null) {
      _appliquerCamera(_affiche ?? _moi!, _cap);
    }
  }

  /// Prochaine manœuvre : première étape située après la distance déjà parcourue le long du tracé.
  void _etapeDepuisParcouru(double parcouru) {
    final it = _itineraire;
    if (it == null || it.etapes.isEmpty || _cumulsEtapes.isEmpty) return;
    for (var i = 0; i < _cumulsEtapes.length; i++) {
      if (_cumulsEtapes[i] > parcouru + 5) {
        _prochaineEtapeIndex = i;
        _distanceProchaineEtape = _cumulsEtapes[i] - parcouru;
        return;
      }
    }
    _prochaineEtapeIndex = it.etapes.length - 1;
    _distanceProchaineEtape = math.max(0, _restantMetres);
  }

  // ---- Simulation au clavier (tests sur PC) : passe par le même chemin qu'une vraie position GPS.

  void _simulerPosition(LatLng pos, double cap) {
    _surPositionLive(Position(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: cap,
      headingAccuracy: 5,
      speed: 3,
      speedAccuracy: 1,
    ));
  }

  /// ↑/↓ : avance/recule tout droit dans le sens de la flèche (permet de quitter le chemin).
  void _avancerLibre(double metres) {
    final moi = _moi;
    if (moi == null) return;
    final cap = metres >= 0 ? _cap : (_cap + 180) % 360;
    _simulerPosition(const Distance().offset(moi, metres.abs(), cap), _cap);
  }

  /// W/S : avance/recule en suivant le chemin.
  void _avancerSurRoute(double metres) {
    final it = _itineraire;
    if (it == null || _cumuls.isEmpty) return;
    final cible = (_distanceParcourue + metres).clamp(0.0, _cumuls.last);
    final portion =
        ItineraireService.portion(it.points, _cumuls, cible / _cumuls.last);
    final pos = portion.last;
    final cap = portion.length >= 2
        ? ItineraireService.cap(portion[portion.length - 2], pos)
        : _cap;
    _simulerPosition(pos, metres >= 0 ? cap : _cap);
  }

  /// ←/→ : fait pivoter la flèche, comme si l'on tournait sur place.
  void _pivoterManuel(double deltaDegres) {
    setState(() {
      _cap = (_cap + deltaDegres + 360) % 360;
      _capAffiche = _cap;
    });
    final pos = _affiche ?? _moi;
    if (pos != null) _appliquerCamera(pos, _cap);
  }

  static double _interpolerAngle(double de, double vers, double f) {
    final ecart = ((vers - de + 540) % 360) - 180;
    return (de + ecart * f + 360) % 360;
  }

  // ------------------------------------------------------------------ caméra et boussole

  /// Déplacement de caméra animé, avec un léger dézoom à mi-course comme sur Google Maps.
  Future<void> _voler(LatLng cible, double zoom,
      {Duration duree = const Duration(milliseconds: 900)}) async {
    if (!_carteprete || !mounted) return;
    final c0 = _carte.camera.center;
    final z0 = _carte.camera.zoom;
    final d = ItineraireService.distance(c0, cible);
    final bosse = d > 3000 ? 1.2 : (d > 800 ? 0.6 : 0.0);
    _vol.stop();
    _vol.duration = duree;
    void etape() {
      final t = Curves.easeInOutCubic.transform(_vol.value);
      _carte.move(
        LatLng(c0.latitude + (cible.latitude - c0.latitude) * t,
            c0.longitude + (cible.longitude - c0.longitude) * t),
        z0 + (zoom - z0) * t - bosse * math.sin(math.pi * t),
      );
    }

    _vol.addListener(etape);
    try {
      await _vol.forward(from: 0).orCancel;
    } on TickerCanceled {
      // Remplacé par un autre déplacement.
    } finally {
      _vol.removeListener(etape);
    }
  }

  Future<void> _volerVers(List<LatLng> points,
      {Duration duree = const Duration(milliseconds: 900)}) async {
    if (!_carteprete || points.isEmpty) {
      return;
    }
    if (points.length == 1) {
      return _voler(points.first, _zoomGuidage, duree: duree);
    }
    final cible = CameraFit.coordinates(
            coordinates: points, padding: _marges, maxZoom: 17)
        .fit(_carte.camera);
    await _voler(cible.center, cible.zoom, duree: duree);
  }

  void _recentrerSurMoi() {
    if (_moi == null || !_carteprete) return;
    _vol.stop();
    setState(() {
      _suivi = true;
      _orientationBoussole = true;
    });
    _appliquerCamera(
        _affiche ?? _moi!, _etape == _Etape.guidage ? _capAffiche : _cap,
        immediat: true);
  }

  void _reinitialiserNord() {
    setState(() {
      _orientationBoussole = false;
      _rotationCarte = 0;
    });
    if (_carteprete) {
      _carte.rotate(0);
    }
  }

  void _basculerBoussole() {
    if (_carteprete && _carte.camera.rotation.abs() > 1) {
      _reinitialiserNord();
    } else {
      setState(() {
        _orientationBoussole = !_orientationBoussole;
        if (_orientationBoussole) {
          _rotationCarte = -_cap;
          _carte.rotate(-_cap);
        } else {
          _rotationCarte = 0;
          _carte.rotate(0);
        }
      });
    }
  }

  void _changerMode(ModeTrajet mode) {
    if (_mode == mode || _moi == null) return;
    final session = ++_session;
    setState(() {
      _mode = mode;
      _recalcul = true;
    });
    _calculer(session).then((_) {
      if (_actif(session) && _itineraire != null) {
        setState(() {
          _recalcul = false;
        });
        _volerVers(_itineraire!.points,
            duree: const Duration(milliseconds: 700));
      } else if (mounted) {
        setState(() => _recalcul = false);
      }
    });
  }

  void _zoomer(double delta) {
    if (!_carteprete) return;
    final z = (_carte.camera.zoom + delta).clamp(4.0, 19.0);
    _voler(_carte.camera.center, z, duree: const Duration(milliseconds: 350));
  }

  void _cadrerTrajet() {
    final it = _itineraire;
    if (it != null && it.points.isNotEmpty) {
      _volerVers(it.points, duree: const Duration(milliseconds: 700));
    } else if (_depot != null) {
      _voler(_depot!, 15, duree: const Duration(milliseconds: 700));
    }
  }

  Future<void> _ouvrirExterne() async {
    final lien = widget.lienGoogleMaps;
    if (lien == null) return;
    await launchUrl(Uri.parse(lien), mode: LaunchMode.externalApplication)
        .catchError((_) => false);
  }

  Future<void> _ouvrirRechercheLieu() async {
    final resultat = await showModalBottomSheet<ResultatLieu>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: RechercheLieuSheet(aProximiteDe: _moi ?? _depot),
      ),
    );

    if (resultat != null && mounted) {
      setState(() {
        _lieuRecherche = resultat;
      });
      await _voler(resultat.position, 16.5,
          duree: const Duration(milliseconds: 800));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Lieu localisé : ${resultat.nom}"),
          backgroundColor: _encre,
          action: SnackBarAction(
            label: "Partir d'ici",
            textColor: AppTheme.ocre,
            onPressed: () {
              setState(() {
                _moi = resultat.position;
                _adresseDepart = resultat.nom;
                _recalcul = true;
              });
              final session = ++_session;
              _calculer(session).then((_) {
                if (_actif(session) && _itineraire != null) {
                  setState(() => _recalcul = false);
                  _volerVers(_itineraire!.points,
                      duree: const Duration(milliseconds: 700));
                } else if (mounted) {
                  setState(() => _recalcul = false);
                }
              });
            },
          ),
        ),
      );
    }
  }

  // ------------------------------------------------------------------ rendu

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && _etape == _Etape.guidage) {
          // Simulation sur PC : ↑/↓ tout droit dans le sens de la flèche (pour sortir du chemin
          // et voir le recalcul), W/S (ou Z) en suivant le chemin, ←/→ pour tourner.
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _avancerLibre(10);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _avancerLibre(-10);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.keyW ||
              event.logicalKey == LogicalKeyboardKey.keyZ) {
            _avancerSurRoute(10);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.keyS) {
            _avancerSurRoute(-10);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.keyA ||
              event.logicalKey == LogicalKeyboardKey.keyQ) {
            _pivoterManuel(-15.0);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.keyD) {
            _pivoterManuel(15.0);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.space) {
            _recentrerSurMoi();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Material(
          color: AppTheme.background,
          child: Stack(
            children: [
              Positioned.fill(child: _corps()),
              Positioned(top: 0, left: 0, right: 0, child: _entete()),
              if (_depot != null)
                Positioned(left: 0, right: 0, bottom: 0, child: _panneau()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _corps() {
    if (_etape == _Etape.depot) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.olive));
    }
    if (_etape == _Etape.introuvable) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 120, 32, 32),
        child: Column(
          children: [
            const Icon(Icons.wrong_location_rounded,
                size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            const Text("Localisation du dépôt indisponible",
                style: TextStyle(
                    fontFamily: AppTheme.policeTitre,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: _encre)),
            const SizedBox(height: 6),
            Text(
              widget.adresse ??
                  "Le lien de localisation fourni par l'administrateur n'a pas pu être lu.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            if (widget.lienGoogleMaps != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _ouvrirExterne,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text("Ouvrir la position"),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final depot = _depot!;
    final it = _itineraire;
    final enGuidage = _etape == _Etape.guidage;
    final pointille = it != null && !it.routier;
    final motif = pointille
        ? StrokePattern.dashed(segments: const [12, 8])
        : const StrokePattern.solid();

    // En navigation, le tracé est coupé à la position calée sur la route : partie parcourue en gris,
    // reste du chemin en bleu (hors du chemin, on garde tout le tracé en bleu).
    final ici = _affiche ?? _moi;
    final pointsRestants = <LatLng>[];
    final pointsParcourus = <LatLng>[];
    if (it != null && it.points.isNotEmpty) {
      final seg = _segmentCourant.clamp(0, it.points.length - 1);
      if (ici != null && enGuidage && !_horsRoute) {
        pointsParcourus
          ..addAll(it.points.sublist(0, seg + 1))
          ..add(ici);
        pointsRestants
          ..add(ici)
          ..addAll(it.points.sublist(math.min(seg + 1, it.points.length)));
      } else {
        pointsRestants.addAll(it.points);
      }
    }

    return FlutterMap(
      mapController: _carte,
      options: MapOptions(
        initialCenter: depot,
        initialZoom: 15,
        minZoom: 4,
        maxZoom: 19,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        onMapReady: () => _carteprete = true,
        onPositionChanged: (pos, geste) {
          if (geste && _suivi) {
            setState(() => _suivi = false);
          }
          if (_carteprete &&
              (_rotationCarte - _carte.camera.rotation).abs() > 0.5) {
            setState(() => _rotationCarte = _carte.camera.rotation);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.karavan_app',
        ),
        if (it != null)
          PolylineLayer(polylines: [
            // Tracé complet en fond semi-transparent
            Polyline(
                points: it.points,
                strokeWidth: 6,
                color: _bleu.withValues(alpha: 0.28),
                pattern: motif),
            if (pointsParcourus.length > 1)
              Polyline(
                  points: pointsParcourus,
                  strokeWidth: 7,
                  color: AppTheme.textePale,
                  pattern: motif),
            // Tracé actif restant en bleu vif
            if (pointsRestants.length > 1)
              Polyline(
                points: pointsRestants,
                strokeWidth: 8,
                color: _bleu,
                borderStrokeWidth: 2.5,
                borderColor: _bleuFonce,
                pattern: motif,
              ),
          ]),
        if (_moi != null &&
            _precision != null &&
            _precision! > 15 &&
            !enGuidage)
          CircleLayer(circles: [
            CircleMarker(
              point: _moi!,
              radius: _precision!,
              useRadiusInMeter: true,
              color: _bleu.withValues(alpha: 0.10),
              borderColor: _bleu.withValues(alpha: 0.25),
              borderStrokeWidth: 1,
            ),
          ]),
        MarkerLayer(markers: [
          Marker(
            point: depot,
            width: 120,
            height: 86,
            alignment: Alignment.topCenter,
            rotate: true,
            child: EpingleDepot(
                arrivee: _etape == _Etape.apercu, nom: widget.nomDepot),
          ),
          if (ici != null)
            Marker(
              point: ici,
              width: 56,
              height: 56,
              // Contre-rotation : la flèche est dessinée par rapport à l'écran (cap + rotation de la carte).
              rotate: true,
              child: enGuidage || _suivi
                  ? FlecheGps(
                      cap: enGuidage ? _capAffiche : _cap,
                      rotationCarte: _rotationCarte)
                  : PointDepart(pulsation: _pulsation, libelle: "Départ"),
            ),
          if (_lieuRecherche != null)
            Marker(
              point: _lieuRecherche!.position,
              width: 140,
              height: 70,
              alignment: Alignment.topCenter,
              child: EpingleLieuRecherche(nom: _lieuRecherche!.nom),
            ),
        ]),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          showFlutterMapAttribution: false,
          attributions: [
            TextSourceAttribution('© les contributeurs OpenStreetMap')
          ],
        ),
      ],
    );
  }

  Widget _entete() {
    return Container(
      key: _cleEntete,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x142C241E), blurRadius: 12, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
                color: AppTheme.bordureForte,
                borderRadius: BorderRadius.circular(2)),
          ),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                    color: AppTheme.primary, shape: BoxShape.circle),
                child: const Icon(Icons.warehouse_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.nomDepot,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _encre)),
                    if (widget.adresse != null && widget.adresse!.isNotEmpty)
                      Text(widget.adresse!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: "Rechercher un lieu",
                icon: const Icon(Icons.search_rounded, color: _encre),
                onPressed: _ouvrirRechercheLieu,
              ),
              IconButton(
                tooltip: "Fermer",
                icon: const Icon(Icons.close_rounded, color: _encre),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _panneau() {
    final afficherControlesCarte = _etape == _Etape.apercu ||
        _etape == _Etape.guidage ||
        _etape == _Etape.depotSeul;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (afficherControlesCarte)
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 12),
            child: Column(
              children: [
                BoutonBoussole(
                  rotation: _rotationCarte,
                  modeSuiviOrientation: _orientationBoussole,
                  onTap: _basculerBoussole,
                ),
                const SizedBox(height: 8),
                BoutonRond(
                  icone: _suivi
                      ? Icons.navigation_rounded
                      : Icons.my_location_rounded,
                  aide:
                      _suivi ? "Suivi GPS actif" : "Recentrer sur ma position",
                  actif: _suivi,
                  onTap: _recentrerSurMoi,
                ),
                const SizedBox(height: 8),
                BoutonRond(
                    icone: Icons.add_rounded,
                    aide: "Zoomer",
                    onTap: () => _zoomer(1)),
                const SizedBox(height: 8),
                BoutonRond(
                    icone: Icons.remove_rounded,
                    aide: "Dézoomer",
                    onTap: () => _zoomer(-1)),
                const SizedBox(height: 8),
                BoutonRond(
                    icone: Icons.fit_screen_rounded,
                    aide: "Cadrer tout le trajet",
                    onTap: _cadrerTrajet),
              ],
            ),
          ),
        Container(
          key: _clePanneau,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                  color: Color(0x1F2C241E),
                  blurRadius: 18,
                  offset: Offset(0, -4))
            ],
          ),
          child: SafeArea(
            top: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (enfant, anim) => FadeTransition(
                opacity: anim,
                child: SizeTransition(
                    sizeFactor: anim,
                    alignment: Alignment.topCenter,
                    child: enfant),
              ),
              child:
                  KeyedSubtree(key: ValueKey(_etape), child: _contenuPanneau()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _contenuPanneau() {
    switch (_etape) {
      case _Etape.autorisation:
        return _demandeAutorisation();
      case _Etape.depotSeul:
        return _message(
          icone: Icons.location_on_rounded,
          texte:
              "Le dépôt est indiqué sur la carte. Autorisez votre position pour voir le chemin depuis l'endroit où vous êtes.",
          bouton: "Afficher le chemin depuis ma position",
          action: _localiserMoi,
        );
      case _Etape.recherche:
        return _attente(
          titre: "Recherche de votre position GPS…",
          sousTitre: "Votre point de départ va apparaître sur la carte.",
        );
      case _Etape.refusee:
        return _message(
          icone: Icons.location_disabled_rounded,
          texte: _refusDefinitif
              ? (kIsWeb
                  ? "La localisation est bloquée pour Karavan. Autorisez-la dans les réglages du navigateur (icône à gauche de l'adresse), puis réessayez."
                  : "La localisation est bloquée pour Karavan. Autorisez-la dans les paramètres de l'application, puis réessayez.")
              : "Sans votre position, Karavan ne peut pas tracer le chemin jusqu'au dépôt.",
          bouton: "Réessayer",
          action: _localiserMoi,
          secondaire: _refusDefinitif && !kIsWeb ? "Paramètres" : null,
          actionSecondaire: Geolocator.openAppSettings,
        );
      case _Etape.indisponible:
        return _message(
          icone: Icons.gps_off_rounded,
          texte:
              "Votre position est introuvable. Activez la localisation (GPS) de votre téléphone, puis réessayez.",
          bouton: "Réessayer",
          action: _localiserMoi,
          secondaire: kIsWeb ? null : "Activer le GPS",
          actionSecondaire: Geolocator.openLocationSettings,
        );
      case _Etape.calcul:
        return _attente(
            titre: "Calcul du meilleur chemin…", sousTitre: _ligneDepart());
      case _Etape.guidage:
        return _panneauGuidage();
      case _Etape.apercu:
        return _panneauApercu();
      case _Etape.depot:
      case _Etape.introuvable:
        return const SizedBox.shrink();
    }
  }

  String _ligneDepart() =>
      "Départ : ${_adresseDepart ?? "votre position actuelle"}";

  Widget _demandeAutorisation() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconePulsee(pulsation: _pulsation, icone: Icons.my_location_rounded),
        const SizedBox(height: 14),
        const Text(
          "Où vous trouvez-vous ?",
          style: TextStyle(
              fontFamily: AppTheme.policeTitre,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _encre),
        ),
        const SizedBox(height: 6),
        Text(
          "Pour vous guider jusqu'au ${widget.nomDepot}, Karavan a besoin d'accéder à votre position. "
          "Elle sert uniquement à tracer votre chemin et n'est partagée avec personne.",
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 13, height: 1.35, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _localiserMoi,
            icon: const Icon(Icons.near_me_rounded, size: 18),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text("Activer la localisation",
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _bleu,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _etape = _Etape.depotSeul),
          child: const Text("Plus tard",
              style: TextStyle(color: AppTheme.textMuted)),
        ),
      ],
    );
  }

  Widget _attente({required String titre, required String sousTitre}) {
    return Row(
      children: [
        IconePulsee(
            pulsation: _pulsation, icone: Icons.gps_fixed_rounded, taille: 44),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _encre)),
              const SizedBox(height: 3),
              Text(sousTitre,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppTheme.textMuted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _message({
    required IconData icone,
    required String texte,
    required String bouton,
    required VoidCallback action,
    String? secondaire,
    Future<bool> Function()? actionSecondaire,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: _bleu, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(texte,
                  style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: _encre,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: action,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _bleu,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(bouton, textAlign: TextAlign.center),
              ),
            ),
            if (secondaire != null && actionSecondaire != null) ...[
              const SizedBox(width: 10),
              TextButton(onPressed: actionSecondaire, child: Text(secondaire)),
            ],
          ],
        ),
      ],
    );
  }

  /// Panneau de navigation en direct (turn-by-turn réel réagissant aux déplacements et rotations).
  Widget _panneauGuidage() {
    final it = _itineraire!;
    final distDirecteDepot = (_moi != null && _depot != null)
        ? ItineraireService.distance(_moi!, _depot!)
        : double.infinity;
    // Restant mesuré le long de la route depuis la position réelle ; temps au prorata de l'estimation
    // de l'itinéraire (recalculée à chaque changement de chemin).
    final distanceRestante = _restantMetres;
    final arrive = distDirecteDepot <= 20 || distanceRestante <= 15;
    final etapeCourante = (_prochaineEtapeIndex < it.etapes.length)
        ? it.etapes[_prochaineEtapeIndex]
        : null;
    final consigne = arrive
        ? "Vous êtes arrivé au dépôt !"
        : (etapeCourante != null
            ? etapeCourante.consigne
            : (it.routier
                ? "Continuez vers le dépôt"
                : "Dirigez-vous vers le dépôt"));
    final dans = _distanceProchaineEtape;
    final dureeSecondesRestante = _restantSecondes;
    final vitesseLibelle = "${(_vitesse * 3.6).round()} km/h";

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _avis == null
              ? const SizedBox(width: double.infinity)
              : _BandeauAvis(key: ValueKey(_avis!.titre), avis: _avis!),
        ),
        // Carte d'instruction de navigation principale
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: arrive ? AppTheme.oliveProfond : _vert,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x28000000),
                  blurRadius: 10,
                  offset: Offset(0, 3))
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  arrive ? Icons.check_circle_rounded : _iconeEtape(consigne),
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!arrive)
                      Text(
                        dans > 15
                            ? "Dans ${ItineraireService.formaterDistance(dans)}"
                            : "Maintenant",
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    Text(
                      consigne,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              if (_recalcul)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Ligne des métriques en direct : Temps restant, distance restante, vitesse et cap
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      ItineraireService.formaterDuree(dureeSecondesRestante),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _vert),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      "· ${ItineraireService.formaterDistance(distanceRestante)} · arrivée ${_heureArrivee(dureeSecondesRestante)}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _bleu.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      vitesseLibelle,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _bleu),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "· ${_formaterCap(_cap)}",
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            // Bouton pour afficher/masquer la liste des étapes
            if (it.etapes.isNotEmpty)
              TextButton.icon(
                onPressed: () =>
                    setState(() => _etapesOuvertes = !_etapesOuvertes),
                icon: Icon(
                    _etapesOuvertes
                        ? Icons.expand_more_rounded
                        : Icons.format_list_bulleted_rounded,
                    size: 18),
                label: Text(_etapesOuvertes
                    ? "Masquer"
                    : "Étapes (${it.etapes.length})"),
                style: TextButton.styleFrom(
                  foregroundColor: _bleu,
                  minimumSize: Size.zero,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        if (_etapesOuvertes) ...[
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(top: 4),
              itemCount: it.etapes.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppTheme.bordure),
              itemBuilder: (_, i) {
                final e = it.etapes[i];
                final estActuelle = i == _prochaineEtapeIndex;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_iconeEtape(e.consigne),
                      color: estActuelle ? _vert : _bleu, size: 20),
                  title: Text(
                    e.consigne,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          estActuelle ? FontWeight.w800 : FontWeight.w500,
                      color: estActuelle ? _vert : _encre,
                    ),
                  ),
                  trailing: e.distanceMetres > 0
                      ? Text(
                          ItineraireService.formaterDistance(e.distanceMetres),
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted))
                      : null,
                  onTap: () => _voler(e.position, 18),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 12),
        // Bouton Quitter la navigation
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: _arreterGuidage,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text(
              "Quitter la navigation",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.danger,
              side: const BorderSide(color: AppTheme.dangerBordure, width: 1.5),
              minimumSize: const Size(0, 46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _panneauApercu() {
    final it = _itineraire!;
    final restant = _moi != null && _depot != null
        ? ItineraireService.distance(_moi!, _depot!)
        : it.distanceMetres;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bandeau confirmant que la position GPS du commerçant est bien relevée
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: _vert.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _vert.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.my_location_rounded, size: 15, color: _vert),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Position GPS relevée${_precision != null ? ' (±${_precision!.round()} m)' : ''} — choisissez votre moyen de déplacement",
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _vert),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: _localiserMoi,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Icon(Icons.refresh_rounded, size: 16, color: _vert),
                ),
              ),
            ],
          ),
        ),
        // Choix interactif du moyen de déplacement
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoixMode(
                icone: Icons.directions_car_rounded,
                libelle: "Voiture",
                actif: _mode == ModeTrajet.voiture,
                onTap: () => _changerMode(ModeTrajet.voiture),
              ),
              const SizedBox(width: 8),
              ChoixMode(
                icone: Icons.two_wheeler_rounded,
                libelle: "Moto",
                actif: _mode == ModeTrajet.moto,
                onTap: () => _changerMode(ModeTrajet.moto),
              ),
              const SizedBox(width: 8),
              ChoixMode(
                icone: Icons.directions_walk_rounded,
                libelle: "À pied",
                actif: _mode == ModeTrajet.aPied,
                onTap: () => _changerMode(ModeTrajet.aPied),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      ItineraireService.formaterDuree(it.dureeSecondes),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: _vert),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      "(${ItineraireService.formaterDistance(it.distanceMetres)})",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            if (_recalcul)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            if (it.etapes.isNotEmpty)
              TextButton.icon(
                onPressed: () =>
                    setState(() => _etapesOuvertes = !_etapesOuvertes),
                icon: Icon(
                    _etapesOuvertes
                        ? Icons.expand_more_rounded
                        : Icons.format_list_bulleted_rounded,
                    size: 18),
                label: Text(_etapesOuvertes
                    ? "Masquer"
                    : "Étapes (${it.etapes.length})"),
                style: TextButton.styleFrom(
                  foregroundColor: _bleu,
                  minimumSize: Size.zero,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        LigneTrajet(
            depart: _adresseDepart ?? "Votre position actuelle",
            arrivee: widget.adresse ?? widget.nomDepot),
        if (!it.routier || restant < 60) ...[
          const SizedBox(height: 6),
          Text(
            restant < 60
                ? "Vous êtes au dépôt : présentez votre code de retrait."
                : "Distance à vol d'oiseau — itinéraire routier indisponible",
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
          ),
        ],
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: _etapesOuvertes
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: it.etapes.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppTheme.bordure),
                    itemBuilder: (_, i) {
                      final e = it.etapes[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(_iconeEtape(e.consigne),
                            color: _bleu, size: 20),
                        title: Text(e.consigne,
                            style:
                                const TextStyle(fontSize: 13, color: _encre)),
                        trailing: e.distanceMetres > 0
                            ? Text(
                                ItineraireService.formaterDistance(
                                    e.distanceMetres),
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textMuted))
                            : null,
                        onTap: () => _voler(e.position, 18),
                      );
                    },
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 14),
        // Bouton principal « Démarrer » déclenchant l'itinéraire en direct à la demande du commerçant
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _recalcul ? null : _demarrerNavigation,
            icon: const Icon(Icons.navigation_rounded, size: 20),
            label: const Text(
              "Démarrer l'itinéraire",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _bleu,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 50),
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  String _formaterCap(double cap) {
    final deg = (cap % 360).round();
    if (deg >= 338 || deg < 23) return "$deg° N";
    if (deg >= 23 && deg < 68) return "$deg° NE";
    if (deg >= 68 && deg < 113) return "$deg° E";
    if (deg >= 113 && deg < 158) return "$deg° SE";
    if (deg >= 158 && deg < 203) return "$deg° S";
    if (deg >= 203 && deg < 248) return "$deg° SO";
    if (deg >= 248 && deg < 293) return "$deg° O";
    return "$deg° NO";
  }

  IconData _iconeEtape(String consigne) {
    final c = consigne.toLowerCase();
    if (c.contains('gauche')) return Icons.turn_left_rounded;
    if (c.contains('droite')) return Icons.turn_right_rounded;
    if (c.contains('rond-point')) return Icons.roundabout_left_rounded;
    if (c.contains('demi-tour')) return Icons.u_turn_left_rounded;
    if (c.contains('arrivé') || c.contains('arrive')) return Icons.flag_rounded;
    return Icons.straight_rounded;
  }
}

/// Épingle du dépôt avec son nom.
/// Message temporaire de la navigation (sortie du chemin, recalcul, chemin plus rapide…).
class _AvisTrajet {
  final String titre;
  final String? detail;
  final Color couleur;
  final IconData icone;

  const _AvisTrajet(
      {required this.titre,
      this.detail,
      required this.couleur,
      required this.icone});
}

class _BandeauAvis extends StatelessWidget {
  final _AvisTrajet avis;

  const _BandeauAvis({super.key, required this.avis});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: avis.couleur.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: avis.couleur.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(avis.icone, color: avis.couleur, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(avis.titre,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: avis.couleur)),
                if (avis.detail != null)
                  Text(avis.detail!,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.terreDouce)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
