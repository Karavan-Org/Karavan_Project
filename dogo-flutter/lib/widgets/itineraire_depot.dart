import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:url_launcher/url_launcher.dart';

import '../services/itineraire_service.dart';
import '../theme/app_theme.dart';

/// Ouvre, dans un cadre au-dessus de l'écran courant, la carte du dépôt avec l'itinéraire animé
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
      child: ItineraireDepot(nomDepot: nomDepot, adresse: adresse, lienGoogleMaps: lienGoogleMaps),
    ),
  );
}

class ItineraireDepot extends StatefulWidget {
  final String nomDepot;
  final String? adresse;
  final String? lienGoogleMaps;

  const ItineraireDepot({super.key, required this.nomDepot, this.adresse, this.lienGoogleMaps});

  @override
  State<ItineraireDepot> createState() => _ItineraireDepotState();
}

/// Déroulé : dépôt localisé → autorisation de la position → point de départ révélé →
/// calcul du chemin → guidage GPS animé (flèche qui parcourt le chemin) → aperçu du trajet.
enum _Etape { depot, introuvable, autorisation, depotSeul, recherche, refusee, indisponible, calcul, guidage, apercu }

class _ItineraireDepotState extends State<ItineraireDepot> with TickerProviderStateMixin {
  static const _bleu = Color(0xFF1A73E8);
  static const _bleuFonce = Color(0xFF0B57D0);
  static const _vert = Color(0xFF188038);
  static const _encre = Color(0xFF2C241E);
  static const _zoomGuidage = 16.5;
  /// Place laissée à l'en-tête, au panneau du bas et à l'étiquette du dépôt lors du cadrage du trajet.
  static const _marges = EdgeInsets.fromLTRB(72, 150, 72, 300);

  final _carte = MapController();
  late final AnimationController _guidage;
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
  List<LatLng> _dessine = const [];
  double _cap = 0;
  bool _recalcul = false;
  bool _suivi = false;
  bool _etapesOuvertes = false;
  StreamSubscription<Position>? _flux;

  /// Incrémentée à chaque nouvelle séquence (rejouer, changement de mode…) pour arrêter la précédente.
  int _session = 0;

  @override
  void initState() {
    super.initState();
    _guidage = AnimationController(vsync: this)..addListener(_surGuidage);
    _vol = AnimationController(vsync: this);
    _pulsation = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
    _demarrer();
  }

  @override
  void dispose() {
    _session++;
    _flux?.cancel();
    _guidage.dispose();
    _vol.dispose();
    _pulsation.dispose();
    super.dispose();
  }

  bool _actif(int session) => mounted && session == _session;

  // ------------------------------------------------------------------ déroulé

  Future<void> _demarrer() async {
    final depot = await ItineraireService.localiserDepot(lien: widget.lienGoogleMaps, adresse: widget.adresse);
    if (!mounted) return;
    if (depot == null) {
      setState(() => _etape = _Etape.introuvable);
      return;
    }
    setState(() => _depot = depot);
    if (await _positionDejaAutorisee()) {
      await _localiserMoi();
    } else if (mounted) {
      setState(() => _etape = _Etape.autorisation);
    }
  }

