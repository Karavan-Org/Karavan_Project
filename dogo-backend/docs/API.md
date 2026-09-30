# API REST de DoGo

Toutes les routes sont préfixées par `/api`. L'authentification se fait par jeton JWT (`Authorization: Bearer …`, obtenu par `POST /api/auth/connexion`). 
La colonne « Droit » est la permission exigée (RG-06) ; « connecté » = tout utilisateur authentifié, « public » = sans jeton. 
La documentation interactive (Swagger) est disponible sur `/swagger-ui.html`. Le tableau est généré à partir des contrôleurs.


## Identité (inscription, connexion, profil, KYC, comptes)

| Méthode | Route | Droit |
|---|---|---|
| POST | `/api/admin/administrateurs` | `ADMIN_CREER` |
| POST | `/api/admin/comptes/{id}/reactivation` | `COMPTE_SUSPENDRE` |
| POST | `/api/admin/comptes/{id}/suspension` | `COMPTE_SUSPENDRE` |
| GET | `/api/admin/kyc` | `KYC_VALIDER` |
| POST | `/api/admin/kyc/{dossierId}/decision` | `KYC_VALIDER` |
| GET | `/api/admin/kyc/{dossierId}/documents/{documentId}` | `KYC_VALIDER` |
| POST | `/api/auth/connexion` | public |
| POST | `/api/auth/inscription` | public |
| POST | `/api/auth/renvoyer-otp` | public |
| POST | `/api/auth/verifier-otp` | public |
| POST | `/api/kyc` | `KYC_SOUMETTRE` |
| GET | `/api/kyc/moi` | `KYC_SOUMETTRE` |
| GET | `/api/moi` | `PROFIL_GERER` |
| PATCH | `/api/moi` | `PROFIL_GERER` |
| POST | `/api/moi/deconnexion` | connecté |
| GET | `/api/moi/moyens-paiement` | `PROFIL_GERER` |
| POST | `/api/moi/moyens-paiement` | `PROFIL_GERER` |
| DELETE | `/api/moi/moyens-paiement/{id}` | `PROFIL_GERER` |
| PUT | `/api/moi/moyens-paiement/{id}/defaut` | `PROFIL_GERER` |

## Catalogue (grossiste)

| Méthode | Route | Droit |
|---|---|---|
| GET | `/api/catalogue/categories` | connecté |
| GET | `/api/catalogue/produits` | `CATALOGUE_GERER` |
| POST | `/api/catalogue/produits` | `CATALOGUE_GERER` |
| PUT | `/api/catalogue/produits/{id}` | `CATALOGUE_GERER` |
| POST | `/api/catalogue/produits/{id}/variantes` | `CATALOGUE_GERER` |
| PATCH | `/api/catalogue/variantes/{id}/stock` | `CATALOGUE_GERER` |

## Groupes d'achat

| Méthode | Route | Droit |
|---|---|---|
| GET | `/api/admin/groupes/en-validation` | `GROUPE_PUBLICATION_VALIDER` |
| POST | `/api/admin/groupes/{id}/publication` | `GROUPE_PUBLICATION_VALIDER` |
| GET | `/api/groupes` | `CAMPAGNE_EXPLORER` |
| POST | `/api/groupes` | `GROUPE_CREER` |
| GET | `/api/groupes/a-valider` | `GROUPE_DISPONIBILITE_VALIDER` |
| GET | `/api/groupes/mes-groupes` | `GROUPE_CREER` |
| GET | `/api/groupes/{id}` | connecté |
| PUT | `/api/groupes/{id}` | `GROUPE_CREER` |
| POST | `/api/groupes/{id}/annulation` | `GROUPE_ANNULER` |
| POST | `/api/groupes/{id}/disponibilite` | `GROUPE_DISPONIBILITE_VALIDER` |
| GET | `/api/groupes/{id}/historique` | connecté |
| POST | `/api/groupes/{id}/soumission` | `GROUPE_CREER` |

## Participations

| Méthode | Route | Droit |
|---|---|---|
| POST | `/api/groupes/{groupeId}/participations` | `PARTICIPATION_GERER` |
| GET | `/api/moi/participations` | `PARTICIPATION_GERER` |
| GET | `/api/participations/{id}` | `PARTICIPATION_GERER` |
| POST | `/api/participations/{id}/annulation` | `PARTICIPATION_GERER` |
| GET | `/api/participations/{id}/historique` | `PARTICIPATION_GERER` |

## Paiement, séquestre, remboursements, portefeuille

| Méthode | Route | Droit |
|---|---|---|
| POST | `/api/admin/paiements/{paiementId}/remboursements` | `REMBOURSEMENT_APPROUVER` |
| GET | `/api/admin/remboursements` | `REMBOURSEMENT_APPROUVER` |
| POST | `/api/admin/remboursements/{id}/approbation` | `REMBOURSEMENT_APPROUVER` |
| POST | `/api/admin/remboursements/{id}/rejet` | `REMBOURSEMENT_APPROUVER` |
| POST | `/api/dev/mobile-money/{paiementId}/echec` | public |
| POST | `/api/dev/mobile-money/{paiementId}/succes` | public |
| GET | `/api/moi/portefeuille` | `PORTEFEUILLE_RETIRER` |
| GET | `/api/moi/portefeuille/mouvements` | `PORTEFEUILLE_RETIRER` |
| POST | `/api/moi/portefeuille/retraits` | `PORTEFEUILLE_RETIRER` |
| POST | `/api/paiements/callback` | public |
| POST | `/api/participations/{id}/paiement` | `PAIEMENT_EFFECTUER` |
| GET | `/api/participations/{id}/paiements` | `PAIEMENT_EFFECTUER` |

## Commandes, acheminement, retrait

| Méthode | Route | Droit |
|---|---|---|
| POST | `/api/admin/groupes/{groupeId}/reception` | `RECEPTION_VALIDER` |
| POST | `/api/admin/points-retrait` | `POINT_RETRAIT_GERER` |
| GET | `/api/commandes/{id}` | `COMMANDE_LIRE` |
| GET | `/api/commandes/{id}/code-retrait` | `RETRAIT_EFFECTUER` |
| POST | `/api/commandes/{id}/code-retrait/regeneration` | `RETRAIT_VALIDER` |
| GET | `/api/groupes/{groupeId}/commandes` | `COMMANDE_LIRE` |
| POST | `/api/groupes/{groupeId}/expedition` | `COMMANDE_AVANCER` |
| POST | `/api/groupes/{groupeId}/preparation` | `COMMANDE_AVANCER` |
| POST | `/api/groupes/{groupeId}/reception-point-retrait` | `COMMANDE_AVANCER` |
| GET | `/api/moi/commandes` | `COMMANDE_LIRE` |
| GET | `/api/points-retrait` | connecté |
| POST | `/api/retraits/valider` | `RETRAIT_VALIDER` |

## Notifications

| Méthode | Route | Droit |
|---|---|---|
| GET | `/api/moi/notifications` | `NOTIFICATION_LIRE` |
| POST | `/api/moi/notifications/{id}/lue` | `NOTIFICATION_LIRE` |

## Journal d'audit

| Méthode | Route | Droit |
|---|---|---|
| GET | `/api/admin/audit` | `AUDIT_LIRE` |
| GET | `/api/admin/audit/verification` | `AUDIT_LIRE` |
