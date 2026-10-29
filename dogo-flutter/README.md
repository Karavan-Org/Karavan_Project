# Application mobile Dɔgɔ

Client Flutter pour les espaces commerçant, grossiste et courtier. Le backend Spring Boot fournit les données métier et l'authentification. Voir le [README racine](../README.md) pour lancer l'ensemble du projet.

## Développement

```powershell
flutter pub get
flutter run -d chrome
```

Flutter Web utilise `http://localhost:8080` par défaut. Pour pointer vers une autre API, définir `ip` et éventuellement `port` :

```powershell
flutter run -d chrome --dart-define=ip=192.168.1.10 --dart-define=port=8080
```

Sur un appareil physique, remplacer l'adresse par l'adresse réseau de la machine qui exécute le backend. Ne pas utiliser `localhost` depuis le téléphone.

## Contrôles

```powershell
flutter analyze
flutter test
flutter build web
```

Les journaux de `flutter analyze` distinguent les erreurs des lints informatifs. Le profil backend `demo` et ses comptes partagés sont réservés au développement.
