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

export interface ChambreRevolver {
  groupe: GroupeCadranVue;
  indexOriginal: number;
  angleDeg: number;
  x: number;
  y: number;
  scale: number;
  opacity: number;
  estActive: boolean;
  pourcentage: number;
  drapeau: string;
}

@Component({
  selector: 'app-cadran-groupes',
  standalone: true,
  imports: [CommonModule, FormsModule, MatIconModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="barillet-revolver-container" (wheel)="onMolette($event)">
      <!-- 1. En-tête compact du barillet -->
      <div class="barillet-header">
        <div class="titre-revolver">
          <span class="icone-barillet">⚙️</span>
          <span class="titre-texte">Barillet Groupes</span>
        </div>
        <span class="compteur-chambres">
          {{ groupesFiltres.length > 0 ? indexActif + 1 : 0 }} / {{ groupesFiltres.length }}
        </span>
      </div>

      <!-- 2. Commandes de rotation mécanique (Haut) -->
      <button
        type="button"
        class="btn-rotation btn-haut"
        (click)="tournerHaut()"
        title="Faire tourner le barillet vers le haut"
      >
        <mat-icon>keyboard_arrow_up</mat-icon>
      </button>

      <!-- 3. Demi-cylindre / Arc de cercle du barillet (180° à gauche de la planète) -->
      <div class="arene-barillet" #areneBarillet>
        <!-- Courbure métallique du corps du barillet -->
        <svg class="arc-metal-guide" viewBox="0 0 210 340" preserveAspectRatio="none">
          <defs>
            <linearGradient id="metal-grad" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" stop-color="#2D231C" />
              <stop offset="40%" stop-color="#4A3B32" />
              <stop offset="85%" stop-color="#8F6243" />
              <stop offset="100%" stop-color="#EEA823" stop-opacity="0.8" />
            </linearGradient>
          </defs>
          <!-- Arc semi-circulaire ouvert vers la droite (épousant la planète) -->
          <path
            d="M 138,26 Q 40,170 138,314"
            fill="none"
            stroke="url(#metal-grad)"
            stroke-width="12"
            stroke-linecap="round"
          />
          <path
            d="M 138,26 Q 40,170 138,314"
            fill="none"
            stroke="#EEA823"
            stroke-width="2"
            stroke-dasharray="4 8"
            opacity="0.75"
          />
        </svg>

        <!-- Ligne de mire / encoche d'alignement avec la planète -->
        <div class="ligne-mire-alignement">
          <div class="cran-aligneur"></div>
          <div class="laser-reticule"></div>
        </div>

        @if (groupesFiltres.length === 0) {
          <div class="aucun-groupe-barillet">
            <mat-icon>search_off</mat-icon>
            <span>Aucun groupe</span>
          </div>
        } @else {
          <!-- Les alvéoles / chambres de barillet disposées en arc de cercle -->
          <div class="conteneur-chambres">
            @for (chambre of chambresVisibles; track chambre.groupe.id) {
              <div
                class="alveole-revolver"
                [class.chambrée]="chambre.estActive"
                [style.transform]="'translate(' + chambre.x + 'px, ' + chambre.y + 'px) scale(' + chambre.scale + ')'"
                [style.opacity]="chambre.opacity"
                (click)="choisirGroupeParIndex(chambre.indexOriginal)"
                [title]="chambre.groupe.titre"
              >
                <!-- Anneau circulaire de progression (jauge de barillet) -->
                <svg class="jauge-chambre-svg" viewBox="0 0 44 44">
                  <circle
                    class="piste-fond"
                    cx="22"
                    cy="22"
                    r="19"
                  />
                  <circle
                    class="piste-progression"
                    cx="22"
                    cy="22"
                    r="19"
                    [style.strokeDashoffset]="calculerDashoffset(chambre.pourcentage)"
                    [class.progression-complete]="chambre.pourcentage >= 100"
                  />
                </svg>

                <!-- Cœur de l'alvéole / trou de balle métallique -->
                <div class="trou-cylindre">
                  <span class="drapeau-origine">{{ chambre.drapeau }}</span>
                  <span class="code-groupe">{{ chambre.pourcentage }}%</span>
                </div>

                <!-- Pastille d'état chambré -->
                @if (chambre.estActive) {
                  <span class="pastille-chambree-aura"></span>
                }
              </div>
            }
          </div>
        }
      </div>

      <!-- 4. Commandes de rotation mécanique (Bas) -->
      <button
        type="button"
        class="btn-rotation btn-bas"
        (click)="tournerBas()"
        title="Faire tourner le barillet vers le bas"
      >
        <mat-icon>keyboard_arrow_down</mat-icon>
      </button>

      <!-- 5. Fiche rétractable du groupe chambré (aligné avec la mire) -->
      @if (groupeActif) {
        <div class="fiche-groupe-chambre">
          <div class="chambre-titre-ligne">
            <span class="statut-badge" [ngClass]="classeStatut(groupeActif.statut)">
              {{ libelleStatut(groupeActif.statut) }}
            </span>
            <span class="pays-badge">
              {{ drapeauPays(groupeActif.paysOrigine?.codeIso || '') }}
              {{ groupeActif.paysOrigine?.nomFr || 'Origine libre' }}
            </span>
          </div>

          <h4 class="titre-produit" [title]="groupeActif.titre">{{ groupeActif.titre }}</h4>

          <div class="stats-chambre">
            <div class="stat-col">
              <span class="lbl">Réservé</span>
              <span class="val">{{ groupeActif.quantiteConfirmee + groupeActif.quantiteReservee }} / {{ groupeActif.quantiteCible }} pcs</span>
            </div>
            <div class="stat-col">
              <span class="lbl">Prix Unitaire</span>
              <span class="val">{{ (groupeActif.prixUnitaire || 0).toLocaleString('fr-FR') }} <small>FCFA</small></span>
            </div>
          </div>

          <button
            type="button"
            class="btn-examiner-groupe"
            (click)="groupeSelectionne.emit(groupeActif)"
          >
            <span>Détails du convoi</span>
            <mat-icon>arrow_forward</mat-icon>
          </button>
        </div>
      }
    </div>
  `,
  styles: [`
    .barillet-revolver-container {
      position: relative;
      display: flex;
      flex-direction: column;
      align-items: center;
      width: 210px;
      height: 100%;
      min-height: 540px;
      user-select: none;
      z-index: 20;
    }

    // 1. En-tête
    .barillet-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      width: 100%;
      padding: 8px 12px;
      background: #FFFFFF;
      border-radius: 14px;
      border: 1px solid rgba(143, 98, 67, 0.16);
      box-shadow: 0 2px 10px rgba(45, 35, 28, 0.05);
      margin-bottom: 6px;

      .titre-revolver {
        display: flex;
        align-items: center;
        gap: 6px;

        .icone-barillet {
          font-size: 14px;
        }

        .titre-texte {
          font-size: 12px;
          font-weight: 800;
          color: #2D231C;
          text-transform: uppercase;
          letter-spacing: 0.5px;
        }
      }

      .compteur-chambres {
        font-size: 11px;
        font-weight: 800;
        color: #8F6243;
        background: #FAF8F5;
        padding: 2px 7px;
        border-radius: 10px;
        border: 1px solid rgba(143, 98, 67, 0.2);
      }
    }

    // 2. Boutons de rotation mécanique
    .btn-rotation {
      width: 38px;
      height: 30px;
      background: #FFFFFF;
      border: 1.5px solid rgba(143, 98, 67, 0.25);
      border-radius: 15px;
      color: #8F6243;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      box-shadow: 0 2px 8px rgba(45, 35, 28, 0.08);
      transition: all 0.2s cubic-bezier(0.2, 0.8, 0.2, 1);
      z-index: 10;

      mat-icon {
        font-size: 20px;
        width: 20px;
        height: 20px;
      }

      &:hover {
        background: #8F6243;
        color: #FFFFFF;
        border-color: #8F6243;
        transform: scale(1.08);
        box-shadow: 0 4px 12px rgba(143, 98, 67, 0.3);
      }

      &:active {
        transform: scale(0.95);
      }

      &.btn-haut {
        margin-bottom: 4px;
      }

      &.btn-bas {
        margin-top: 4px;
      }
    }

    // 3. Arène semi-circulaire du barillet
    .arene-barillet {
      position: relative;
      width: 100%;
      height: 340px;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    // SVG Guide métallique
    .arc-metal-guide {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      pointer-events: none;
      z-index: 1;
    }

    // Ligne de mire et réticule d'alignement avec la planète
    .ligne-mire-alignement {
      position: absolute;
      top: 50%;
      right: -12px;
      transform: translateY(-50%);
      display: flex;
      align-items: center;
      z-index: 5;
      pointer-events: none;

      .cran-aligneur {
        width: 10px;
        height: 10px;
        background: #EEA823;
        clip-path: polygon(100% 50%, 0 0, 0 100%);
      }

      .laser-reticule {
        width: 20px;
        height: 2px;
        background: linear-gradient(90deg, #EEA823, transparent);
      }
    }

    .conteneur-chambres {
      position: absolute;
      top: 50%;
      left: 50%;
      width: 0;
      height: 0;
      z-index: 6;
    }

    // 4. Alvéole / Chambre de revolver
    .alveole-revolver {
      position: absolute;
      width: 62px;
      height: 62px;
      margin-left: -31px;
      margin-top: -31px;
      border-radius: 50%;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: transform 0.35s cubic-bezier(0.2, 0.8, 0.2, 1),
                  opacity 0.35s ease,
                  box-shadow 0.35s ease;
      background: radial-gradient(circle at 35% 35%, #4A3B32 0%, #2D231C 70%, #17120F 100%);
      box-shadow: inset 0 3px 8px rgba(0, 0, 0, 0.75), 0 4px 12px rgba(45, 35, 28, 0.3);
      border: 2px solid rgba(143, 98, 67, 0.5);

      &:hover:not(.chambrée) {
        border-color: #EEA823;
        box-shadow: inset 0 3px 8px rgba(0, 0, 0, 0.75), 0 0 14px rgba(238, 168, 35, 0.4);
      }

      // Chambre alignée / engagée (chambrée)
      &.chambrée {
        border: 2.5px solid #EEA823;
        box-shadow: inset 0 2px 6px rgba(0, 0, 0, 0.9), 0 0 22px rgba(238, 168, 35, 0.85);
        z-index: 15;

        .trou-cylindre {
          background: radial-gradient(circle at 35% 35%, #5E4B40 0%, #352922 80%);
        }

        .pastille-chambree-aura {
          position: absolute;
          inset: -6px;
          border-radius: 50%;
          border: 1.5px solid #EEA823;
          animation: pulserAura 2s infinite ease-in-out;
          pointer-events: none;
        }
      }

      // Jauge circulaire SVG
      .jauge-chambre-svg {
        position: absolute;
        inset: -2px;
        width: calc(100% + 4px);
        height: calc(100% + 4px);
        transform: rotate(-90deg);
        pointer-events: none;

        .piste-fond {
          fill: none;
          stroke: rgba(255, 255, 255, 0.08);
          stroke-width: 2.5;
        }

        .piste-progression {
          fill: none;
          stroke: #EEA823;
          stroke-width: 3;
          stroke-linecap: round;
          stroke-dasharray: 119.38; // 2 * PI * 19
          transition: stroke-dashoffset 0.4s ease;

          &.progression-complete {
            stroke: #10B981;
          }
        }
      }

      // Intérieur de l'alvéole
      .trou-cylindre {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        width: 48px;
        height: 48px;
        border-radius: 50%;
        background: radial-gradient(circle at 35% 35%, #3D2F27 0%, #1E1612 90%);
        box-shadow: inset 0 2px 6px rgba(0, 0, 0, 0.8);

        .drapeau-origine {
          font-size: 16px;
          line-height: 1;
        }

        .code-groupe {
          font-size: 10px;
          font-weight: 800;
          color: #FAF8F5;
          margin-top: 2px;
          letter-spacing: 0.2px;
        }
      }
    }

    // 5. Fiche rétractable du groupe actif
    .fiche-groupe-chambre {
      width: 100%;
      background: #FFFFFF;
      border: 1px solid rgba(143, 98, 67, 0.16);
      border-radius: 14px;
      padding: 10px 12px;
      box-shadow: 0 4px 16px rgba(45, 35, 28, 0.08);
      margin-top: 6px;
      display: flex;
      flex-direction: column;
      gap: 6px;

      .chambre-titre-ligne {
        display: flex;
        justify-content: space-between;
        align-items: center;
        font-size: 10.5px;
      }

      .statut-badge {
        font-size: 9.5px;
        font-weight: 800;
        padding: 2px 6px;
        border-radius: 6px;
        text-transform: uppercase;

        &.statut-ouvert { background: rgba(16, 185, 129, 0.12); color: #10B981; }
        &.statut-objectif { background: rgba(238, 168, 35, 0.15); color: #C6820A; }
        &.statut-transit { background: rgba(21, 101, 192, 0.12); color: #1565C0; }
        &.statut-termine { background: rgba(140, 126, 116, 0.15); color: #8C7E74; }
      }

      .pays-badge {
        font-weight: 700;
        color: #2D231C;
        font-size: 10.5px;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        max-width: 90px;
      }

      .titre-produit {
        margin: 0;
        font-size: 11.5px;
        font-weight: 800;
        color: #2D231C;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
      }

      .stats-chambre {
        display: flex;
        justify-content: space-between;
        background: #FAF8F5;
        padding: 5px 8px;
        border-radius: 8px;

        .stat-col {
          display: flex;
          flex-direction: column;

          .lbl {
            font-size: 9px;
            color: #8C7E74;
            font-weight: 600;
          }

          .val {
            font-size: 10.5px;
            font-weight: 800;
            color: #2D231C;

            small {
              font-size: 8.5px;
              color: #EEA823;
            }
          }
        }
      }

      .btn-examiner-groupe {
        width: 100%;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 6px;
        background: #8F6243;
        color: #FFFFFF;
        border: none;
        border-radius: 8px;
        padding: 6px 10px;
        font-size: 11px;
        font-weight: 700;
        cursor: pointer;
        transition: background 0.2s ease;

        mat-icon {
          font-size: 14px;
          width: 14px;
          height: 14px;
        }

        &:hover {
          background: #734c31;
        }
      }
    }

    .aucun-groupe-barillet {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 4px;
      color: #8C7E74;
      font-size: 12px;
      font-weight: 600;

      mat-icon {
        color: #8F6243;
        font-size: 24px;
      }
    }

    @keyframes pulserAura {
      0% { transform: scale(1); opacity: 0.8; }
      50% { transform: scale(1.15); opacity: 0.3; }
      100% { transform: scale(1); opacity: 0.8; }
    }
  `]
})
export class CadranGroupesComponent implements OnChanges {
  @Input() groupes: GroupeCadranVue[] = [];
  @Input() filtrePays: string | null = null;
  @Output() groupeSelectionne = new EventEmitter<GroupeCadranVue>();

  indexActif = 0;
  groupesFiltres: GroupeCadranVue[] = [];
  chambresVisibles: ChambreRevolver[] = [];

  // Rayon de l'arc de cercle du barillet (en px)
  private readonly RAYON_ARC = 155;
  // Décalage angulaire entre les chambres le long du demi-cercle
  private readonly PAS_ANGULAIRE = 34;

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
    this.groupesFiltres = res;
    if (this.indexActif >= this.groupesFiltres.length) {
      this.indexActif = Math.max(0, this.groupesFiltres.length - 1);
    }
    this.calculerChambresVisibles();
  }

  get groupeActif(): GroupeCadranVue | null {
    if (this.groupesFiltres.length === 0) return null;
    return this.groupesFiltres[this.indexActif] || null;
  }

  choisirGroupeParIndex(index: number): void {
    if (index >= 0 && index < this.groupesFiltres.length) {
      this.indexActif = index;
      this.calculerChambresVisibles();
      const g = this.groupesFiltres[index];
      this.groupeSelectionne.emit(g);
    }
  }

  tournerHaut(): void {
    if (this.groupesFiltres.length === 0) return;
    const nouveau = (this.indexActif - 1 + this.groupesFiltres.length) % this.groupesFiltres.length;
    this.choisirGroupeParIndex(nouveau);
  }

  tournerBas(): void {
    if (this.groupesFiltres.length === 0) return;
    const nouveau = (this.indexActif + 1) % this.groupesFiltres.length;
    this.choisirGroupeParIndex(nouveau);
  }

  onMolette(event: WheelEvent): void {
    event.preventDefault();
    if (event.deltaY > 20) {
      this.tournerBas();
    } else if (event.deltaY < -20) {
      this.tournerHaut();
    }
  }

  @HostListener('keydown.arrowdown', ['$event'])
  onArrowDown(event: any): void {
    event?.preventDefault?.();
    this.tournerBas();
  }

  @HostListener('keydown.arrowup', ['$event'])
  onArrowUp(event: any): void {
    event?.preventDefault?.();
    this.tournerHaut();
  }

  /**
   * Calcule les positions polaires des 5 chambres visibles le long du demi-cercle (arc 180°).
   * L'angle 0° pointe vers la gauche (-X), avec ouverture du cercle vers la planète à droite (+X).
   */
  private calculerChambresVisibles(): void {
    const total = this.groupesFiltres.length;
    if (total === 0) {
      this.chambresVisibles = [];
      return;
    }

    const chambres: ChambreRevolver[] = [];
    // 5 alvéoles : décalages de -2, -1, 0 (centre engagé), +1, +2
    const offsets = [-2, -1, 0, 1, 2];

    for (const offset of offsets) {
      const idx = (this.indexActif + offset + total * 10) % total;
      const g = this.groupesFiltres[idx];
      const angleDeg = offset * this.PAS_ANGULAIRE;
      const angleRad = (angleDeg * Math.PI) / 180;

      // Courbure de demi-cercle à gauche de la planète :
      // - À angle = 0 (centre), x est le plus à gauche (-RAYON_ARC)
      // - À angle = +/- 68°, x remonte vers la droite (-RAYON_ARC * cos(angle))
      // Centre de coordonnées décalé pour s'inscrire harmonieusement dans l'arène :
      const cx = 90; // pivot horizontal
      const cy = 0;  // pivot vertical

      const x = cx - this.RAYON_ARC * Math.cos(angleRad);
      const y = cy + this.RAYON_ARC * Math.sin(angleRad);

      const estActive = offset === 0;
      const scale = estActive ? 1.18 : Math.max(0.72, 1 - Math.abs(offset) * 0.16);
      const opacity = estActive ? 1 : Math.max(0.45, 1 - Math.abs(offset) * 0.28);
      const pct = this.calculerPourcentage(g);

      chambres.push({
        groupe: g,
        indexOriginal: idx,
        angleDeg,
        x,
        y,
        scale,
        opacity,
        estActive,
        pourcentage: pct,
        drapeau: this.drapeauPays(g.paysOrigine?.codeIso || '')
      });
    }

    this.chambresVisibles = chambres;
  }

  calculerDashoffset(pourcentage: number): number {
    const circonference = 119.38; // 2 * PI * 19
    const clamp = Math.max(0, Math.min(100, pourcentage));
    return circonference - (clamp / 100) * circonference;
  }

  calculerPourcentage(g: GroupeCadranVue): number {
    if (!g || g.quantiteCible <= 0) return 0;
    const reserve = (g.quantiteConfirmee || 0) + (g.quantiteReservee || 0);
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
      case 'EXPEDIE': return 'Transit';
      case 'LIVRE': return 'Arrivé';
      case 'TERMINE': return 'Clôturé';
      default: return statut || 'Actif';
    }
  }

  drapeauPays(codeIso: string): string {
    if (!codeIso || codeIso.length !== 2) return '🌐';
    const p = codeIso.toUpperCase().charCodeAt(0) - 65 + 0x1F1E6;
    const s = codeIso.toUpperCase().charCodeAt(1) - 65 + 0x1F1E6;
    return String.fromCodePoint(p, s);
  }
}
