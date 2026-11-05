import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { Observable, forkJoin, of } from 'rxjs';
import { catchError, map, switchMap } from 'rxjs/operators';
import {
  LIBELLES_COMMANDE,
  LIBELLES_GROUPE,
  LIBELLES_SEQUESTRE,
  dateCourte,
  dateRelative,
  fcfa,
  messageErreur,
  urlImage
} from '../../core/api';
import { LIBELLES_COMPTE, LIBELLES_ROLE_ADMIN, LIBELLES_TYPE } from '../../core/permissions';
import { AdminApiService, CommandeGroupe, DossierKyc, Groupe, LigneAudit } from '../../core/services/admin-api.service';
import { AnnuaireService, Membre, Relation, Reseau } from '../../core/services/annuaire.service';
import { AuthService } from '../../core/services/auth.service';
import { AdminSecuriteService } from '../../core/services/admin-securite.service';
import { Portefeuille3dComponent } from '../../components/portefeuille-3d/portefeuille-3d.component';

/** Groupes dont les commandes existent (créées à l'objectif atteint) */
const ETATS_AVEC_COMMANDES = ['OBJECTIF_ATTEINT', 'EN_EXPEDITION', 'LIVRE', 'TERMINE'];
const ETATS_ACTIFS = ['BROUILLON', 'EN_VALIDATION', 'OUVERT', 'OBJECTIF_ATTEINT', 'EN_EXPEDITION', 'LIVRE'];

export interface CommandeFiche extends CommandeGroupe {
  produit: string;
  montant: number;
}

/**
 * Fiche d'un compte : identité, statut et KYC, puis tout ce qui le relie aux autres acteurs — groupes fournis,
 * pilotés ou achetés, partenaires (grossistes ↔ courtiers ↔ commerçants), commandes, séquestres et journal d'audit.
 * L'administrateur y suspend ou réactive le compte et intervient sur les retraits du commerçant.
 */
