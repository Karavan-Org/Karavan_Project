import 'package:dogo_app/services/plus_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  // Vecteurs officiels : github.com/google/open-location-code/test_data (decoding.csv, shortCodeTests.csv).
  test('codes complets', () {
    final a = PlusCode.depuisTexte('7FG49QCJ+2VX')!;
    expect(a.latitude, closeTo(20.3701125, 1e-7));
    expect(a.longitude, closeTo(2.782234375, 1e-7));
    final b = PlusCode.depuisTexte('4VCPPQGP+Q9')!;
    expect(b.latitude, closeTo(-41.2730625, 1e-7));
    expect(b.longitude, closeTo(174.7859375, 1e-7));
  });

  test('code court complété depuis la référence la plus proche', () {
    final complet = PlusCode.depuisTexte('9C3W9QCJ+2VX')!;
    for (final (court, ref) in [
      ('9QCJ+2VX', const LatLng(51.3852125, -1.217765625)),
      ('CJ+2VX', const LatLng(51.3708675, -1.217765625)),
      ('CJ+2VX', const LatLng(51.3701125, -1.218520625)),
    ]) {
      final p = PlusCode.depuisTexte(court, reference: ref)!;
      expect(p.latitude, closeTo(complet.latitude, 1e-7), reason: court);
      expect(p.longitude, closeTo(complet.longitude, 1e-7), reason: court);
    }
  });

  test('adresse réelle du dépôt à Bamako', () {
    final p = PlusCode.depuisTexte('JXJF+76R, Unnamed Road')!;
    expect(p.latitude, closeTo(12.6307375, 1e-7));
    expect(p.longitude, closeTo(-8.0269844, 1e-7));
  });

  test('pas de faux positif sur une adresse classique ou un numéro', () {
    expect(PlusCode.depuisTexte('Rue 14, Porte 205'), isNull);
    expect(PlusCode.depuisTexte('Tél +22370000002'), isNull);
    expect(PlusCode.depuisTexte(null), isNull);
  });
}
