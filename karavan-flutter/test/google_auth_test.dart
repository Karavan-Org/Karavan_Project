import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karavan_app/commercant/commercant_connexion_screen.dart';
import 'package:karavan_app/commercant/commercant_inscription_screen.dart';
import 'package:karavan_app/courtier/courtier_connexion_screen.dart';
import 'package:karavan_app/courtier/courtier_inscription_screen.dart';
import 'package:karavan_app/grossiste/grossiste_connexion_screen.dart';
import 'package:karavan_app/grossiste/grossiste_inscription_screen.dart';
import 'package:karavan_app/models/role_acteur.dart';
import 'package:karavan_app/screens/google_completer_profil_screen.dart';
import 'package:karavan_app/screens/onboarding_screen.dart';
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

  test('Règles de validation selon le rôle : seul Grossiste et Courtier sont soumis à validation', () {
    expect(RoleActeur.commercant.exigeValidation, isFalse);
    expect(RoleActeur.grossiste.exigeValidation, isTrue);
    expect(RoleActeur.courtier.exigeValidation, isTrue);
    expect(RoleActeur.grossiste.criteresValidation, contains('RCCM'));
    expect(RoleActeur.grossiste.criteresValidation, contains('NIF'));
    expect(RoleActeur.courtier.criteresValidation, contains('licence de transitaire'));
  });

  testWidgets('BoutonGoogleSignIn distingue Connexion (estInscription: false) et Inscription (estInscription: true) sur les 3 acteurs', (WidgetTester tester) async {
    for (final screen in <Widget>[
      const CommercantConnexionScreen(role: RoleActeur.commercant),
      const CourtierConnexionScreen(),
      const GrossisteConnexionScreen(),
    ]) {
      await tester.pumpWidget(MaterialApp(home: screen));
      final btn = tester.widget<BoutonGoogleSignIn>(find.byType(BoutonGoogleSignIn));
      expect(btn.estInscription, isFalse);
    }

    for (final screen in <Widget>[
      const CommercantInscriptionScreen(role: RoleActeur.commercant),
      const CourtierInscriptionScreen(),
      const GrossisteInscriptionScreen(),
    ]) {
      await tester.pumpWidget(MaterialApp(home: screen));
      final btn = tester.widget<BoutonGoogleSignIn>(find.byType(BoutonGoogleSignIn));
      expect(btn.estInscription, isTrue);
    }
  });

  testWidgets('Chaque choix de départ sur OnboardingScreen mène à son propre parcours isolé sans mélange', (WidgetTester tester) async {
    // 1. Choix Commerçant -> CommercantConnexionScreen
    await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: const OnboardingScreen(initialRole: RoleActeur.commercant)));
    await tester.tap(find.text('Suivant'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CommercantConnexionScreen), findsOneWidget);
    expect(find.text('Espace Commerçant'), findsOneWidget);
    expect(find.byType(GrossisteConnexionScreen), findsNothing);
    expect(find.byType(CourtierConnexionScreen), findsNothing);

    // 2. Choix Grossiste -> GrossisteConnexionScreen
    await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: const OnboardingScreen(initialRole: RoleActeur.grossiste)));
    await tester.tap(find.text('Suivant'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(GrossisteConnexionScreen), findsOneWidget);
    expect(find.text('Bienvenue Grossiste !'), findsOneWidget);
    expect(find.byType(CommercantConnexionScreen), findsNothing);
    expect(find.byType(CourtierConnexionScreen), findsNothing);

    // 3. Choix Courtier -> CourtierConnexionScreen
    await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: const OnboardingScreen(initialRole: RoleActeur.courtier)));
    await tester.tap(find.text('Suivant'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CourtierConnexionScreen), findsOneWidget);
    expect(find.text('Bienvenue Courtier !'), findsOneWidget);
    expect(find.byType(CommercantConnexionScreen), findsNothing);
    expect(find.byType(GrossisteConnexionScreen), findsNothing);
  });

  testWidgets('GoogleCompleterProfilScreen ne redemande pas le choix du rôle et n\'exige pas de validation au Commerçant', (WidgetTester tester) async {
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
    expect(find.text("Compte Commerçant"), findsOneWidget);
    // Aucun sélecteur redemandant le rôle
    expect(find.byType(SegmentedButton<RoleActeur>), findsNothing);
    expect(find.text("Votre activité sur Karavan"), findsNothing);
    // Aucune mention de justificatifs KYC pour le commerçant
    expect(find.byIcon(Icons.verified_user_outlined), findsNothing);
    expect(find.text("Recevoir le code par SMS"), findsOneWidget);
  });

  testWidgets('GoogleCompleterProfilScreen conserve Grossiste / Courtier et affiche leurs critères respectifs', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GoogleCompleterProfilScreen(
          jetonInscription: 'test-jeton-g',
          nom: 'Import Bamako',
          email: 'grossiste@gmail.com',
          roleParDefaut: RoleActeur.grossiste,
        ),
      ),
    );

    expect(find.text("Compte Grossiste"), findsOneWidget);
    expect(find.byType(SegmentedButton<RoleActeur>), findsNothing);
    expect(find.textContaining("RCCM"), findsOneWidget);
    expect(find.textContaining("NIF"), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: GoogleCompleterProfilScreen(
          jetonInscription: 'test-jeton-c',
          nom: 'Transit Mali',
          email: 'courtier@gmail.com',
          roleParDefaut: RoleActeur.courtier,
        ),
      ),
    );

    expect(find.text("Compte Courtier"), findsOneWidget);
    expect(find.byType(SegmentedButton<RoleActeur>), findsNothing);
    expect(find.textContaining("licence de transitaire"), findsOneWidget);
  });
}

