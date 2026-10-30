# Guide de configuration Google Sign-In & Fédération OAuth2 Karavan

Ce document détaille, pas à pas, la configuration de l'authentification Google (OAuth 2.0 / OpenID Connect) pour la plateforme Karavan sur l'ensemble des cibles : **Backend Spring Boot**, **Application mobile/web Flutter** et **Console d'administration Angular**.

---

## 1. Configuration de la Console Google Cloud

### Étape 1 : Création du projet Google Cloud
1. Rendez-vous sur la [Google Cloud Console](https://console.cloud.google.com/).
2. Créez un nouveau projet (ex. `karavan-prod` ou `karavan-dev`).
3. Notez le **Numéro du projet** et l'**ID du projet**.

### Étape 2 : Écran de consentement OAuth
1. Accédez au menu **API et services** > **Écran de consentement OAuth**.
2. Sélectionnez **Utilisateurs externes** puis cliquez sur **Créer**.
3. Renseignez les informations de base :
   - **Nom de l'application** : `Karavan`
   - **Adresse e-mail d'assistance utilisateur** : votre adresse e-mail administrateur.
   - **Logo** : logo officiel Karavan (carré 120x120px recommandé).
   - **Domaine de l'application** : page d'accueil, conditions d'utilisation, politique de confidentialité.
   - **Coordonnées du développeur** : votre adresse e-mail.
4. Dans l'onglet **Champs d'application (Scopes)**, ajoutez :
   - `.../auth/userinfo.email`
   - `.../auth/userinfo.profile`
   - `openid`
5. Dans l'onglet **Utilisateurs test** (pendant la phase de développement) :
   - Ajoutez les adresses Gmail utilisées pour tester l'application avant la vérification publique.
6. Cliquez sur **Enregistrer et continuer**.

---

## 2. Création des Identifiants OAuth 2.0

Dans **API et services** > **Identifiants**, vous devez créer **3 identifiants distincts** qui partagent le même projet :

### A. Identifiant Client Web (OBLIGATOIRE - `serverClientId`)
> Cet identifiant est le pivot central de la sécurité : c'est l'audience (`aud`) vérifiée par le backend Spring Boot.

1. Cliquez sur **Créer des identifiants** > **ID client OAuth**.
2. Type d'application : **Application Web**.
3. Nom : `Karavan Web & Backend Aud`.
4. **Origines JavaScript autorisées** :
   - `http://localhost:4200` (Console Angular locale)
   - `http://localhost:3000` (Flutter Web local)
   - `https://admin.karavan.ml` (Production Angular)
   - `https://app.karavan.ml` (Production Flutter Web)
5. **URI de redirection autorisés** :
   - `http://localhost:4200`
   - `http://localhost:3000`
6. Cliquez sur **Créer** et copiez l'**ID Client** (ex: `1234567890-xxx.apps.googleusercontent.com`).

---

### B. Identifiant Client Android (Application Flutter Android)
1. Cliquez sur **Créer des identifiants** > **ID client OAuth**.
2. Type d'application : **Android**.
3. Nom : `Karavan Android App`.
4. **Nom du package** : `ml.dogo.karavan` (ou le nom défini dans `android/app/build.gradle`).
5. **Empreinte numérique du certificat SHA-1** :
   - Pour obtenir la clé SHA-1 de debug locale, exécutez dans le terminal :
     ```bash
     cd karavan-flutter/android
     ./gradlew signingReport
     ```
     ou via `keytool` :
     ```bash
     keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
     ```
   - Pour la production, extrayez l'empreinte SHA-1 de votre clé de signature release (`upload-keystore.jks`) ou depuis la console Google Play (Signature d'application Play).
6. Cliquez sur **Créer**.

---

### C. Identifiant Client iOS (Application Flutter iOS)
1. Cliquez sur **Créer des identifiants** > **ID client OAuth**.
2. Type d'application : **iOS**.
3. Nom : `Karavan iOS App`.
4. **ID de bundle** : `ml.dogo.karavan`.
5. Cliquez sur **Créer**.
6. Copiez le **Schéma d'URL inversé** (ex: `com.googleusercontent.apps.1234567890-yyy`).
7. Dans `karavan-flutter/ios/Runner/Info.plist`, ajoutez :
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleTypeRole</key>
           <string>Editor</string>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>com.googleusercontent.apps.1234567890-yyy</string>
           </array>
       </dict>
   </array>
   ```

---

## 3. Configuration des Variables d'Environnement

### Backend Spring Boot
Dans votre fichier d'environnement ou variables de production :
```bash
# Variable système ou conteneur Docker
export DOGO_GOOGLE_CLIENT_ID="1234567890-xxx.apps.googleusercontent.com"
```
Ou dans `application.yml` :
```yaml
dogo:
  google:
    client-id: ${DOGO_GOOGLE_CLIENT_ID:1234567890-xxx.apps.googleusercontent.com}
```

### Application Flutter
Lors du build ou du lancement de Flutter, injectez l'ID Client Web via `--dart-define` :
```bash
flutter run --dart-define=GOOGLE_CLIENT_ID=1234567890-xxx.apps.googleusercontent.com
flutter build apk --dart-define=GOOGLE_CLIENT_ID=1234567890-xxx.apps.googleusercontent.com
```
Par défaut, `ApiConfig.googleClientId` lit cette variable via `String.fromEnvironment('GOOGLE_CLIENT_ID')`.

### Console Angular
Dans `karavan-angular/src/index.html`, le script Google Identity Services est déjà injecté :
```html
<script src="https://accounts.google.com/gsi/client" async defer></script>
```
L'ID client Web est initialisé dans `login.ts` via `google.accounts.id.initialize({ client_id: '...' })`.

---

## 4. Mode Développement & Tests sans identifiants GCP

Pour faciliter les tests locaux et l'intégration continue sans dépendre d'une connexion Internet ou de clés Google actives, le système inclut un **émulateur de jetons Google** :

1. En profil Spring Boot `demo`, `test` ou `local`, tout jeton commençant par :
   ```text
   mock-google-token:<sub-unique>:<email>:<email_verified>:<nom>:<photo_url>
   ```
   est validé directement sans requête externe vers les serveurs de clés publiques de Google.
2. Dans Flutter, si aucun `GOOGLE_CLIENT_ID` n'est fourni, cliquer sur le bouton Google ouvre la boîte de dialogue assistée Karavan permettant de tester immédiatement le parcours complet (connexion directe, complétion de profil, 2FA OTP, fusion de comptes).
3. Dans Angular, le bouton de repli permet de tester la connexion Google en un clic.

