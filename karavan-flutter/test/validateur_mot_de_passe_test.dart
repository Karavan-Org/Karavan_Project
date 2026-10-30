import 'package:flutter_test/flutter_test.dart';
import 'package:karavan_app/services/validateur_mot_de_passe.dart';

void main() {
  group('ValidateurMotDePasse - Création et modification', () {
    test('Rejette les entrées nulles ou vides', () {
      expect(ValidateurMotDePasse.validerCreation(null), isNotNull);
      expect(ValidateurMotDePasse.validerCreation(''), isNotNull);
      expect(ValidateurMotDePasse.validerCreation('   '), isNotNull);
    });

    test('Rejette les mots de passe trop courts (< 8 caractères)', () {
      expect(ValidateurMotDePasse.validerCreation('Abc1'),
          contains('au moins 8 caractères'));
      expect(ValidateurMotDePasse.validerCreation('Pass1'),
          contains('au moins 8 caractères'));
      expect(ValidateurMotDePasse.validerCreation('Short1A'),
          contains('au moins 8 caractères'));
    });

    test('Rejette les mots de passe de plus de 64 caractères', () {
      final tropLong = '${'A1b' * 21}xxxx'; // 67 chars
      expect(ValidateurMotDePasse.validerCreation(tropLong),
          contains('ne doit pas dépasser 64 caractères'));
    });

    test('Exige au moins une majuscule', () {
      expect(ValidateurMotDePasse.validerCreation('motdepasse123'),
          contains('majuscule'));
    });

    test('Exige au moins une minuscule', () {
      expect(ValidateurMotDePasse.validerCreation('MOTDEPASSE123'),
          contains('minuscule'));
    });

    test('Exige au moins un chiffre', () {
      expect(ValidateurMotDePasse.validerCreation('MotDePasseSansChiffre'),
          contains('chiffre'));
    });

    test('Valide un mot de passe conforme aux règles de sécurité RG-07', () {
      expect(ValidateurMotDePasse.validerCreation('Dogo2026!'), isNull);
      expect(ValidateurMotDePasse.validerCreation('BamakoSecurite1'), isNull);
      expect(
          ValidateurMotDePasse.validerCreation('MonCompteGrossiste99'), isNull);
    });

    test('Accepte la rétrocompatibilité 4 chiffres en test', () {
      expect(ValidateurMotDePasse.validerCreation('2580'), isNull);
      expect(ValidateurMotDePasse.validerCreation('4826'), isNull);
    });
  });

  group('ValidateurMotDePasse - Confirmation', () {
    test('Valide deux mots de passe identiques', () {
      expect(ValidateurMotDePasse.validerConfirmation('Dogo2026!', 'Dogo2026!'),
          isNull);
    });

    test('Rejette une confirmation vide ou différente', () {
      expect(ValidateurMotDePasse.validerConfirmation('Dogo2026!', ''),
          contains('confirmer'));
      expect(ValidateurMotDePasse.validerConfirmation('Dogo2026!', null),
          contains('confirmer'));
      expect(
          ValidateurMotDePasse.validerConfirmation('Dogo2026!', 'Autre2026!'),
          contains('ne correspondent pas'));
    });
  });

  group('ValidateurMotDePasse - Connexion', () {
    test('Rejette les valeurs vides', () {
      expect(ValidateurMotDePasse.validerConnexion(null), isNotNull);
      expect(ValidateurMotDePasse.validerConnexion(''), isNotNull);
    });

    test('Ne bloque pas les comptes existants avec code 4 chiffres', () {
      expect(ValidateurMotDePasse.validerConnexion('2580'), isNull);
      expect(ValidateurMotDePasse.validerConnexion('1234'), isNull);
    });

    test('Valide un mot de passe complet', () {
      expect(ValidateurMotDePasse.validerConnexion('Dogo2026!'), isNull);
    });
  });

  group('ValidateurMotDePasse - Indicateurs dynamiques UI', () {
    test('Vérifie chaque critère individuellement', () {
      expect(ValidateurMotDePasse.aLongueurValide('1234567'), isFalse);
      expect(ValidateurMotDePasse.aLongueurValide('12345678'), isTrue);

      expect(ValidateurMotDePasse.aMajuscule('bonjour'), isFalse);
      expect(ValidateurMotDePasse.aMajuscule('Bonjour'), isTrue);

      expect(ValidateurMotDePasse.aMinuscule('BONJOUR'), isFalse);
      expect(ValidateurMotDePasse.aMinuscule('BONJour'), isTrue);

      expect(ValidateurMotDePasse.aChiffre('Bonjour'), isFalse);
      expect(ValidateurMotDePasse.aChiffre('Bonjour1'), isTrue);

      expect(ValidateurMotDePasse.estConforme('Dogo2026!'), isTrue);
    });
  });
}