  Future<bool> _positionDejaAutorisee() async {
    try {
      final p = await Geolocator.checkPermission();
      return p == LocationPermission.whileInUse || p == LocationPermission.always;
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
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (_actif(session)) {
          setState(() {
            _etape = _Etape.refusee;
            _refusDefinitif = permission == LocationPermission.deniedForever;
          });
        }
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
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
      // Révélation du point de départ (la caméra rejoint le commerçant) pendant le calcul du chemin.
      final calcul = _calculer(session);
      await _voler(moi, _zoomGuidage, duree: const Duration(milliseconds: 1400));
      if (!_actif(session)) return;
      await Future.wait([calcul, Future.delayed(const Duration(milliseconds: 900))]);
      if (_actif(session) && _itineraire != null) await _lancerGuidage(session);
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
    setState(() {
      _itineraire = it;
      _cumuls = cumuls;
      _cumulsEtapes = ItineraireService.cumulsEtapes(it, cumuls);
    });
  }

  /// Guidage GPS animé : survol du trajet, retour au départ, puis la flèche parcourt le chemin
  /// jusqu'au dépôt, la caméra la suivant comme en navigation.
  Future<void> _lancerGuidage(int session) async {
    final it = _itineraire;
    if (it == null) return;
    _arreterSuivi();
    setState(() {
      _etape = _Etape.guidage;
      _dessine = [it.points.first];
      _cap = it.points.length > 1 ? ItineraireService.cap(it.points[0], it.points[1]) : 0;
    });
    _guidage.value = 0;
    await _volerVers(it.points, duree: const Duration(milliseconds: 1000));
    if (!_actif(session)) return;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!_actif(session)) return;
    await _voler(it.points.first, _zoomGuidage, duree: const Duration(milliseconds: 900));
    if (!_actif(session)) return;
    final secondes = (5 + it.distanceMetres / 1000).clamp(6.0, 12.0);
    _guidage.duration = Duration(milliseconds: (secondes * 1000).round());
    try {
      await _guidage.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (_actif(session)) await _terminerGuidage();
  }

  Future<void> _terminerGuidage() async {
    final it = _itineraire;
    if (it == null) return;
    _guidage.stop();
    setState(() {
      _etape = _Etape.apercu;
      _dessine = it.points;
    });
    await _volerVers(it.points, duree: const Duration(milliseconds: 1000));
  }

  void _passer() {
    _session++;
    _vol.stop();
    _terminerGuidage();
  }

  void _rejouer() {
    _lancerGuidage(++_session);
  }

  void _surGuidage() {
    final it = _itineraire;
    if (it == null || _etape != _Etape.guidage) return;
    final t = Curves.easeInOutSine.transform(_guidage.value);
    final portion = ItineraireService.portion(it.points, _cumuls, t);
    final tete = portion.last;
    if (portion.length >= 2) {
      final a = portion[portion.length - 2];
      if (ItineraireService.distance(a, tete) > 0.5) {
        _cap = _interpolerAngle(_cap, ItineraireService.cap(a, tete), 0.18);
      }
    }
    setState(() => _dessine = portion);
    if (_carteprete && !_vol.isAnimating) _carte.move(tete, _zoomGuidage);
  }

  static double _interpolerAngle(double de, double vers, double f) {
    final ecart = ((vers - de + 540) % 360) - 180;
    return de + ecart * f;
  }

  // ------------------------------------------------------------------ caméra

  /// Déplacement de caméra animé, avec un léger dézoom à mi-course comme sur Google Maps.
  Future<void> _voler(LatLng cible, double zoom, {Duration duree = const Duration(milliseconds: 900)}) async {
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
        LatLng(c0.latitude + (cible.latitude - c0.latitude) * t, c0.longitude + (cible.longitude - c0.longitude) * t),
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

  Future<void> _volerVers(List<LatLng> points, {Duration duree = const Duration(milliseconds: 900)}) async {
    if (!_carteprete || points.isEmpty) return;
    if (points.length == 1) return _voler(points.first, _zoomGuidage, duree: duree);
    final cible = CameraFit.coordinates(coordinates: points, padding: _marges, maxZoom: 17).fit(_carte.camera);
    await _voler(cible.center, cible.zoom, duree: duree);
  }

  // ------------------------------------------------------------------ suivi en direct

  void _arreterSuivi() {
    _flux?.cancel();
    _flux = null;
    _suivi = false;
  }

  void _basculerSuivi() {
    if (_suivi) {
      setState(_arreterSuivi);
      if (_itineraire != null) _volerVers(_itineraire!.points);
      return;
    }
    setState(() => _suivi = true);
    if (_moi != null) _voler(_moi!, 17);
    _flux = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((p) {
      if (!mounted) return;
      final pos = LatLng(p.latitude, p.longitude);
      setState(() {
        if (p.speed > 1 && p.heading >= 0) _cap = p.heading;
        _moi = pos;
        _precision = p.accuracy;
      });
      if (_suivi && !_vol.isAnimating) _carte.move(pos, _carte.camera.zoom);
      final it = _itineraire;
      if (it != null && it.routier && !_recalcul && ItineraireService.ecartAuTrace(pos, it.points) > 80) {
        _recalcul = true;
        final session = ++_session;
        _calculer(session).whenComplete(() {
          _recalcul = false;
          if (_actif(session) && _itineraire != null) setState(() => _dessine = _itineraire!.points);
        });
      }
    }, onError: (_) {});
  }

  void _changerMode(ModeTrajet mode) {
    if (_mode == mode || _moi == null) return;
    final session = ++_session;
    _guidage.stop();
    setState(() {
      _mode = mode;
      _etape = _Etape.calcul;
    });
    _calculer(session).then((_) {
      if (_actif(session)) _lancerGuidage(session);
    });
  }

  Future<void> _ouvrirExterne() async {
    final lien = widget.lienGoogleMaps;
    if (lien == null) return;
    await launchUrl(Uri.parse(lien), mode: LaunchMode.externalApplication).catchError((_) => false);
  }

  // ------------------------------------------------------------------ rendu

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Material(
        color: AppTheme.background,
        child: Stack(
          children: [
            Positioned.fill(child: _corps()),
            Positioned(top: 0, left: 0, right: 0, child: _entete()),
            if (_depot != null) Positioned(left: 0, right: 0, bottom: 0, child: _panneau()),
          ],
        ),
      ),
    );
  }

