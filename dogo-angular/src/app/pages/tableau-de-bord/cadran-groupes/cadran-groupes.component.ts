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
import { DrapeauPaysComponent } from '../../../components/drapeau-pays/drapeau-pays.component';
import { PaysResolverService } from '../../../core/services/pays-resolver.service';

export interface CarteCadran3D {
  groupe: GroupeCadranVue;
  indexOriginal: number;
  offset: number; // -3, -2, -1, 0, 1, 2, 3
  baseTx: string;
  baseTz: string;
  baseRy: string;
  baseScale: number;
  opacity: number;
  zIndex: number;
  estActive: boolean;
  nomPays: string;
  photoUrl?: string;
}

@Component({
  selector: 'app-cadran-groupes',
  standalone: true,
  imports: [CommonModule, MatIconModule, DrapeauPaysComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div
      class="cadran-horizontal-scene"
      [class.en-glissement]="glissementActif"
      (wheel)="onMolette($event)"
    >
      <!-- Flèche gauche de rotation (<) : fait tourner le cadran SANS ouvrir le tiroir -->
      <button
        type="button"
        class="nav-cadran-btn btn-gauche"
        (click)="tournerGauche()"
        (pointerdown)="$event.stopPropagation()"
        (pointerup)="$event.stopPropagation()"
        title="Groupe précédent (Flèche gauche)"
        [disabled]="groupesFiltres.length === 0"
        aria-label="Groupe précédent"
      >
        <mat-icon>chevron_left</mat-icon>
      </button>

      <!-- Scène 3D avec perspective cylindrique et glissement tactile/souris -->
      <div
        class="cadran-cylindre-3d"
        #cylindre3d
        (pointerdown)="onPointerDown($event)"
        (pointermove)="onPointerMove($event)"
        (pointerup)="onPointerUp($event)"
        (pointercancel)="onPointerCancel($event)"
      >
        @if (groupesFiltres.length === 0) {
          <div class="aucun-groupe-msg">
            <mat-icon>public_off</mat-icon>
            <span>Aucun groupe actif</span>
          </div>
        } @else {
          <div
            #cartesWrapper
            class="cartes-arc-wrapper"
            [class.glissement-actif]="glissementActif"
          >
            @for (item of cartesVisibles; track item.groupe.id) {
              <div
                class="carte-groupe-3d"
                [class.carte-active]="item.estActive"
                [class.carte-survolee]="survolId === item.groupe.id"
                [class.carte-laterale]="!item.estActive"
                [style.--offset]="item.offset"
                [style.--base-tx]="item.baseTx"
                [style.--base-tz]="item.baseTz"
                [style.--base-ry]="item.baseRy"
                [style.--base-scale]="item.baseScale"
                [style.--base-opacity]="item.opacity"
                [style.--base-z]="item.zIndex"
                (mouseenter)="onSurvolEntree(item, $event)"
                (mousemove)="onSurvolMouvement(item, $event)"
                (mouseleave)="onSurvolSortie(item, $event)"
                (click)="clicCarte(item, $event)"
                (dblclick)="doubleClicCarte(item, $event)"
                [title]="item.estActive ? (groupeSelectionneId === item.groupe.id ? 'Cliquer pour fermer le détail' : 'Cliquer pour voir le détail de ce produit') : 'Cliquer pour afficher ce groupe au centre'"
              >
                <!-- Badge d'action contextuelle au survol -->
                <div class="carte-action-hint">
                  @if (item.estActive) {
                    <mat-icon>visibility</mat-icon>
                    <span>Détails</span>
                  } @else {
                    <mat-icon>center_focus_strong</mat-icon>
                    <span>Centrer</span>
                  }
                </div>

                <!-- En-tête de la carte : Drapeau + Pays d'origine + #ID -->
                <div class="carte-top-row">
                  <div class="carte-pays-pill" [title]="'Origine : ' + item.nomPays">
                    <app-drapeau-pays [pays]="item.groupe.paysOrigine?.codeIso || item.nomPays" [largeur]="16" [hauteur]="11"></app-drapeau-pays>
                    <span class="carte-pays-nom">{{ item.nomPays }}</span>
                  </div>
                  <span class="carte-id">#{{ item.groupe.id }}</span>
                </div>

                <!-- Nom réel du groupe / produit -->
                <div class="carte-titre-groupe" [title]="item.groupe.titre">
                  {{ item.groupe.titre }}
                </div>

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
                      <mat-icon class="icone-produit">inventory_2</mat-icon>
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

      <!-- Flèche droite de rotation (>) : fait tourner le cadran SANS ouvrir le tiroir -->
      <button
        type="button"
        class="nav-cadran-btn btn-droite"
        (click)="tournerDroite()"
        (pointerdown)="$event.stopPropagation()"
        (pointerup)="$event.stopPropagation()"
        title="Groupe suivant (Flèche droite)"
        [disabled]="groupesFiltres.length === 0"
        aria-label="Groupe suivant"
      >
        <mat-icon>chevron_right</mat-icon>
      </button>

      <!-- Zone inférieure : Barre de commandes (Précédent / Suivant + Points) + Bouton Tourner le cadran -->
      <div class="cadran-bas-actions" (pointerdown)="$event.stopPropagation()">
        <!-- Indice d'interaction à la souris / tactile -->
        <div class="cadran-roulis-hint" title="Glissez avec la souris ou utilisez la molette pour faire tourner le cadran">
          <mat-icon class="hint-icon">drag_indicator</mat-icon>
          <span>Glissez ou roulez avec la souris pour faire tourner le cadran</span>
          <mat-icon class="hint-icon">swipe</mat-icon>
        </div>

        <!-- Barre de commandes complète sans aucun chevauchement avec les cartes -->
        <div class="barre-commandes-row">
          <button
            type="button"
            class="btn-nav-bas btn-prev"
            (click)="tournerGauche()"
            [disabled]="groupesFiltres.length === 0"
            title="Groupe précédent (<)"
            aria-label="Groupe précédent"
          >
            <mat-icon>chevron_left</mat-icon>
            <span>Précédent</span>
          </button>

          <!-- Points de pagination -->
          <div class="dots-pagination">
            @for (g of groupesFiltres; track (g.id + '_' + idx); let idx = $index) {
              <button
                type="button"
                class="dot-indicateur"
                [class.dot-actif]="idx === indexActif"
                (click)="choisirIndex(idx)"
                [title]="nomDuPays(g) ? (nomDuPays(g) + ' - ' + g.titre) : g.titre"
              ></button>
            }
          </div>

          <button
            type="button"
            class="btn-nav-bas btn-next"
            (click)="tournerDroite()"
            [disabled]="groupesFiltres.length === 0"
            title="Groupe suivant (>)"
            aria-label="Groupe suivant"
          >
            <span>Suivant</span>
            <mat-icon>chevron_right</mat-icon>
          </button>
        </div>

        <!-- Bouton pillule d'action : Tourner le cadran -->
        <button
          type="button"
          class="btn-tourner-cadran"
          (click)="tournerDroite()"
          title="Faire tourner le cadran vers le groupe suivant"
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
      cursor: grab;
      touch-action: pan-y;

      &.en-glissement {
        cursor: grabbing !important;

        .carte-groupe-3d {
          cursor: grabbing !important;
          pointer-events: none !important;
        }
      }
    }

    // 1. Boutons flèches flottants (dégagés en hauteur sur l'horizon du globe pour ne jamais toucher les cartes)
    .nav-cadran-btn {
      position: absolute;
      top: 15%;
      transform: translateY(-50%);
      width: 44px;
      height: 44px;
      border-radius: 50%;
      border: 1px solid rgba(238, 168, 35, 0.35);
      background: rgba(24, 54, 48, 0.85);
      backdrop-filter: blur(12px);
      color: #FFFFFF;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      z-index: 60;
      transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
      box-shadow: 0 6px 20px rgba(0, 0, 0, 0.45);

      &:hover:not(:disabled) {
        background: #AC7F5E;
        border-color: #EEA823;
        box-shadow: 0 6px 16px rgba(0, 0, 0, 0.35);
        transform: translateY(-50%) scale(1.12);
      }

      &:active:not(:disabled) {
        transform: translateY(-50%) scale(0.96);
      }

      &:disabled {
        opacity: 0.25;
        cursor: not-allowed;
      }

      &.btn-gauche {
        left: 28px;
      }

      &.btn-droite {
        right: 28px;
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
      transition: transform 0.35s cubic-bezier(0.16, 1, 0.3, 1);
      will-change: transform;

      &.glissement-actif {
        transition: none !important;
      }
    }

    // 3. Carte individuelle sur l'arc 3D
    .carte-groupe-3d {
      position: absolute;
      width: 142px;
      height: 184px;
      background: linear-gradient(145deg, rgba(24, 54, 48, 0.94) 0%, rgba(14, 32, 28, 0.98) 100%);
      border: 1.5px solid rgba(238, 168, 35, 0.25);
      border-radius: 16px;
      padding: 10px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      color: #FFFFFF;
      cursor: pointer;
      box-shadow: 0 12px 30px rgba(0, 0, 0, 0.45), inset 0 1px 0 rgba(255, 255, 255, 0.15);
      backdrop-filter: blur(12px);

      // Positionnement initial sur l'arc 3D via variables CSS matérielles
      transform: translateX(var(--base-tx)) translateZ(var(--base-tz)) rotateY(var(--base-ry)) scale(var(--base-scale));
      opacity: var(--base-opacity);
      z-index: var(--base-z);

      // Vitesse de transition ajustée : fluide, progressive et élégante (520ms)
      transition: transform 0.52s cubic-bezier(0.22, 1, 0.36, 1),
                  opacity 0.45s ease,
                  box-shadow 0.35s ease,
                  border-color 0.35s ease,
                  background 0.35s ease;
      will-change: transform, opacity, box-shadow;
      pointer-events: auto;

      // Carte active centrale au repos
      &.carte-active {
        border-color: #AC7F5E;
        box-shadow: 0 16px 32px rgba(0, 0, 0, 0.45);
      }

      &.carte-laterale {
        &:hover {
          border-color: #EEA823 !important;
        }
      }

      // RÉACTION INTÉRACTIVE AU PASSAGE DU CURSEUR (SOURIS) :
      // La carte s'élève, s'illumine d'or et s'incline subtilement vers la souris en 3D
      &:hover,
      &.carte-survolee {
        transform: translateX(var(--base-tx))
                   translateY(-28px)
                   translateZ(85px)
                   rotateY(calc(var(--base-ry) + var(--survol-tilt-y, 0deg)))
                   rotateX(var(--survol-tilt-x, 0deg))
                   scale(1.22) !important;
        opacity: 1 !important;
        z-index: 1000 !important;
        border-color: #EEA823 !important;
        background: linear-gradient(145deg, rgba(30, 68, 60, 0.98) 0%, rgba(16, 40, 34, 0.99) 100%) !important;
        box-shadow: 0 22px 44px rgba(0, 0, 0, 0.6) !important;
        transition: transform 0.12s ease-out, box-shadow 0.25s ease, border-color 0.25s ease !important;

        .carte-top-row .carte-id {
          color: #FFFFFF;
        }

        .media-img {
          transform: scale(1.08);
        }

        .icone-produit {
          transform: scale(1.18);
        }
      }

      &:active {
        transform: translateX(var(--base-tx)) translateY(-22px) translateZ(75px) scale(1.16) !important;
      }
    }

    // Badge d'action réactive qui apparaît au survol de chaque carte
    .carte-action-hint {
      position: absolute;
      top: -14px;
      left: 50%;
      transform: translateX(-50%) translateY(6px);
      background: #EEA823;
      color: #0F172A;
      font-size: 10.5px;
      font-weight: 800;
      padding: 3px 10px;
      border-radius: 14px;
      display: inline-flex;
      align-items: center;
      gap: 5px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.35);
      opacity: 0;
      pointer-events: none;
      transition: opacity 0.2s ease, transform 0.2s cubic-bezier(0.16, 1, 0.3, 1);
      white-space: nowrap;
      z-index: 100;

      mat-icon {
        font-size: 13px;
        width: 13px;
        height: 13px;
      }
    }

    .carte-groupe-3d:hover .carte-action-hint,
    .carte-groupe-3d.carte-survolee .carte-action-hint {
      opacity: 1;
      transform: translateX(-50%) translateY(0);
    }

    .carte-top-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 6px;
      font-size: 11px;
      font-weight: 700;

      .carte-pays-pill {
        display: inline-flex;
        align-items: center;
        gap: 4px;
        background: rgba(255, 255, 255, 0.08);
        border: 1px solid rgba(255, 255, 255, 0.12);
        border-radius: 8px;
        padding: 2px 6px;
        max-width: 95px;
        overflow: hidden;

        .carte-pays-nom {
          font-size: 10px;
          font-weight: 600;
          color: #E2E8F0;
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
        }
      }

      .carte-id {
        color: #EEA823;
        letter-spacing: 0.5px;
        font-size: 11px;
        font-weight: 800;
      }
    }

    .carte-titre-groupe {
      font-size: 12px;
      font-weight: 800;
      color: #FFFFFF;
      line-height: 1.25;
      margin: 4px 0 2px 0;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
      text-overflow: ellipsis;
      text-shadow: 0 1px 3px rgba(0, 0, 0, 0.6);
      min-height: 28px;
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
        transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1);
      }

      .media-placeholder {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 100%;
        height: 100%;

        .icone-produit {
          font-size: 30px;
          width: 30px;
          height: 30px;
          color: rgba(255, 255, 255, 0.35);
          transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1);
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
          color: #EEA823;
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
          background: linear-gradient(90deg, #AC7F5E, #EEA823);
          border-radius: 2px;
        }
      }
    }

    // 4. Zone basse : commandes (Précédent / Points / Suivant) + bouton tourner
    .cadran-bas-actions {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 10px;
      margin-top: 10px;
      z-index: 40;
    }

    .cadran-roulis-hint {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      font-size: 11px;
      font-weight: 600;
      color: rgba(255, 255, 255, 0.65);
      background: rgba(14, 32, 28, 0.75);
      backdrop-filter: blur(10px);
      border: 1px solid rgba(238, 168, 35, 0.2);
      border-radius: 20px;
      padding: 4px 14px;
      letter-spacing: 0.25px;
      transition: all 0.25s ease;
      box-shadow: 0 4px 14px rgba(0, 0, 0, 0.35);

      .hint-icon {
        font-size: 14px;
        width: 14px;
        height: 14px;
        color: #EEA823;
      }

      &:hover {
        color: #FAF8F5;
        border-color: rgba(238, 168, 35, 0.45);
        background: rgba(24, 54, 48, 0.85);
      }
    }

    .barre-commandes-row {
      display: inline-flex;
      align-items: center;
      gap: 16px;
      background: rgba(24, 54, 48, 0.85);
      backdrop-filter: blur(14px);
      border: 1px solid rgba(238, 168, 35, 0.25);
      border-radius: 30px;
      padding: 6px 16px;
      box-shadow: 0 4px 18px rgba(0, 0, 0, 0.4);

      .btn-nav-bas {
        display: inline-flex;
        align-items: center;
        gap: 6px;
        background: transparent;
        border: none;
        color: #FAF8F5;
        font-size: 12px;
        font-weight: 700;
        cursor: pointer;
        padding: 5px 10px;
        border-radius: 14px;
        transition: all 0.2s ease;

        &:hover:not(:disabled) {
          color: #EEA823;
          background: rgba(238, 168, 35, 0.15);
        }

        &:disabled {
          opacity: 0.3;
          cursor: not-allowed;
        }

        mat-icon {
          font-size: 18px;
          width: 18px;
          height: 18px;
        }
      }
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
          background: rgba(255, 255, 255, 0.6);
          transform: scale(1.25);
        }

        &.dot-actif {
          width: 12px;
          height: 12px;
          background: #EEA823;
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
        background: #FDFBF8;
        border-color: #EEA823;
        transform: translateY(-2px);
        box-shadow: 0 8px 24px rgba(172, 127, 94, 0.25);

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
        color: #AC7F5E;
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

  /** Émis lors de la rotation (flèches < / >, molette, points, glissement souris) : oriente le Globe SANS ouvrir le tiroir */
  @Output() rotationChange = new EventEmitter<GroupeCadranVue>();

  /** Émis UNIQUEMENT lors du clic sur la carte active ou double-clic pour ouvrir son détail */
  @Output() groupeClique = new EventEmitter<GroupeCadranVue>();

  /** Émis quand on clique sur la carte active pour fermer son détail */
  @Output() groupeFerme = new EventEmitter<void>();

  @ViewChild('cartesWrapper') cartesWrapperRef?: ElementRef<HTMLDivElement>;

  indexActif = 0;
  survolId: number | null = null;
  groupesFiltres: GroupeCadranVue[] = [];
  cartesVisibles: CarteCadran3D[] = [];

  // Propriétés de manipulation directe à la souris (Glisser / Faire rouler le cadran)
  glissementActif = false;
  aGlisse = false;
  startX = 0;
  startY = 0;
  deltaX = 0;
  dateDebutGlissement = 0;
  capturedPointerId: number | null = null;

  // Lissage de la molette et cadence de transition
  private dernierTempsMolette = 0;
  private accumulateurMolette = 0;
  private rotationVerrouillee = false;

  constructor(
    private readonly cdr: ChangeDetectorRef,
    private readonly paysResolver: PaysResolverService
  ) {}

  nomDuPays(g: GroupeCadranVue): string {
    const info = this.paysResolver.resoudre(g.paysOrigine?.codeIso || g.paysOrigine?.nomFr);
    return info.reconnu ? info.nomFr : (g.paysOrigine?.nomFr || '');
  }

  // ---------------------------------------------------------------------------
  // INTERACTION DYNAMIQUE AU PASSAGE DU CURSEUR (SOURIS) SUR LES GROUPES
  // ---------------------------------------------------------------------------

  onSurvolEntree(item: CarteCadran3D, event: MouseEvent): void {
    if (this.glissementActif) return;
    this.survolId = item.groupe.id;
    this.cdr.markForCheck();
  }

  onSurvolMouvement(item: CarteCadran3D, event: MouseEvent): void {
    if (this.glissementActif) return;
    const cardEl = event.currentTarget as HTMLElement;
    if (!cardEl) return;
    const rect = cardEl.getBoundingClientRect();
    const x = event.clientX - rect.left - (rect.width / 2);
    const y = event.clientY - rect.top - (rect.height / 2);
    const tiltX = (y / (rect.height / 2)) * -8;
    const tiltY = (x / (rect.width / 2)) * 10;
    cardEl.style.setProperty('--survol-tilt-x', `${tiltX.toFixed(1)}deg`);
    cardEl.style.setProperty('--survol-tilt-y', `${tiltY.toFixed(1)}deg`);
  }

  onSurvolSortie(item: CarteCadran3D, event: MouseEvent): void {
    this.survolId = null;
    const cardEl = event.currentTarget as HTMLElement;
    if (cardEl) {
      cardEl.style.removeProperty('--survol-tilt-x');
      cardEl.style.removeProperty('--survol-tilt-y');
    }
    this.cdr.markForCheck();
  }

  // ---------------------------------------------------------------------------
  // INTERACTION DIRECTE SOURIS / TACTILE : FAIRE ROULER LE CADRAN (DRAG & ROLL)
  // ---------------------------------------------------------------------------

  onPointerDown(event: PointerEvent): void {
    if (this.groupesFiltres.length === 0) return;
    // Ne capturer que le clic principal gauche de la souris ou le contact tactile
    if (event.pointerType === 'mouse' && event.button !== 0) return;

    // Ne JAMAIS intercepter de clic sur un bouton ou la barre de commandes
    const target = event.target as HTMLElement;
    if (target.closest('button') || target.closest('.cadran-bas-actions')) {
      return;
    }

    this.glissementActif = true;
    this.aGlisse = false;
    this.startX = event.clientX;
    this.startY = event.clientY;
    this.deltaX = 0;
    this.dateDebutGlissement = Date.now();

    try {
      (event.currentTarget as HTMLElement)?.setPointerCapture(event.pointerId);
      this.capturedPointerId = event.pointerId;
    } catch (_) {}
  }

  onPointerMove(event: PointerEvent): void {
    if (!this.glissementActif) return;

    const dx = event.clientX - this.startX;
    if (Math.abs(dx) > 6) {
      this.aGlisse = true;
    }

    this.deltaX = dx;

    // Rendu physique direct en temps réel à 120 FPS du cylindre rotatif sous la souris
    if (this.cartesWrapperRef?.nativeElement) {
      const el = this.cartesWrapperRef.nativeElement;
      el.style.transition = 'none';
      const rotY = this.deltaX * 0.07;
      el.style.transform = `translateX(${this.deltaX}px) rotateY(${rotY}deg)`;
    }
  }

  onPointerUp(event: PointerEvent): void {
    if (!this.glissementActif) return;
    this.terminerGlissement(event);
  }

  onPointerCancel(event: PointerEvent): void {
    if (!this.glissementActif) return;
    this.terminerGlissement(event);
  }

  private terminerGlissement(event?: PointerEvent): void {
    this.glissementActif = false;

    if (this.capturedPointerId !== null && event) {
      try {
        (event.currentTarget as HTMLElement)?.releasePointerCapture(this.capturedPointerId);
      } catch (_) {}
      this.capturedPointerId = null;
    }

    const duree = Math.max(1, Date.now() - this.dateDebutGlissement);
    const vitesse = this.deltaX / duree; // pixels par ms

    const seuilDistance = 38; // seuil de déclenchement du cran
    const seuilVitesse = 0.28; // impulsion rapide (flick)

    if (this.deltaX < -seuilDistance || vitesse < -seuilVitesse) {
      // Glissement vers la gauche -> Avancer vers la droite (groupe suivant)
      const pas = Math.min(3, Math.max(1, Math.round(-this.deltaX / 156)));
      this.avancerDe(pas);
    } else if (this.deltaX > seuilDistance || vitesse > seuilVitesse) {
      // Glissement vers la droite -> Reculer vers la gauche (groupe précédent)
      const pas = Math.min(3, Math.max(1, Math.round(this.deltaX / 156)));
      this.reculerDe(pas);
    }

    // Réinitialisation de la transformation avec transition magnétique fluide (snap)
    if (this.cartesWrapperRef?.nativeElement) {
      const el = this.cartesWrapperRef.nativeElement;
      el.style.transition = 'transform 0.35s cubic-bezier(0.16, 1, 0.3, 1)';
      el.style.transform = 'translateX(0px) rotateY(0deg)';
    }

    this.deltaX = 0;
    this.cdr.markForCheck();

    // Maintient aGlisse vrai quelques millisecondes pour éviter qu'un drag ne déclenche un clic accidentel
    setTimeout(() => {
      this.aGlisse = false;
      this.cdr.markForCheck();
    }, 60);
  }

  // ---------------------------------------------------------------------------
  // INTERACTION SOURIS : MOLETTE ET TOUCHPAD (SCROLL FLUIDE DU CADRAN)
  // ---------------------------------------------------------------------------

  onMolette(event: WheelEvent): void {
    event.preventDefault();
    const maintenant = Date.now();
    const delta = Math.abs(event.deltaX) > Math.abs(event.deltaY) ? event.deltaX : event.deltaY;
    this.accumulateurMolette += delta;

    // Déclenchement au-delà d'un seuil avec temporisation pour éviter l'emballement
    if (Math.abs(this.accumulateurMolette) > 35 && (maintenant - this.dernierTempsMolette > 150)) {
      if (this.accumulateurMolette > 0) {
        this.tournerDroite();
      } else {
        this.tournerGauche();
      }
      this.accumulateurMolette = 0;
      this.dernierTempsMolette = maintenant;
    }
  }

  // ---------------------------------------------------------------------------
  // GESTION DU FILTRAGE ET RECALCUL 3D
  // ---------------------------------------------------------------------------

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
    this.groupesFiltres = [...this.groupes];

    if (this.paysFiltre) {
      const idx = this.groupesFiltres.findIndex(
        g => g.paysOrigine?.codeIso?.toUpperCase() === this.paysFiltre?.toUpperCase()
      );
      if (idx !== -1) {
        this.indexActif = idx;
      }
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

      const angleDeg = offset * 13;
      const translateX = offset * 156;
      const translateZ = -Math.abs(offset) * 44;
      const scale = offset === 0 ? 1.06 : Math.max(0.74, 1 - Math.abs(offset) * 0.08);
      const opacity = offset === 0 ? 1 : Math.max(0.55, 1 - Math.abs(offset) * 0.15);
      const zIndex = 30 - Math.abs(offset);

      const infoPays = this.paysResolver.resoudre(groupe.paysOrigine?.codeIso || groupe.paysOrigine?.nomFr);
      const nomPays = infoPays.reconnu ? infoPays.nomFr : (groupe.paysOrigine?.nomFr || 'Origine non renseignée');

      cartes.push({
        groupe,
        indexOriginal: idx,
        offset,
        baseTx: `${translateX}px`,
        baseTz: `${translateZ}px`,
        baseRy: `${angleDeg}deg`,
        baseScale: scale,
        opacity,
        zIndex,
        estActive: offset === 0,
        nomPays,
        photoUrl: groupe.produitPhotoUrl
      });
    }

    this.cartesVisibles = cartes;
    this.cdr.markForCheck();
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION ET ROTATION DU CADRAN
  // ---------------------------------------------------------------------------

  avancerDe(pas: number): void {
    if (this.groupesFiltres.length === 0) return;
    this.indexActif = (this.indexActif + pas) % this.groupesFiltres.length;
    this.recalculerCartes3D();
    this.rotationChange.emit(this.groupesFiltres[this.indexActif]);
  }

  reculerDe(pas: number): void {
    if (this.groupesFiltres.length === 0) return;
    this.indexActif = (this.indexActif - (pas % this.groupesFiltres.length) + this.groupesFiltres.length) % this.groupesFiltres.length;
    this.recalculerCartes3D();
    this.rotationChange.emit(this.groupesFiltres[this.indexActif]);
  }

  /**
   * Rotation à gauche (<) : fait tourner le cadran d'un cran vers la gauche avec transition douce cadencée
   */
  tournerGauche(): void {
    if (this.rotationVerrouillee || this.groupesFiltres.length === 0) return;
    this.rotationVerrouillee = true;
    this.reculerDe(1);
    setTimeout(() => {
      this.rotationVerrouillee = false;
      this.cdr.markForCheck();
    }, 320);
  }

  /**
   * Rotation à droite (>) : fait tourner le cadran d'un cran vers la droite avec transition douce cadencée
   */
  tournerDroite(): void {
    if (this.rotationVerrouillee || this.groupesFiltres.length === 0) return;
    this.rotationVerrouillee = true;
    this.avancerDe(1);
    setTimeout(() => {
      this.rotationVerrouillee = false;
      this.cdr.markForCheck();
    }, 320);
  }

  /**
   * Sélection directe via un point indicateur : tourne directement vers cet index
   */
  choisirIndex(index: number): void {
    if (this.rotationVerrouillee || index < 0 || index >= this.groupesFiltres.length) return;
    this.rotationVerrouillee = true;
    this.indexActif = index;
    this.recalculerCartes3D();
    this.rotationChange.emit(this.groupesFiltres[this.indexActif]);
    setTimeout(() => {
      this.rotationVerrouillee = false;
      this.cdr.markForCheck();
    }, 320);
  }

  /**
   * Clic direct sur une carte :
   * - Si c'est une carte latérale : PAGER DIRECTEMENT VERS CE GROUPE (le fait rouler au centre) !
   * - Si c'est la carte déjà active au centre : ouvre ou ferme le tiroir de détails !
   */
  clicCarte(item: CarteCadran3D, event?: MouseEvent): void {
    event?.stopPropagation();

    // Si l'utilisateur était en train de glisser/faire rouler avec la souris, ne pas traiter comme un clic
    if (this.aGlisse) {
      return;
    }

    if (item.estActive) {
      // Carte centrale active : ouvre/ferme le tiroir latéral
      if (this.groupeSelectionneId === item.groupe.id) {
        this.groupeFerme.emit();
      } else {
        this.groupeClique.emit(item.groupe);
      }
    } else {
      // Carte latérale (gauche ou droite) : PAGER VERS CETTE CARTE !
      // Fait tourner le cadran pour l'amener au centre et oriente la caméra du globe
      this.choisirIndex(item.indexOriginal);
    }
  }

  /**
   * Double-clic sur n'importe quelle carte : centre la carte et ouvre immédiatement son tiroir de détail
   */
  doubleClicCarte(item: CarteCadran3D, event?: MouseEvent): void {
    event?.stopPropagation();
    if (this.aGlisse) return;

    this.indexActif = item.indexOriginal;
    this.recalculerCartes3D();
    this.rotationChange.emit(item.groupe);
    this.groupeClique.emit(item.groupe);
  }

  @HostListener('window:keydown', ['$event'])
  onToucheClavier(event: KeyboardEvent): void {
    const tag = (event.target as HTMLElement)?.tagName?.toLowerCase();
    if (tag === 'input' || tag === 'textarea') return;

    if (event.key === 'ArrowLeft') {
      this.tournerGauche();
    } else if (event.key === 'ArrowRight') {
      this.tournerDroite();
    }
  }

  onImageErreur(event: Event, item: CarteCadran3D): void {
    item.photoUrl = undefined;
    this.cdr.markForCheck();
  }

}
