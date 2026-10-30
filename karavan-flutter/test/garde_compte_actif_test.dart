import 'package:karavan_app/grossiste/grossiste_acces.dart';
import 'package:karavan_app/models/role_acteur.dart';
import 'package:karavan_app/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// RG-03 : l'espace Grossiste / Courtier n'est construit que pour un compte actif.
void main() {
  UtilisateurProfil profil(String statut) =>
      UtilisateurProfil(id: 1, type: 'GROSSISTE', nom: 'Dépôt', telephone: '+22379000000', statut: statut);

  tearDown(() => AuthService.instance.profilNotifier.value = null);

  Widget espace() => const MaterialApp(
        home: GardeCompteActif(role: RoleActeur.grossiste, child: Text('ESPACE GROSSISTE')),
      );

  testWidgets('un compte actif accède à son espace', (tester) async {
    AuthService.instance.profilNotifier.value = profil('ACTIF');
    await tester.pumpWidget(espace());
    expect(find.text('ESPACE GROSSISTE'), findsOneWidget);
  });

  testWidgets("un compte en attente de validation ne voit jamais l'espace", (tester) async {
    AuthService.instance.profilNotifier.value = profil('EN_ATTENTE');
    await tester.pumpWidget(espace());
    expect(find.text('ESPACE GROSSISTE'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
