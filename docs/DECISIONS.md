# Registre des Décisions d'Architecture (ADR) - Karavan

## ADR-021 : Fédération d'Identité Google Sign-In & Gestion des Comptes Externes

### Contexte
La plateforme Karavan nécessitait une intégration de Google Sign-In (OAuth2 / OIDC) sur ses trois interfaces :
- **Backend Spring Boot** : vérification cryptographique des ID tokens Google, création de session sécurisée.
- **Application mobile/web Flutter** : bouton natif respectant la charte Google et l'identité Karavan.
- **Console d'administration Angular** : intégration Google Identity Services (GIS) avec cookies HttpOnly.

### Décisions Prises

#### 1. Modèle de Données & Migration V21
- Création de la table `compte_externe` :
  - Colonnes : `id`, `fournisseur` (`GOOGLE`), `sub` (identifiant unique immuable Google), `utilisateur_id` (clé étrangère vers `utilisateur`), `email`, `cree_le`.
  - Contrainte d'unicité : `UNIQUE(fournisseur, sub)`.
  - Suppression en cascade : si un utilisateur est supprimé, ses liaisons externes sont supprimées proprement.
- Assouplissement de la colonne `utilisateur.mot_de_passe_hash` :
  - Rendue `NULLABLE` afin d'accueillir les comptes créés exclusivement via Google sans mot de passe local.
  - Ajout de la colonne `utilisateur.email` pour stocker l'adresse vérifiée transmise par Google.
- Migration Flyway `V21__compte_externe_google.sql` et script de retour arrière `rollback_V21__compte_externe_google.sql`.

#### 2. Logique Métier : Rôle Acheteur par Défaut (`COMMERCANT`)
- **Analyse du modèle de domaine** : La spécification mentionnait un « rôle Client par défaut ». Cependant, l'architecture métier Karavan est une plateforme d'achats groupés B2B internationale reposant sur 3 rôles d'acteurs :
  - `COMMERCANT` : commerçant acheteur (détail/demi-gros) participant aux conteneurs groupés.
  - `GROSSISTE` : importateur / vendeur en gros initiateur de campagnes.
  - `COURTIER` : transitaire / logisticien gérant les convois et le dédouanement.
- **Décision** : Le rôle acheteur par défaut assigné lors d'une inscription Google est `COMMERCANT`. L'écran de finalisation permet également au professionnel d'indiquer son activité (Grossiste, Courtier ou Commerçant). Cela préserve l'intégrité de toutes les règles métier (RG-01 à RG-36), du séquestre financier et de la logistique des dépôts.

#### 3. Primauté du Numéro de Téléphone Malien (+223) & Double Facteur OTP
- Google ne certifie aucun numéro de téléphone malien.
- Or, les flux financiers (Orange Money, Wave, Moov) et les retraits physiques au dépôt central de Bamako exigent un numéro de téléphone vérifié.
- **Décision** :
  - Tout compte Google dont le `sub` est inconnu reçoit un statut `PROFIL_INCOMPLET` avec un jeton temporaire HMAC d'inscription (durée de vie 15 min, usage unique).
  - L'utilisateur doit impérativement saisir son numéro de téléphone (+223) et valider le code OTP reçu par SMS.
  - **Fusion de compte** : Le numéro de téléphone vérifié constitue la clé d'unicité absolue. Si le numéro confirmé appartient déjà à un utilisateur de la plateforme, le compte Google (`sub`) est immédiatement rattaché à cet utilisateur existant. Il n'existe jamais de doublon.

#### 4. Comptes Google sans mot de passe & Sécurité RG-07
- Pour les comptes Google sans mot de passe local :
  - La règle RG-07 (mot de passe 8-64 caractères) ne bloque pas la connexion Google.
  - En cas de tentative de connexion classique (Téléphone + Mot de passe) sur un tel compte, le backend renvoie une erreur explicite invitant à se connecter avec Google ou à utiliser « Mot de passe oublié ? ».
  - L'utilisateur peut à tout moment définir un mot de passe classique depuis son profil ou via la réinitialisation par code OTP.

#### 5. Sécurité, Cache des Clés et Traçabilité
- Les clés publiques de signature Google (`https://www.googleapis.com/oauth2/v3/certs`) sont mises en cache en mémoire via le composant officiel `GoogleIdTokenVerifier` avec rafraîchissement automatique.
- Les jetons d'identification bruts ne sont jamais journalisés dans les logs applicatifs (seul le `sub` est consigné dans le journal d'audit `JournalAuditService`).
- Un limiteur de débit par IP (`LimiteurDebitIp`) bloque les attaques par force brute (seuil configuré à 20 requêtes/minute par adresse IP).



## ADR-022 : Code de Sécurité à 4 Chiffres pour Validation des Actions Administrateur

### Contexte
La console d'administration Karavan permet des actions à fort impact : validation/rejet de dossiers KYC, suspension ou réactivation de comptes, envoi de notifications SMS/In-App, diffusion d'alertes groupées, libération de séquestres et création de comptes administrateurs.
Pour prévenir les erreurs de manipulation et les compromissions de session active laissée ouverte, un second facteur de confirmation à 4 chiffres (PIN Administrateur) est exigé à chaque action sensible.

### Décisions Prises

#### 1. Modèle de Données & Migration V22
- Ajout de colonnes dédiées dans la table `administrateur` :
  - `code_securite_hash VARCHAR(100) NULL` : hash BCrypt du code PIN à 4 chiffres.
  - `code_securite_date TIMESTAMP NULL` : date de configuration ou dernière modification.
- Migration Flyway `V22__admin_code_securite.sql` et rollback `rollback_V22__admin_code_securite.sql`.

#### 2. Workflow de Configuration
- À la connexion d'un administrateur, si son code à 4 chiffres n'est pas encore configuré (`code_securite_hash IS NULL`), une modale de configuration s'ouvre automatiquement pour lui demander de définir son code à 4 chiffres.
- L'administrateur peut à tout moment modifier son code depuis son profil (barre latérale `🔒 Code de sécurité (4 chiffres)`). Si un code existe déjà, la saisie de l'ancien code est obligatoire.
- Format strictement imposé : exactement 4 chiffres (`^\d{4}$`).

#### 3. Déclenchement & Validation lors des Actions Sensibles
- Toute action sensible requiert la saisie du code à 4 chiffres via une modale sécurisée dédiée :
  - **Validation KYC & Rejet KYC** (Grossistes et Courtiers).
  - **Suspension / Réactivation de comptes**.
  - **Envois de notifications** (messages de support, notification d'arrivée au dépôt avec lien GPS).
  - **Création de nouveaux comptes administrateurs**.
- Le backend valide cryptographiquement le code (`POST /api/admin/securite/verifier`). Si le code est invalide ou absent, l'action est rejetée avec le code d'erreur HTTP 403 `CODE_SECURITE_INVALIDE` (règle `RG-SEC-02`), et l'échec est tracé dans le journal d'audit.