  Widget _corps() {
    if (_etape == _Etape.depot) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_etape == _Etape.introuvable) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 120, 32, 32),
        child: Column(
          children: [
            const Icon(Icons.wrong_location_rounded, size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            const Text("Localisation du dépôt indisponible",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _encre)),
            const SizedBox(height: 6),
            Text(
              widget.adresse ?? "Le lien de localisation fourni par l'administrateur n'a pas pu être lu.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            if (widget.lienGoogleMaps != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _ouvrirExterne,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text("Ouvrir le lien de localisation"),
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
    final motif = pointille ? StrokePattern.dashed(segments: const [12, 8]) : const StrokePattern.solid();

    return FlutterMap(
      mapController: _carte,
      options: MapOptions(
        initialCenter: depot,
        initialZoom: 15,
        minZoom: 4,
        maxZoom: 19,
        interactionOptions: InteractionOptions(
          flags: enGuidage ? InteractiveFlag.none : InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () => _carteprete = true,
        onPositionChanged: (_, geste) {
          if (geste && _suivi) setState(_arreterSuivi);
        },
      ),
      children: [
        TileLayer(
          // Tuiles OpenStreetMap (sans clé). En production à fort trafic : fournisseur dédié (MapTiler, Stadia…).
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'ml.dogo.app',
        ),
        if (it != null)
          PolylineLayer(polylines: [
            // Chemin complet en filigrane ; le tracé plein montre la partie déjà parcourue par le guidage.
            Polyline(points: it.points, strokeWidth: 7, color: _bleu.withValues(alpha: 0.22), pattern: motif),
            if (_dessine.length > 1)
              Polyline(
                points: _dessine,
                strokeWidth: 7,
                color: _bleu,
                borderStrokeWidth: 2,
                borderColor: _bleuFonce,
                pattern: motif,
              ),
          ]),
        if (_moi != null && _precision != null && _precision! > 15 && !enGuidage)
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
            child: _EpingleDepot(arrivee: _etape == _Etape.apercu, nom: widget.nomDepot),
          ),
          if (_moi != null && !_suivi)
            Marker(
              point: _moi!,
              width: 110,
              height: 80,
              child: _PointDepart(pulsation: _pulsation, libelle: "Départ"),
            ),
          if (enGuidage && _dessine.isNotEmpty)
            Marker(point: _dessine.last, width: 52, height: 52, child: _FlecheGps(cap: _cap)),
          if (_suivi && _moi != null) Marker(point: _moi!, width: 52, height: 52, child: _FlecheGps(cap: _cap)),
        ]),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          showFlutterMapAttribution: false,
          attributions: [TextSourceAttribution('© les contributeurs OpenStreetMap')],
        ),
      ],
    );
  }

  Widget _entete() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x1446321E), blurRadius: 12, offset: Offset(0, 3))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: const Color(0xFFE5DDD5), borderRadius: BorderRadius.circular(2)),
          ),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                child: const Icon(Icons.warehouse_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.nomDepot,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _encre)),
                    if (widget.adresse != null && widget.adresse!.isNotEmpty)
                      Text(widget.adresse!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
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
    final apercu = _etape == _Etape.apercu;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (apercu)
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 12),
            child: Column(
              children: [
                _BoutonRond(icone: Icons.replay_rounded, aide: "Rejouer le guidage", onTap: _rejouer),
                const SizedBox(height: 10),
                _BoutonRond(
                  icone: _suivi ? Icons.navigation_rounded : Icons.my_location_rounded,
                  aide: _suivi ? "Arrêter le suivi" : "Suivre ma position",
                  actif: _suivi,
                  onTap: _basculerSuivi,
                ),
              ],
            ),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [BoxShadow(color: Color(0x1F46321E), blurRadius: 18, offset: Offset(0, -4))],
          ),
          child: SafeArea(
            top: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (enfant, anim) => FadeTransition(
                opacity: anim,
                child: SizeTransition(sizeFactor: anim, alignment: Alignment.topCenter, child: enfant),
              ),
              child: KeyedSubtree(key: ValueKey(_etape), child: _contenuPanneau()),
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
                  ? "La localisation est bloquée pour DoGo. Autorisez-la dans les réglages du navigateur (icône à gauche de l'adresse), puis réessayez."
                  : "La localisation est bloquée pour DoGo. Autorisez-la dans les paramètres de l'application, puis réessayez.")
              : "Sans votre position, DoGo ne peut pas tracer le chemin jusqu'au dépôt.",
          bouton: "Réessayer",
          action: _localiserMoi,
          secondaire: _refusDefinitif && !kIsWeb ? "Paramètres" : null,
          actionSecondaire: Geolocator.openAppSettings,
        );
      case _Etape.indisponible:
        return _message(
          icone: Icons.gps_off_rounded,
          texte: "Votre position est introuvable. Activez la localisation (GPS) de votre téléphone, puis réessayez.",
          bouton: "Réessayer",
          action: _localiserMoi,
          secondaire: kIsWeb ? null : "Activer le GPS",
          actionSecondaire: Geolocator.openLocationSettings,
        );
      case _Etape.calcul:
        return _attente(titre: "Calcul du meilleur chemin…", sousTitre: _ligneDepart());
      case _Etape.guidage:
        return _panneauGuidage();
      case _Etape.apercu:
        return _panneauApercu();
      case _Etape.depot:
      case _Etape.introuvable:
        return const SizedBox.shrink();
    }
  }

  String _ligneDepart() => "Départ : ${_adresseDepart ?? "votre position actuelle"}";

  Widget _demandeAutorisation() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconePulsee(pulsation: _pulsation, icone: Icons.my_location_rounded),
        const SizedBox(height: 14),
        const Text(
          "Où vous trouvez-vous ?",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _encre),
        ),
        const SizedBox(height: 6),
        Text(
          "Pour vous guider jusqu'au ${widget.nomDepot}, DoGo a besoin d'accéder à votre position. "
          "Elle sert uniquement à tracer votre chemin et n'est partagée avec personne.",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, height: 1.35, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _localiserMoi,
            icon: const Icon(Icons.near_me_rounded, size: 18),
            label: const Text("Autoriser ma localisation", style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _bleu,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _etape = _Etape.depotSeul),
          child: const Text("Plus tard", style: TextStyle(color: AppTheme.textMuted)),
        ),
      ],
    );
  }

  Widget _attente({required String titre, required String sousTitre}) {
    return Row(
      children: [
        _IconePulsee(pulsation: _pulsation, icone: Icons.gps_fixed_rounded, taille: 44),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _encre)),
              const SizedBox(height: 3),
              Text(sousTitre, style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
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
                  style: const TextStyle(fontSize: 13, height: 1.35, color: _encre, fontWeight: FontWeight.w600)),
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  Widget _panneauGuidage() {
    final it = _itineraire!;
    final t = Curves.easeInOutSine.transform(_guidage.value);
    final parcouru = it.distanceMetres * t;
    var courante = -1;
    for (var i = 0; i < _cumulsEtapes.length; i++) {
      if (_cumulsEtapes[i] <= parcouru + 1) courante = i;
    }
    final suivante = courante + 1 < it.etapes.length ? courante + 1 : -1;
    final consigne = suivante >= 0
        ? it.etapes[suivante].consigne
        : (it.routier ? "Vous êtes arrivé au dépôt" : "Dirigez-vous vers le dépôt");
    final dans = suivante >= 0 ? _cumulsEtapes[suivante] - parcouru : it.distanceMetres - parcouru;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _vert, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Icon(_iconeEtape(consigne), color: Colors.white, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dans > 15 ? "Dans ${ItineraireService.formaterDistance(dans)}" : "Maintenant",
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(consigne,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: t,
            minHeight: 6,
            backgroundColor: _bleu.withValues(alpha: 0.12),
            valueColor: const AlwaysStoppedAnimation(_bleu),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                "${ItineraireService.formaterDuree(it.dureeSecondes * (1 - t))} · "
                "${ItineraireService.formaterDistance(it.distanceMetres - parcouru)} restants",
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _encre),
              ),
            ),
            TextButton.icon(
              onPressed: _passer,
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              label: const Text("Passer"),
              style: TextButton.styleFrom(foregroundColor: _bleu),
            ),
          ],
        ),
      ],
    );
  }

  Widget _panneauApercu() {
    final it = _itineraire!;
    final restant = _moi != null && _depot != null ? ItineraireService.distance(_moi!, _depot!) : it.distanceMetres;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(ItineraireService.formaterDuree(it.dureeSecondes),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _vert)),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text("(${ItineraireService.formaterDistance(it.distanceMetres)})",
                  style: const TextStyle(fontSize: 15, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            if (_recalcul) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: 6),
        _LigneTrajet(depart: _adresseDepart ?? "Votre position", arrivee: widget.adresse ?? widget.nomDepot),
        if (!it.routier || restant < 60) ...[
          const SizedBox(height: 6),
          Text(
            restant < 60
                ? "Vous êtes au dépôt : présentez votre code de retrait."
                : "Distance à vol d'oiseau — itinéraire routier indisponible",
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            _ChoixMode(
              icone: Icons.directions_car_rounded,
              libelle: "Voiture / moto",
              actif: _mode == ModeTrajet.voiture,
              onTap: () => _changerMode(ModeTrajet.voiture),
            ),
            const SizedBox(width: 8),
            _ChoixMode(
              icone: Icons.directions_walk_rounded,
              libelle: "À pied",
              actif: _mode == ModeTrajet.aPied,
              onTap: () => _changerMode(ModeTrajet.aPied),
            ),
            const Spacer(),
            if (it.etapes.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() => _etapesOuvertes = !_etapesOuvertes),
                icon: Icon(_etapesOuvertes ? Icons.expand_more_rounded : Icons.format_list_bulleted_rounded, size: 18),
                label: Text(_etapesOuvertes ? "Masquer" : "Étapes"),
                style: TextButton.styleFrom(foregroundColor: _bleu),
              ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: _etapesOuvertes
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: it.etapes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3ECE5)),
                    itemBuilder: (_, i) {
                      final e = it.etapes[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(_iconeEtape(e.consigne), color: _bleu, size: 20),
                        title: Text(e.consigne, style: const TextStyle(fontSize: 13, color: _encre)),
                        trailing: e.distanceMetres > 0
                            ? Text(ItineraireService.formaterDistance(e.distanceMetres),
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))
                            : null,
                        onTap: () => _voler(e.position, 18),
                      );
                    },
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  IconData _iconeEtape(String consigne) {
    if (consigne.contains('gauche')) return Icons.turn_left_rounded;
    if (consigne.contains('droite')) return Icons.turn_right_rounded;
    if (consigne.contains('rond-point')) return Icons.roundabout_left_rounded;
    if (consigne.contains('demi-tour')) return Icons.u_turn_left_rounded;
    if (consigne.contains('arrivé')) return Icons.flag_rounded;
    return Icons.straight_rounded;
  }
}

