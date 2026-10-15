import 'package:dogo_app/services/itineraire_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('coordonneesDepuisLien', () {
    test('lit le paramètre q des liens de dépôt', () {
      expect(ItineraireService.coordonneesDepuisLien('https://maps.google.com/?q=12.6174,-7.9942'),
          const LatLng(12.6174, -7.9942));
    });

    test("préfère l'épingle du lieu au centre de la vue", () {
      expect(
        ItineraireService.coordonneesDepuisLien(
            'https://www.google.com/maps/place/Dabanani/@12.60,-8.00,17z/data=!3m1!4b1!4m6!3m5!8m2!3d12.6391!4d-7.9978'),
        const LatLng(12.6391, -7.9978),
      );
    });

    test('lit les coordonnées encodées et le centre de la vue', () {
      expect(ItineraireService.coordonneesDepuisLien('https://www.google.com/maps/search/?api=1&query=12.645%2C-7.995'),
          const LatLng(12.645, -7.995));
      expect(ItineraireService.coordonneesDepuisLien('https://www.google.com/maps/@12.645,-7.995,15z'),
          const LatLng(12.645, -7.995));
    });

    test('lien court : résolution déléguée au backend', () {
      expect(ItineraireService.coordonneesDepuisLien('https://maps.app.goo.gl/AbCdEf123'), isNull);
    });
  });

  test("portion suit le tracé jusqu'à l'arrivée", () {
    const trace = [LatLng(12.60, -8.00), LatLng(12.61, -8.00), LatLng(12.61, -7.99)];
    final cumuls = ItineraireService.cumuls(trace);
    expect(ItineraireService.portion(trace, cumuls, 0), [trace.first]);
    expect(ItineraireService.portion(trace, cumuls, 1), trace);
    final quart = ItineraireService.portion(trace, cumuls, 0.25);
    expect(quart.length, 2);
    expect(quart.last.latitude, closeTo(12.605, 0.0002));
    final troisQuarts = ItineraireService.portion(trace, cumuls, 0.75);
    expect(troisQuarts.length, 3);
    expect(troisQuarts.last.latitude, 12.61);
    expect(troisQuarts.last.longitude, closeTo(-7.995, 0.0005));
  });

  test('formatage distance et durée', () {
    expect(ItineraireService.formaterDistance(430), '430 m');
    expect(ItineraireService.formaterDistance(4781), '4,8 km');
    expect(ItineraireService.formaterDuree(311), '5 min');
    expect(ItineraireService.formaterDuree(4000), '1 h 07');
  });
}
