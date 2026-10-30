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

## ADR-023 : Nouveau Tableau de Bord Administrateur (Globe Terrestre 3D & Cadran des Groupes) et Pays d'Origine

### Contexte
La supervision des flux d'importation internationaux de Karavan nécessitait une refonte majeure de l'accueil administrateur pour offrir une vue spatiale 3D et interactive des importations vers le hub central de Bamako (Mali).

### Décisions Prises

#### 1. Modèle de Données & Migration V23
- Table de référence `pays` : `code_iso` (PK, 2 lettres), `code_iso3`, `nom_fr`, `latitude`, `longitude` (centroïdes), `actif`.
- Données initiales : pays plausibles pour l'import malien (Chine, Turquie, Émirats arabes unis, Inde, France, Maroc, Sénégal, Côte d'Ivoire, Ghana, Nigéria) et le Mali comme hub de convergence.
- Colonne nullable `pays_origine_code` sur la table `groupe_achat` avec clé étrangère vers `pays(code_iso)`.
- Migration Flyway `V23__pays_origine_groupes.sql` et script de rollback `rollback_V23__pays_origine_groupes.sql`.

#### 2. Règle Métier RG-PAYS
- Tout NOUVEAU groupe d'achat créé par un grossiste ou un courtier DOIT obligatoirement avoir son pays d'origine renseigné (`paysOrigineCode != null`).
- La publication ou validation d'un groupe sans pays d'origine est systématiquement refusée par le backend (code `DONNEES_INVALIDES`, règle `RG-PAYS`).
- Côté mobile/web Flutter, intégration d'un sélecteur dédié `SelecteurPays` avec recherche textuelle et drapeaux emojis dans les formulaires de création grossiste et courtier.

#### 3. Remplacement du Tableau de Bord Administrateur Angular
- L'ancien accueil `DashboardComponent` est supprimé au profit de `TableauDeBordComponent` chargé sur la route par défaut `/admin` (avec redirection rétro-compatible de `/dashboard`).
- **Zone Centrale (A)** : Globe 3D interactif basé sur `globe.gl` et Three.js utilisant les contours GeoJSON locaux (`assets/geo/ne_110m_admin_0_countries.geojson`, 0 dépendance externe/payante). Arcs lumineux animés reliant chaque pays source à Bamako (lat 12.6392, lon -8.0029). Auto-rotation douce et recentrage interactif.
- **Zone Gauche (B)** : Cadran rotatif circulaire des groupes avec jauge de progression, pilules de statut, navigation scroll/clavier et accroche magnétique.
- **Zone Droite (C)** : Statistiques en temps réel (volume sous séquestre FCFA, barres de répartition par pays, alertes retards, encart de rattrapage en 1 clic pour anciens groupes sans pays).
- **Tiroir Latéral Coulissant** : panneau détaillé sans quitter la page (décomposition des coûts, intervenants, chronologie logistique, bouton fiche complète).
- Préservation intégrale des fonctionnalités antérieures, notamment la génération et le téléchargement du rapport PDF complet (`jsPDF` et `autoTable`).



## ADR-024 : Configuration Différée du Nom de Boutique/Société & Emplacement sur Carte/GPS dans les Paramètres

### Contexte
Afin de fluidifier l'expérience d'inscription des utilisateurs (Commerçants, Grossistes et Courtiers), le renseignement du nom de la boutique ou société ainsi que la localisation géographique précise (quartier, coordonnées GPS) ne doivent plus bloquer le formulaire d'inscription. Ces informations doivent être configurables et modifiables ultérieurement depuis l'écran **Paramètres**.

### Décisions Prises

#### 1. Modèle de Données & Migration V24
- Ajout de colonnes géographiques et de localisation :
  - `commercant` : `latitude DOUBLE NULL`, `longitude DOUBLE NULL`.
  - `grossiste` : `latitude DOUBLE NULL`, `longitude DOUBLE NULL`, `quartier_marche VARCHAR(120) NULL`.
  - `courtier` : `latitude DOUBLE NULL`, `longitude DOUBLE NULL`.
- Migration additive Flyway `V24__coordonnees_emplacement_acteurs.sql` et script de retour arrière `rollback_V24__coordonnees_emplacement_acteurs.sql`.