/// Épingle du dépôt avec son nom, qui « rebondit » quand le guidage l'atteint.
class _EpingleDepot extends StatelessWidget {
  final bool arrivee;
  final String nom;

  const _EpingleDepot({required this.arrivee, required this.nom});

  @override
  Widget build(BuildContext context) {
    // La pointe de l'épingle doit toucher exactement le point du dépôt (bas du marqueur).
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedScale(
        scale: arrivee ? 1.12 : 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Color(0x3346321E), blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Text(nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.primaryDark)),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [BoxShadow(color: Color(0x4046321E), blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: const Icon(Icons.warehouse_rounded, color: Colors.white, size: 20),
            ),
            CustomPaint(size: const Size(14, 10), painter: _PointeEpingle()),
          ],
        ),
      ),
    );
  }
}

class _PointeEpingle extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppTheme.primary);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Point bleu « vous êtes ici » avec halo pulsé et étiquette « Départ ».
class _PointDepart extends StatelessWidget {
  final Animation<double> pulsation;
  final String? libelle;

  const _PointDepart({required this.pulsation, this.libelle});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: pulsation,
          builder: (_, __) {
            final t = pulsation.value;
            return Container(
              width: 16 + 34 * t,
              height: 16 + 34 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A73E8).withValues(alpha: 0.32 * (1 - t)),
              ),
            );
          },
        ),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF1A73E8),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4)],
          ),
        ),
        if (libelle != null)
          Positioned(
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF1A73E8), borderRadius: BorderRadius.circular(6)),
              child: Text(libelle!,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }
}

