# Karavan

Karavan est une plateforme d'achats groupés qui relie commerçants, grossistes et courtiers pour l'importation de marchandises vers le Mali. L'application mobile accompagne les opérations métier ; une console Angular sert à l'administration ; une API Spring Boot applique les règles de gestion.

## Applications

| Dossier | Application | Technologies |
|---|---|---|
| `karavan-flutter/` | Application commerçant, grossiste et courtier | Flutter / Dart |
| `karavan-angular/` | Console d'administration | Angular 22 / TypeScript |
| `karavan-backend/` | API, authentification, règles métier et persistance | Java 25 / Spring Boot 3.5 / MySQL / Flyway |

Le backend est organisé en monolithe modulaire. Les principaux modules sont l'identité, le catalogue, les groupes d'achat, les participations, la finance, la logistique, les litiges, les notifications et l'audit.

## Démarrage local

Prérequis : JDK 25 LTS, Maven 3.9+, MySQL 8, Node.js/npm et Flutter.

Créer une base MySQL locale `karavan`, puis lancer le backend avec le profil `local` (il utilise `root` / `1234` par défaut uniquement dans ce profil).

Le profil par défaut est `prod` et refuse de démarrer sans secrets et origines CORS de production valides. `DOGO_COOKIE_SECURE=true` et des origines CORS HTTPS exactes sont obligatoires en production.

### Backend Spring Boot

Depuis `karavan-backend/` :

```powershell
Set-Location karavan-backend
mvn spring-boot:run "-Dspring-boot.run.profiles=local"
```

Le serveur écoute sur `http://localhost:8080`.

Le profil `demo`, lorsqu'il est disponible, permet de réaliser des démonstrations avec des comptes de test et des simulations de services SMS et Mobile Money. Il est réservé au développement et aux soutenances ; ne pas l'utiliser en production.

### Console Angular

Dans un autre terminal :

```powershell
Set-Location karavan-angular
npm ci
npm start
```

Ouvrir `http://localhost:4200`.

### Application Flutter

Dans un autre terminal :

```powershell
Set-Location karavan-flutter
flutter pub get
flutter run -d chrome --web-port=3000
```

Par défaut, Flutter Web appelle l'API sur `http://localhost:8080`.

Sur un téléphone ou un émulateur, définir l'adresse API avec les options `--dart-define` décrites dans `karavan-flutter/lib/services/api/api_config.dart`.

## Vérifications

Exécuter les contrôles depuis le dossier de chaque application :

```powershell
# Flutter
Set-Location karavan-flutter
flutter analyze
flutter test

# Angular
Set-Location karavan-angular
npm test -- --watch=false
npm run build

# Backend
Set-Location karavan-backend
mvn test
```

`mvn verify` lance également les tests d'intégration MySQL. Vérifier la configuration de la base de test avant de l'exécuter : certaines configurations utilisent `dogo_test`, qui doit être une base jetable, car les tests peuvent la vider et la reconstruire.

## Documentation

- [Architecture et séquences métier](docs/ARCHITECTURE.md)
- [Contrats API](karavan-backend/docs/API.md)
- [Présentation détaillée du backend et parcours de démonstration](karavan-backend/README.md)
- [Diagramme de classes](docs/diagrams/diagramClass.xml)
- [Diagramme de cas d'utilisation](docs/diagrams/DiagramsUseCase.xml)
- [Identité visuelle](docs/images/Design%20System.png)

## Limites et sécurité à traiter

- Le profil `demo` ne représente pas une intégration réelle d'opérateur SMS ou Mobile Money.
- La migration Flyway V11 donne le même mot de passe de démonstration à tous les comptes déjà présents lors de son exécution. Ne pas l'appliquer à une base contenant de vrais comptes ; toute correction doit préserver les installations existantes et prévoir une procédure de réinitialisation.
- Les tests d'intégration et un démarrage complet avec une base MySQL doivent être vérifiés avant de considérer le déploiement comme validé.
- Ne jamais utiliser les identifiants de démonstration en production.
