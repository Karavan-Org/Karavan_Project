// ignore_for_file: avoid_print
//
// Parcours complet Flutter -> backend réel, sur une base jetable.
// 1. Backend (profil demo, base dédiée) :
//    DB_URL='jdbc:mysql://localhost:3306/dogo_e2e?createDatabaseIfNotExist=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC' \
//      mvn spring-boot:run -Dspring-boot.run.profiles=demo -Dspring-boot.run.arguments=--server.port=8091
// 2. flutter test test_e2e --dart-define=ip=localhost --dart-define=port=8091
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:karavan_app/services/api/api_client.dart';
import 'package:karavan_app/services/auth_service.dart';
import 'package:karavan_app/services/courtier_api_service.dart';
import 'package:karavan_app/services/grossiste_api_service.dart';
import 'package:karavan_app/services/groupe_api_service.dart';
import 'package:karavan_app/services/paiement_api_service.dart';
import 'package:karavan_app/services/profil_api_service.dart';
import 'package:karavan_app/services/logistique_api_service.dart';

const pin = '2580';

Future<void> en(String telephone) async {
  await AuthService.instance.deconnecter();
  await AuthService.instance.connecter(telephone: telephone, pin: pin);
}

void main() {
  HttpOverrides.global = null;

  test('cycle complet groupe -> paiement -> acheminement -> retrait', () async {
    final courtier = CourtierApiService.instance;
    final grossiste = GrossisteApiService.instance;

    // 1. Le courtier monte un groupe sur un produit d'un grossiste actif
    await en('72000001');
    final produits = await courtier.produitsDisponibles();
    expect(produits, isNotEmpty);
    var groupe = await courtier.creerGroupe(
      produitId: produits.first.id,
      quantiteCible: 10,
      dateLimite: DateTime.now().add(const Duration(days: 7)),
      marchandise: 1000,
      transport: 200,
      douane: 100,
      autres: 0,
      quantiteMinParCommercant: 1,
    );
    expect(groupe.statut, 'BROUILLON');
    groupe = await courtier.soumettre(groupe.id);
    expect(groupe.statut, 'EN_VALIDATION');
    final id = groupe.id;
    print('groupe $id, prix unitaire ${groupe.prixGroupe}');

    // 2. Le grossiste confirme le stock
    await en('71000001');
    expect((await grossiste.groupesAValider()).map((g) => g.id), contains(id));
    await grossiste.validerDisponibilite(id);
    expect((await grossiste.mesGroupes()).map((g) => g.id), contains(id));

    // 3. L'administration publie
    await en('70000001');
    await ApiClient.instance.post('/api/admin/groupes/$id/publication', body: {'approuve': true, 'commentaire': 'e2e'});

    // 4. Trois commerçants rejoignent et paient (5 + 3 + 2 = 10)
    final participations = <int>[];
    final paiements = <int>[];
    for (final (tel, qte) in [('73000001', 5), ('73000002', 3), ('73000003', 2)]) {
      await en(tel);
      final detail = await GroupeApiService.instance.detail(id);
      expect(detail.statut, 'OUVERT');
      expect(detail.variantes, isNotEmpty);
      final p = await GroupeApiService.instance.rejoindreGroupe(
          groupeId: id, varianteId: detail.variantes.first.id, quantite: qte);
      final moyen = (await ProfilApiService.instance.mesMoyensPaiement()).firstWhere((m) => m.parDefaut).id;
      final paiement = await PaiementApiService.instance.initierPaiement(
          participationId: p['id'], moyenPaiementId: moyen);
      participations.add((p['id'] as num).toInt());
      paiements.add(paiement.id);
      expect(paiement.montant, (detail.prixGroupe * qte).toDouble());
    }

    // 5. L'opérateur confirme les débits (simulateur réservé à l'administration)
    await en('70000001');
    for (final paiementId in paiements) {
      await ApiClient.instance.post('/api/dev/mobile-money/$paiementId/succes');
    }

    // 6. Le courtier prépare, suit le convoi et expédie
    await en('72000001');
    final mesGroupes = await courtier.mesGroupes();
    expect(mesGroupes.firstWhere((g) => g.id == id).statut, 'OBJECTIF_ATTEINT');
    expect(await courtier.commandesDuGroupe(id), hasLength(3));
    await courtier.preparer(id);
    var convoi = await courtier.creerConvoi(groupeId: int.parse(id), reference: 'E2E-$id', transporteur: 'Fret test');
    convoi = await courtier.avancerConvoi(convoi.id, 'transitaire', localisation: 'Istanbul');
    convoi = await courtier.avancerConvoi(convoi.id, 'transit');
    convoi = await courtier.ajouterEtape(convoi.id, statut: 'Passage frontière', localisation: 'Kati');
    convoi = await courtier.avancerConvoi(convoi.id, 'arrivee', localisation: 'Bamako');
    expect(convoi.statut, 'ARRIVE');
    await courtier.expedier(id);

    // 7. Réception au dépôt par l'administration
    await en('70000001');
    await ApiClient.instance.post('/api/admin/groupes/$id/reception');

    // 8. Arrivée au point de retrait (génère les codes)
    await en('72000001');
    final points = await courtier.pointsRetrait();
    expect(points, isNotEmpty);
    await courtier.confirmerArriveeAuPoint(id, points.first.id);

    // 9. Le commerçant récupère son code ; le courtier valide le retrait par QR
    await en('73000001');
    final participationsCommercant = await LogistiqueApiService.instance.mesParticipations();
    expect(participationsCommercant.map((p) => p['id']), contains(participations.first));
    final commande = (await LogistiqueApiService.instance.mesCommandes())
        .firstWhere((c) => c['participationId'] == participations.first);
    expect(commande['statut'], 'EN_ATTENTE_RETRAIT');
    final code = await LogistiqueApiService.instance.obtenirCodeRetrait(commande['id']);
    expect(code.qrToken, isNotEmpty);

    await en('72000001');
    final retrait = await LogistiqueApiService.instance.validerRetrait(qrToken: code.qrToken);
    print('retrait : $retrait');

    final portefeuille = await courtier.portefeuille();
    final mouvements = await courtier.mouvements();
    print('portefeuille : disponible ${portefeuille.soldeDisponible}, bloqué ${portefeuille.soldeBloque}, '
        '${mouvements.length} mouvement(s)');
    await AuthService.instance.deconnecter();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
