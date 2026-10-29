import 'package:flutter_test/flutter_test.dart';
import 'package:karavan_app/services/pays_resolver_service.dart';

void main() {
  final r = PaysResolverService.instance;

  test('référentiel ISO 3166-1 complet', () {
    expect(r.tousLesPays.length, greaterThanOrEqualTo(249));
  });

  test('codes, noms et variantes désignent le même pays', () {
    for (final s in ['CN', 'chn', 'Chine', 'china', 'Guangzhou']) {
      expect(r.resoudre(s).codeIso, 'CN', reason: s);
    }
    for (final s in ["Côte d'Ivoire", 'Côte d’Ivoire', 'cote divoire', 'Cote-d-Ivoire', 'CIV', 'Ivory Coast']) {
      expect(r.resoudre(s).codeIso, 'CI', reason: s);
    }
    expect(r.resoudre('Turkey').nomFr, 'Turquie');
    expect(r.resoudre('UAE').nomFr, 'Émirats arabes unis');
  });

  test('pas de confusion par sous-chaîne', () {
    expect(r.resoudre('Niger').codeIso, 'NE');
    expect(r.resoudre('Nigéria').codeIso, 'NG');
    expect(r.resoudre('Somalie').codeIso, 'SO');
    expect(r.resoudre('Guinée équatoriale').codeIso, 'GQ');
    expect(r.resoudre('Guinée').codeIso, 'GN');
    expect(r.resoudre('Congo').codeIso, 'CG');
    expect(r.resoudre('RDC').codeIso, 'CD');
  });

  test('une saisie inconnue ou vide ne devient jamais « Mali »', () {
    final inconnu = r.resoudre('Atlantide');
    expect(inconnu.estReconnu, isFalse);
    expect(inconnu.nomFr, 'Atlantide');
    expect(r.resoudre('').estReconnu, isFalse);
    expect(r.resoudre(null).estReconnu, isFalse);
  });

  test('auto-complétion par préfixe', () {
    final noms = r.rechercher('tur').map((p) => p.codeIso);
    expect(noms, contains('TR'));
    expect(r.rechercher('mali').map((p) => p.codeIso), isNot(contains('SO')));
  });
}