/// Flèche de navigation orientée dans le sens de la marche.
class _FlecheGps extends StatelessWidget {
  final double cap;

  const _FlecheGps({required this.cap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [BoxShadow(color: const Color(0xFF1A73E8).withValues(alpha: 0.45), blurRadius: 14, spreadRadius: 2)],
      ),
      padding: const EdgeInsets.all(6),
      child: Transform.rotate(
        angle: cap * math.pi / 180,
        child: const Icon(Icons.navigation_rounded, color: Color(0xFF1A73E8), size: 34),
      ),
    );
  }
}

class _IconePulsee extends StatelessWidget {
  final Animation<double> pulsation;
  final IconData icone;
  final double taille;

  const _IconePulsee({required this.pulsation, required this.icone, this.taille = 64});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: taille * 1.4,
      height: taille * 1.4,
      child: AnimatedBuilder(
        animation: pulsation,
        builder: (_, __) {
          final t = pulsation.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: taille * (0.8 + 0.6 * t),
                height: taille * (0.8 + 0.6 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1A73E8).withValues(alpha: 0.22 * (1 - t)),
                ),
              ),
              Container(
                width: taille * 0.8,
                height: taille * 0.8,
                decoration: const BoxDecoration(color: Color(0xFFE8F0FE), shape: BoxShape.circle),
                child: Icon(icone, color: const Color(0xFF1A73E8), size: taille * 0.42),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// « Départ → Dépôt », comme le récapitulatif d'un trajet Google Maps.
class _LigneTrajet extends StatelessWidget {
  final String depart;
  final String arrivee;

  const _LigneTrajet({required this.depart, required this.arrivee});

  @override
  Widget build(BuildContext context) {
    Widget ligne(IconData icone, Color couleur, String texte) => Row(
          children: [
            Icon(icone, size: 14, color: couleur),
            const SizedBox(width: 8),
            Expanded(
              child: Text(texte,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF5A493B))),
            ),
          ],
        );
    return Column(
      children: [
        ligne(Icons.radio_button_checked_rounded, const Color(0xFF1A73E8), depart),
        const SizedBox(height: 4),
        ligne(Icons.location_on_rounded, AppTheme.primary, arrivee),
      ],
    );
  }
}

class _BoutonRond extends StatelessWidget {
  final IconData icone;
  final String aide;
  final VoidCallback onTap;
  final bool actif;

  const _BoutonRond({required this.icone, required this.aide, required this.onTap, this.actif = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: aide,
      child: Material(
        color: actif ? const Color(0xFF1A73E8) : Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: const Color(0x4046321E),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icone, color: actif ? Colors.white : const Color(0xFF1A73E8)),
          ),
        ),
      ),
    );
  }
}

class _ChoixMode extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final bool actif;
  final VoidCallback onTap;

  const _ChoixMode({required this.icone, required this.libelle, required this.actif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: actif ? const Color(0xFFE8F0FE) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: actif ? const Color(0xFF1A73E8) : const Color(0xFFE5DDD5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 16, color: actif ? const Color(0xFF1A73E8) : const Color(0xFF5A493B)),
            const SizedBox(width: 6),
            Text(libelle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: actif ? const Color(0xFF1A73E8) : const Color(0xFF5A493B),
                )),
          ],
        ),
      ),
    );
  }
}
