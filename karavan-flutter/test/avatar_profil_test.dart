import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karavan_app/widgets/avatar_profil_interactif.dart';
import 'package:karavan_app/services/auth_service.dart';

class _FakePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  testWidgets('AvatarProfilInteractif affiche le CustomPainter par défaut et le bouton caméra', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvatarProfilInteractif(
            photoUrl: null,
            taille: 86,
            customPainterDefaut: _FakePainter(),
          ),
        ),
      ),
    );

    // Vérifie que le CustomPaint par défaut est rendu
    expect(find.byType(CustomPaint), findsWidgets);

    // Vérifie que l'icône de caméra d'édition est présente
    expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
  });

  test('UtilisateurProfil prend en charge photoUrl et copyWith', () {
    const profil = UtilisateurProfil(
      id: 42,
      type: 'COMMERCANT',
      nom: 'Test User',
      telephone: '+22370123456',
      photoUrl: '/api/public/images/avatars/test.jpg',
      statut: 'ACTIF',
    );

    expect(profil.photoUrl, '/api/public/images/avatars/test.jpg');

    final json = profil.toJson();
    expect(json['photoUrl'], '/api/public/images/avatars/test.jpg');

    final deserialise = UtilisateurProfil.fromJson(json);
    expect(deserialise.photoUrl, '/api/public/images/avatars/test.jpg');

    final maj = profil.copyWith(photoUrl: '/api/public/images/avatars/nouveau.jpg');
    expect(maj.photoUrl, '/api/public/images/avatars/nouveau.jpg');
    expect(maj.id, 42);
    expect(maj.nom, 'Test User');
  });
}

