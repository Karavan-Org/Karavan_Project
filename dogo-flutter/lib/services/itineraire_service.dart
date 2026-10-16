import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'api/api_client.dart';
import 'plus_code.dart';

/// Mode de déplacement proposé pour l'itinéraire vers le dépôt.
enum ModeTrajet { voiture, moto, aPied }

/// Une étape de l'itinéraire (« Tournez à gauche sur Avenue de l'OUA »).
class EtapeTrajet {
  final String consigne;
  final double distanceMetres;
  final LatLng position;

  const EtapeTrajet(
      {required this.consigne,
      required this.distanceMetres,
      required this.position});
}

/// Résultat d'une recherche d'adresse ou de lieu via OpenStreetMap Nominatim.
class ResultatLieu {
  final String nom;
  final String adresseComplete;
  final LatLng position;

  const ResultatLieu({
    required this.nom,
    required this.adresseComplete,
    required this.position,
  });
}

/// Itinéraire calculé entre la position du commerçant et le dépôt.
class Itineraire {
  final List<LatLng> points;
  final double distanceMetres;
  final double dureeSecondes;
  final List<EtapeTrajet> etapes;

  /// `false` quand aucun service d'itinéraire n'a répondu : tracé à vol d'oiseau.
  final bool routier;

  const Itineraire({
    required this.points,
    required this.distanceMetres,
    required this.dureeSecondes,
    required this.etapes,
    required this.routier,
  });
}

/// Localisation des dépôts et calcul d'itinéraire, entièrement dans l'application
/// (OpenStreetMap / OSRM : aucune clé d'API requise).
class ItineraireService {
  ItineraireService._();

  static const _distance = Distance();

  static const _nombre = r'(-?\d{1,3}(?:\.\d+)?)';
  static final List<RegExp> _motifs = [
    RegExp('!3d$_nombre!4d$_nombre'),
    RegExp(
        '[?&](?:q|ll|query|destination|daddr|center|sll)=(?:loc:)?\\s*$_nombre\\s*,\\s*\\+?$_nombre'),
    RegExp('@$_nombre,$_nombre'),
    RegExp('/$_nombre\\s*,\\s*\\+?$_nombre(?:[/?&]|\$)'),
  ];

  /// Lecture locale des coordonnées présentes dans un lien Google Maps (sans réseau).
  static LatLng? coordonneesDepuisLien(String? lien) {
    if (lien == null || lien.isEmpty) return null;
    String texte;
    try {
      texte = Uri.decodeFull(lien.replaceAll('+', '%2B'));
    } catch (_) {
      texte = lien;
    }
    for (final motif in _motifs) {
      for (final m in motif.allMatches(texte)) {
        final lat = double.tryParse(m.group(1)!);
        final lng = double.tryParse(m.group(2)!);
        if (lat != null &&
            lng != null &&
            lat.abs() <= 90 &&
            lng.abs() <= 180 &&
            !(lat == 0 && lng == 0)) {
          return LatLng(lat, lng);
        }
      }
    }
    return null;
  }

  /// Coordonnées du dépôt : lien lu localement, sinon résolu par le backend
  /// (lien court maps.app.goo.gl ou géocodage de l'adresse).
  static Future<LatLng?> localiserDepot({String? lien, String? adresse}) async {
    final locales = coordonneesDepuisLien(lien) ??
        PlusCode.depuisTexte(lien) ??
        PlusCode.depuisTexte(adresse);
    if (locales != null) {
      return locales;
    }
    if ((lien == null || lien.isEmpty) &&
        (adresse == null || adresse.isEmpty)) {
      return null;
    }
    try {
      final res =
          await ApiClient.instance.get('/api/localisation', queryParams: {
        if (lien != null && lien.isNotEmpty) 'lien': lien,
        if (adresse != null && adresse.isNotEmpty) 'adresse': adresse,
      });
      if (res is Map && res['latitude'] is num && res['longitude'] is num) {
        return LatLng((res['latitude'] as num).toDouble(),
            (res['longitude'] as num).toDouble());
      }
    } catch (_) {
      // Dépôt non localisable : l'écran propose l'ouverture externe en dernier recours.
    }
    return null;
  }

