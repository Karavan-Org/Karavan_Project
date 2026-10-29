# Dɔgɔ

Dɔgɔ est une plateforme d'achats groupés qui relie commerçants, grossistes et courtiers pour l'importation de marchandises vers le Mali. L'application mobile accompagne les opérations métier ; une console Angular sert à l'administration ; une API Spring Boot applique les règles de gestion.

## Applications

| Dossier | Application | Technologies |
|---|---|---|
| `dogo-flutter/` | Application commerçant, grossiste et courtier | Flutter / Dart |
| `dogo-angular/` | Console d'administration | Angular 22 / TypeScript |
| `dogo-backend/` | API, authentification, règles métier et persistance | Java 21 / Spring Boot 3.5 / MySQL / Flyway |

Le backend est organisé en monolithe modulaire. Les principaux modules sont l'identité, le catalogue, les groupes d'achat, les participations, la finance, la logistique, les litiges, les notifications et l'audit.

## Démarrage local

Prérequis : JDK 21, Maven 3.9+, MySQL 8, Node.js/npm et Flutter. Créer une base MySQL locale `dogo`, puis lancer le backend avec le profil `local` (il utilise `root` / `1234` par défaut uniquement dans ce profil). Le profil par défaut est `prod` et refuse de démarrer sans secrets et origines CORS de production valides. `DOGO_COOKIE_SECURE=true` et des origines CORS HTTPS exactes sont obligatoires en production.

Lancer le backend en mode démonstration depuis `dogo-backend/` :

```powershell
mvn spring-boot:run "-Dspring-boot.run.profiles=demo"
```

Le serveur écoute sur `http://localhost:8080`. Le profil `demo` ajoute des comptes de démonstration, expose l'OTP d'inscription et simule les SMS et Mobile Money. Il est réservé au développement et à la soutenance ; ne pas l'activer en production. La configuration des variables et les comptes de démonstration sont décrits dans [dogo-backend/README.md](dogo-backend/README.md).

Lancer la console Angular dans un autre terminal :

```powershell
Set-Location dogo-angular
npm ci
npm start
```

Ouvrir `http://localhost:4200`.

Lancer l'application Flutter dans un autre terminal :

```powershell
Set-Location dogo-flutter
flutter pub get
flutter run -d chrome
```

Par défaut, Flutter Web appelle l'API sur `http://localhost:8080`. Sur un téléphone ou un émulateur, définir l'adresse API avec les options `--dart-define` décrites dans `dogo-flutter/lib/services/api/api_config.dart`.

## Vérifications

Exécuter les contrôles depuis le dossier de chaque application :

```powershell
# Flutter
flutter analyze
flutter test

# Angular
npm test -- --watch=false
npm run build

# Backend
mvn test
```

`mvn verify` lance aussi les tests d'intégration MySQL. Ils vident et reconstruisent la base `dogo_test` : ne les lancer que si cette base est jetable.

## Documentation

- [Architecture et séquences métier](docs/ARCHITECTURE.md)
- [Contrats API](dogo-backend/docs/API.md)
- [Présentation détaillée du backend et parcours de démonstration](dogo-backend/README.md)
- [Diagramme de classes](docs/diagrams/diagramClass.xml)
- [Diagramme de cas d'utilisation](docs/diagrams/DiagramsUseCase.xml)
- [Identité visuelle](docs/images/Design%20System.svg)

## Limites et sécurité à traiter

- Le profil `demo` ne représente pas une intégration réelle d'opérateur SMS ou Mobile Money.
- La migration Flyway V11 donne le même mot de passe de démonstration à tous les comptes déjà présents lors de son exécution. Ne pas l'appliquer à une base contenant de vrais comptes ; toute correction doit préserver les installations existantes et prévoir une procédure de réinitialisation.
- Les tests d'intégration et un démarrage complet avec une base MySQL n'ont pas été vérifiés par l'audit courant.
