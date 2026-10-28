import 'package:karavan_app/services/itineraire_service.dart';
import 'package:karavan_app/services/navigation_live.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// Route en L : 1,1 km plein nord puis 1,1 km plein est, avec de longs segments sans sommet intermédiaire.
const _trace = [LatLng(12.60, -8.00), LatLng(12.61, -8.00), LatLng(12.61, -7.99)];

Itineraire _itineraire({List<LatLng> points = _trace, double duree = 300}) => Itineraire(
      points: points,
      distanceMetres: ItineraireService.cumuls(points).last,
      dureeSecondes: duree,
      etapes: const [],
      routier: true,
    );

void main() {
  final t0 = DateTime(2026, 10, 16, 9);

  test('au milieu d\'une longue ligne droite on reste sur la route (pas de faux recalcul)', () {
    final suivi = SuiviNavigation(_itineraire());
    // ~550 m de chaque sommet, mais à 5 m de la route.
    final e = suivi.mettreAJour(const LatLng(12.605, -8.00005), instant: t0);
    expect(e.surLaRoute, isTrue);
    expect(e.ecart, lessThan(10));
    expect(e.parcouru, closeTo(553, 5));
    expect(e.position.longitude, closeTo(-8.00, 1e-6)); // calée sur la route
    // 1 639 m restants sur 2 192 m → 75 % des 300 s.
    expect(e.restantSecondes, closeTo(224, 2));
  });

  test('sortie du chemin : recalcul seulement après 2 positions et 3 s, puis pause de 10 s', () {
    final suivi = SuiviNavigation(_itineraire());
    const dehors = LatLng(12.605, -8.002); // ~217 m à l'ouest de la route
    expect(suivi.mettreAJour(dehors, instant: t0).doitRecalculer, isFalse);
    expect(suivi.mettreAJour(dehors, instant: t0.add(const Duration(seconds: 1))).doitRecalculer, isFalse);
    final e = suivi.mettreAJour(dehors, instant: t0.add(const Duration(seconds: 3)));
    expect(e.surLaRoute, isFalse);
    expect(e.doitRecalculer, isTrue);
    expect(e.position, dehors); // pas de calage sur une route qu'on a quittée

    suivi.signalerRecalcul(t0.add(const Duration(seconds: 3)));
    expect(suivi.mettreAJour(dehors, instant: t0.add(const Duration(seconds: 8))).doitRecalculer, isFalse);
    expect(suivi.mettreAJour(dehors, instant: t0.add(const Duration(seconds: 14))).doitRecalculer, isTrue);
  });

  test('un saut GPS isolé ne déclenche rien', () {
    final suivi = SuiviNavigation(_itineraire());
    suivi.mettreAJour(const LatLng(12.605, -8.002), instant: t0);
    final retour = suivi.mettreAJour(const LatLng(12.6052, -8.0), instant: t0.add(const Duration(seconds: 4)));
    expect(retour.surLaRoute, isTrue);
    expect(suivi.mettreAJour(const LatLng(12.605, -8.002), instant: t0.add(const Duration(seconds: 5))).doitRecalculer,
        isFalse);
  });

  test('la tolérance suit la précision du GPS', () {
    final suivi = SuiviNavigation(_itineraire());
    // 60 m de la route : hors chemin avec un bon GPS, toléré avec ±50 m de précision.
    expect(suivi.mettreAJour(const LatLng(12.605, -8.00055), precision: 5, instant: t0).surLaRoute, isFalse);
    expect(suivi.mettreAJour(const LatLng(12.605, -8.00055), precision: 50, instant: t0).surLaRoute, isTrue);
  });

  test('comparaison du nouvel itinéraire', () {
    final plusLong = SuiviNavigation.comparer(
        ancienRestantSecondes: 300, ancienRestantMetres: 2000, nouveau: _itineraire(duree: 480));
    expect(plusLong.plusLong, isTrue);
    expect(plusLong.libelle, 'Plus long de 3 min');
    final plusCourt = SuiviNavigation.comparer(
        ancienRestantSecondes: 600, ancienRestantMetres: 4000, nouveau: _itineraire(duree: 300));
    expect(plusCourt.plusCourt, isTrue);
    expect(plusCourt.libelle, 'Plus court de 5 min');
    expect(SuiviNavigation.comparer(ancienRestantSecondes: 300, ancienRestantMetres: 2200, nouveau: _itineraire())
        .libelle, 'Durée équivalente');
    // Seuil : 1 min et 10 % du temps restant.
    expect(SuiviNavigation.estNettementPlusRapide(600, 550), isFalse); // −50 s
    expect(SuiviNavigation.estNettementPlusRapide(600, 500), isTrue); // −100 s
    expect(SuiviNavigation.estNettementPlusRapide(3000, 2800), isFalse); // −200 s mais < 10 %
    expect(SuiviNavigation.estNettementPlusRapide(3000, 2600), isTrue);
  });

  test('cap : GPS en roulant, boussole à l\'arrêt', () {
    expect(SuiviNavigation.capPrefere(capGps: 90, vitesse: 8, capBoussole: 10), 90);
    expect(SuiviNavigation.capPrefere(capGps: 90, vitesse: 0.2, capBoussole: 10), 10);
    expect(SuiviNavigation.capPrefere(capGps: 90, vitesse: 1, capBoussole: null), 90);
    expect(SuiviNavigation.capPrefere(capGps: -1, vitesse: 1, capRoute: 45, surLaRoute: true), 45);
    expect(SuiviNavigation.capPrefere(vitesse: 0), isNull);
  });
}
