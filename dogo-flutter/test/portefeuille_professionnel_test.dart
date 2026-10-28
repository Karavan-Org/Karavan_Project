import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karavan_app/courtier/portefeuille_courtier_screen.dart';
import 'package:karavan_app/services/api/api_client.dart';
import 'package:karavan_app/services/api/api_config.dart';

/// Portefeuille Courtier branché sur l'API réelle (serveur HTTP local).
void main() {
  late HttpServer serveur;
  late List<({String chemin, String? cle, Object? corps})> requetes;
  var disponible = 150000;

  setUp(() async {
    HttpOverrides.global = null;
    requetes = [];
    disponible = 150000;
    serveur = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    serveur.listen((r) async {
      final texte = await utf8.decodeStream(r);
      requetes.add((
        chemin: '${r.method} ${r.uri.path}',
        cle: r.headers.value('idempotency-key'),
        corps: texte.isEmpty ? null : jsonDecode(texte),
      ));
      Object? corps;
      switch ('${r.method} ${r.uri.path}') {
        case 'GET /api/moi/portefeuille':
          corps = {'soldeDisponible': disponible, 'soldeBloque': 420000, 'devise': 'XOF'};
        case 'GET /api/moi/portefeuille/mouvements':
          corps = [
            {'id': 1, 'type': 'LIBERATION_SEQUESTRE', 'montant': 150000, 'date': '2026-10-15T10:00:00Z', 'reference': 'G-12'},
          ];
        case 'GET /api/moi/moyens-paiement':
          corps = [
            {'id': 4, 'numero': '+22372000001', 'operateur': 'ORANGE_MONEY', 'parDefaut': true},
            {'id': 9, 'numero': '+22365000009', 'operateur': 'MOOV_MONEY', 'parDefaut': false},
          ];
        case 'POST /api/moi/portefeuille/retraits':
          disponible -= 50000;
          corps = {'soldeDisponible': disponible, 'soldeBloque': 420000, 'devise': 'XOF'};
      }
      r.response.headers.contentType = ContentType.json;
      r.response.write(jsonEncode(corps));
      await r.response.close();
    });
    ApiConfig.baseUrlTest = 'http://127.0.0.1:${serveur.port}';
    ApiClient.instance.definirJeton('jeton-courtier');
  });

  tearDown(() async {
    ApiConfig.baseUrlTest = null;
    ApiClient.instance.deconnecter();
    await serveur.close(force: true);
  });

  /// Les appels HTTP réels doivent tourner hors de l'horloge simulée de flutter_test.
  Future<void> attendreReseau(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
  }

  testWidgets('affiche le solde réel, le séquestre, les comptes et retire vers le compte choisi', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: PortefeuilleCourtierScreen()));
    await attendreReseau(tester);

    expect(find.text('150 000 FCFA'), findsOneWidget);
    expect(find.textContaining('En séquestre : 420 000 FCFA'), findsOneWidget);
    expect(find.text('+22365000009'), findsOneWidget);
    expect(find.text('Séquestre débloqué'), findsOneWidget);

    await tester.tap(find.text('Retirer vers Mobile Money'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '50000');
    await tester.tap(find.text('Confirmer le retrait'));
    await attendreReseau(tester);
    await tester.pumpAndSettle();

    final retrait = requetes.singleWhere((q) => q.chemin == 'POST /api/moi/portefeuille/retraits');
    expect(retrait.corps, {'montant': 50000.0, 'moyenPaiementId': 4}); // compte par défaut
    expect(retrait.cle, isNotEmpty); // l'API refuse un retrait sans clé d'idempotence
    expect(find.text('100 000 FCFA'), findsOneWidget); // solde rechargé après retrait
    await tester.pump(ApiConfig.timeout); // écoule les délais d'attente réseau de l'horloge simulée
  });

  testWidgets('refuse un montant supérieur au solde sans appeler le serveur', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: PortefeuilleCourtierScreen()));
    await attendreReseau(tester);

    await tester.tap(find.text('Retirer vers Mobile Money'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '999999');
    await tester.tap(find.text('Confirmer le retrait'));
    await tester.pump();

    expect(find.textContaining('Entre 1 et 150 000 FCFA'), findsOneWidget);
    expect(requetes.where((q) => q.chemin.startsWith('POST')), isEmpty);
    await tester.pump(ApiConfig.timeout);
  });
}
