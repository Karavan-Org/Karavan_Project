import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { API_URL } from '../api';

// ---------------------------------------------------------------- vues renvoyées par le backend

export interface DocumentKyc {
  id: number;
  type: string;
  empreinteSha256: string;
}

export interface DossierKyc {
  id: number;
  utilisateurId: number;
  nom: string;
  telephone: string;
  typeActeur: string;
  statut: string;
  dateSoumission: string;
  motifRejet: string | null;
  documents: DocumentKyc[];
}

export interface Acteur {
  id: number;
  nom: string;
}

export interface Groupe {
  id: number;
  titre: string;
  statut: string;
  produit: { id: number; nom: string; categorie: string; paysOrigine: string; photoUrl: string | null };
  courtier: Acteur | null;
  grossiste: Acteur;
  porteParGrossiste: boolean;
  quantiteCible: number;
  quantiteConfirmee: number;
  quantiteReservee: number;
  quantiteRestante: number;
  prixUnitaire: number;
  grille: { marchandise: number; transport: number; fraisPlateforme: number; douane: number; autres: number };
  conditions: { delaiLivraisonJours: number; politiqueAnnulation: string; quantiteMinParCommercant: number };
  dateOuverture: string;
  dateLimite: string;
  disponibiliteValidee: boolean;
}

export interface EtapeSignalee {
  id: number;
  etape: string;
  commentaire: string | null;
  date: string;
}

export interface EvenementConvoi {
  id: number;
  statut: string;
  localisation: string;
  date: string;
}

export interface Convoi {
  id: number;
  groupeId: number;
  reference: string;
  statut: string;
  dateDepart: string;
  transporteur: string | null;
  evenements: EvenementConvoi[];
}

/** Commande née d'un groupe (CommandeVue du backend ; l'administrateur voit l'acheteur) */
export interface CommandeGroupe {
  id: number;
  groupeId: number;
  statut: string;
  quantite: number;
  commercantId: number | null;
  commercantNom: string | null;
}

export interface PointRetrait {
  id: number;
  nom: string;
  adresse: string;
  quartier?: string;
  lienGoogleMap?: string;
}

export interface Sequestre {
  id: number;
  paiementId: number;
  montantBloque: number;
  statut: string;
  gele: boolean;
  dateBlocage: string;
  dateLiberation: string | null;
  groupeId: number | null;
  groupeTitre: string | null;
  groupeStatut: string | null;
  quantite: number;
  acheteur: string | null;
  beneficiaire: string | null;
  participationId: number | null;
  acheteurId: number | null;
  beneficiaireId: number | null;
  grossisteId: number | null;
  courtierId: number | null;
}

export interface TableauSequestres {
  totalBloque: number;
  nombreSequestres: number;
  sequestres: Sequestre[];
  totalLibere: number;
  totalRestitue: number;
  totalGele: number;
  commissions: number;
}

export interface Remboursement {
  id: number;
  paiementId: number;
  montant: number;
  statut: string;
  motif: string;
  dateDemande: string;
}

export interface Commercant {
  id: number;
  telephone: string;
  nom: string;
  statut: string;
  photoUrl: string | null;
  nomBoutique: string | null;
  adresseLivraison: string | null;
  quartierBamako: string | null;
  canalVente: string | null;
  dateCreation: string | null;
}

export interface Grossiste {
  id: number;
  telephone: string;
  nom: string;
  statut: string;
  photoUrl: string | null;
  nomBoutiqueMarche: string | null;
  numeroNif: string | null;
  registreCommerce: string | null;
  noteFiabilite: number | null;
  dateCreation: string | null;
}

export interface Courtier {
  id: number;
  telephone: string;
  nom: string;
  statut: string;
  photoUrl: string | null;
  nomSocieteImport: string | null;
  licenceTransit: string | null;
  adresseDepot: string | null;
  noteFiabilite: number | null;
  dateCreation: string | null;
}

