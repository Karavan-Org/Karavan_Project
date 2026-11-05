# Karavan WP Connect — Extension WordPress Dynamique & Sécurisée

Extension officielle pour connecter n'importe quel site WordPress en temps réel à l'écosystème **Karavan** (achats groupés & fret).

---

## Fonctionnalités

1. **Dynamisme Temps Réel :** Affiche en direct les groupes d'achats en cours, la progression des conteneurs (jauges animées) et les statistiques d'importation sans recharger la page.
2. **Architecture Sécurisée BFF (Backend-For-Frontend) :** Le navigateur ne contacte jamais directement le backend avec des secrets. WordPress agit comme mandataire sécurisé via l'API REST `/wp-json/karavan/v1/`.
3. **Protection Anti-CSRF :** Chaque requête AJAX est validée par un jeton cryptographique **Nonce** WordPress (`wp_create_nonce` & `check_ajax_referer`).
4. **Cache Haute Performance :** Utilise les *Transients* de WordPress (durée configurable, par défaut 5 min) pour garantir des temps de réponse instantanés sans saturer le serveur Spring Boot.
5. **Design System Intégré :** Respecte rigoureusement la charte graphique de Karavan (Camel `#AC7F5E`, Ocre `#EEA823`, Terre `#2C241E`, Crème `#FAF8F5`, Vert Nuit `#183630`, formes douces 24px).

---

## Installation

### Méthode 1 : Copie Directe
Copiez le dossier `karavan-wp-connect` dans le répertoire d'extensions de votre site WordPress :
```
wp-content/plugins/karavan-wp-connect/
```

### Méthode 2 : Téléversement ZIP
Compressez le dossier `karavan-wp-connect` en `karavan-wp-connect.zip`, puis dans l'admin WordPress :
1. Rendez-vous dans **Extensions > Ajouter**.
2. Cliquez sur **Téléverser une extension**.
3. Sélectionnez le fichier ZIP et cliquez sur **Activer**.

---

## Configuration

Dans l'administration WordPress, accédez à **Réglages > Karavan Connect** :
* **URL de l'API Karavan** : 
  * En local : `http://localhost:8080/api`
  * En production (Render/Cloud) : `https://votre-app-backend.onrender.com/api`
* **Durée du cache** : `300` secondes (5 minutes).

---

## Utilisation des Shortcodes

Insérez simplement ces balises dans n'importe quelle page, article ou widget Elementor / Gutenberg :

### 1. Grille Dynamique des Groupes d'Achats
```
[karavan_groupes titre="Opportunités d'importation en cours" limite="6"]
```
* Bouton d'actualisation instantané (AJAX).
* Jauges animées de pourcentage de remplissage.
* Badges de statut et pays d'origine.

### 2. Métriques & Statistiques Clés
```
[karavan_stats]
```
Affiche sous forme de cartes élégantes le nombre de conteneurs en cours, les tonnes de marchandises mutualisées et l'économie moyenne constatée.
