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

export const LIBELLES_ROLE_ADMIN: Record<string, string> = {
  TECHNIQUE: 'Admin Technique (super-administrateur)',
  VALIDATION: 'Admin Validation (KYC, conformité stocks)',
  FINANCE: 'Admin Finance (séquestre, virements, remboursements)',
  SUPPORT: 'Admin Support (utilisateurs, litiges, réclamations)',
  LOGISTIQUE: 'Admin Logistique (suivi des colis, livraison, dépôts)'
};
