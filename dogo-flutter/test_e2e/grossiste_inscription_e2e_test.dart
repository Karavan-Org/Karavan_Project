// Parcours d'arrivée du Grossiste contre un vrai backend (profil demo) :
//   flutter test test_e2e --dart-define=ip=localhost --dart-define=port=8091
import 'dart:io';
import 'dart:typed_data';

import 'package:karavan_app/services/api/api_client.dart';
import 'package:karavan_app/services/api/api_config.dart';
import 'package:karavan_app/services/auth_service.dart';
import 'package:karavan_app/services/catalogue_api_service.dart';
import 'package:karavan_app/services/groupe_api_service.dart';
import 'package:karavan_app/services/kyc_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// PNG 1×1 valide
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
  0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
final _pdf = Uint8List.fromList('%PDF-1.4\n%%EOF\n'.codeUnits);

void main() {
  // flutter_test bloque le réseau par défaut
  setUpAll(() => HttpOverrides.global = null);

  test('inscription grossiste → OTP → KYC → validation → photo → produit', () async {
    final auth = AuthService.instance;
    final suffixe = (DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
    final telephone = '+22379$suffixe';
    const pin = '4826';

    // 1. Inscription (mêmes arguments que GrossisteInscriptionScreen)
    final inscrit = await auth.inscrire(
      typeActeur: 'GROSSISTE',
      telephone: telephone,
      nom: 'Grand Dépôt Mandé $suffixe',
      pin: pin,
      nomBoutiqueMarche: 'Grand Dépôt Mandé $suffixe',
    );
    expect(inscrit['statut'], 'EN_ATTENTE');
    final code = inscrit['codeOtp'] as String;

    // 2. OTP puis ouverture de session (CommercantOtpScreen avec pin)
    expect((await auth.verifierOtp(telephone: telephone, code: code))['statut'], 'EN_ATTENTE');
    final profil = await auth.connecter(telephone: telephone, pin: pin);
    expect(profil.type, 'GROSSISTE');
    expect(profil.statut, 'EN_ATTENTE');
    expect(await KycApiService.instance.monDossier(), isNull);

    // 3. Dépôt du dossier (GrossisteDocumentsKycScreen) : 3 obligatoires + relevé + 2 « autres »
    final dossier = await KycApiService.instance.soumettre([
      PieceKyc(type: TypeDocumentKyc.pieceIdentite, nomFichier: 'cni.png', octets: _png),
      PieceKyc(type: TypeDocumentKyc.registreCommerce, nomFichier: 'rccm.pdf', octets: _pdf),
      PieceKyc(type: TypeDocumentKyc.nif, nomFichier: 'nif.png', octets: _png),
      PieceKyc(type: TypeDocumentKyc.releveBancaire, nomFichier: 'releve.pdf', octets: _pdf),
      PieceKyc(type: TypeDocumentKyc.autre, nomFichier: 'autre1.png', octets: _png),
      PieceKyc(type: TypeDocumentKyc.autre, nomFichier: 'autre2.pdf', octets: _pdf),
    ]);
    expect(dossier.statut, 'EN_ATTENTE');
    expect(dossier.typesDocuments, hasLength(6));
    expect((await KycApiService.instance.monDossier())!.statut, 'EN_ATTENTE');
    final jetonGrossiste = ApiClient.instance.jeton;

    // 4. Un administrateur VALIDATION approuve (back-office)
    final admin = await ApiClient.instance.post(ApiConfig.connexion,
        body: {'telephone': '+22370000002', 'pin': '2580', 'deviceId': 'e2e'});
    ApiClient.instance.definirJeton(admin['jeton'] as String);
    await ApiClient.instance.post('/api/admin/kyc/${dossier.id}/decision',
        body: {'decision': 'APPROUVE', 'commentaire': 'Pièces conformes'});
    ApiClient.instance.definirJeton(jetonGrossiste);
    expect((await KycApiService.instance.monDossier())!.statut, 'APPROUVE');

    // 5. Photo + produit (AjouterProduitScreen), deux fois pour vérifier l'unicité des SKU
    final categories = await CatalogueApiService.instance.categories();
    final categorieId = (categories.first['id'] as num).toInt();
    for (final nom in ['Sneakers Joyride', 'Sneakers Joyride']) {
      final photoUrl = await CatalogueApiService.instance.uploaderPhotoProduit(bytes: _png, nomFichier: 'p.png');
      expect(photoUrl, startsWith('/api/public/images/produits/'));
      final skus = CatalogueApiService.genererSkus(nom, 2);
      final produit = await CatalogueApiService.instance.creerProduit(
        categorieId: categorieId,
        nom: nom,
        description: 'Semelle amortissante',
        paysOrigine: 'Mali',
        photoUrl: photoUrl,
        variantes: [
          {'sku': skus[0], 'taille': '42', 'couleur': 'Noir', 'qteDisponible': 100},
          {'sku': skus[1], 'taille': '43', 'couleur': 'Noir', 'qteDisponible': 50},
        ],
      );
      expect(produit['photoUrl'], photoUrl);
      expect(produit['variantes'], hasLength(2));

      final image = await HttpClient().getUrl(Uri.parse(ApiConfig.resolutionImageUrl(photoUrl)));
      expect((await image.close()).statusCode, 200);
    }
    final mesProduits = await CatalogueApiService.instance.mesProduits();
    expect(mesProduits, hasLength(2));
    final produitId = (mesProduits.first['id'] as num).toInt();

    // 6. Le courtier voit le produit dans le catalogue et monte un groupe (CreerGroupeCourtierScreen)
    await _connecter('+22372000001');
    final disponibles = await GroupeApiService.instance.produitsDisponibles();
    expect(disponibles.map((p) => p['id']), contains(produitId));
    final brouillon = await GroupeApiService.instance.creer(
      produitId: produitId,
      quantiteCible: 20,
      dateLimite: DateTime.now().add(const Duration(days: 7)),
      marchandise: 5000,
      transport: 500,
      douane: 300,
      autres: 200,
      delaiLivraisonJours: 30,
      politiqueAnnulation: 'Annulation possible avant objectif',
      quantiteMinParCommercant: 1,
    );
    expect(brouillon.statut, 'BROUILLON');
    final soumis = await GroupeApiService.instance.soumettre(brouillon.id);
    expect(soumis.statut, 'EN_VALIDATION');
    expect((await GroupeApiService.instance.mesGroupesCourtier()).map((g) => g.id), contains(soumis.id));

    // 7. Le grossiste retrouve le groupe et confirme son stock (MesGroupesGrossisteScreen)
    ApiClient.instance.definirJeton(jetonGrossiste);
    final duGrossiste = await GroupeApiService.instance.groupesDuGrossiste();
    final aConfirmer = duGrossiste.firstWhere((g) => g.id == soumis.id);
    expect(aConfirmer.libelleStatut, 'Stock à confirmer');
    expect(aConfirmer.photoUrl, startsWith('/api/public/images/produits/'));
    final confirme = await GroupeApiService.instance.validerDisponibilite(soumis.id);
    expect(confirme.disponibiliteValidee, isTrue);

    // 8. Un administrateur publie ; le commerçant voit le groupe avec la vraie photo du produit
    await _connecter('+22370000001');
    await ApiClient.instance.post('/api/admin/groupes/${soumis.id}/publication',
        body: {'approuve': true, 'commentaire': 'ok'});
    await _connecter('+22373000001');
    final ouverts = await GroupeApiService.instance.explorer();
    final campagne = ouverts.firstWhere((c) => c.id == '${soumis.id}');
    expect(campagne.imagePath, aConfirmer.photoUrl);
    expect(campagne.tempsRestant, contains('jour'));
  });
}

Future<void> _connecter(String telephone) async {
  final r = await ApiClient.instance.post(ApiConfig.connexion,
      body: {'telephone': telephone, 'pin': '2580', 'deviceId': 'e2e'});
  ApiClient.instance.definirJeton(r['jeton'] as String);
}
