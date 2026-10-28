import {
  ChangeDetectionStrategy,
  ChangeDetectorRef,
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
import { MatIconModule } from '@angular/material/icon';
import { GroupeCadranVue } from '../tableau-de-bord.service';

export interface CarteCadran3D {
  groupe: GroupeCadranVue;
  indexOriginal: number;
  offset: number; // -3, -2, -1, 0, 1, 2, 3
  transform: string;
  opacity: number;
  zIndex: number;
  estActive: boolean;
  drapeau: string;
  nomPays: string;
  photoUrl?: string;
}

@Component({
  selector: 'app-cadran-groupes',
  standalone: true,
  imports: [CommonModule, MatIconModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="cadran-horizontal-scene" (wheel)="onMolette($event)">
      <!-- Flèche gauche de rotation -->
      <button
        type="button"
        class="nav-cadran-btn btn-gauche"
        (click)="tournerGauche()"
        title="Groupe précédent"
        [disabled]="groupesFiltres.length <= 1"
      >
        <mat-icon>chevron_left</mat-icon>
      </button>

      <!-- Scène 3D avec perspective cylindrique -->
      <div class="cadran-cylindre-3d" #cylindre3d>
        @if (groupesFiltres.length === 0) {
          <div class="aucun-groupe-msg">
            <mat-icon>public_off</mat-icon>
            <span>Aucun convoi actif</span>
          </div>
        } @else {
          <div class="cartes-arc-wrapper">
            @for (item of cartesVisibles; track item.offset) {
              <div
                class="carte-groupe-3d"
                [class.carte-active]="item.estActive"
                [style.transform]="item.transform"
                [style.opacity]="item.opacity"
                [style.zIndex]="item.zIndex"
                (click)="choisirIndex(item.indexOriginal)"
              >
                <!-- En-tête de la carte : Drapeau + #ID -->
                <div class="carte-top-row">
                  <span class="carte-drapeau">{{ item.drapeau }}</span>
                  <span class="carte-id">#{{ item.groupe.id }}</span>
                </div>

                <!-- Nom du pays d'origine -->
                <div class="carte-pays">{{ item.nomPays }}</div>

                <!-- Image produit / Miniature -->
                <div class="carte-media">
                  @if (item.photoUrl) {
                    <img
                      [src]="item.photoUrl"
                      [alt]="item.groupe.titre"
                      class="media-img"
                      (error)="onImageErreur($event, item)"
                    />
                  } @else {
                    <div class="media-placeholder">
                      <span class="icone-produit">{{ obtenirIconeProduit(item.groupe) }}</span>
                    </div>
                  }
                </div>

                <!-- Titre compact du produit ou prix -->
                <div class="carte-footer">
                  <span class="prix-badge">
                    {{ (item.groupe.prixUnitaire || 0).toLocaleString('fr-FR') }} <small>FCFA</small>
                  </span>
                  <div class="mini-jauge">
                    <div class="jauge-remplie" [style.width.%]="item.groupe.progressionPourcentage || 0"></div>
                  </div>
                </div>
              </div>
            }
          </div>
        }
      </div>

      <!-- Flèche droite de rotation -->
      <button
        type="button"
        class="nav-cadran-btn btn-droite"
        (click)="tournerDroite()"
        title="Groupe suivant"
        [disabled]="groupesFiltres.length <= 1"
      >
        <mat-icon>chevron_right</mat-icon>
      </button>

      <!-- Zone inférieure : Pagination par points + Bouton Tourner le cadran -->
      <div class="cadran-bas-actions">
        <!-- Points de pagination -->
        <div class="dots-pagination">
          @for (g of groupesFiltres; track (g.id + '_' + idx); let idx = $index) {
            <button
              type="button"
              class="dot-indicateur"
              [class.dot-actif]="idx === indexActif"
              (click)="choisirIndex(idx)"
              [title]="g.titre"
            ></button>
          }
        </div>

        <!-- Bouton pillule d'action : Tourner le cadran -->
        <button
          type="button"
          class="btn-tourner-cadran"
          (click)="tournerDroite()"
          title="Faire tourner le cadran mécanique vers le groupe suivant"
        >
          <mat-icon class="icon-spin-step">sync</mat-icon>
          <span>Tourner le cadran</span>
        </button>
      </div>
    </div>
  `,
  styles: [`
    :host {
      display: block;
      width: 100%;
    }

    .cadran-horizontal-scene {
      position: relative;
      width: 100%;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      user-select: none;
      perspective: 1200px;
    }

    // 1. Boutons flèches flottants
    .nav-cadran-btn {
      position: absolute;
      top: 38%;
      transform: translateY(-50%);
      width: 44px;
      height: 44px;
      border-radius: 50%;
      border: 1px solid rgba(255, 255, 255, 0.4);
      background: rgba(15, 23, 42, 0.7);
      backdrop-filter: blur(10px);
      color: #FFFFFF;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      z-index: 50;
      transition: all 0.25s ease;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.35);

      &:hover:not(:disabled) {
        background: #2563EB;
        border-color: #3B82F6;
        box-shadow: 0 0 16px rgba(59, 130, 246, 0.6);
        transform: translateY(-50%) scale(1.1);
      }

      &:active:not(:disabled) {
        transform: translateY(-50%) scale(0.95);
      }

      &:disabled {
        opacity: 0.3;
        cursor: not-allowed;
      }

      &.btn-gauche {
        left: 20px;
      }

      &.btn-droite {
        right: 20px;
      }

      mat-icon {
        font-size: 26px;
        width: 26px;
        height: 26px;
      }
    }

    // 2. Scène cylindrique 3D
    .cadran-cylindre-3d {
      position: relative;
      width: 100%;
      height: 220px;
      display: flex;
      align-items: center;
      justify-content: center;
      transform-style: preserve-3d;
    }

    .cartes-arc-wrapper {
      position: relative;
      width: 100%;
      height: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
      transform-style: preserve-3d;
    }

    // 3. Carte individuelle sur l'arc 3D
    .carte-groupe-3d {
      position: absolute;
      width: 124px;
      height: 160px;
      background: linear-gradient(145deg, rgba(20, 30, 55, 0.88) 0%, rgba(10, 16, 32, 0.94) 100%);
      border: 1px solid rgba(255, 255, 255, 0.15);
      border-radius: 16px;
      padding: 10px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      color: #FFFFFF;
      cursor: pointer;
      box-shadow: 0 12px 30px rgba(0, 0, 0, 0.45), inset 0 1px 0 rgba(255, 255, 255, 0.2);
      backdrop-filter: blur(12px);
      transition: transform 0.45s cubic-bezier(0.2, 0.8, 0.2, 1),
                  opacity 0.45s ease,
                  box-shadow 0.35s ease,
                  border-color 0.35s ease;
      will-change: transform, opacity;

      &:hover:not(.carte-active) {
        border-color: rgba(59, 130, 246, 0.5);
      }

      // Carte active mise en valeur avec halo néon bleu cyan
      &.carte-active {
        width: 136px;
        height: 174px;
        border: 2px solid #3B82F6;
        box-shadow: 0 0 28px rgba(59, 130, 246, 0.65),
                    inset 0 0 14px rgba(59, 130, 246, 0.35),
                    0 16px 36px rgba(0, 0, 0, 0.6);
        background: linear-gradient(145deg, rgba(30, 48, 88, 0.94) 0%, rgba(15, 25, 48, 0.98) 100%);
      }
    }

    .carte-top-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      font-size: 11px;
      font-weight: 700;

      .carte-drapeau {
        font-size: 18px;
        line-height: 1;
        filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.4));
      }

      .carte-id {
        color: #93C5FD;
        letter-spacing: 0.5px;
        font-size: 11px;
      }
    }

    .carte-pays {
      font-size: 12px;
      font-weight: 700;
      color: #FFFFFF;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      margin-top: 2px;
      text-shadow: 0 1px 3px rgba(0, 0, 0, 0.6);
    }

    .carte-media {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 6px 0;
      overflow: hidden;
      border-radius: 10px;
      background: rgba(255, 255, 255, 0.04);

      .media-img {
        width: 100%;
        height: 100%;
        object-fit: cover;
        border-radius: 8px;
      }

      .media-placeholder {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 100%;
        height: 100%;

        .icone-produit {
          font-size: 28px;
          filter: drop-shadow(0 2px 6px rgba(0, 0, 0, 0.5));
        }
      }
    }

    .carte-footer {
      display: flex;
      flex-direction: column;
      gap: 4px;

      .prix-badge {
        font-size: 11px;
        font-weight: 800;
        color: #E2E8F0;
        text-align: center;
        white-space: nowrap;

        small {
          font-size: 9px;
          color: #93C5FD;
        }
      }

      .mini-jauge {
        width: 100%;
        height: 3px;
        background: rgba(255, 255, 255, 0.15);
        border-radius: 2px;
        overflow: hidden;

        .jauge-remplie {
          height: 100%;
          background: #3B82F6;
          border-radius: 2px;
        }
      }
    }

    // 4. Zone basse : points + bouton
    .cadran-bas-actions {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 12px;
      margin-top: 10px;
      z-index: 30;
    }

    .dots-pagination {
      display: flex;
      align-items: center;
      gap: 8px;

      .dot-indicateur {
        width: 8px;
        height: 8px;
        border-radius: 50%;
        background: rgba(255, 255, 255, 0.25);
        border: none;
        padding: 0;
        cursor: pointer;
        transition: all 0.25s ease;

        &:hover {
          background: rgba(255, 255, 255, 0.5);
          transform: scale(1.2);
        }

        &.dot-actif {
          width: 10px;
          height: 10px;
          background: #2563EB;
          box-shadow: 0 0 10px #3B82F6;
        }
      }
    }

    .btn-tourner-cadran {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: #FFFFFF;
      color: #0F172A;
      font-size: 13px;
      font-weight: 700;
      padding: 10px 22px;
      border-radius: 30px;
      border: 1px solid rgba(255, 255, 255, 0.8);
      box-shadow: 0 6px 20px rgba(0, 0, 0, 0.25);
      cursor: pointer;
      transition: all 0.25s ease;

      &:hover {
        background: #F1F5F9;
        transform: translateY(-2px);
        box-shadow: 0 8px 24px rgba(0, 0, 0, 0.35);

        .icon-spin-step {
          transform: rotate(180deg);
        }
      }

      &:active {
        transform: translateY(0);
      }

      .icon-spin-step {
        font-size: 18px;
        width: 18px;
        height: 18px;
        color: #2563EB;
        transition: transform 0.4s ease;
      }
    }

    .aucun-groupe-msg {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 8px;
      color: rgba(255, 255, 255, 0.6);
      font-size: 14px;

      mat-icon {
        font-size: 32px;
        width: 32px;
        height: 32px;
      }
    }
  `]
})
export class CadranGroupesComponent implements OnChanges {
  @Input() groupes: GroupeCadranVue[] = [];
  @Input() paysFiltre: string | null = null;
  @Input() groupeSelectionneId: number | null = null;

  @Output() groupeSelectionne = new EventEmitter<GroupeCadranVue>();

  indexActif = 0;
  groupesFiltres: GroupeCadranVue[] = [];
  cartesVisibles: CarteCadran3D[] = [];

  constructor(private readonly cdr: ChangeDetectorRef) {}

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['groupes'] || changes['paysFiltre']) {
      this.appliquerFiltre();
    }
    if (changes['groupeSelectionneId'] && this.groupeSelectionneId != null) {
      const idx = this.groupesFiltres.findIndex(g => g.id === this.groupeSelectionneId);
      if (idx !== -1 && idx !== this.indexActif) {
        this.indexActif = idx;
        this.recalculerCartes3D();
      }
    }
  }

  private appliquerFiltre(): void {
    if (!this.paysFiltre) {
      this.groupesFiltres = [...this.groupes];
    } else {
      this.groupesFiltres = this.groupes.filter(
        g => g.paysOrigine?.codeIso?.toUpperCase() === this.paysFiltre?.toUpperCase()
      );
    }

    if (this.indexActif >= this.groupesFiltres.length) {
      this.indexActif = Math.max(0, this.groupesFiltres.length - 1);
    }

    this.recalculerCartes3D();
  }

  recalculerCartes3D(): void {
    const total = this.groupesFiltres.length;
    if (total === 0) {
      this.cartesVisibles = [];
      this.cdr.markForCheck();
      return;
    }

    // Déterminer la plage d'offsets selon le nombre de groupes disponibles
    let minOffset = -3;
    let maxOffset = 3;

    if (total === 1) {
      minOffset = 0;
      maxOffset = 0;
    } else if (total === 2) {
      minOffset = 0;
      maxOffset = 1;
    } else if (total === 3) {
      minOffset = -1;
      maxOffset = 1;
    } else if (total === 4) {
      minOffset = -1;
      maxOffset = 2;
    } else if (total === 5) {
      minOffset = -2;
      maxOffset = 2;
    } else if (total === 6) {
      minOffset = -2;
      maxOffset = 3;
    }

    const cartes: CarteCadran3D[] = [];

    for (let offset = minOffset; offset <= maxOffset; offset++) {
      let idx = (this.indexActif + offset) % total;
      if (idx < 0) idx += total;

      const groupe = this.groupesFiltres[idx];
      if (!groupe) continue;

      // Paramètres géométriques 3D de l'arc cylindrique
      // L'arc s'incurve vers l'arrière à gauche et à droite
      const angleDeg = offset * 14; // rotation Y en degrés
      const translateX = offset * 142; // espacement horizontal
      const translateZ = -Math.abs(offset) * 42; // profondeur (s'éloigne du spectateur)
      const scale = offset === 0 ? 1.05 : Math.max(0.72, 1 - Math.abs(offset) * 0.09);
      const opacity = offset === 0 ? 1 : Math.max(0.45, 1 - Math.abs(offset) * 0.18);
      const zIndex = 30 - Math.abs(offset);

      const drapeau = groupe.drapeau || this.drapeauParCode(groupe.paysOrigine?.codeIso);
      const nomPays = groupe.paysOrigine?.nomFr || 'International';

      cartes.push({
        groupe,
        indexOriginal: idx,
        offset,
        transform: `translateX(${translateX}px) translateZ(${translateZ}px) rotateY(${angleDeg}deg) scale(${scale})`,
        opacity,
        zIndex,
        estActive: offset === 0,
        drapeau,
        nomPays,
        photoUrl: groupe.produitPhotoUrl
      });
    }

    this.cartesVisibles = cartes;
    this.cdr.markForCheck();
  }

  tournerGauche(): void {
    if (this.groupesFiltres.length <= 1) return;
    this.indexActif = (this.indexActif - 1 + this.groupesFiltres.length) % this.groupesFiltres.length;
    this.recalculerCartes3D();
    this.notifierSelection();
  }

  tournerDroite(): void {
    if (this.groupesFiltres.length <= 1) return;
    this.indexActif = (this.indexActif + 1) % this.groupesFiltres.length;
    this.recalculerCartes3D();
    this.notifierSelection();
  }

  choisirIndex(index: number): void {
    if (index >= 0 && index < this.groupesFiltres.length) {
      this.indexActif = index;
      this.recalculerCartes3D();
      this.notifierSelection();
    }
  }

  private notifierSelection(): void {
    const actif = this.groupesFiltres[this.indexActif];
    if (actif) {
      this.groupeSelectionne.emit(actif);
    }
  }

  onMolette(event: WheelEvent): void {
    event.preventDefault();
    if (event.deltaY > 0 || event.deltaX > 0) {
      this.tournerDroite();
    } else {
      this.tournerGauche();
    }
  }

  onImageErreur(event: Event, item: CarteCadran3D): void {
    item.photoUrl = undefined;
    this.cdr.markForCheck();
  }

  obtenirIconeProduit(groupe: GroupeCadranVue): string {
    const code = groupe.paysOrigine?.codeIso?.toUpperCase();
    const cat = (groupe.categorieNom || '').toLowerCase();
    const titre = (groupe.titre || '').toLowerCase();

    if (titre.includes('cajou') || titre.includes('épice')) return '🥜';
    if (titre.includes('wax') || titre.includes('bazin') || titre.includes('tissu')) return '👗';
    if (titre.includes('argan') || titre.includes('karité') || titre.includes('huile')) return '🧴';
    if (titre.includes('sneaker') || titre.includes('sport') || cat.includes('chaussure')) return '👟';
    if (titre.includes('chemise') || titre.includes('polo') || cat.includes('vêtement')) return '👔';
    if (titre.includes('cuir')) return '👞';
    if (code === 'CI') return '🌾';
    if (code === 'SN') return '🥜';
    if (code === 'MA') return '🫒';
    if (code === 'GH') return '🍫';
    if (code === 'CN') return '📦';
    if (code === 'TR') return '🧵';
    if (code === 'BR') return '👞';
    return '📦';
  }

  drapeauParCode(codeIso?: string | null): string {
    if (!codeIso || codeIso.length !== 2) return '🌐';
    const c = codeIso.toUpperCase();
    const d1 = String.fromCodePoint(0x1F1E6 + (c.charCodeAt(0) - 65));
    const d2 = String.fromCodePoint(0x1F1E6 + (c.charCodeAt(1) - 65));
    return d1 + d2;
  }
}
