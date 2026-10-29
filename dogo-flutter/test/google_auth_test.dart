import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karavan_app/models/role_acteur.dart';
import 'package:karavan_app/screens/google_completer_profil_screen.dart';
import 'package:karavan_app/services/api/api_config.dart';
import 'package:karavan_app/widgets/bouton_google_signin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Endpoints et Client ID Google dans ApiConfig', () {
    expect(ApiConfig.googleClientId, '462534787008-7c48fkvh3n0nu65po72p005qr5qo05ot.apps.googleusercontent.com');
    expect(ApiConfig.googleAuth, '/api/auth/google');
    expect(ApiConfig.googleCompleter, '/api/auth/google/completer');
    expect(ApiConfig.googleDemanderOtp, '/api/auth/google/demander-otp');
  });

  testWidgets('BoutonGoogleSignIn s\'affiche correctement', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BoutonGoogleSignIn(
            role: RoleActeur.commercant,
            libelle: "Continuer avec Google",
          ),
        ),
      ),
    );

    expect(find.text("Continuer avec Google"), findsOneWidget);
  });

  testWidgets('GoogleCompleterProfilScreen affiche les infos reçues de Google', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GoogleCompleterProfilScreen(
          jetonInscription: 'test-jeton-123',
          nom: 'Moussa Diarra',
          email: 'moussa.diarra@gmail.com',
          roleParDefaut: RoleActeur.commercant,
        ),
      ),
    );

    expect(find.text("Finaliser votre compte"), findsOneWidget);
    expect(find.text("Moussa Diarra"), findsOneWidget);
    expect(find.text("moussa.diarra@gmail.com"), findsOneWidget);
    expect(find.text("Recevoir le code par SMS"), findsOneWidget);
  });
}

