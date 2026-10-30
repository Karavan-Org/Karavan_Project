import { ChangeDetectionStrategy, Component, EventEmitter, Input, Output, computed, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatIconModule } from '@angular/material/icon';
import { LIBELLES_GROUPE, dateCourte, fcfa } from '../../../core/api';
import { normaliser } from '../../../core/services/annuaire.service';
import { GroupeCadranVue } from '../tableau-de-bord.service';
import { DrapeauPaysComponent } from '../../../components/drapeau-pays/drapeau-pays.component';

/**
 * Tiroir « Convois » du tableau de bord : les groupes lancés et leurs informations (état, origine, progression,
 * prix, porteurs, échéance). Un clic sur un groupe ouvre son détail complet.
 */
@Component({
  selector: 'app-panneau-convois',
  standalone: true,
  imports: [CommonModule, MatIconModule, DrapeauPaysComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './panneau-convois.component.html',
  styleUrl: './panneau-convois.component.scss'
})
export class PanneauConvoisComponent {
  @Input({ required: true }) set groupes(liste: GroupeCadranVue[]) {
    this.tous.set(liste ?? []);
  }
  @Output() fermer = new EventEmitter<void>();
  @Output() groupeChoisi = new EventEmitter<GroupeCadranVue>();

  readonly libelles = LIBELLES_GROUPE;
  readonly dateCourte = dateCourte;
  readonly fcfa = fcfa;

  private readonly tous = signal<GroupeCadranVue[]>([]);
  readonly filtreStatut = signal<string>('TOUS');
  readonly recherche = signal('');

  readonly parStatut = computed(() => {
    const c: Record<string, number> = { TOUS: this.tous().length };
    this.tous().forEach(g => (c[g.statut] = (c[g.statut] ?? 0) + 1));
    return c;
  });

  /** États présents, dans l'ordre du cycle de vie d'un groupe */
  readonly statuts = computed(() =>
    ['TOUS', ...Object.keys(LIBELLES_GROUPE).filter(s => this.parStatut()[s])]);

  readonly totaux = computed(() => {
    const liste = this.tous();
    const pieces = liste.reduce((s, g) => s + g.quantiteConfirmee + g.quantiteReservee, 0);
    const cible = liste.reduce((s, g) => s + g.quantiteCible, 0);
    return {
      ouverts: liste.filter(g => g.statut === 'OUVERT').length,
      pays: new Set(liste.map(g => g.paysOrigine?.codeIso).filter(Boolean)).size,
      progression: cible ? Math.round((pieces / cible) * 100) : 0
    };
  });

  readonly affiches = computed(() => {
    const statut = this.filtreStatut();
    const mots = normaliser(this.recherche()).split(/\s+/).filter(Boolean);
    return this.tous()
      .filter(g => statut === 'TOUS' || g.statut === statut)
      .filter(g => {
        const texte = normaliser([g.id, g.titre, g.paysOrigine?.nomFr, g.grossiste?.nom, g.courtier?.nom, g.categorieNom]
          .filter(Boolean).join(' '));
        return mots.every(m => texte.includes(m));
      })
      .sort((a, b) => (b.dateLancement ?? '').localeCompare(a.dateLancement ?? ''));
  });

  libelleStatut(s: string): string {
    return s === 'TOUS' ? 'Tous' : (LIBELLES_GROUPE[s] ?? s);
  }

  couleur(statut: string): string {
    switch (statut) {
      case 'OUVERT': return 'vert';
      case 'OBJECTIF_ATTEINT':
      case 'EN_EXPEDITION':
      case 'LIVRE': return 'brun';
      case 'EN_VALIDATION':
      case 'BROUILLON': return 'ocre';
      case 'ANNULE':
      case 'ECHOUE': return 'rouge';
      default: return '';
    }
  }

  pieces(g: GroupeCadranVue): number {
    return g.quantiteConfirmee + g.quantiteReservee;
  }
}
