import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { fcfa, messageErreur, urlImage } from '../../core/api';
import { AdminApiService, Groupe, Grossiste } from '../../core/services/admin-api.service';
import { AuthService } from '../../core/services/auth.service';

/** Groupes dont l'argent des commerçants est en séquestre (payé, pas encore retiré) */
const ETATS_SEQUESTRE = ['OUVERT', 'OBJECTIF_ATTEINT', 'EN_EXPEDITION', 'LIVRE'];

export interface LigneGrossiste {
  compte: Grossiste;
  groupesActifs: number;
  produits: string;
  sequestre: number;
  /** Courtiers qui montent des groupes sur ses produits (ou « en direct » s'il porte lui-même ses groupes) */
  partenaires: string;
}

/**
 * Grossistes & dépôts : comptes réels, groupes montés sur leurs produits (par eux ou par un courtier),
 * modération des groupes avant publication (RG-18) et suspension des comptes (COMPTE_SUSPENDRE).
 */
@Component({
  selector: 'app-grossistes',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './grossistes.html',
  styleUrl: './grossistes.scss'
})
export class GrossistesComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  private readonly router = inject(Router);
  private readonly auth = inject(AuthService);

  readonly comptes = signal<Grossiste[]>([]);
  readonly groupes = signal<Groupe[]>([]);
  readonly aPublier = signal<Groupe[]>([]);
  readonly chargement = signal(true);
  readonly erreur = signal('');
  readonly message = signal('');
  readonly envoi = signal(false);

  readonly fcfa = fcfa;
  readonly urlImage = urlImage;

  ngOnInit(): void {
    this.charger();
  }

  charger(): void {
    this.chargement.set(true);
    this.erreur.set('');
    forkJoin({
      comptes: this.api.grossistes(),
      groupes: this.api.groupes().pipe(catchError(() => of([] as Groupe[]))),
      aPublier: this.api.groupesEnValidation().pipe(catchError(() => of([] as Groupe[])))
    }).subscribe({
      next: ({ comptes, groupes, aPublier }) => {
        this.comptes.set(comptes ?? []);
        this.groupes.set(groupes ?? []);
        this.aPublier.set(aPublier ?? []);
        this.chargement.set(false);
      },
      error: e => {
        this.erreur.set(messageErreur(e, 'Impossible de charger les grossistes.'));
        this.chargement.set(false);
      }
    });
  }

  readonly lignes = computed<LigneGrossiste[]>(() =>
    this.comptes().map(compte => {
      const tous = this.groupes().filter(g => g.grossiste?.id === compte.id);
      const siens = tous.filter(g => ETATS_SEQUESTRE.includes(g.statut));
      const courtiers = [...new Set(tous.map(g => g.courtier?.nom).filter(Boolean))];
      const enDirect = tous.some(g => g.porteParGrossiste);
      return {
        compte,
        groupesActifs: siens.length,
        produits: [...new Set(siens.map(g => g.produit?.nom).filter(Boolean))].join(', ') || 'Aucun groupe en cours',
        sequestre: siens.reduce((t, g) => t + g.prixUnitaire * g.quantiteConfirmee, 0),
        partenaires: [...courtiers, ...(enDirect ? ['groupes en direct'] : [])].join(', ')
      };
    })
  );

  readonly agrees = computed(() => this.comptes().filter(c => c.statut === 'ACTIF').length);
  readonly lotsEnDistribution = computed(() => this.groupes().filter(g => g.statut === 'OUVERT').length);
  readonly valeurSequestre = computed(() => this.lignes().reduce((t, l) => t + l.sequestre, 0));

  /** Prochain groupe à modérer : stock confirmé par le grossiste, en attente de l'autorisation de publication */
  readonly lotEnAttente = computed(() => this.aPublier().find(g => g.disponibiliteValidee) ?? this.aPublier()[0] ?? null);

  libelleStatut(statut: string): string {
    return { ACTIF: 'Actif', EN_ATTENTE: 'KYC en attente', SUSPENDU: 'Suspendu' }[statut] ?? statut;
  }

  agreer(): void {
    // Grossistes en attente de validation, avec ou sans dossier KYC déposé : chacun s'accepte depuis sa fiche
    void this.router.navigate(['/utilisateurs'], { queryParams: { type: 'GROSSISTE', statut: 'EN_ATTENTE' } });
  }

  /**
   * Un compte en attente de KYC s'examine dans « Validations KYC » ; sinon sa fiche montre ses groupes, ses
   * courtiers partenaires et ses acheteurs, et permet de le suspendre ou de le réactiver.
   */
  gerer(l: LigneGrossiste): void {
    const c = l.compte;
    void this.router.navigate(['/utilisateurs', c.id]);
  }

  readonly peutModerer = computed(() => this.auth.peut('GROUPE_PUBLICATION_VALIDER'));

  approveLot(): void {
    const g = this.lotEnAttente();
    if (!g) {
      return;
    }
    if (!g.disponibiliteValidee) {
      this.message.set('Le grossiste n’a pas encore confirmé son stock (RG-18) : publication impossible.');
      return;
    }
    this.executer(this.api.deciderPublication(g.id, true, 'Conforme'),
      `« ${g.titre} » est publié : les commerçants peuvent le rejoindre.`);
  }

  refuserLot(): void {
    const g = this.lotEnAttente();
    const motif = g && prompt(`Motif du refus de « ${g.titre} » (envoyé au porteur du groupe) :`);
    if (g && motif?.trim()) {
      this.executer(this.api.deciderPublication(g.id, false, motif.trim()), `« ${g.titre} » est renvoyé en brouillon.`);
    }
  }

  private executer(appel: import('rxjs').Observable<unknown>, succes: string): void {
    this.envoi.set(true);
    this.message.set('');
    appel.subscribe({
      next: () => {
        this.envoi.set(false);
        this.message.set(succes);
        this.charger();
      },
      error: e => {
        this.envoi.set(false);
        this.message.set(messageErreur(e, 'Action impossible.'));
      }
    });
  }
}
