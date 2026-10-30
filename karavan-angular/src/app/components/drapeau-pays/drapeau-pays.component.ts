import { ChangeDetectionStrategy, Component, Input, computed, inject, signal } from '@angular/core';
import { PaysResolverService } from '../../core/services/pays-resolver.service';

/**
 * Drapeau d'un pays (SVG flag-icons embarqué, aucun appel réseau) avec nom français officiel.
 * Accepte un code ISO 2 ou 3 lettres, un nom français ou anglais. Une saisie non reconnue
 * affiche un globe neutre et le texte tel quel, jamais un pays deviné.
 */
@Component({
  selector: 'app-drapeau-pays',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <span class="drapeau" [class.badge]="badge" [class.compact]="compact" [title]="info().nomFr">
      <span
        class="cadre"
        [style.width.px]="largeur"
        [style.height.px]="hauteur"
        role="img"
        [attr.aria-label]="info().nomFr || 'Pays non renseigné'">
        @if (info().reconnu) {
          <span [class]="'fi fi-' + info().codeIso.toLowerCase()"></span>
        } @else {
          <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9" /><path d="M3 12h18M12 3c2.5 2.6 3.8 5.6 3.8 9s-1.3 6.4-3.8 9c-2.5-2.6-3.8-5.6-3.8-9S9.5 5.6 12 3z" /></svg>
        }
      </span>
      @if ((avecNom || badge) && info().nomFr) {
        <span class="nom">{{ info().nomFr }}</span>
      }
      @if (avecCode && info().reconnu) {
        <span class="code">{{ info().codeIso }}</span>
      }
    </span>
  `,
  styles: [`
    :host { display: inline-flex; align-items: center; vertical-align: middle; }

    .drapeau { display: inline-flex; align-items: center; gap: 6px; min-width: 0; }

    .cadre {
      position: relative;
      flex-shrink: 0;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      border-radius: 2px;
      overflow: hidden;
      background: var(--surface-alt, #F3F4F6);
      box-shadow: inset 0 0 0 0.5px rgba(0, 0, 0, 0.14);

      .fi { width: 100%; height: 100%; line-height: 1; background-size: cover; }

      svg {
        width: 80%;
        height: 80%;
        fill: none;
        stroke: var(--text-muted, #6B7280);
        stroke-width: 1.6;
      }
    }

    .nom {
      font-size: 0.92em;
      font-weight: 600;
      color: var(--text-main, #1F2937);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .code {
      font-size: 0.78em;
      font-weight: 600;
      letter-spacing: 0.04em;
      color: var(--text-muted, #6B7280);
    }

    .badge {
      padding: 3px 8px;
      border-radius: 6px;
      border: 1px solid var(--border, #E5E7EB);
      background: var(--surface, #FFFFFF);

      &.compact { padding: 2px 6px; gap: 5px; font-size: 12px; }
    }
  `]
})
export class DrapeauPaysComponent {
  private readonly paysResolver = inject(PaysResolverService);
  private readonly saisie = signal('');

  @Input() set pays(valeur: string | null | undefined) {
    this.saisie.set(valeur ?? '');
  }

  @Input() largeur = 20;
  @Input() hauteur = 15;
  @Input() avecNom = false;
  @Input() avecCode = false;
  @Input() badge = false;
  @Input() compact = false;

  readonly info = computed(() => this.paysResolver.resoudre(this.saisie()));
}
