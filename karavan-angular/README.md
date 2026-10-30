# Console d'administration Dɔgɔ

Application Angular de supervision de la plateforme. Les routes d'administration sont protégées par les permissions du compte ; le backend reste l'autorité pour les contrôles d'accès. La connexion s'appuie sur un cookie de rafraîchissement HttpOnly et un jeton d'accès gardé en mémoire.

Voir le [README racine](../README.md) pour le démarrage de l'API et de l'application Flutter.

## Développement

```powershell
npm ci
npm start
```

La console est disponible sur `http://localhost:4200` et utilise l'API locale sur le port `8080`.

## Vérifications

```powershell
npm test -- --watch=false
npm run build
```
