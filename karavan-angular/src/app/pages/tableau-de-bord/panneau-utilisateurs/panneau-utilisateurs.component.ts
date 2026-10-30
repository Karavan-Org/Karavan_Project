import { ChangeDetectionStrategy, Component, EventEmitter, OnInit, Output, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { MatIconModule } from '@angular/material/icon';
import { catchError, of } from 'rxjs';
import { dateCourte, dateRelative, messageErreur } from '../../../core/api';
import { LIBELLES_COMPTE, LIBELLES_TYPE } from '../../../core/permissions';
import { AdminApiService, LigneAudit } from '../../../core/services/admin-api.service';
import { AnnuaireService, Membre, TypeActeur, normaliser } from '../../../core/services/annuaire.service';
import { AuthService } from '../../../core/services/auth.service';

type FiltreType = TypeActeur | 'TOUS';

/** Nombre d'actions affichées par utilisateur quand on déplie sa ligne */
const ACTIONS_AFFICHEES = 10;

/**
 * Tiroir « Utilisateurs » du tableau de bord : nombre de comptes, leur état et les actions qu'ils ont menées sur la
 * plateforme (journal d'audit, lisible par les fonctions qui détiennent AUDIT_LIRE, comme sur la fiche utilisateur).
 */
@Component({
  selector: 'app-panneau-utilisateurs',
  standalone: true,
  imports: [CommonModule, RouterLink, MatIconModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './panneau-utilisateurs.component.html',
  styleUrl: './panneau-utilisateurs.component.scss'
})
export class PanneauUtilisateursComponent implements OnInit {
  @Output() fermer = new EventEmitter<void>();

  private readonly annuaire = inject(AnnuaireService);
  private readonly api = inject(AdminApiService);
  private readonly auth = inject(AuthService);

  readonly libellesType = LIBELLES_TYPE;
  readonly libellesCompte = LIBELLES_COMPTE;
  readonly dateCourte = dateCourte;
  readonly dateRelative = dateRelative;
  readonly types: FiltreType[] = ['TOUS', 'COMMERCANT', 'GROSSISTE', 'COURTIER', 'ADMINISTRATEUR'];

  /** Le journal d'audit n'est lisible qu'avec AUDIT_LIRE (administrateur principal) */
  readonly auditLisible = this.auth.peut('AUDIT_LIRE');

  readonly membres = this.annuaire.membres;
  readonly chargement = this.annuaire.chargement;
  readonly erreur = signal('');
  readonly journal = signal<LigneAudit[]>([]);
  readonly filtreType = signal<FiltreType>('TOUS');
  readonly recherche = signal('');
  readonly deplie = signal<number | null>(null);

  /** Actions de chaque compte, les plus récentes d'abord */
  private readonly actionsParActeur = computed(() => {
    const parActeur = new Map<number, LigneAudit[]>();
    for (const ligne of this.journal()) {
      if (ligne.acteurId == null) continue;
      const liste = parActeur.get(ligne.acteurId) ?? [];
      liste.push(ligne);
      parActeur.set(ligne.acteurId, liste);
    }
    parActeur.forEach(l => l.sort((a, b) => b.date.localeCompare(a.date)));
    return parActeur;
  });

  readonly parStatut = computed(() => {
    const c: Record<string, number> = {};
    this.membres().forEach(m => (c[m.statut] = (c[m.statut] ?? 0) + 1));
    return c;
  });

  readonly parType = computed(() => {
    const c: Record<string, number> = { TOUS: this.membres().length };
    this.membres().forEach(m => (c[m.type] = (c[m.type] ?? 0) + 1));
    return c;
  });

  readonly affiches = computed(() => {
    const type = this.filtreType();
    const mots = normaliser(this.recherche()).split(/\s+/).filter(Boolean);
    return this.membres()
      .filter(m => type === 'TOUS' || m.type === type)
      .filter(m => mots.every(mot => m.recherche.includes(mot)))
      .sort((a, b) => (this.derniereAction(b)?.date ?? '').localeCompare(this.derniereAction(a)?.date ?? ''));
  });

  ngOnInit(): void {
    this.annuaire.charger(true).subscribe({
      error: e => this.erreur.set(messageErreur(e, 'Impossible de charger les utilisateurs.'))
    });
    if (this.auditLisible) {
      this.api.journalAudit(500).pipe(catchError(() => of([] as LigneAudit[])))
        .subscribe(l => this.journal.set(l ?? []));
    }
  }

  actions(m: Membre): LigneAudit[] {
    return (this.actionsParActeur().get(m.id) ?? []).slice(0, ACTIONS_AFFICHEES);
  }

  nombreActions(m: Membre): number {
    return this.actionsParActeur().get(m.id)?.length ?? 0;
  }

  derniereAction(m: Membre): LigneAudit | undefined {
    return this.actionsParActeur().get(m.id)?.[0];
  }

  basculer(m: Membre): void {
    this.deplie.update(id => (id === m.id ? null : m.id));
  }

  /** « PARTICIPATION_CONFIRMEE » → « Participation confirmee » */
  libelleAction(action: string): string {
    const texte = action.replace(/_/g, ' ').toLowerCase();
    return texte.charAt(0).toUpperCase() + texte.slice(1);
  }

  couleurStatut(statut: string): string {
    return statut === 'ACTIF' ? 'vert' : statut === 'EN_ATTENTE' ? 'ocre' : statut === 'SUSPENDU' ? 'rouge' : '';
  }

  initiales(nom: string): string {
    return nom.trim().split(/\s+/).map(p => p[0]).slice(0, 2).join('').toUpperCase() || '?';
  }

  libelleFiltre(t: FiltreType): string {
    return t === 'TOUS' ? 'Tous' : (LIBELLES_TYPE[t] ?? t) + 's';
  }
}
