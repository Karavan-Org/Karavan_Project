import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dogo_app/widgets/mobile_money_logo.dart';

void main() {
  group('OperateurMobileMoney', () {
    test('détection insensible à la casse et par mots clés', () {
      expect(OperateurMobileMoney.detecter('ORANGE_MONEY'), OperateurMobileMoney.orangeMoney);
      expect(OperateurMobileMoney.detecter('orange money'), OperateurMobileMoney.orangeMoney);
      expect(OperateurMobileMoney.detecter('Orange'), OperateurMobileMoney.orangeMoney);

      expect(OperateurMobileMoney.detecter('MOOV_MONEY'), OperateurMobileMoney.moovMoney);
      expect(OperateurMobileMoney.detecter('Moov Africa'), OperateurMobileMoney.moovMoney);
      expect(OperateurMobileMoney.detecter('moov'), OperateurMobileMoney.moovMoney);

      expect(OperateurMobileMoney.detecter('WAVE'), OperateurMobileMoney.wave);
      expect(OperateurMobileMoney.detecter('Wave 🇲🇱'), OperateurMobileMoney.wave);

      expect(OperateurMobileMoney.detecter('INCONNU'), OperateurMobileMoney.inconnu);
      expect(OperateurMobileMoney.detecter(null), OperateurMobileMoney.inconnu);
    });

    test('chemins des assets de logo', () {
      expect(OperateurMobileMoney.orangeMoney.assetPath, 'assets/logo/orangemoney.png');
      expect(OperateurMobileMoney.moovMoney.assetPath, 'assets/logo/moovafrica.png');
      expect(OperateurMobileMoney.wave.assetPath, 'assets/logo/wave.png');
      expect(OperateurMobileMoney.inconnu.assetPath, '');
    });
  });

  group('MobileMoneyLogo Widget', () {
    testWidgets('affiche l’icône de secours pour un opérateur inconnu', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MobileMoneyLogo(operateur: 'AUTRE_MOYEN'),
          ),
        ),
      );

      expect(find.byIcon(Icons.phone_android_rounded), findsOneWidget);
    });
  });
}
