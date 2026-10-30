/**
 * Permissions exigées par le backend pour chaque page (au moins une suffit), d'après les rôles administratifs :
 *   TECHNIQUE  : Tout (Super-Administrateur - ADMIN_CREER, AUDIT_LIRE, etc.)
 *   VALIDATION : KYC_VALIDER, GROUPE_PUBLICATION_VALIDER, GROUPE_ANNULER
 *   FINANCE    : REMBOURSEMENT_APPROUVER, PORTEFEUILLE_RETIRER
 *   SUPPORT    : COMPTE_SUSPENDRE, COMMANDE_LIRE (suivi utilisateurs, litiges & contact)
 *   LOGISTIQUE : POINT_RETRAIT_GERER, RECEPTION_VALIDER, RETRAIT_VALIDER, COMMANDE_AVANCER
 * 
 * Règle stricte : Seul l'administrateur TECHNIQUE a tous les accès.
 * Les autres administrateurs n'ont accès qu'à leur mission respective.
 */
export const PERMISSIONS_PAGES: Record<string, string[]> = {
  admin: [],
  dashboard: [],
  'kyc-validation': ['KYC_VALIDER'],
  groupes: ['GROUPE_PUBLICATION_VALIDER', 'COMMANDE_AVANCER'],
  finance: ['REMBOURSEMENT_APPROUVER', 'PORTEFEUILLE_RETIRER'],
  corridors: ['POINT_RETRAIT_GERER'],
  retraits: ['RETRAIT_VALIDER'],
  utilisateurs: ['ADMIN_CREER', 'COMPTE_SUSPENDRE'],
  grossistes: ['ADMIN_CREER', 'KYC_VALIDER', 'COMPTE_SUSPENDRE'],
  courtiers: ['ADMIN_CREER', 'KYC_VALIDER', 'COMPTE_SUSPENDRE'],
  commercants: ['ADMIN_CREER', 'COMPTE_SUSPENDRE'],
  administrateurs: ['ADMIN_CREER'],
  audit: ['AUDIT_LIRE']
};

/** Libellé lisible du type d'acteur (TypeActeur du backend) */
export const LIBELLES_TYPE: Record<string, string> = {
  COMMERCANT: 'Commerçant',
  GROSSISTE: 'Grossiste',
  COURTIER: 'Courtier',
  ADMINISTRATEUR: 'Administrateur'
};

/** Libellé lisible du statut de compte (StatutCompte du backend) */
export const LIBELLES_COMPTE: Record<string, string> = {
  ACTIF: 'Actif',
  EN_ATTENTE: 'KYC en attente',
  SUSPENDU: 'Suspendu',
  DESACTIVE: 'Désactivé'
};

/** Ce que permet chaque permission, en clair (affiché sous la fonction choisie à la création d'un administrateur) */
export const LIBELLES_PERMISSION: Record<string, string> = {
  ADMIN_CREER: 'Créer les administrateurs',
  AUDIT_LIRE: "Consulter le journal d'audit",
  CAMPAGNE_EXPLORER: 'Consulter le catalogue et les groupes',
  COMMANDE_AVANCER: 'Faire avancer les commandes',
  COMMANDE_LIRE: 'Consulter les commandes',
  COMPTE_SUSPENDRE: 'Suspendre et réactiver les comptes',
  GROUPE_ANNULER: 'Annuler un groupe',
  GROUPE_CREER: 'Créer un groupe',
  GROUPE_DISPONIBILITE_VALIDER: 'Valider la disponibilité des stocks',
  GROUPE_PUBLICATION_VALIDER: 'Valider la publication des groupes',
  GROUPE_SUIVRE: 'Suivre les groupes',
  KYC_VALIDER: 'Valider les dossiers KYC',
  NOTIFICATION_LIRE: 'Recevoir les notifications',
  POINT_RETRAIT_GERER: 'Gérer les points de retrait',
  PORTEFEUILLE_RETIRER: 'Traiter les retraits de portefeuille',
  PROFIL_GERER: 'Gérer son profil',
  RECEPTION_VALIDER: 'Valider les réceptions au dépôt',
  REMBOURSEMENT_APPROUVER: 'Approuver les remboursements',
  RETRAIT_VALIDER: 'Valider les retraits de colis'
};

export const LIBELLES_ROLE_ADMIN: Record<string, string> = {
  TECHNIQUE: 'Administrateur principal',
  VALIDATION: 'Admin Validation (KYC, conformité stocks)',
  FINANCE: 'Admin Finance (séquestre, virements, remboursements)',
  SUPPORT: 'Admin Support (utilisateurs, litiges, réclamations)',
  LOGISTIQUE: 'Admin Logistique (suivi des colis, livraison, dépôts)'
};