export type RoleAdministratif = 'TECHNIQUE' | 'VALIDATION' | 'FINANCE' | 'SUPPORT' | 'LOGISTIQUE';

export interface Administrateur {
  id: number;
  telephone: string;
  nom: string;
  statut: string;
  photoUrl: string | null;
  matricule: string;
  roleAdministratif: RoleAdministratif;
  dateCreation: string | null;
}

export interface NouvelAdministrateur {
  telephone: string;
  nom: string;
  motDePasse?: string;
  pin?: string;
  matricule: string;
  role: RoleAdministratif;
}

/** Transition d'état d'un groupe (TransitionVue du backend) : auteur = « COURTIER:12 », « ADMIN:3 »… */
export interface TransitionGroupe {
  ancien: string;
  nouveau: string;
  date: string;
  auteur: string | null;
}

export interface StatsSupervision {
  totalCommercants: number;
  totalGrossistes: number;
  totalCourtiers: number;
  totalAdministrateurs: number;
}

export interface LigneAudit {
  id: number;
  acteurId: number | null;
  action: string;
  avant: string | null;
  apres: string | null;
  date: string;
  hash: string;
}

export interface VerificationAudit {
  chaineIntacte: boolean;
  lignesVerifiees: number;
  premiereLigneFausse: number | null;
}

/**
 * Appels de l'administrateur vers le backend DoGo. Mêmes règles que les applications Commerçant, Grossiste
 * et Courtier : le backend vérifie chaque permission (KYC_VALIDER, RECEPTION_VALIDER, …) et chaque transition.
 */
@Injectable({ providedIn: 'root' })
export class AdminApiService {
  private readonly http = inject(HttpClient);

  // ---------------------------------------------------------------- KYC

  dossiersKyc(): Observable<DossierKyc[]> {
    return this.http.get<DossierKyc[]>(`${API_URL}/admin/kyc`);
  }

  deciderKyc(dossierId: number, decision: 'APPROUVE' | 'REJETE', commentaire?: string): Observable<DossierKyc> {
    return this.http.post<DossierKyc>(`${API_URL}/admin/kyc/${dossierId}/decision`, { decision, commentaire });
  }

  documentKyc(dossierId: number, documentId: number): Observable<Blob> {
    return this.http.get(`${API_URL}/admin/kyc/${dossierId}/documents/${documentId}`, { responseType: 'blob' });
  }

  /**
   * Accepte un grossiste ou un courtier : approuve son dossier en attente, ou enregistre une validation manuelle
   * (pièces vérifiées hors application). Un compte en attente devient actif ; un compte suspendu peut ensuite
   * être réactivé.
   */
  validerCompte(utilisateurId: number, commentaire: string): Observable<DossierKyc> {
    return this.http.post<DossierKyc>(`${API_URL}/admin/kyc/utilisateurs/${utilisateurId}/validation`, { commentaire });
  }

  /** Tous les dossiers d'un acteur (approuvés, rejetés, en attente), du plus récent au plus ancien */
  dossiersKycDe(utilisateurId: number): Observable<DossierKyc[]> {
    return this.http.get<DossierKyc[]>(`${API_URL}/admin/kyc/utilisateurs/${utilisateurId}`);
  }

  // ---------------------------------------------------------------- groupes

  groupes(): Observable<Groupe[]> {
    return this.http.get<Groupe[]>(`${API_URL}/admin/groupes`);
  }

  groupesEnValidation(): Observable<Groupe[]> {
    return this.http.get<Groupe[]>(`${API_URL}/admin/groupes/en-validation`);
  }

  deciderPublication(groupeId: number, approuve: boolean, commentaire: string): Observable<Groupe> {
    return this.http.post<Groupe>(`${API_URL}/admin/groupes/${groupeId}/publication`, { approuve, commentaire });
  }

  annulerGroupe(groupeId: number, motif: string): Observable<Groupe> {
    return this.http.post<Groupe>(`${API_URL}/groupes/${groupeId}/annulation`, { motif });
  }