  /// Adresse lisible d'une position (« Avenue Cheick Zayed, Hamdallaye, Bamako »), pour présenter
  /// au commerçant le point de départ révélé par sa localisation.
  static Future<String?> adresseDe(LatLng p) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=17'
          '&accept-language=fr&lat=${p.latitude}&lon=${p.longitude}');
      // Un navigateur interdit de fixer User-Agent : il envoie déjà le sien.
      final r = await http
          .get(uri,
              headers: kIsWeb
                  ? null
                  : const {'User-Agent': 'DoGo/1.0 (achats groupes B2B Mali)'})
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return null;
      final a = (jsonDecode(r.body)['address'] as Map?) ?? const {};
      final parties = <String>{
        for (final v in [
          a['road'],
          a['neighbourhood'] ?? a['suburb'] ?? a['quarter'],
          a['city'] ?? a['town'] ?? a['village'],
        ])
          if (v is String && v.isNotEmpty) v,
      };
      return parties.isEmpty ? null : parties.join(', ');
    } catch (_) {
      return null;
    }
  }

  /// Recherche d'adresses, points d'intérêt ou quartiers via OpenStreetMap Nominatim.
  /// Gère les timeouts (5s), la limitation de débit et l'encodage réseau propre.
  static Future<List<ResultatLieu>> rechercherLieux(String requete,
      {LatLng? aProximiteDe}) async {
    final q = requete.trim();
    if (q.length < 2) return const [];
    try {
      final params = <String, String>{
        'format': 'jsonv2',
        'q': q,
        'limit': '5',
        'accept-language': 'fr',
        'addressdetails': '1',
      };
      if (aProximiteDe != null) {
        params['lat'] = aProximiteDe.latitude.toString();
        params['lon'] = aProximiteDe.longitude.toString();
      }
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);
      final r = await http
          .get(uri,
              headers: kIsWeb
                  ? null
                  : const {'User-Agent': 'DoGo/1.0 (achats groupes B2B Mali)'})
          .timeout(const Duration(seconds: 5));
      if (r.statusCode != 200) return const [];
      final list = jsonDecode(r.body);
      if (list is! List) return const [];
      final resultats = <ResultatLieu>[];
      for (final item in list) {
        if (item is Map) {
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lon = double.tryParse(item['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            final nom = item['name']?.toString() ?? '';
            final displayName = item['display_name']?.toString() ?? q;
            resultats.add(ResultatLieu(
              nom: nom.isNotEmpty ? nom : displayName.split(',').first,
              adresseComplete: displayName,
              position: LatLng(lat, lon),
            ));
          }
        }
      }
      return resultats;
    } catch (_) {
      return const [];
    }
  }

  /// Itinéraire routier via OSRM ; à défaut, ligne droite (le trajet reste affiché).
  static Future<Itineraire> calculer(
      LatLng depart, LatLng arrivee, ModeTrajet mode) async {
    final coord =
        '${depart.longitude},${depart.latitude};${arrivee.longitude},${arrivee.latitude}';
    final profil = mode == ModeTrajet.aPied ? 'routed-foot' : 'routed-car';
    final serveurs = [
      'https://routing.openstreetmap.de/$profil/route/v1/driving/$coord',
      if (mode != ModeTrajet.aPied)
        'https://router.project-osrm.org/route/v1/driving/$coord',
    ];
    for (final base in serveurs) {
      try {
        final uri =
            Uri.parse('$base?overview=full&geometries=geojson&steps=true');
        final r = await http.get(uri).timeout(const Duration(seconds: 8));
        if (r.statusCode != 200) continue;
        final json = jsonDecode(r.body);
        final routes = json['routes'];
        if (json['code'] != 'Ok' || routes is! List || routes.isEmpty) continue;
        final route = routes.first as Map<String, dynamic>;
        final coords = (route['geometry']['coordinates'] as List)
            .map((c) =>
                LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
            .toList();
        if (coords.length < 2) continue;
        final etapes = <EtapeTrajet>[];
        for (final leg in (route['legs'] as List? ?? const [])) {
          for (final s in (leg['steps'] as List? ?? const [])) {
            final man = s['maneuver'] as Map<String, dynamic>;
            final loc = man['location'] as List;
            etapes.add(EtapeTrajet(
              consigne: _consigne(man['type']?.toString(),
                  man['modifier']?.toString(), s['name']?.toString()),
              distanceMetres: (s['distance'] as num? ?? 0).toDouble(),
              position: LatLng(
                  (loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
            ));
          }
        }
        var duree = (route['duration'] as num).toDouble();
        // Le serveur de démonstration OSRM ne connaît que la voiture : on corrige la durée à pied (≈ 4,8 km/h)
        // ou en moto urbaine (≈ 20 % plus rapide dans le trafic).
        if (mode == ModeTrajet.aPied && !base.contains('routed-foot')) {
          duree = (route['distance'] as num).toDouble() / 1.33;
        } else if (mode == ModeTrajet.moto) {
          duree = duree * 0.78;
        }
        return Itineraire(
          points: [depart, ...coords, arrivee],
          distanceMetres: (route['distance'] as num).toDouble(),
          dureeSecondes: duree,
          etapes: etapes,
          routier: true,
        );
      } catch (_) {
        // Serveur suivant.
      }
    }
    final d = _distance.as(LengthUnit.Meter, depart, arrivee);
    final vitesse = switch (mode) {
      ModeTrajet.aPied => 1.33,
      ModeTrajet.moto => 10.5,
      ModeTrajet.voiture => 8.3,
    };
    return Itineraire(
      points: [depart, arrivee],
      distanceMetres: d,
      dureeSecondes: d / vitesse,
      etapes: const [],
      routier: false,
    );
  }

  /// Distances cumulées le long du tracé (pour l'animation de progression).
  static List<double> cumuls(List<LatLng> points) {
    final res = <double>[0];
    for (var i = 1; i < points.length; i++) {
      res.add(
          res.last + _distance.as(LengthUnit.Meter, points[i - 1], points[i]));
    }
    return res;
  }

  /// Portion du tracé parcourue à la fraction [t] (0 → 1) de la longueur totale.
  static List<LatLng> portion(
      List<LatLng> points, List<double> cumuls, double t) {
    if (points.length < 2 || t <= 0) return [points.first];
    if (t >= 1) return points;
    final cible = cumuls.last * t;
    var i = 1;
    while (i < cumuls.length - 1 && cumuls[i] < cible) {
      i++;
    }
    final seg = cumuls[i] - cumuls[i - 1];
    final f = seg <= 0 ? 0.0 : ((cible - cumuls[i - 1]) / seg).clamp(0.0, 1.0);
    final a = points[i - 1];
    final b = points[i];
    final tete = LatLng(a.latitude + (b.latitude - a.latitude) * f,
        a.longitude + (b.longitude - a.longitude) * f);
    return [...points.sublist(0, i), tete];
  }

  /// Distance la plus courte entre [p] et le tracé (pour recalculer si le commerçant s'en écarte).
  static double ecartAuTrace(LatLng p, List<LatLng> trace) {
    var min = double.infinity;
    for (final q in trace) {
      min = math.min(min, _distance.as(LengthUnit.Meter, p, q));
    }
    return min;
  }

  static double distance(LatLng a, LatLng b) =>
      _distance.as(LengthUnit.Meter, a, b);

  static double cap(LatLng a, LatLng b) => _distance.bearing(a, b);

  /// Distance parcourue (le long du tracé) au moment où l'on atteint chaque étape.
  static List<double> cumulsEtapes(Itineraire it, List<double> cumuls) {
    final res = <double>[];
    var debut = 0;
    for (final e in it.etapes) {
      var meilleur = debut;
      var min = double.infinity;
      for (var i = debut; i < it.points.length; i++) {
        final d = _distance.as(LengthUnit.Meter, e.position, it.points[i]);
        if (d < min) {
          min = d;
          meilleur = i;
        }
      }
      res.add(cumuls[meilleur]);
      debut = meilleur;
    }
    return res;
  }

  static String formaterDistance(double m) {
    if (m < 1000) return '${(m / 10).round() * 10} m';
    final km = m / 1000;
    return '${km < 10 ? km.toStringAsFixed(1).replaceAll('.', ',') : km.round()} km';
  }

  static String formaterDuree(double s) {
    final min = (s / 60).round();
    if (min < 1) return '< 1 min';
    if (min < 60) return '$min min';
    final h = min ~/ 60;
    final r = min % 60;
    return r == 0 ? '$h h' : '$h h ${r.toString().padLeft(2, '0')}';
  }

  static String _consigne(String? type, String? modifier, String? rue) {
    final sur = (rue != null && rue.isNotEmpty) ? ' sur $rue' : '';
    final direction = switch (modifier) {
      'left' => 'à gauche',
      'right' => 'à droite',
      'slight left' => 'légèrement à gauche',
      'slight right' => 'légèrement à droite',
      'sharp left' => 'franchement à gauche',
      'sharp right' => 'franchement à droite',
      'uturn' => 'demi-tour',
      _ => 'tout droit',
    };
    return switch (type) {
      'depart' => 'Partez$sur',
      'arrive' => 'Vous êtes arrivé au dépôt',
      'roundabout' || 'rotary' => 'Au rond-point, continuez$sur',
      'merge' => 'Rejoignez la voie$sur',
      'fork' => 'À l\'embranchement, restez $direction$sur',
      'end of road' => 'Au bout de la route, tournez $direction$sur',
      'continue' || 'new name' => 'Continuez $direction$sur',
      _ => modifier == 'uturn'
          ? 'Faites demi-tour$sur'
          : (modifier == null || modifier == 'straight')
              ? 'Continuez tout droit$sur'
              : 'Tournez $direction$sur',
    };
  }
}
