import { Component, Input, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { DomSanitizer, SafeHtml } from '@angular/platform-browser';
import { PaysResolverService } from '../../core/services/pays-resolver.service';

@Component({
  selector: 'app-drapeau-pays',
  standalone: true,
  imports: [CommonModule],
  template: `
    @if (badge) {
      <span class="drapeau-badge-pill" [class.badge-compact]="compact">
        <span
          class="drapeau-img-wrapper"
          [style.width.px]="largeur"
          [style.height.px]="hauteur"
          [innerHTML]="svgSecurise()"
        ></span>
        <span class="drapeau-nom">{{ info().nomFr }}</span>
        @if (avecCode) {
          <span class="drapeau-code">({{ info().codeIso }})</span>
        }
      </span>
    } @else {
      <span class="drapeau-inline-wrapper" [class.inline-flex]="avecNom || avecCode">
        <span
          class="drapeau-img-wrapper"
          [style.width.px]="largeur"
          [style.height.px]="hauteur"
          [innerHTML]="svgSecurise()"
        ></span>
        @if (avecNom) {
          <span class="drapeau-nom">{{ info().nomFr }}</span>
        }
        @if (avecCode) {
          <span class="drapeau-code">({{ info().codeIso }})</span>
        }
      </span>
    }
  `,
  styles: [`
    :host {
      display: inline-flex;
      align-items: center;
      vertical-align: middle;
    }

    .drapeau-img-wrapper {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      overflow: hidden;
      border-radius: 3.5px;
      border: 1px solid rgba(0, 0, 0, 0.18);
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.14);
      background-color: rgba(255, 255, 255, 0.15);
      flex-shrink: 0;

      ::ng-deep svg {
        width: 100%;
        height: 100%;
        display: block;
        object-fit: cover;
      }
    }

    .drapeau-inline-wrapper.inline-flex {
      display: inline-flex;
      align-items: center;
      gap: 6px;
    }

    .drapeau-badge-pill {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 3px 8px;
      border-radius: 8px;
      background: rgba(172, 127, 94, 0.10);
      border: 1px solid rgba(172, 127, 94, 0.25);
      color: inherit;
      font-size: 12px;
      font-weight: 700;
      line-height: 1.2;

      &.badge-compact {
        padding: 2px 6px;
        gap: 4px;
        font-size: 11px;
      }
    }

    .drapeau-nom {
      font-weight: 700;
    }

    .drapeau-code {
      font-weight: 800;
      opacity: 0.75;
      font-size: 0.9em;
    }
  `]
})
export class DrapeauPaysComponent {
  private readonly paysResolver = inject(PaysResolverService);
  private readonly sanitizer = inject(DomSanitizer);

  @Input() set pays(valeur: string | null | undefined) {
    this._paysSaisie.set(valeur ?? '');
  }

  @Input() largeur = 22;
  @Input() hauteur = 15;
  @Input() avecNom = false;
  @Input() avecCode = false;
  @Input() badge = false;
  @Input() compact = false;

  private readonly _paysSaisie = signal<string>('ML');

  readonly info = computed(() => {
    return this.paysResolver.resoudre(this._paysSaisie());
  });

  readonly svgSecurise = computed<SafeHtml>(() => {
    const rawSvg = this.paysResolver.svgDrapeau(this.info().codeIso);
    return this.sanitizer.bypassSecurityTrustHtml(rawSvg);
  });
}