  /** Cycle de vie du groupe : chaque changement d'état avec son auteur */
  historiqueGroupe(groupeId: number): Observable<TransitionGroupe[]> {
    return this.http.get<TransitionGroupe[]>(`${API_URL}/groupes/${groupeId}/historique`);
  }

  /** Étapes d'acheminement signalées par le grossiste qui porte le groupe */
  etapesSignalees(groupeId: number): Observable<EtapeSignalee[]> {
    return this.http.get<EtapeSignalee[]>(`${API_URL}/groupes/${groupeId}/etapes`);
  }

  // ---------------------------------------------------------------- logistique

  convois(): Observable<Convoi[]> {
    return this.http.get<Convoi[]>(`${API_URL}/convois`);
  }

  creerConvoi(groupeId: number, reference: string, transporteur: string): Observable<Convoi> {
    return this.http.post<Convoi>(`${API_URL}/convois`, { groupeId, reference, transporteur });
  }

  /** ACHETE → CHEZ_TRANSITAIRE → EN_TRANSIT ⇄ BLOQUE_DOUANE → ARRIVE */
  avancerConvoi(
    convoiId: number,
    action: 'transitaire' | 'transit' | 'douane' | 'arrivee',
    localisation?: string
  ): Observable<Convoi> {
    return this.http.post<Convoi>(`${API_URL}/convois/${convoiId}/${action}`, localisation ? { localisation } : {});
  }

  ajouterEvenementConvoi(convoiId: number, statut: string, localisation: string): Observable<Convoi> {
    return this.http.post<Convoi>(`${API_URL}/convois/${convoiId}/evenements`, { statut, localisation });
  }

  /** Commandes nées d'un groupe (CommandeVue) */
  commandesDuGroupe(groupeId: number): Observable<CommandeGroupe[]> {
    return this.http.get<CommandeGroupe[]>(
      `${API_URL}/groupes/${groupeId}/commandes`
    );
  }

  preparerCommandes(groupeId: number): Observable<unknown[]> {
    return this.http.post<unknown[]>(`${API_URL}/groupes/${groupeId}/preparation`, {});
  }

  expedierCommandes(groupeId: number): Observable<unknown[]> {
    return this.http.post<unknown[]>(`${API_URL}/groupes/${groupeId}/expedition`, {});
  }

  /** RG-52 : réception des colis au dépôt (groupe LIVRE) */
  validerReception(groupeId: number): Observable<unknown[]> {
    return this.http.post<unknown[]>(`${API_URL}/admin/groupes/${groupeId}/reception`, {});
  }

  /** RG-53 : colis disponibles au point de retrait, codes envoyés aux commerçants */
  confirmerPointRetrait(groupeId: number, pointRetraitId: number): Observable<unknown[]> {
    return this.http.post<unknown[]>(`${API_URL}/groupes/${groupeId}/reception-point-retrait`, { pointRetraitId });
  }

  /** Notification d'arrivée au dépôt avec lien Google Maps envoyé directement aux commerçants */
  notifierArriveeDepot(groupeId: number, pointRetraitId: number): Observable<unknown[]> {
    return this.http.post<unknown[]>(`${API_URL}/admin/groupes/${groupeId}/notifier-depot`, { pointRetraitId });
  }

  pointsRetrait(): Observable<PointRetrait[]> {
    return this.http.get<PointRetrait[]>(`${API_URL}/points-retrait`);
  }

  creerPointRetrait(nom: string, adresse: string, quartier: string, lienGoogleMap?: string): Observable<PointRetrait> {
    return this.http.post<PointRetrait>(`${API_URL}/admin/points-retrait`, { nom, adresse, quartier, lienGoogleMap });
  }

  modifierPointRetrait(id: number, nom: string, adresse: string, quartier: string, lienGoogleMap?: string): Observable<PointRetrait> {
    return this.http.put<PointRetrait>(`${API_URL}/admin/points-retrait/${id}`, { nom, adresse, quartier, lienGoogleMap });
  }

