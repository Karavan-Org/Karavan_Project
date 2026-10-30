import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karavan_app/commercant/campagne_model.dart';
import 'package:karavan_app/commercant/rejoindre_groupe_screen.dart';
import 'package:karavan_app/commercant/fiche_campagne_screen.dart';

void main() {
  group('Variantes du Grossiste et Quantités pour Commerçant', () {
    test('GroupeCampagneModel désérialise les variantes et quantiteMin du grossiste', () {
      final json = {
        'id': 10,
        'titre': 'Achat groupé Sneaker Pro',
        'prixUnitaire': 12000,
        'produit': {
          'id': 4,
          'nom': 'Sneaker Pro',
          'variantes': [
            {'id': 101, 'sku': 'SNK-42-NOIR', 'taille': '42', 'couleur': 'Noir'},
            {'id': 102, 'sku': 'SNK-43-BLANC', 'taille': '43', 'couleur': 'Blanc'},
          ]
        },
        'conditions': {
          'quantiteMinParCommercant': 3,
        }
      };

      final model = GroupeCampagneModel.fromJson(json);

      expect(model.id, '10');
      expect(model.titre, 'Achat groupé Sneaker Pro');
      expect(model.quantiteMinParCommercant, 3);
      expect(model.variantes.length, 2);
      expect(model.variantes[0].id, 101);
      expect(model.variantes[0].libelleComplet, '42 • Noir');
      expect(model.variantes[1].id, 102);
      expect(model.variantes[1].libelleComplet, '43 • Blanc');
    });

    testWidgets('RejoindreGroupeScreen affiche les variantes et permet d ajuster la quantité', (tester) async {
      final variantes = [
        const VarianteGroupeModel(id: 1, sku: 'SKU-1', taille: '42', couleur: 'Noir'),
        const VarianteGroupeModel(id: 2, sku: 'SKU-2', taille: '44', couleur: 'Bleu'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: RejoindreGroupeScreen(
            groupeId: 5,
            variantesDisponibles: variantes,
            varianteId: 1,
            quantite: 3,
            quantiteMin: 2,
            quantiteObjectif: 10,
            quantiteRestante: 10,
            prixUnitaire: 10000,
            titre: 'Chaussures Sport',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Vérifier la présence du titre et des variantes
      expect(find.textContaining('Variantes du Grossiste'), findsOneWidget);
      expect(find.text('42 • Noir'), findsOneWidget);
      expect(find.text('44 • Bleu'), findsOneWidget);

      // Quantité initiale
      expect(find.text('3'), findsWidgets);

      // Incrémenter la quantité
      final boutonAjout = find.byIcon(Icons.add_circle);
      expect(boutonAjout, findsOneWidget);
      await tester.tap(boutonAjout);
      await tester.pumpAndSettle();

      // Quantité maintenant = 4
      expect(find.text('4'), findsWidgets);

      // Sélectionner l'autre variante (44 • Bleu)
      await tester.tap(find.text('44 • Bleu'));
      await tester.pumpAndSettle();

      // Vérifier que le sous-total se recalcule avec 4 x 10 000 = 40 000 FCFA
      expect(find.textContaining('40 000 FCFA'), findsWidgets);
    });

    testWidgets('FicheCampagneScreen affiche les variantes du grossiste', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final variantes = [
        const VarianteGroupeModel(id: 11, sku: 'DRE-S', taille: 'S', couleur: 'Rouge'),
        const VarianteGroupeModel(id: 12, sku: 'DRE-L', taille: 'L', couleur: 'Noir'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: FicheCampagneScreen(
            id: '',
            titre: 'Robe d été',
            prixGroupe: 5000,
            variantes: variantes,
            quantiteMin: 2,
            quantiteObjectif: 10,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Variantes du grossiste'), findsOneWidget);
      expect(find.text('S • Rouge'), findsOneWidget);
      expect(find.text('L • Noir'), findsOneWidget);
      expect(find.text('Min: 2 · Max: 10 lots'), findsOneWidget);
    });
  });
}
