import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { Observable, forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { LIBELLES_CONVOI, LIBELLES_GROUPE, fcfa, messageErreur, urlImage } from '../../core/api';
import { AdminApiService, Convoi, Courtier, Groupe } from '../../core/services/admin-api.service';
import { AuthService } from '../../core/services/auth.service';

const ETATS_EN_COURS = ['OUVERT', 'OBJECTIF_ATTEINT', 'EN_EXPEDITION', 'LIVRE'];

export interface LigneCourtier {
  compte: Courtier;
  groupe: Groupe | null;
  convoi: Convoi | null;
  sequestre: number;
  statut: string;
  badge: string;
}

/**
 * Courtiers & transitaires : comptes réels, groupes qu'ils pilotent, convois en cours et fonds en séquestre
 * (part du courtier = prix payé moins les frais de plateforme, RG-38). Suspension via COMPTE_SUSPENDRE.
 */
@Component({
  selector: 'app-courtiers',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './courtiers.html',
  styleUrl: './courtiers.scss'
})
export class CourtiersComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  private readonly router = inject(Router);
  private readonly auth = inject(AuthService);

  readonly comptes = signal<Courtier[]>([]);
  readonly groupes = signal<Groupe[]>([]);
  readonly convois = signal<Convoi[]>([]);
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
      comptes: this.api.courtiers(),
      groupes: this.api.groupes().pipe(catchError(() => of([] as Groupe[]))),
      convois: this.api.convois().pipe(catchError(() => of([] as Convoi[])))
    }).subscribe({
      next: ({ comptes, groupes, convois }) => {
        this.comptes.set(comptes ?? []);
        this.groupes.set(groupes ?? []);
        this.convois.set(convois ?? []);
        this.chargement.set(false);
      },
      error: e => {
        this.erreur.set(messageErreur(e, 'Impossible de charger les courtiers.'));
        this.chargement.set(false);
      }
    });
  }

  private groupesDu(courtierId: number): Groupe[] {
    return this.groupes().filter(g => g.courtier?.id === courtierId && ETATS_EN_COURS.includes(g.statut));
  }

  readonly lignes = computed<LigneCourtier[]>(() =>
    this.comptes().map(compte => {
      const siens = this.groupesDu(compte.id);
      const groupe = siens[0] ?? null;
      const convoi = groupe ? this.convois().find(c => c.groupeId === groupe.id) ?? null : null;
      const sequestre = siens.reduce((t, g) => t + (g.prixUnitaire - g.grille.fraisPlateforme) * g.quantiteConfirmee, 0);
      const statut = convoi
        ? LIBELLES_CONVOI[convoi.statut] ?? convoi.statut
        : groupe
          ? LIBELLES_GROUPE[groupe.statut] ?? groupe.statut
          : compte.statut === 'ACTIF' ? 'Disponible' : this.libelleStatut(compte.statut);
      const badge = convoi?.statut === 'ARRIVE' || !groupe ? 'green' : convoi?.statut === 'BLOQUE_DOUANE' ? 'yellow' : 'orange';
      return { compte, groupe, convoi, sequestre, statut, badge };
    })
  );

  readonly actifs = computed(() => this.comptes().filter(c => c.statut === 'ACTIF').length);

  /** Places encore libres dans les groupes ouverts des courtiers */
  readonly capacite = computed(() =>
    this.groupes().filter(g => g.courtier && g.statut === 'OUVERT').reduce((t, g) => t + g.quantiteRestante, 0)
  );

  readonly sequestreTotal = computed(() => this.lignes().reduce((t, l) => t + l.sequestre, 0));

  /** Convois ouverts par pays d'origine */
  readonly corridorsDistribution = computed(() => {
    const parPays = new Map<string, number>();
    for (const c of this.convois().filter(x => x.statut !== 'ARRIVE')) {
      const g = this.groupes().find(x => x.id === c.groupeId);
      if (g?.courtier) {
        const pays = g.produit?.paysOrigine || 'Origine inconnue';
        parPays.set(pays, (parPays.get(pays) ?? 0) + 1);
      }
    }
    const total = [...parPays.values()].reduce((a, b) => a + b, 0);
    return [...parPays.entries()].map(([pays, n]) => ({
      name: pays,
      count: `${n} convoi${n > 1 ? 's' : ''} (${Math.round((n / total) * 100)}%)`
    }));
  });

  libelleStatut(statut: string): string {
    return { ACTIF: 'Actif', EN_ATTENTE: 'KYC en attente', SUSPENDU: 'Suspendu' }[statut] ?? statut;
  }

  agreer(): void {
    // Courtiers en attente de validation, avec ou sans dossier KYC déposé : chacun s'accepte depuis sa fiche
    void this.router.navigate(['/utilisateurs'], { queryParams: { type: 'COURTIER', statut: 'EN_ATTENTE' } });
  }

  registreDouane(): void {
    void this.router.navigate(['/corridors']);
  }

  /** KYC en attente → dossier à examiner ; sinon la fiche (groupes, grossistes fournisseurs, acheteurs, suspension) */
  superviseBroker(l: LigneCourtier): void {
    const c = l.compte;
    void this.router.navigate(['/utilisateurs', c.id]);
  }

  /** Grossistes dont le courtier a monté des groupes */
  fournisseurs(courtierId: number): string {
    return [...new Set(this.groupes().filter(g => g.courtier?.id === courtierId).map(g => g.grossiste?.nom).filter(Boolean))].join(', ');
  }

  /** Signale les courtiers actifs sans licence de transit déclarée */
  checkLicenses(): void {
    const sans = this.comptes().filter(c => c.statut === 'ACTIF' && !c.licenceTransit);
    this.message.set(
      sans.length
        ? `Sans licence déclarée : ${sans.map(c => c.nomSocieteImport || c.nom).join(', ')}.`
        : 'Tous les courtiers actifs ont déclaré une licence de transit.'
    );
  }

  private executer(appel: Observable<unknown>, succes: string): void {
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