  validerRetrait(code:{ qrToken?: string; commandeId?: number; pin?: string }): Observable<unknown> {
    return this.http.post(`${API_URL}/retraits/valider`, code);
  }

  regenererCodeRetrait(commandeId: number): Observable<unknown> {
    return this.http.post(`${API_URL}/commandes/${commandeId}/code-retrait/regeneration`, {});
  }

  // ---------------------------------------------------------------- finance

  sequestres(): Observable<TableauSequestres> {
    return this.http.get<TableauSequestres>(`${API_URL}/admin/finance/sequestres`);
  }

  remboursements(): Observable<Remboursement[]> {
    return this.http.get<Remboursement[]>(`${API_URL}/admin/remboursements`);
  }

  approuverRemboursement(id: number): Observable<Remboursement> {
    return this.http.post<Remboursement>(`${API_URL}/admin/remboursements/${id}/approbation`, {});
  }

  rejeterRemboursement(id: number, justification: string): Observable<Remboursement> {
    return this.http.post<Remboursement>(`${API_URL}/admin/remboursements/${id}/rejet`, { justification });
  }

  /** Arbitrage : rembourse un paiement en séquestre (colis perdu, litige tranché en faveur du commerçant) */
  demanderRemboursement(paiementId: number, motif: 'COLIS_PERDU' | 'LITIGE_RESOLU'): Observable<Remboursement> {
    return this.http.post<Remboursement>(`${API_URL}/admin/paiements/${paiementId}/remboursements`, { motif });
  }

  // ---------------------------------------------------------------- comptes

  commercants(): Observable<Commercant[]> {
    return this.http.get<Commercant[]>(`${API_URL}/admin/commercants`);
  }

  grossistes(): Observable<Grossiste[]> {
    return this.http.get<Grossiste[]>(`${API_URL}/admin/grossistes`);
  }

  courtiers(): Observable<Courtier[]> {
    return this.http.get<Courtier[]>(`${API_URL}/admin/courtiers`);
  }

  administrateurs(): Observable<Administrateur[]> {
    return this.http.get<Administrateur[]>(`${API_URL}/admin/administrateurs`);
  }

  /** RG-06 : seul un administrateur TECHNIQUE peut créer un autre administrateur */
  creerAdministrateur(a: NouvelAdministrateur): Observable<{ id: number }> {
    const payload = { ...a, motDePasse: a.motDePasse || a.pin, pin: a.pin || a.motDePasse };
    return this.http.post<{ id: number }>(`${API_URL}/admin/administrateurs`, payload);
  }

  statistiques(): Observable<StatsSupervision> {
    return this.http.get<StatsSupervision>(`${API_URL}/admin/supervision/stats`);
  }

  suspendreCompte(id: number, motif: string): Observable<void> {
    return this.http.post<void>(`${API_URL}/admin/comptes/${id}/suspension`, { motif });
  }

  reactiverCompte(id: number): Observable<void> {
    return this.http.post<void>(`${API_URL}/admin/comptes/${id}/reactivation`, {});
  }

  // ---------------------------------------------------------------- audit

  journalAudit(taille = 200): Observable<LigneAudit[]> {
    return this.http.get<LigneAudit[]>(`${API_URL}/admin/audit`, { params: { taille } });
  }

  verifierAudit(): Observable<VerificationAudit> {
    return this.http.get<VerificationAudit>(`${API_URL}/admin/audit/verification`);
  }

  // ---------------------------------------------------------------- support & communication

  envoyerMessageSupport(destinataireId: number, message: string): Observable<void> {
    return this.http.post<void>(`${API_URL}/admin/support/message-utilisateur`, { destinataireId, message });
  }

  diffuserAuxAdmins(sujet: string, message: string): Observable<void> {
    return this.http.post<void>(`${API_URL}/admin/support/diffuser-admins`, { sujet, message });
  }

  litigesSupport(): Observable<any[]> {
    return this.http.get<any[]>(`${API_URL}/admin/support/litiges`);
  }
}
