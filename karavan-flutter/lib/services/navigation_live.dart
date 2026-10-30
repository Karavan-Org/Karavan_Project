import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'itineraire_service.dart';

/// Projection d'une position GPS sur le tracé : point le plus proche *sur la route* (pas seulement
/// sur les sommets du tracé, qui peuvent être espacés de centaines de mètres sur une ligne droite).
class ProjectionTrace {
  final LatLng point;
  final int segment;

  /// Distance parcourue le long du tracé jusqu'au point projeté (m).
  final double parcouru;

  /// Écart entre la position GPS et la route (m).
  final double ecart;

  const ProjectionTrace(this.point, this.segment, this.parcouru, this.ecart);
}

/// État de la navigation après une nouvelle position GPS.
class EtatNavigation {
  /// Position à afficher : calée sur la route quand le commerçant la suit, brute sinon.
  final LatLng position;
  final double parcouru;

  /// Segment du tracé sur lequel se trouve le commerçant (pour découper la partie déjà parcourue).
  final int segment;
  final double restantMetres;
  final double restantSecondes;
  final double ecart;
  final bool surLaRoute;

  /// Le commerçant a quitté le chemin assez longtemps pour qu'un nouvel itinéraire soit calculé.
  final bool doitRecalculer;

  /// Sens de la route au point courant (degrés, 0 = nord).
  final double capRoute;

  const EtatNavigation({
    required this.position,
    required this.parcouru,
    required this.segment,
    required this.restantMetres,
    required this.restantSecondes,
    required this.ecart,
    required this.surLaRoute,
    required this.doitRecalculer,
    required this.capRoute,
  });
}

/// Nouvel itinéraire comparé à ce qu'il restait à parcourir sur l'ancien.
class ComparaisonTrajet {
  final double deltaSecondes;
  final double deltaMetres;

  const ComparaisonTrajet(this.deltaSecondes, this.deltaMetres);

  bool get plusLong => deltaSecondes >= 30;
  bool get plusCourt => deltaSecondes <= -30;

  String get libelle {
    if (plusLong) return "Plus long de ${ItineraireService.formaterDuree(deltaSecondes)}";
    if (plusCourt) return "Plus court de ${ItineraireService.formaterDuree(-deltaSecondes)}";
    return "Durée équivalente";
  }

  String get detailDistance {
    final d = deltaMetres.abs();
    if (d < 50) return "même distance";
    return "${deltaMetres > 0 ? '+' : '−'}${ItineraireService.formaterDistance(d)}";
  }
}

/// Suivi d'une navigation en direct : calage sur la route, progression, détection de sortie
/// du chemin (avec anti-rebond pour ignorer les sauts du GPS) et délai entre deux recalculs.
class SuiviNavigation {
  static const ecartMin = 35.0;
  static const ecartMax = 80.0;

  /// Durée pendant laquelle il faut rester hors du chemin avant de recalculer.
  static const delaiHorsRoute = Duration(seconds: 3);

  /// Délai minimal entre deux recalculs (évite de bombarder le serveur d'itinéraires).
  static const pauseEntreRecalculs = Duration(seconds: 10);

  Itineraire itineraire;
  List<double> cumuls;
  int _segment = 0;
  DateTime? _horsRouteDepuis;
  int _positionsHorsRoute = 0;
  DateTime? _dernierRecalcul;

  SuiviNavigation(this.itineraire) : cumuls = ItineraireService.cumuls(itineraire.points);

  double get longueur => cumuls.isEmpty ? 0 : cumuls.last;

  /// À appeler au lancement d'un recalcul : démarre le délai avant le suivant.
  void signalerRecalcul(DateTime instant) => _dernierRecalcul = instant;

  /// Bascule sur un nouvel itinéraire (recalcul ou chemin plus rapide trouvé).
  void remplacer(Itineraire it) {
    itineraire = it;
    cumuls = ItineraireService.cumuls(it.points);
    _segment = 0;
    _horsRouteDepuis = null;
    _positionsHorsRoute = 0;
  }