#### 2. Assouplissement de l'Inscription (Backend & Mobile)
- Dans `InscriptionService.java` :
  - `nomBoutique`, `nomBoutiqueMarche` et `nomSocieteImport` sont désormais optionnels lors de l'appel d'inscription.
  - S'ils ne sont pas fournis, ils prennent automatiquement pour valeur par défaut `"Boutique " + nom` ou `"Société " + nom`.
- Dans `commercant_inscription_screen.dart` :
  - Suppression des champs préalables "Nom de la boutique", "Quartier", "Licence" et "Dépôt".
  - Le formulaire d'inscription est allégé (Nom, Téléphone, Mot de passe, Confirmation) avec un encart explicatif informant que la structure et l'emplacement se configurent dans les Paramètres.

#### 3. Gestion dans l'Écran Paramètres (`ParametresCompteScreen`)
- Ajout d'une section dédiée **« BOUTIQUE & EMPLACEMENT »** (ou **« SOCIÉTÉ & DÉPÔT »** pour les courtiers) :
  - **Modification du nom de la structure** : boîte de dialogue interactive pour modifier le nom de la boutique ou de la société de transit.
  - **Localisation sur carte interactive** : ouverture de `SelecteurEmplacementCarteDialog` exploitant `flutter_map` et les tuiles OpenStreetMap avec un pointeur interactif (déplacement au toucher, calcul en temps réel des coordonnées GPS, recentrage sur Bamako).
  - **Saisie directe des coordonnées** : boîte de dialogue `SaisieCoordonneesDialog` permettant la saisie manuelle de la latitude, de la longitude et du nom du quartier/repère.
- Les modifications sont enregistrées via l'endpoint sécurisé `PATCH /api/moi`.

#### 4. Didacticiel Guidé (`DidacticielGuideOverlay`)
- Mise à jour des étapes du didacticiel pour les trois rôles :
  - Commerçant : ajout d'une étape dédiée invitant à configurer sa boutique et son emplacement GPS dans l'onglet Paramètres.
  - Grossiste : mise à jour de l'étape de l'en-tête pour mettre en valeur la localisation sur la carte.
  - Courtier : mise à jour de l'étape de profil pour guider la localisation du dépôt de transit.


## ADR-022 : Tableau de Bord Administrateur Karavan — Globe Terrestre 3D & Cadran Horizontal des Groupes

### Contexte
L'interface d'administration Karavan nécessitait une refonte complète de sa page d'accueil (`/admin`) pour offrir une supervision immersive des flux d'achats groupés internationaux convergeant vers le hub de Bamako (Mali).
La maquette cible (image Figma de référence) présente :
- Un Globe terrestre 3D réaliste (Three.js / Globe.gl) avec texture Blue Marble, atmosphère bleue et anneaux orbitaux.
- Des marqueurs géographiques dynamiques pour chaque pays d'origine de convoi (avec drapeaux et coordonnées réelles).
- Un Cadran rotatif 3D horizontal des groupes (demi-cylindre mécanique en perspective) enveloppant la partie inférieure de la planète avec drapeaux ISO, identifiants `#ID`, pays, visuels des produits et prix.
- Un panneau rétractable « Statistiques générales » (fermé par défaut, ouverture au clic sur le bouton de l'en-tête ou depuis la barre latérale, et fermeture via une croix `✕`).

### Décisions Prises

#### 1. Persistance et dynamique des données
- Aucune donnée statique dans l'interface d'administration : tous les compteurs, groupes, flux d'activité récente et drapeaux proviennent des endpoints Spring Boot `/api/admin/tableau-de-bord/resume` et `/api/admin/tableau-de-bord/groupes`.
- Amorçage au démarrage (`AmorcageGroupesDemo.java`) : si la table des groupes d'achats est vide, amorçage automatique de convois actifs représentatifs des corridors réels (Côte d'Ivoire, Sénégal, Maroc, Ghana, Chine, Turquie, Brésil) avec leurs grossistes, produits, photos et prix unitaires.

#### 2. Expérience Utilisateur et Interactivité
- **Globe 3D interactif** : au clic sur une carte du cadran ou lors de la rotation (`[ Tourner le cadran ]`, flèches `<` / `>`), la caméra du globe WebGL pivote automatiquement pour centrer le pays d'origine sélectionné.
- **Tiroir Statistiques Générales** : fermé par défaut conformément aux consignes. L'administrateur peut l'ouvrir d'un clic sur `[ Statistiques ]` dans l'en-tête ou en cliquant sur « Tableau de bord » dans la barre latérale, et le refermer d'un clic sur la croix `✕`.
- **Fiche de détail d'un groupe** : tiroir latéral droit s'ouvrant à la sélection d'un groupe pour visualiser le détail complet du convoi.