@Component({
  selector: 'app-fiche-utilisateur',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, Portefeuille3dComponent],
  templateUrl: './fiche-utilisateur.html',
  styleUrl: './fiche-utilisateur.scss'
})
export class FicheUtilisateurComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  private readonly annuaire = inject(AnnuaireService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  readonly auth = inject(AuthService);
  readonly securite = inject(AdminSecuriteService);

  readonly id = signal(0);
  readonly chargement = signal(true);
  readonly erreur = signal('');
  readonly message = signal('');
  readonly echec = signal(false);
  readonly envoi = signal(false);

  readonly dossiers = signal<DossierKyc[]>([]);
  readonly commandes = signal<CommandeFiche[]>([]);
  readonly audit = signal<LigneAudit[]>([]);

  readonly suspensionOuverte = signal(false);
  motif = '';

  readonly messageSupportOuvert = signal(false);
  messageSupportTexte = '';

  readonly diffusionAdminsOuverte = signal(false);
  diffusionSujet = '';
  diffusionMessage = '';

  async envoyerMessageSupport(): Promise<void> {
    if (!this.messageSupportTexte.trim()) return;
    try {
      await this.securite.demanderConfirmation({
        titre: 'Envoi de notification support',
        description: `Envoi d'un message direct par SMS et In-App à l'utilisateur : « ${this.messageSupportTexte.trim()} ».`,
        actionTexte: 'Envoyer la notification',
        icone: 'sms'
      });
      this.envoi.set(true);
      this.api.envoyerMessageSupport(this.id(), this.messageSupportTexte.trim()).subscribe({
        next: () => {
          this.envoi.set(false);
          this.messageSupportOuvert.set(false);
          this.messageSupportTexte = '';
          this.echec.set(false);
          this.message.set('Message de support transmis avec succès à l’utilisateur (notification in-app et SMS).');
        },
        error: (e) => {
          this.envoi.set(false);
          this.echec.set(true);
          this.message.set(messageErreur(e, 'Échec de l’envoi du message de support.'));
        }
      });
    } catch {
      // Annulé
    }
  }

  async diffuserAuxAdmins(): Promise<void> {
    if (!this.diffusionSujet.trim() || !this.diffusionMessage.trim()) return;
    try {
      await this.securite.demanderConfirmation({
        titre: 'Diffusion administrative',
        description: `Diffusion d'une alerte à tous les administrateurs Karavan : « ${this.diffusionSujet.trim()} ».`,
        actionTexte: 'Diffuser la note',
        icone: 'campaign'
      });
      this.envoi.set(true);
      this.api.diffuserAuxAdmins(this.diffusionSujet.trim(), this.diffusionMessage.trim()).subscribe({
        next: () => {
          this.envoi.set(false);
          this.diffusionAdminsOuverte.set(false);
          this.diffusionSujet = '';
          this.diffusionMessage = '';
          this.echec.set(false);
          this.message.set('Note d’information diffusée avec succès à tous les administrateurs.');
        },
        error: (e) => {
          this.envoi.set(false);
          this.echec.set(true);
          this.message.set(messageErreur(e, 'Échec de la diffusion aux administrateurs.'));
        }
      });
    } catch {
      // Annulé
    }
  }

  readonly libellesType = LIBELLES_TYPE;
  readonly libellesCompte = LIBELLES_COMPTE;
  readonly libellesGroupe = LIBELLES_GROUPE;
  readonly libellesCommande = LIBELLES_COMMANDE;
  readonly libellesSequestre = LIBELLES_SEQUESTRE;
  readonly libellesRoleAdmin = LIBELLES_ROLE_ADMIN;
  readonly fcfa = fcfa;
  readonly dateCourte = dateCourte;
  readonly relatif = dateRelative;
  readonly urlImage = urlImage;

  ngOnInit(): void {
    // La même instance sert quand on passe d'une fiche à une autre (lien vers un partenaire)
    this.route.paramMap.subscribe(p => {
      this.id.set(Number(p.get('id')));
      this.suspensionOuverte.set(false);
      this.message.set('');
      this.charger();
    });
  }

  readonly membre = computed<Membre | null>(() => (this.annuaire.charge() ? this.annuaire.membre(this.id()) : null));

  readonly reseau = computed<Reseau>(() => {
    const m = this.membre();
    return m ? this.annuaire.reseau(m, this.commandes()) : { groupes: [], sequestres: [], partenaires: [] };
  });

  readonly partenairesParType = computed(() => {
    const p = this.reseau().partenaires;
    return [
      { titre: 'Grossistes', liste: p.filter(x => x.type === 'GROSSISTE') },
      { titre: 'Courtiers', liste: p.filter(x => x.type === 'COURTIER') },
      { titre: 'Commerçants', liste: p.filter(x => x.type === 'COMMERCANT') }
    ].filter(s => s.liste.length);
  });

  readonly groupesActifs = computed(() => this.reseau().groupes.filter(g => ETATS_ACTIFS.includes(g.statut)).length);

  readonly sequestreBloque = computed(() =>
    this.reseau().sequestres.filter(s => s.statut === 'BLOQUE').reduce((t, s) => t + Number(s.montantBloque), 0)
  );

  readonly sequestreLibere = computed(() =>
    this.reseau().sequestres.filter(s => s.statut === 'LIBERE').reduce((t, s) => t + Number(s.montantBloque), 0)
  );

  readonly totalSequestreActif = computed(() =>
    this.sequestreBloque() + this.sequestreLibere()
  );

  /** Commandes du commerçant lui-même (les autres comptes voient les acheteurs dans leurs partenaires) */
  readonly sesCommandes = computed(() => {
    const m = this.membre();
    return m?.type === 'COMMERCANT' ? this.commandes().filter(c => c.commercantId === m.id) : [];
  });

  readonly dossierEnAttente = computed(() => this.dossiers().find(d => d.statut === 'EN_ATTENTE') ?? null);

  readonly exigeKyc = computed(() => ['GROSSISTE', 'COURTIER'].includes(this.membre()?.type ?? ''));

  /**
   * Grossiste / courtier sans dossier approuvé : il doit être validé avant de devenir actif ou d'être réactivé
   * (RG-03). C'est le cas d'un courtier inscrit sans dossier, ou d'un compte suspendu pendant l'examen du KYC.
   */
  readonly aValider = computed(() => this.exigeKyc() && !this.chargement() && !this.dossiers().some(d => d.statut === 'APPROUVE'));

  readonly validationOuverte = signal(false);
  commentaireValidation = '';

  ouvrirValidation(): void {
    const d = this.dossierEnAttente();
    this.commentaireValidation = d
      ? `Pièces du dossier #${d.id} vérifiées et conformes`
      : 'Identité et documents professionnels vérifiés hors application';
    this.validationOuverte.set(true);
    this.suspensionOuverte.set(false);
  }

  /** Valide le compte ; un compte suspendu est ensuite réactivé dans la foulée */
  validerCompte(): void {
    const m = this.membre();
    const commentaire = this.commentaireValidation.trim();
    if (!m || !commentaire) {
      return;
    }
    const reactiver = m.statut === 'SUSPENDU' && this.auth.peut('COMPTE_SUSPENDRE');
    const appel = reactiver
      ? this.api.validerCompte(m.id, commentaire).pipe(switchMap(() => this.api.reactiverCompte(m.id)))
      : this.api.validerCompte(m.id, commentaire);
    this.executer(
      appel,
      reactiver
        ? `${m.nom} est validé et son compte est de nouveau actif.`
        : `${m.nom} est validé : son compte est actif et il en est notifié.`,
      () => this.validationOuverte.set(false)
    );
  }

  readonly estMoi = computed(() => this.auth.obtenirProfil()?.id === this.id());

  // ---------------------------------------------------------------- chargement

  charger(force = true): void {
    this.chargement.set(true);
    this.erreur.set('');
    this.dossiers.set([]);
    this.commandes.set([]);
    this.audit.set([]);
    this.annuaire.charger(force).subscribe({
      next: () => {
        const m = this.membre();
        if (!m) {
          this.erreur.set(`Le compte #${this.id()} est introuvable (ou réservé au rôle TECHNIQUE).`);
          this.chargement.set(false);
          return;
        }
        this.chargerDetails(m);
      },
      error: e => {
        this.erreur.set(messageErreur(e, 'Impossible de charger le compte.'));
        this.chargement.set(false);
      }
    });
  }

  private chargerDetails(m: Membre): void {
    const kyc =
      ['GROSSISTE', 'COURTIER'].includes(m.type) && this.auth.peut('KYC_VALIDER', 'COMPTE_SUSPENDRE', 'AUDIT_LIRE')
        ? this.api.dossiersKycDe(m.id).pipe(catchError(() => of([] as DossierKyc[])))
        : of([] as DossierKyc[]);
    const journal = this.auth.peut('AUDIT_LIRE')
      ? this.api.journalAudit(500).pipe(catchError(() => of([] as LigneAudit[])))
      : of([] as LigneAudit[]);
    forkJoin({ kyc, journal, commandes: this.commandesDes(this.annuaire.groupesDe(m)) }).subscribe(r => {
      this.dossiers.set(r.kyc ?? []);
      this.commandes.set(r.commandes);
      const cible = new RegExp(`utilisateur=${m.id}(\\D|$)`);
      this.audit.set((r.journal ?? []).filter(l => l.acteurId === m.id || cible.test(l.avant ?? '') || cible.test(l.apres ?? '')));
      this.chargement.set(false);
    });
  }

  private commandesDes(groupes: Groupe[]): Observable<CommandeFiche[]> {
    const avecCommandes = groupes.filter(g => ETATS_AVEC_COMMANDES.includes(g.statut));
    if (!avecCommandes.length || !this.auth.peut('COMMANDE_LIRE')) {
      return of([]);
    }
    return forkJoin(
      avecCommandes.map(g =>
        this.api.commandesDuGroupe(g.id).pipe(
          map(liste => (liste ?? []).map(c => ({ ...c, produit: g.produit?.nom ?? g.titre, montant: c.quantite * g.prixUnitaire }))),
          catchError(() => of([] as CommandeFiche[]))
        )
      )
    ).pipe(map(listes => listes.flat()));
  }

  // ---------------------------------------------------------------- présentation

  badgeStatut(statut: string): string {
    return { ACTIF: 'green', EN_ATTENTE: 'yellow', SUSPENDU: 'red', DESACTIVE: 'red' }[statut] ?? '';
  }

  badgeType(type: string): string {
    return { GROSSISTE: 'orange', COURTIER: 'blue', COMMERCANT: 'green', ADMINISTRATEUR: 'violet' }[type] ?? '';
  }

  badgeGroupe(statut: string): string {
    if (['TERMINE', 'LIVRE'].includes(statut)) return 'green';
    if (['ANNULE', 'ECHOUE'].includes(statut)) return 'red';
    if (['BROUILLON', 'EN_VALIDATION'].includes(statut)) return 'yellow';
    return 'orange';
  }

  badgeKyc(statut: string): string {
    return { APPROUVE: 'green', REJETE: 'red', EN_ATTENTE: 'yellow' }[statut] ?? '';
  }

  /** Rôle du compte dans le groupe, vu depuis sa fiche */
  roleDans(g: Groupe): string {
    const m = this.membre();
    if (!m) return '';
    if (m.type === 'GROSSISTE') return g.porteParGrossiste ? 'Fournisseur et porteur' : 'Fournisseur';
    if (m.type === 'COURTIER') return 'Porteur (courtier)';
    const qte = this.reseau().sequestres.filter(s => s.groupeId === g.id).reduce((t, s) => t + s.quantite, 0);
    return `Acheteur · ${qte} pce${qte > 1 ? 's' : ''}`;
  }

  progression(g: Groupe): number {
    return g.quantiteCible ? Math.min(100, Math.round((g.quantiteConfirmee / g.quantiteCible) * 100)) : 0;
  }

  libelleAction(action: string): string {
    return action.replace(/_/g, ' ').toLowerCase().replace(/^\w/, c => c.toUpperCase());
  }

  libellePartenaire(r: Relation): string {
    return r.membre?.entreprise ? `${r.nom} · ${r.membre.entreprise}` : r.nom;
  }

  // ---------------------------------------------------------------- actions

  ouvrirGroupe(g: Groupe): void {
    void this.router.navigate(['/groupes'], { queryParams: { id: g.id } });
  }

  examinerKyc(): void {
    void this.router.navigate(['/kyc-validation'], { queryParams: { utilisateur: this.id() } });
  }

  async suspendre(): Promise<void> {
    const m = this.membre();
    const motif = this.motif.trim();
    if (!m || !motif) {
      return;
    }
    try {
      await this.securite.demanderConfirmation({
        titre: 'Suspension de compte',
        description: `Suspension immédiate du compte de ${m.nom} pour le motif : « ${motif} ». Ses sessions seront fermées.`,
        actionTexte: 'Suspendre le compte',
        icone: 'block',
        danger: true
      });
      this.executer(this.api.suspendreCompte(m.id, motif), `Le compte de ${m.nom} est suspendu : ses sessions sont fermées et il est notifié.`, () => {
        this.motif = '';
        this.suspensionOuverte.set(false);
      });
    } catch {
      // Annulé
    }
  }

  async reactiver(): Promise<void> {
    const m = this.membre();
    if (!m) return;
    try {
      await this.securite.demanderConfirmation({
        titre: 'Réactivation de compte',
        description: `Réactivation du compte de ${m.nom}. L'utilisateur pourra à nouveau se connecter et opérer.`,
        actionTexte: 'Réactiver le compte',
        icone: 'check_circle'
      });
      this.executer(this.api.reactiverCompte(m.id), `Le compte de ${m.nom} est de nouveau actif.`);
    } catch {
      // Annulé
    }
  }

  /** RG-54 : nouveau code de retrait envoyé par SMS au commerçant */
  async regenererCode(c: CommandeFiche): Promise<void> {
    try {
      await this.securite.demanderConfirmation({
        titre: 'Génération Code de Retrait',
        description: `Génération d'un nouveau code de retrait pour la commande #${c.id}. L'ancien code sera révoqué.`,
        actionTexte: 'Générer le code',
        icone: 'vpn_key'
      });
      this.executer(this.api.regenererCodeRetrait(c.id), `Nouveau code envoyé par SMS pour la commande #${c.id}.`);
    } catch {
      // Annulé
    }
  }

  private executer(appel: Observable<unknown>, succes: string, apres?: () => void): void {
    this.envoi.set(true);
    this.message.set('');
    appel.subscribe({
      next: () => {
        this.envoi.set(false);
        this.echec.set(false);
        this.message.set(succes);
        apres?.();
        this.charger();
      },
      error: e => {
        this.envoi.set(false);
        this.echec.set(true);
        this.message.set(messageErreur(e, 'Action impossible.'));
      }
    });
  }
}
