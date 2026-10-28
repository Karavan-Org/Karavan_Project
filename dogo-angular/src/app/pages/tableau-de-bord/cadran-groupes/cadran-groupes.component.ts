import {
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  EventEmitter,
  HostListener,
  Input,
  OnChanges,
  Output,
  SimpleChanges,
  ViewChild
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatIconModule } from '@angular/material/icon';
import { GroupeCadranVue } from '../tableau-de-bord.service';

@Component({
  selector: 'app-cadran-groupes',
  standalone: true,
  imports: [CommonModule, FormsModule, MatIconModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="cadran-container" #cadranRoot tabindex="0">
      <div class="cadran-header">
        <div class="titre-bloc">
          <mat-icon class="compass-icon">explore</mat-icon>
          <h3>Cadran des Groupes</h3>
          <span class="badge-count">{{ groupesFiltres.length }}</span>
        </div>

        <!-- Recherche rapide -->
        <div class="recherche-wrapper">
          <mat-icon>search</mat-icon>
          <input
            type="text"
            placeholder="Filtrer par nom, pays..."
            [(ngModel)]="termeRecherche"
            (ngModelChange)="filtrer()"
          />
          @if (termeRecherche) {
            <button type="button" class="btn-clear" (click)="termeRecherche = ''; filtrer()">
              <mat-icon>close</mat-icon>
            </button>
          }
        </div>

        <!-- Filtres par statut -->
        <div class="filtres-onglets">
          @for (f of filtres; track f.id) {
            <button
              type="button"
              class="filtre-btn"
              [class.active]="filtreActif === f.id"
              (click)="definirFiltre(f.id)"
            >
              {{ f.label }}
            </button>
          }
        </div>
      </div>

      <!-- Liste courbe avec effet de cadran / arc de cercle -->
      <div
        class="cadran-roue"
        #cadranRoue
        (wheel)="onMolette($event)"
      >
        @if (groupesFiltres.length === 0) {
          <div class="aucun-groupe">
            <mat-icon>info_outline</mat-icon>
            <p>Aucun groupe d'achat ne correspond aux filtres.</p>
          </div>
        } @else {
          <div class="roue-liste">
            @for (g of groupesFiltres; track g.id; let idx = $index) {
              <div
                class="carte-groupe"
                [class.selectionne]="indexActif === idx"
                (click)="choisirGroupe(idx)"
              >
                <!-- Jauge circulaire de progression -->
                <div class="jauge-wrapper">
                  <svg viewBox="0 0 36 36" class="jauge-circulaire">
                    <path
                      class="cercle-fond"
                      d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                    />
                    <path
                      class="cercle-progression"
                      [attr.stroke-dasharray]="calculerPourcentage(g) + ', 100'"
                      d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                    />
                  </svg>
                  <span class="jauge-texte">{{ calculerPourcentage(g) }}%</span>
                </div>

                <!-- Informations du groupe -->
                <div class="infos-groupe">
                  <div class="ligne-haut">
                    <span class="statut-pilule" [ngClass]="classeStatut(g.statut)">
                      {{ libelleStatut(g.statut) }}
                    </span>
                    @if (g.paysOrigine) {
                      <span class="pays-badge" [title]="g.paysOrigine.nomFr">
                        {{ drapeauPays(g.paysOrigine.codeIso) }} {{ g.paysOrigine.codeIso }}
                      </span>
                    } @else {
                      <span class="sans-pays-badge" title="Pays d'origine non renseigné">
                        Origine ?
                      </span>
                    }
                  </div>

                  <h4 class="titre-groupe" [title]="g.titre">{{ g.titre }}</h4>

                  <div class="ligne-details">
                    <span class="quantites">
                      <strong>{{ g.quantiteConfirmee + g.quantiteReservee }}</strong> / {{ g.quantiteCible }} pcs
                    </span>
                    <span class="prix">
                      {{ (g.prixUnitaire || 0).toLocaleString('fr-FR') }} FCFA
                    </span>
                  </div>
                </div>

                <mat-icon class="chevron-selection">chevron_right</mat-icon>
              </div>
            }
          </div>
        }
      </div>

      <!-- Navigation pied de cadran -->
      <div class="cadran-pied">
        <button
          type="button"
          class="btn-nav"
          (click)="precedent()"
          [disabled]="indexActif <= 0"
        >
          <mat-icon>keyboard_arrow_up</mat-icon>
        </button>
        <span class="position-info">
          {{ groupesFiltres.length > 0 ? indexActif + 1 : 0 }} / {{ groupesFiltres.length }}
        </span>
        <button
          type="button"
          class="btn-nav"
          (click)="suivant()"
          [disabled]="indexActif >= groupesFiltres.length - 1"
        >
          <mat-icon>keyboard_arrow_down</mat-icon>
        </button>
      </div>
    </div>
  `,
  styles: [`
    .cadran-container {
      display: flex;
      flex-direction: column;
      height: 100%;
      background: #FFFFFF;
      border-radius: 20px;
      padding: 18px;
      box-shadow: 0 4px 20px rgba(45, 35, 28, 0.06);
      border: 1px solid rgba(143, 98, 67, 0.14);
      outline: none;
    }

    .cadran-header {
      margin-bottom: 14px;
    }

    .titre-bloc {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 12px;

      .compass-icon {
        color: #8F6243;
        font-size: 22px;
        width: 22px;
        height: 22px;
      }

      h3 {
        margin: 0;
        font-size: 16px;
        font-weight: 800;
        color: #2D231C;
      }

      .badge-count {
        background: #FAF8F5;
        border: 1px solid #8F6243;
        color: #8F6243;
        font-size: 11.5px;
        font-weight: 700;
        padding: 2px 8px;
        border-radius: 12px;
        margin-left: auto;
      }
    }

    .recherche-wrapper {
      position: relative;
      display: flex;
      align-items: center;
      background: #FAF8F5;
      border: 1px solid rgba(45, 35, 28, 0.12);
      border-radius: 12px;
      padding: 0 10px;
      margin-bottom: 10px;

      mat-icon {
        color: #8F6243;
        font-size: 18px;
        width: 18px;
        height: 18px;
      }

      input {
        flex: 1;
        border: none;
        background: transparent;
        padding: 8px;
        font-size: 12.5px;
        color: #2D231C;
        outline: none;

        &::placeholder {
          color: #8C7E74;
        }
      }

      .btn-clear {
        background: transparent;
        border: none;
        color: #8C7E74;
        cursor: pointer;
        padding: 0;
        display: flex;
        align-items: center;

        mat-icon {
          font-size: 15px;
        }
      }
    }

    .filtres-onglets {
      display: flex;
      gap: 6px;
      overflow-x: auto;
      padding-bottom: 4px;
    }

    .filtre-btn {
      background: #FAF8F5;
      border: 1px solid rgba(45, 35, 28, 0.1);
      color: #2D231C;
      font-size: 11px;
      font-weight: 600;
      padding: 4px 10px;
      border-radius: 16px;
      cursor: pointer;
      white-space: nowrap;
      transition: all 0.2s ease;

      &:hover {
        background: rgba(143, 98, 67, 0.1);
      }

      &.active {
        background: #8F6243;
        color: #FFFFFF;
        border-color: #8F6243;
      }
    }

    .cadran-roue {
      flex: 1;
      overflow-y: auto;
      padding: 6px 2px;
      scroll-behavior: smooth;
    }

    .roue-liste {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }

    .carte-groupe {
      display: flex;
      align-items: center;
      gap: 12px;
      background: #FAF8F5;
      border: 1.5px solid rgba(45, 35, 28, 0.08);
      border-radius: 16px;
      padding: 12px 14px;
      cursor: pointer;
      transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);

      &:hover {
        transform: translateX(4px);
        border-color: rgba(143, 98, 67, 0.35);
        background: #FFFFFF;
        box-shadow: 0 4px 14px rgba(45, 35, 28, 0.08);
      }

      &.selectionne {
        background: #FFFFFF;
        border-color: #8F6243;
        box-shadow: 0 6px 20px rgba(143, 98, 67, 0.18);
        transform: scale(1.02) translateX(4px);

        .chevron-selection {
          color: #EEA823;
          transform: translateX(2px);
        }
      }
    }

    .jauge-wrapper {
      position: relative;
      width: 44px;
      height: 44px;
      flex-shrink: 0;

      .jauge-circulaire {
        width: 100%;
        height: 100%;
        transform: rotate(-90deg);
      }

      .cercle-fond {
        fill: none;
        stroke: rgba(45, 35, 28, 0.1);
        stroke-width: 3.5;
      }

      .cercle-progression {
        fill: none;
        stroke: #EEA823;
        stroke-width: 3.5;
        stroke-linecap: round;
        transition: stroke-dasharray 0.5s ease;
      }

      .jauge-texte {
        position: absolute;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        font-size: 10.5px;
        font-weight: 800;
        color: #2D231C;
      }
    }

    .infos-groupe {
      flex: 1;
      min-width: 0;
    }

    .ligne-haut {
      display: flex;
      align-items: center;
      gap: 6px;
      margin-bottom: 4px;
    }

    .statut-pilule {
      font-size: 9.5px;
      font-weight: 700;
      padding: 2px 7px;
      border-radius: 8px;
      text-transform: uppercase;
      letter-spacing: 0.3px;

      &.statut-ouvert {
        background: #E8F5E9;
        color: #2E7D32;
      }

      &.statut-objectif {
        background: #FFF8E1;
        color: #F57F17;
      }

      &.statut-transit {
        background: #E3F2FD;
        color: #1565C0;
      }

      &.statut-termine {
        background: #ECEFF1;
        color: #455A64;
      }
    }

    .pays-badge {
      font-size: 11px;
      font-weight: 700;
      color: #8F6243;
      margin-left: auto;
    }

    .sans-pays-badge {
      font-size: 10px;
      font-weight: 700;
      color: #D32F2F;
      background: #FFEBEE;
      padding: 2px 6px;
      border-radius: 6px;
      margin-left: auto;
    }

    .titre-groupe {
      margin: 0 0 6px 0;
      font-size: 13.5px;
      font-weight: 700;
      color: #2D231C;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .ligne-details {
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 11.5px;
      color: #8C7E74;

      .quantites strong {
        color: #2D231C;
      }

      .prix {
        font-weight: 700;
        color: #8F6243;
      }
    }

    .chevron-selection {
      color: rgba(45, 35, 28, 0.2);
      font-size: 20px;
      transition: all 0.2s ease;
    }

    .cadran-pied {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding-top: 10px;
      border-top: 1px solid rgba(45, 35, 28, 0.08);

      .btn-nav {
        background: #FAF8F5;
        border: 1px solid rgba(45, 35, 28, 0.12);
        border-radius: 10px;
        width: 32px;
        height: 32px;
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
        color: #8F6243;

        &:disabled {
          opacity: 0.3;
          cursor: not-allowed;
        }

        &:hover:not(:disabled) {
          background: #8F6243;
          color: #FFFFFF;
        }

        mat-icon {
          font-size: 20px;
        }
      }

      .position-info {
        font-size: 12px;
        font-weight: 700;
        color: #8C7E74;
      }
    }

    .aucun-groupe {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 40px 10px;
      text-align: center;
      color: #8C7E74;

      mat-icon {
        font-size: 32px;
        width: 32px;
        height: 32px;
        margin-bottom: 8px;
        color: #8F6243;
      }

      p {
        margin: 0;
        font-size: 13px;
      }
    }
  `]
})
export class CadranGroupesComponent implements OnChanges {
  @ViewChild('cadranRoue') cadranRoue!: ElementRef<HTMLDivElement>;

  @Input() groupes: GroupeCadranVue[] = [];
  @Input() filtrePays: string | null = null;
  @Output() groupeSelectionne = new EventEmitter<GroupeCadranVue>();

  termeRecherche = '';
  filtreActif = 'TOUS';
  indexActif = 0;
  groupesFiltres: GroupeCadranVue[] = [];

  readonly filtres = [
    { id: 'TOUS', label: 'Tous' },
    { id: 'OUVERT', label: 'Ouverts' },
    { id: 'EN_COURS', label: 'En transit' },
    { id: 'OBJECTIF_ATTEINT', label: 'Atteints' }
  ];

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['groupes'] || changes['filtrePays']) {
      this.filtrer();
    }
  }

  filtrer(): void {
    let res = [...this.groupes];

    if (this.filtrePays) {
      res = res.filter(g => g.paysOrigine?.codeIso === this.filtrePays);
    }

    if (this.filtreActif !== 'TOUS') {
      if (this.filtreActif === 'EN_COURS') {
        res = res.filter(g => ['EN_VALIDATION', 'EN_PREPARATION', 'EN_EXPEDITION', 'EXPEDIE', 'LIVRE'].includes(g.statut));
      } else {
        res = res.filter(g => g.statut === this.filtreActif);
      }
    }

    if (this.termeRecherche.trim()) {
      const q = this.termeRecherche.trim().toLowerCase();
      res = res.filter(g =>
        g.titre.toLowerCase().includes(q) ||
        (g.paysOrigine?.nomFr.toLowerCase().includes(q) ?? false) ||
        (g.categorieNom?.toLowerCase().includes(q) ?? false)
      );
    }

    this.groupesFiltres = res;
    if (this.indexActif >= this.groupesFiltres.length) {
      this.indexActif = Math.max(0, this.groupesFiltres.length - 1);
    }
  }

  definirFiltre(id: string): void {
    this.filtreActif = id;
    this.filtrer();
  }

  choisirGroupe(index: number): void {
    if (index >= 0 && index < this.groupesFiltres.length) {
      this.indexActif = index;
      const g = this.groupesFiltres[index];
      this.groupeSelectionne.emit(g);
    }
  }

  precedent(): void {
    if (this.indexActif > 0) {
      this.choisirGroupe(this.indexActif - 1);
      this.faireDefilerVersCarte(this.indexActif);
    }
  }

  suivant(): void {
    if (this.indexActif < this.groupesFiltres.length - 1) {
      this.choisirGroupe(this.indexActif + 1);
      this.faireDefilerVersCarte(this.indexActif);
    }
  }

  onMolette(event: WheelEvent): void {
    if (event.deltaY > 20) {
      this.suivant();
    } else if (event.deltaY < -20) {
      this.precedent();
    }
  }

  @HostListener('keydown.arrowdown', ['$event'])
  onArrowDown(event: any): void {
    event?.preventDefault?.();
    this.suivant();
  }

  @HostListener('keydown.arrowup', ['$event'])
  onArrowUp(event: any): void {
    event?.preventDefault?.();
    this.precedent();
  }

  private faireDefilerVersCarte(index: number): void {
    const el = this.cadranRoue?.nativeElement;
    if (!el) return;
    const cartes = el.querySelectorAll('.carte-groupe');
    if (cartes[index]) {
      cartes[index].scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }
  }

  calculerPourcentage(g: GroupeCadranVue): number {
    if (g.quantiteCible <= 0) return 0;
    const reserve = g.quantiteConfirmee + g.quantiteReservee;
    return Math.min(100, Math.round((reserve / g.quantiteCible) * 100));
  }

  classeStatut(statut: string): string {
    switch (statut) {
      case 'OUVERT': return 'statut-ouvert';
      case 'OBJECTIF_ATTEINT': return 'statut-objectif';
      case 'TERMINE': return 'statut-termine';
      default: return 'statut-transit';
    }
  }

  libelleStatut(statut: string): string {
    switch (statut) {
      case 'OUVERT': return 'Ouvert';
      case 'OBJECTIF_ATTEINT': return 'Atteint';
      case 'EN_VALIDATION': return 'Validation';
      case 'EN_PREPARATION': return 'Préparation';
      case 'EN_EXPEDITION':
      case 'EXPEDIE': return 'En transit';
      case 'LIVRE': return 'Arrivé';
      case 'TERMINE': return 'Clôturé';
      default: return statut;
    }
  }

  drapeauPays(codeIso: string): string {
    if (!codeIso || codeIso.length !== 2) return '🌐';
    const p = codeIso.toUpperCase().charCodeAt(0) - 65 + 0x1F1E6;
    const s = codeIso.toUpperCase().charCodeAt(1) - 65 + 0x1F1E6;
    return String.fromCodePoint(p, s);
  }
}
