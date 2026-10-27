import 'package:flutter_test/flutter_test.dart';
import 'package:dogo_app/models/campagne_model.dart';

void main() {
  // JSON conforme à GroupeService.GroupeVue côté Spring Boot
  final groupeVue = <String, dynamic>{
    'id': 42,
    'statut': 'OUVERT',
    'produit': {
      'id': 7,
      'nom': 'Sneakers Export',
      'description': 'Lot Turquie',
      'paysOrigine': 'Turquie',
      'categorie': 'Chaussures',
      'photoUrl': '/api/public/images/produits/p7.jpg',
      'variantes': [
        {'id': 11, 'sku': 'SNK-41', 'taille': '41', 'couleur': 'Noir'},
        {'id': 12, 'sku': 'SNK-42', 'taille': '42', 'couleur': ''},
      ],
    },
    'courtier': {'id': 3, 'nom': 'Courtier Demo'},
    'grossiste': {'id': 2, 'nom': 'Grossiste Demo'},
    'quantiteCible': 20,
    'quantiteConfirmee': 6,
    'quantiteReservee': 4,
    'quantiteRestante': 7,
    'prixUnitaire': 18500.00,
    'conditions': {'delaiLivraisonJours': 30, 'politiqueAnnulation': 'x', 'quantiteMinParCommercant': 2},
    'dateLimite': DateTime.now().add(const Duration(days: 3, hours: 2)).toUtc().toIso8601String(),
    'disponibiliteValidee': true,
  };

  test('GroupeVue est lu sans valeurs inventées', () {
    final g = GroupeCampagneModel.fromJson(groupeVue);

    expect(g.id, '42');
    expect(g.titre, 'Sneakers Export');
    expect(g.prixGroupe, 18500);
    expect(g.prixPublic, 0, reason: 'le backend ne fournit pas de prix public');
    expect(g.aPrixPublic, isFalse);
    expect(g.courtierNom, 'Courtier Demo');
    expect(g.statut, 'OUVERT');
    expect(g.imagePath, endsWith('/api/public/images/produits/p7.jpg'));
    expect(g.tempsRestant, '3 jours restants');
  });

  test('variantes, minimum et capacité restante viennent du backend', () {
    final g = GroupeCampagneModel.fromJson(groupeVue);

    expect(g.variantes.map((v) => v.id), [11, 12]);
    expect(g.variantes.first.libelle, '41 · Noir');
    expect(g.variantes.first.qteDisponible, isNull);
    expect(g.varianteId, 11);
    expect(g.quantiteMinParCommercant, 2);
    // La capacité disponible est la cible moins les quantités déjà confirmées ou réservées.
    expect(g.quantiteMaxParCommercant, 7);
  });

  test('aller-retour toJson / fromJson conserve les variantes (favoris)', () {
    final g = GroupeCampagneModel.fromJson(GroupeCampagneModel.fromJson(groupeVue).toJson());

    expect(g.variantes.length, 2);
    expect(g.quantiteMinParCommercant, 2);
    expect(g.quantiteRestante, 7);
  });
}
