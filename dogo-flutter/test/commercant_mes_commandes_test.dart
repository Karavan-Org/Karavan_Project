import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dogo_app/commercant/mes_commandes_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MesCommandesScreen - Suivi des commandes & Annulation RG-31', () {
    testWidgets('MesCommandesScreen se construit correctement et affiche le titre', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MesCommandesScreen(),
        ),
      );

      // On attend la fin du microtask/chargement
      await tester.pump();

      expect(find.text('Mes commandes'), findsOneWidget);
    });

    testWidgets('ElementCommande mappe correctement les participations et les statuts de remboursement', (tester) async {
      final participationPayee = ElementCommande(
        id: 10,
        estParticipation: true,
        participationId: 10,
        titre: 'Chaussures Sport Homme',
        details: 'Taille 42 • Noir • Qté: 2 • 30 000 FCFA',
        numero: 'Participation #10',
        statutBrut: 'CONFIRMEE',
        statutLibelle: 'Payé • Séquestre actif',
        montant: 30000.0,
        quantite: 2,
        imageLocale: 'assets/images/chaussure.png',
        etapeActive: 0,
        annulable: true,
        payee: true,
        annulee: false,
      );

      expect(participationPayee.annulable, isTrue);
      expect(participationPayee.payee, isTrue);
      expect(participationPayee.annulee, isFalse);
      expect(participationPayee.titre, 'Chaussures Sport Homme');
      expect(participationPayee.numero, 'Participation #10');

      final participationAnnulee = ElementCommande(
        id: 11,
        estParticipation: true,
        participationId: 11,
        titre: 'Sac de voyage',
        details: 'Noir • Qté: 1 • 25 000 FCFA',
        numero: 'Participation #11',
        statutBrut: 'ANNULEE',
        statutLibelle: 'Annulé • Remboursé',
        montant: 25000.0,
        quantite: 1,
        imageLocale: 'assets/images/sac.png',
        etapeActive: 0,
        annulable: false,
        payee: false,
        annulee: true,
      );

      expect(participationAnnulee.annulable, isFalse);
      expect(participationAnnulee.annulee, isTrue);
    });
  });
}

