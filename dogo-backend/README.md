# DoGo (dɔgɔ) — Backend

Plateforme d'**achats groupés Chine → Mali** : des commerçants se regroupent pour acheter chez un grossiste, un courtier organise le convoi, l'argent reste **en séquestre** jusqu'au retrait des marchandises, et un back-office d'administration valide, contrôle et audite.

Java 21 · Spring Boot 3.5 · Maven · MySQL 8 · Flyway · JWT + sessions serveur · Swagger

---

## 1. Démarrer

### Prérequis
- JDK 21 et Maven 3.9 (ou l'extension *Spring Boot Extension Pack* de VS Code, qui les pilote)
- MySQL 8 démarré en local

### Base de données
Les tables sont créées automatiquement par Flyway (`src/main/resources/db/migration`, V1 → V19). Il suffit que MySQL tourne :

```sql
CREATE DATABASE dogo CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
```

Le profil par défaut est `prod` : sans profil local explicite, l'application exige des identifiants DB, secrets et origines CORS de production valides et refuse le démarrage si des comptes conservent le mot de passe partagé de V11. En local, activez le profil `local`, qui se connecte par défaut à `localhost:3306/dogo` avec `root` / `1234` :

```bash
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

Variables d'environnement :

| Variable | Rôle | Défaut |
|---|---|---|
| `DB_URL`, `DB_USER`, `DB_PASSWORD` | connexion MySQL | `root`, `1234` (local uniquement) |
| `DOGO_JWT_SECRET` | clé de signature aléatoire (32 caractères minimum, 3 catégories de caractères) | valeur de démo |
| `DOGO_MM_SECRET` | secret partagé de signature des callbacks Mobile Money | valeur de démo |
| `DOGO_CORS_ORIGINS` | origines exactes en HTTPS, séparées par des virgules en production | origines locales |
| `DOGO_COOKIE_SECURE` | exige le transport HTTPS pour le cookie de session en production | `false` localement, requis à `true` en production |
| `DOGO_ADMIN_TELEPHONE`, `DOGO_ADMIN_MOT_DE_PASSE` | crée l'administrateur TECHNIQUE au premier démarrage (hors démo) | — |
| `DOGO_STOCKAGE` | dossier des documents KYC | `./donnees/fichiers` |

> Compte MySQL dédié : créer les triggers d'audit demande le droit `TRIGGER` **et**, si le journal binaire est actif, `SET GLOBAL log_bin_trust_function_creators = 1;` (erreur 1419 sinon). En local, `root` évite le problème.

En production, utilisez explicitement le profil `prod`, une base et un utilisateur dédiés, des secrets aléatoires forts, des origines CORS HTTPS exactes et `DOGO_COOKIE_SECURE=true`. Le démarrage échoue si le hachage de mot de passe partagé introduit par V11 subsiste dans la table `utilisateur` : réinitialisez ces comptes avant la mise en service.

### Lancer avec les données de démonstration
```bash
mvn spring-boot:run -Dspring-boot.run.profiles=demo
```
(ou, dans VS Code, ajouter `--spring.profiles.active=demo` aux arguments de lancement de `DogoApplication`).

- Swagger : <http://localhost:8080/swagger-ui.html> (bouton **Authorize** : coller le jeton obtenu à la connexion)
- Santé : <http://localhost:8080/actuator/health>

### Comptes de démonstration (mot de passe de tous : `Dogo2026!`)
| Rôle | Téléphone |
|---|---|
| Administrateur TECHNIQUE / VALIDATION / FINANCE / SUPPORT | `+22370000001` / `…02` / `…03` / `…04` |
| Grossiste (avec un produit « Baskets Sport Homme » en stock) | `+22371000001` |
| Courtier (avec un compte Mobile Money pour ses retraits) | `+22372000001` |
| Commerçants | `+22373000001`, `+22373000002`, `+22373000003` |

Le profil `demo` active aussi : le code OTP visible dans la réponse d'inscription, des SMS et un Mobile Money **simulés** (les messages apparaissent dans les journaux), et le simulateur d'opérateur `/api/dev/mobile-money/{paiementId}/succes|echec`.

---

## 2. Parcours de démonstration (dans Swagger)

1. **Connexion** de chacun : `POST /api/auth/connexion` `{ "telephone": "+22372000001", "motDePasse": "Dogo2026!" }` → copier `jeton`.
2. **Courtier** : `GET /api/catalogue/produits` (avec le jeton du grossiste) pour l'identifiant du produit, puis `POST /api/groupes` (quantité cible, date limite, marchandise, transport, douane, autres) → le prix unitaire est calculé (RG-20). `POST /api/groupes/{id}/soumission`.
3. **Grossiste** : `POST /api/groupes/{id}/disponibilite` (le stock doit couvrir la cible, RG-18).
4. **Administrateur** : `POST /api/admin/groupes/{id}/publication` `{ "approuve": true }` → le groupe est `OUVERT`.
5. **Commerçants** : `POST /api/groupes/{id}/participations` (variante + quantité) → réservation de 15 minutes (RG-28) ; `POST /api/participations/{id}/paiement` avec l'en-tête `Idempotency-Key` ; puis simuler l'opérateur : `POST /api/dev/mobile-money/{paiementId}/succes`. L'argent passe en **séquestre** et la participation devient `CONFIRMEE`.
6. Quand la quantité confirmée atteint la cible, le groupe passe à `OBJECTIF_ATTEINT` et **les commandes sont créées** (`GET /api/moi/commandes`).
7. **Courtier** : `POST /api/groupes/{id}/preparation`, puis `/expedition`. **Administrateur** : `POST /api/admin/groupes/{id}/reception`. **Courtier** : `POST /api/groupes/{id}/reception-point-retrait` `{ "pointRetraitId": 1 }` → chaque commande reçoit son code (PIN envoyé par SMS, QR disponible dans l'application).
8. **Commerçant** : `GET /api/commandes/{id}/code-retrait` → jeton du QR. **Courtier** : `POST /api/retraits/valider` avec `{ "qrToken": "…" }` (ou `{ "commandeId": 1, "pin": "123456" }`) → commande `COLLECTEE`, séquestre libéré vers le portefeuille du courtier (moins les frais de plateforme).
9. **Courtier** : `GET /api/moi/portefeuille`, `POST /api/moi/portefeuille/retraits` (avec `Idempotency-Key`).
10. **Administrateur** : `GET /api/admin/audit/verification` → la chaîne du journal d'audit est intacte.

La liste complète des routes et des droits est dans [`docs/API.md`](docs/API.md).

---

## 3. Architecture

**Monolithe modulaire** : un seul déployable, huit modules aux frontières strictes.

```
ml.dogo
├── identite      inscription, OTP, PIN, sessions, KYC, comptes, administrateurs
├── catalogue     catégories, produits, variantes, stock
├── groupeachat   groupes d'achat, grille tarifaire, machine à états, expiration
├── participation réservations, participations, annulations
├── finance       paiements, séquestre, portefeuille courtier, remboursements, devises
├── logistique    commandes, expéditions, acheminement, codes de retrait, preuves
├── litige        gestion des contestations, réclamations et preuves
├── notification  SMS (simulés) avec relance
├── audit         journal chaîné par hachage, en ajout seul
├── shared        sécurité JWT, configuration, erreurs, stockage de fichiers
└── demo          données d'exemple (profil « demo » uniquement)
```

Chaque module a les couches `domain` (règles pures, testées sans Spring), `persistence`, `application`, `web` et `api`. **Seul `api` est visible des autres modules** ; les modules se parlent par ces interfaces et par des événements synchrones (`ObjectifAtteint`, `GroupeEchoue`, `GroupeAnnule`, `ParticipationAnnulee`). Le test `ArchitectureTest` (ArchUnit) fait respecter ces règles : domaine pur, sens des couches, accès aux autres modules par `api` seulement, aucun cycle.

### Ce qui garantit la cohérence de l'argent et des stocks
- **Quotas et états par SQL atomique** : réserver des unités, confirmer, changer l'état d'un groupe ou d'un portefeuille sont des `UPDATE … WHERE` conditionnels. Deux acheteurs simultanés ne peuvent pas dépasser la cible (RG-23) ; un groupe ne change d'état que par `MoteurEtatsGroupe`, qui écrit la trace (RG-19).
- **Isolation READ COMMITTED** + verrous d'écriture ciblés (`Verrou`, verrou des commandes d'un groupe) ; un interblocage éventuel est traduit en `409 CONFLIT` (« réessayez »).
- **Séquestre** : le paiement crée un séquestre `BLOQUE` ; il n'est libéré qu'au retrait validé (RG-36), ou restitué en cas d'échec/annulation. Les mouvements financiers sont immuables (trigger MySQL, RG-40) ; les callbacks d'opérateur sont signés (HMAC-SHA256) et rejoués sans effet (référence unique) ; les retraits et paiements acceptent une clé d'idempotence.
- **Compteurs d'échec** (OTP, PIN, code de retrait) écrits dans une transaction indépendante : ils survivent à l'annulation de la tentative (RG-02, RG-07, RG-54).
- **Secrets** : PIN, OTP et PIN de retrait sont hachés (BCrypt), jamais relisibles ; le grossiste ne voit jamais l'identité des acheteurs (RG-71).

### Paramètres métier (`application.yml`)
Commission 5 % · code de retrait valable 7 jours, 3 essais · OTP 2 min, 3 essais · mot de passe : verrouillage 15 min après 5 échecs · session : 30 jours d'inactivité · réservation : 15 min.

---

## 4. Tests

```bash
mvn test      # tests unitaires des règles de gestion (domaine) + tests d'architecture ArchUnit
mvn verify    # + parcours complet de bout en bout (FluxPrincipalIT)
```

`FluxPrincipalIT` rejoue tout le parcours ci-dessus sur une base MySQL locale **`dogo_test`** (créée, vidée et reconstruite à chaque exécution ; mêmes variables `DB_USER` / `DB_PASSWORD`). N'exécuter `mvn verify` qu'avec une base `dogo_test` jetable. Il vérifie au passage les refus attendus : rôle insuffisant, groupe plein, mot de passe erroné trois fois (compte bloqué), ancien code invalidé, double retrait, séquestre libéré seulement à la collecte, chaîne d'audit intacte.

### Statut de vérification
Vérification du 23 octobre 2026 : `mvn test` a exécuté 65 tests unitaires et d'architecture avec succès. Les tests d'intégration (`mvn verify`) n'ont pas été exécutés pendant l'audit : ils vident et reconstruisent `dogo_test`. Le démarrage Spring Boot avec une vraie base reste à vérifier.

---

## 5. Limites connues (hors périmètre de cette livraison)

**Attention avant toute utilisation de données réelles :** la migration V11 affecte le même mot de passe de démonstration à tous les comptes déjà présents au moment de son exécution. Ne pas l'appliquer à des comptes réels. Cette migration étant déjà versionnée, sa correction nécessite une stratégie de migration/réinitialisation des comptes qui préserve les installations existantes.

Le parcours principal est complet. Ne sont **pas** implémentés : le corridor et l'écart de devises (RG-16, RG-42 : tout est en XOF), le convoi et la douane (RG-45 à RG-49), les litiges et le gel de séquestre (RG-61 à RG-64), les avis (RG-65), la réconciliation avec l'opérateur (RG-43) et la libération manuelle du séquestre (RG-39). Mobile Money et SMS sont **simulés** derrière des interfaces (`PasserelleMobileMoney`, `PasserelleSms`) : brancher un vrai opérateur revient à écrire une implémentation. Le journal d'audit sérialise les transactions qui écrivent une trace (tête de chaîne verrouillée) : suffisant pour la démonstration, à revoir pour une forte charge. Un remboursement de groupe entier s'exécute en une seule transaction.