  EtatNavigation mettreAJour(LatLng pos, {double precision = 10, required DateTime instant}) {
    final proj = projeter(pos, itineraire.points, cumuls, depuis: _segment);
    final seuil = (precision * 1.5).clamp(ecartMin, ecartMax);
    final horsRoute = proj.ecart > seuil;
    var recalculer = false;
    if (horsRoute) {
      _horsRouteDepuis ??= instant;
      _positionsHorsRoute++;
      final enPause = _dernierRecalcul != null && instant.difference(_dernierRecalcul!) < pauseEntreRecalculs;
      recalculer = _positionsHorsRoute >= 2 && instant.difference(_horsRouteDepuis!) >= delaiHorsRoute && !enPause;
    } else {
      _horsRouteDepuis = null;
      _positionsHorsRoute = 0;
      _segment = proj.segment;
    }
    final restant = (longueur - proj.parcouru).clamp(0.0, longueur);
    final pts = itineraire.points;
    final capRoute =
        pts.length >= 2 ? ItineraireService.cap(pts[proj.segment], pts[math.min(proj.segment + 1, pts.length - 1)]) : 0.0;
    return EtatNavigation(
      position: proj.ecart <= math.max(15, precision) ? proj.point : pos,
      parcouru: proj.parcouru,
      segment: proj.segment,
      restantMetres: restant,
      restantSecondes: longueur > 0 ? itineraire.dureeSecondes * restant / longueur : 0,
      ecart: proj.ecart,
      surLaRoute: !horsRoute,
      doitRecalculer: recalculer,
      capRoute: capRoute,
    );
  }

  /// Projette [p] sur le tracé. La recherche part du segment courant ([depuis]) pour ne pas sauter sur
  /// une portion parallèle déjà parcourue ; elle s'élargit à tout le tracé si rien n'est proche.
  static ProjectionTrace projeter(LatLng p, List<LatLng> pts, List<double> cumuls, {int depuis = 0}) {
    if (pts.isEmpty) return ProjectionTrace(p, 0, 0, 0);
    if (pts.length == 1) return ProjectionTrace(pts.first, 0, 0, ItineraireService.distance(p, pts.first));
    final kx = 111320 * math.cos(p.latitude * math.pi / 180);
    const ky = 110540.0;

    ProjectionTrace balayer(int debut, int fin) {
      ProjectionTrace? meilleur;
      for (var i = debut; i < fin; i++) {
        final a = pts[i], b = pts[i + 1];
        final ax = (a.longitude - p.longitude) * kx, ay = (a.latitude - p.latitude) * ky;
        final dx = (b.longitude - a.longitude) * kx, dy = (b.latitude - a.latitude) * ky;
        final l2 = dx * dx + dy * dy;
        final t = l2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / l2).clamp(0.0, 1.0);
        final qx = ax + t * dx, qy = ay + t * dy;
        final ecart = math.sqrt(qx * qx + qy * qy);
        if (meilleur == null || ecart < meilleur.ecart) {
          meilleur = ProjectionTrace(
            LatLng(p.latitude + qy / ky, p.longitude + qx / kx),
            i,
            cumuls[i] + t * (cumuls[i + 1] - cumuls[i]),
            ecart,
          );
        }
      }
      return meilleur!;
    }

    final debut = math.max(0, math.min(depuis, pts.length - 2) - 2);
    final fin = math.min(pts.length - 1, depuis + 40);
    var res = balayer(debut, fin);
    if (res.ecart > 50 && (debut > 0 || fin < pts.length - 1)) {
      final global = balayer(0, pts.length - 1);
      if (global.ecart < res.ecart) res = global;
    }
    return res;
  }

  static ComparaisonTrajet comparer({
    required double ancienRestantSecondes,
    required double ancienRestantMetres,
    required Itineraire nouveau,
  }) =>
      ComparaisonTrajet(nouveau.dureeSecondes - ancienRestantSecondes, nouveau.distanceMetres - ancienRestantMetres);

  /// Un autre chemin ne vaut un changement que s'il fait gagner au moins 1 min et 10 % du temps restant.
  static bool estNettementPlusRapide(double ancienSecondes, double nouveauSecondes) =>
      nouveauSecondes < ancienSecondes - math.max(60, ancienSecondes * 0.10);

  /// Cap à afficher : sens réel du déplacement quand on roule (la boussole indique alors l'orientation
  /// du téléphone, pas du véhicule), boussole à l'arrêt ou à pied, sens de la route à défaut.
  static double? capPrefere({double? capGps, double vitesse = 0, double? capBoussole, double? capRoute, bool surLaRoute = false}) {
    final gpsValide = capGps != null && !capGps.isNaN && capGps >= 0;
    if (gpsValide && vitesse >= 2.5) return capGps;
    if (capBoussole != null) return capBoussole;
    if (gpsValide && vitesse >= 0.5) return capGps;
    if (surLaRoute && capRoute != null && vitesse >= 0.5) return capRoute;
    return null;
  }
}
