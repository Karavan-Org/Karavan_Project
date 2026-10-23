import 'package:dogo_app/services/convoi_api_service.dart';
import 'package:dogo_app/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formaterFcfa', () {
    test('sépare les milliers et ajoute la devise', () {
      expect(formaterFcfa(1250000), '1 250 000 FCFA');
      expect(formaterFcfa(0), '0 FCFA');
      expect(formaterFcfa(999), '999 FCFA');
      expect(formaterFcfa(-4500, avecDevise: false), '-4 500');
    });
  });

  group('dateRelative', () {
    final maintenant = DateTime(2026, 10, 21, 12, 0);
    test('du plus récent au plus ancien', () {
      expect(dateRelative(maintenant.subtract(const Duration(seconds: 20)), maintenant: maintenant), "à l'instant");
      expect(dateRelative(maintenant.subtract(const Duration(minutes: 5)), maintenant: maintenant), 'il y a 5 min');
      expect(dateRelative(maintenant.subtract(const Duration(hours: 3)), maintenant: maintenant), 'il y a 3 h');
      expect(dateRelative(maintenant.subtract(const Duration(days: 1, hours: 2)), maintenant: maintenant), 'hier');
      expect(dateRelative(maintenant.subtract(const Duration(days: 4)), maintenant: maintenant), 'il y a 4 j');
      expect(dateRelative(DateTime(2026, 9, 2), maintenant: maintenant), '02/09/2026');
      expect(dateRelative(null), '');
    });
  });

  group('Convoi (ConvoiVue du backend)', () {
    Convoi convoi(String statut, {List<Map<String, dynamic>> evenements = const []}) => Convoi.fromJson({
          'id': 3,
          'groupeId': 12,
          'reference': 'CV-12',
          'statut': statut,
          'transporteur': 'Vol TK',
          'evenements': evenements,
        });

    test('le rang suit la machine d\'états, le contrôle douanier reste dans la phase de transit', () {
      expect(convoi('ACHETE').rang, 0);
      expect(convoi('CHEZ_TRANSITAIRE').rang, 1);
      expect(convoi('EN_TRANSIT').rang, 2);
      expect(convoi('BLOQUE_DOUANE').rang, 2);
      expect(convoi('ARRIVE').rang, 3);
      expect(convoi('ARRIVE').estArrive, isTrue);
    });

    test('le journal est lu tel quel, avec des libellés pour les étapes officielles', () {
      final c = convoi('EN_TRANSIT', evenements: [
        {'id': 1, 'statut': 'CREATION_CONVOI', 'localisation': 'Origine', 'date': '2026-10-20T08:00:00Z'},
        {'id': 2, 'statut': 'Escale technique', 'localisation': 'Dakar', 'date': '2026-10-21T08:00:00Z'},
      ]);
      expect(c.evenements.first.libelle, 'Convoi ouvert');
      expect(c.dernierEvenement!.libelle, 'Escale technique');
      expect(c.dernierEvenement!.localisation, 'Dakar');
    });
  });
}
