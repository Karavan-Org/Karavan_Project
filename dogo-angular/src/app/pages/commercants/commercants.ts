import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { Observable, forkJoin, of } from 'rxjs';
import { catchError, map, switchMap } from 'rxjs/operators';
import { LIBELLES_COMMANDE, fcfa, messageErreur, urlImage } from '../../core/api';
import { AdminApiService, Commercant, Groupe } from '../../core/services/admin-api.service';

/** Commande d'un commerçant vue par l'administrateur, avec le prix de son groupe */
export interface CommandeAdmin {
  id: number;
  groupeId: number;
  produit: string;
  quantite: number;
  statut: string;
  commercantId: number | null;
  montant: number;
}

export interface LigneCommercant {
  compte: Commercant;
  commandes: CommandeAdmin[];
  sequestre: number;
  statut: string;
  badge: 'green' | 'orange' | 'yellow';
}

/** Groupes dont les commandes peuvent encore bouger (avant TERMINE) */
const ETATS_COMMANDES = ['OBJECTIF_ATTEINT', 'EN_EXPEDITION', 'LIVRE'];

/**
 * Commerçants : comptes réels, leurs commandes en cours (groupes en acheminement), fonds encore en séquestre
 * et assistance au retrait (nouveau code PIN par SMS, RG-54 ; validation d'un retrait au dépôt, RG-55).
 */
@Component({
  selector: 'app-commercants',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './commercants.html',
  styleUrl: './commercants.scss'
})
export class CommercantsComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  private readonly router = inject(Router);

  readonly comptes = signal<Commercant[]>([]);
  readonly commandes = signal<CommandeAdmin[]>([]);
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
      comptes: this.api.commercants(),
      commandes: this.api.groupes().pipe(
        switchMap(groupes => this.commandesDes(groupes.filter(g => ETATS_COMMANDES.includes(g.statut)))),
        catchError(() => of([] as CommandeAdmin[]))
      )
    }).subscribe({
      next: ({ comptes, commandes }) => {
        this.comptes.set(comptes ?? []);
        this.commandes.set(commandes);
        this.chargement.set(false);
      },
      error: e => {
        this.erreur.set(messageErreur(e, 'Impossible de charger les commerçants.'));
        this.chargement.set(false);
      }
    });
  }

  private commandesDes(groupes: Groupe[]): Observable<CommandeAdmin[]> {
    if (!groupes.length) {
      return of([]);
    }
    return forkJoin(
      groupes.map(g =>
        this.api.commandesDuGroupe(g.id).pipe(
          map(liste =>
            liste.map(c => ({
              id: c.id,
              groupeId: g.id,
              produit: g.produit?.nom ?? g.titre,
              quantite: c.quantite,
              statut: c.statut,
              commercantId: c.commercantId ?? null,
              montant: c.quantite * g.prixUnitaire
            }))
          ),
          catchError(() => of([] as CommandeAdmin[]))
        )
      )
    ).pipe(map(listes => listes.flat()));
  }

  readonly lignes = computed<LigneCommercant[]>(() =>
    this.comptes().map(compte => {
      const siennes = this.commandes().filter(c => c.commercantId === compte.id && !['COLLECTEE', 'ANNULEE'].includes(c.statut));
      const prete = siennes.some(c => c.statut === 'EN_ATTENTE_RETRAIT');
      const auDepot = siennes.some(c => c.statut === 'ARRIVEE');
      const enTransit = siennes.some(c => ['PREPAREE', 'EXPEDIEE', 'CREEE'].includes(c.statut));
      const statut = prete ? 'Prêt pour retrait' : auDepot ? 'Au dépôt' : enTransit ? 'En transit' : compte.statut === 'ACTIF' ? 'Sécurisé' : compte.statut;
      return {
        compte,
        commandes: siennes,
        sequestre: siennes.reduce((t, c) => t + c.montant, 0),
        statut,
        badge: prete ? 'green' : auDepot ? 'yellow' : enTransit ? 'orange' : 'green'
      };
    })
  );

  readonly enAttenteRetrait = computed(() => this.commandes().filter(c => c.statut === 'EN_ATTENTE_RETRAIT').length);
  readonly sequestreAcheteurs = computed(() => this.lignes().reduce((t, l) => t + l.sequestre, 0));

  /** Répartition des boutiques par quartier de Bamako déclaré à l'inscription */
  readonly marketDistribution = computed(() => {
    const parQuartier = new Map<string, number>();
    for (const c of this.comptes()) {
      const q = c.quartierBamako || 'Quartier non renseigné';
      parQuartier.set(q, (parQuartier.get(q) ?? 0) + 1);
    }
    const total = this.comptes().length || 1;
    return [...parQuartier.entries()]
      .sort((a, b) => b[1] - a[1])
      .map(([name, n]) => ({ name, count: `${n} boutique${n > 1 ? 's' : ''} (${Math.round((n / total) * 100)}%)` }));
  });

  resumeCommandes(l: LigneCommercant): string {
    return l.commandes.length
      ? l.commandes.map(c => `${c.quantite} × ${c.produit} (${LIBELLES_COMMANDE[c.statut] ?? c.statut})`).join(' + ')
      : 'Aucune commande en cours';
  }

  /** Fiche du commerçant : groupes payés, grossistes et courtiers associés, commandes, suspension */
  consultMerchant(l: LigneCommercant): void {
    void this.router.navigate(['/utilisateurs', l.compte.id]);
  }

  /** RG-54 : un code bloqué ou perdu est remplacé ; le nouveau PIN part par SMS au commerçant */
  generateEmergencyPin(): void {
    const saisie = prompt('Numéro de la commande dont le code de retrait doit être régénéré :');
    const id = Number(saisie);
    if (!saisie || !Number.isInteger(id) || id <= 0) {
      return;
    }
    this.executer(this.api.regenererCodeRetrait(id), `Nouveau code envoyé par SMS au commerçant de la commande #${id}.`);
  }

  /** RG-53 à RG-55 : scan du QR code (caméra ou lecteur) ou n° de commande + PIN, sur la page dédiée */
  validerRetrait(): void {
    void this.router.navigate(['/retraits']);
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
