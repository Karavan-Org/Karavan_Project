import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:karavan_app/services/itineraire_service.dart';

void main() {
  group('OpenStreetMap & ItineraireService', () {
    test('ResultatLieu instancie correctement les coordonnées et libellés', () {
      const lieu = ResultatLieu(
        nom: 'Grand Marché de Bamako',
        adresseComplete: 'Grand Marché, Commune III, Bamako, Mali',
        position: LatLng(12.6392, -7.9982),
      );

      expect(lieu.nom, 'Grand Marché de Bamako');
      expect(lieu.adresseComplete, contains('Bamako'));
      expect(lieu.position.latitude, closeTo(12.6392, 0.0001));
      expect(lieu.position.longitude, closeTo(-7.9982, 0.0001));
    });

    test('Lecture locale des coordonnées d\'un lien Google Maps sans réseau',
        () {
      const lien = 'https://www.google.com/maps/@12.6450,-7.9920,17z';
      final coords = ItineraireService.coordonneesDepuisLien(lien);
      expect(coords, isNotNull);
      expect(coords!.latitude, closeTo(12.6450, 0.0001));
      expect(coords.longitude, closeTo(-7.9920, 0.0001));
    });

    test('Calcul de distances cumulées le long d\'un tracé routier', () {
      final points = [
        const LatLng(12.6300, -7.9900),
        const LatLng(12.6310, -7.9900),
        const LatLng(12.6310, -7.9920),
      ];
      final cumuls = ItineraireService.cumuls(points);
      expect(cumuls.length, 3);
      expect(cumuls[0], 0.0);
      expect(cumuls[1], greaterThan(0.0));
      expect(cumuls[2], greaterThan(cumuls[1]));
    });

    test('Portion du tracé parcourue pour l\'animation', () {
      final points = [
        const LatLng(12.6300, -7.9900),
        const LatLng(12.6400, -7.9900),
      ];
      final cumuls = ItineraireService.cumuls(points);

      final debut = ItineraireService.portion(points, cumuls, 0.0);
      expect(debut.length, 1);
      expect(debut.first.latitude, closeTo(12.6300, 0.0001));

      final fin = ItineraireService.portion(points, cumuls, 1.0);
      expect(fin.length, 2);
      expect(fin.last.latitude, closeTo(12.6400, 0.0001));
    });

    test('Recherche de lieux ignore les requêtes trop courtes (< 2 caractères)',
        () async {
      final res = await ItineraireService.rechercherLieux('a');
      expect(res, isEmpty);
    });
  });
}