#### 3. Barre Latérale Rétractable (Mode Miniature & Étendu) et Navigation Retour
- **Barre latérale rétractable (deux états)** :
  - **État étendu (240px)** : identité de marque Karavan, titres de rubriques, libellés de menus, badges KYC / modération, et bouton de réduction `[ < ] Réduire la barre`.
  - **État miniature (72px)** : affichage compact épuré avec icônes centrées, infobulles flottantes au survol (`.floating-tooltip`) indiquant le nom de chaque page (style maquette Figma), et bouton d'expansion `[ > ]`.
  - Navigation continue en mode miniature : les icônes restent 100% interactives et cliquables pour les administrateurs habitués à l'emplacement des pages.
  - Mémorisation de l'état réduit dans `localStorage` (`karavan_sidebar_reduite`).
- **Bouton « Retour au Tableau de bord »** :
  - Présent en en-tête global sur toutes les pages administratives secondaires (`/utilisateurs`, `/groupes`, `/finance`, etc.) pour revenir instantanément au Globe 3D et au cadran d'accueil en un seul clic.


## ADR-023 : Administrateur principal unique et mot de passe provisoire obligatoire

### Contexte
Les bases contenaient des comptes administrateurs de démonstration (`+22370000001` à `+22370000005`, mot de passe partagé) et la console affichait des identifiants pré-remplis. La plateforme doit démarrer avec un seul responsable identifié, qui constitue ensuite son équipe.

### Décisions Prises

#### 1. Migration V26 (`V26__administrateur_principal.sql`)
- Suppression de tous les administrateurs existants et de leurs données propres (sessions, notifications, moyens de paiement, codes OTP, portefeuille vide).
- Le journal d'audit (RG-66, RG-67) n'est pas modifié : il est en ajout seul et chaîné ; ses lignes gardent l'identifiant de l'ancien acteur.
- Les décisions KYC et de publication déjà prises sont conservées ; leur auteur devient `NULL` (inconnu) plutôt que d'être réattribué à quelqu'un qui ne les a pas prises (`validation_compte.administrateur_id` et `validation_groupe.administrateur_id` deviennent nullables).
- Création de l'**administrateur principal** : Salif Modibo Keita, `+22375250430`, `salifmodibok@gmail.com`, fonction `TECHNIQUE`, matricule `ADM-0001`, mot de passe provisoire `1234`.
- Le chargeur de démonstration (`ChargeurDemo`, profil `demo`) ne crée plus aucun administrateur ; l'amorçage par variables `DOGO_ADMIN_*` est supprimé.

#### 2. Mot de passe provisoire (RG-07b)
- Colonne `utilisateur.mot_de_passe_provisoire`, levée pour l'administrateur principal et pour chaque administrateur créé depuis la console.
- Tant qu'elle est levée, `FiltreMotDePasseProvisoire` refuse toute route hors `GET /api/moi`, `POST /api/moi/mot-de-passe`, `POST /api/moi/deconnexion` et `/api/auth/**` (403, code `MOT_DE_PASSE_PROVISOIRE`).
- Le nouveau mot de passe d'un administrateur doit être robuste (8 à 64 caractères, majuscule, minuscule, chiffre) et différent de l'actuel ; l'ancien mot de passe est toujours exigé.
- Console Angular : page plein écran `/premiere-connexion`, imposée par les gardes de route et par l'intercepteur HTTP ; reconnexion automatique après le changement (le backend ferme toutes les sessions du compte).

#### 3. Fonctions administratives (RG-06)
- `TECHNIQUE` est réservé à l'administrateur principal : il est le seul à créer des administrateurs et ne peut pas attribuer cette fonction.
- Les autres fonctions (`VALIDATION`, `FINANCE`, `SUPPORT`, `LOGISTIQUE`) fixent les permissions de l'administrateur. Source unique : `AuthService.permissionsAdministratives`, exposée par `GET /api/admin/fonctions-administratives` et affichée dans la console au moment de la création.

#### 4. Code de sécurité à 4 chiffres
- Distinct du mot de passe : au premier paramétrage, l'administrateur saisit le code provisoire `1234` puis choisit son code personnel (voir ADR-022, RG-SEC-03).
