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
      <!-- Flèche gauche de rotation (<) : fait tourner le cadran SANS ouvrir le tiroir -->
      <button
        type="button"
        class="nav-cadran-btn btn-gauche"
        (click)="tournerGauche()"
        title="Groupe précédent (Flèche gauche)"
        [disabled]="groupesFiltres.length === 0"
        aria-label="Groupe précédent"
      >
        <mat-icon>chevron_left</mat-icon>
      </button>

      <!-- Scène 3D avec perspective cylindrique -->
      <div class="cadran-cylindre-3d" #cylindre3d>
        @if (groupesFiltres.length === 0) {
          <div class="aucun-groupe-msg">
            <mat-icon>public_off</mat-icon>
            <span>Aucun groupe actif</span>
          </div>
        } @else {
          <div class="cartes-arc-wrapper">
            @for (item of cartesVisibles; track item.offset) {
              <div
                class="carte-groupe-3d"
                [class.carte-active]="item.estActive"
                [class.carte-survolee]="survolOffset === item.offset"
                [style.transform]="obtenirTransformCarte(item)"
                [style.opacity]="obtenirOpaciteCarte(item)"
                [style.zIndex]="obtenirZIndexCarte(item)"
                (mouseenter)="onSurvolCarte(item.offset)"
                (mouseleave)="onQuitterSurvol()"
                (click)="clicCarte(item)"
                [title]="item.estActive && groupeSelectionneId === item.groupe.id ? 'Cliquer pour fermer le détail' : 'Cliquer pour voir le détail de ce produit'"
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

      <!-- Flèche droite de rotation (>) : fait tourner le cadran SANS ouvrir le tiroir -->
      <button
        type="button"
        class="nav-cadran-btn btn-droite"
        (click)="tournerDroite()"
        title="Groupe suivant (Flèche droite)"
        [disabled]="groupesFiltres.length === 0"
        aria-label="Groupe suivant"
      >
        <mat-icon>chevron_right</mat-icon>
      </button>

      <!-- Zone inférieure : Barre de commandes (Précédent / Suivant + Points) + Bouton Tourner le cadran -->
      <div class="cadran-bas-actions">
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
                [title]="g.paysOrigine?.nomFr ? (g.paysOrigine?.nomFr + ' - ' + g.titre) : g.titre"
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
        box-shadow: 0 0 20px rgba(238, 168, 35, 0.6);
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
    }

    // 3. Carte individuelle sur l'arc 3D
    .carte-groupe-3d {
      position: absolute;
      width: 126px;
      height: 164px;
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
      transition: transform 0.35s cubic-bezier(0.16, 1, 0.3, 1),
                  opacity 0.35s ease,
                  box-shadow 0.3s ease,
                  border-color 0.3s ease;
      will-change: transform, opacity, box-shadow;

      // Effet quand le curseur passe dessus : la carte s'avance nettement vers le spectateur
      &.carte-survolee {
        border-color: #EEA823 !important;
        box-shadow: 0 28px 60px rgba(0, 0, 0, 0.8),
                    0 0 32px rgba(238, 168, 35, 0.75),
                    inset 0 0 18px rgba(172, 127, 94, 0.5) !important;
        cursor: pointer;
      }

      &:hover:not(.carte-active):not(.carte-survolee) {
        border-color: rgba(238, 168, 35, 0.6);
        box-shadow: 0 14px 34px rgba(0, 0, 0, 0.5), 0 0 12px rgba(172, 127, 94, 0.3);
      }

      // Carte active mise en valeur avec halo chaleureux Karavan (Bissap & Ocre)
      &.carte-active {
        width: 138px;
        height: 176px;
        border: 2px solid #AC7F5E;
        box-shadow: 0 0 32px rgba(172, 127, 94, 0.7),
                    inset 0 0 14px rgba(238, 168, 35, 0.4),
                    0 18px 40px rgba(0, 0, 0, 0.6);
        background: linear-gradient(145deg, rgba(34, 58, 52, 0.98) 0%, rgba(18, 34, 30, 0.99) 100%);
      }
    }

    .carte-top-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      font-size: 11px;
      font-weight: 700;

      .carte-drapeau {
        font-size: 19px;
        line-height: 1;
        filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.5));
      }

      .carte-id {
        color: #EEA823;
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
      gap: 12px;
      margin-top: 12px;
      z-index: 40;
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
          box-shadow: 0 0 12px #EEA823;
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

  /** Émis lors de la rotation (flèches < / >, molette, points) : oriente le Globe SANS ouvrir le tiroir */
  @Output() rotationChange = new EventEmitter<GroupeCadranVue>();

  /** Émis UNIQUEMENT lors du clic sur une carte pour ouvrir son détail */
  @Output() groupeClique = new EventEmitter<GroupeCadranVue>();

  /** Émis quand on clique sur la carte active pour fermer son détail */
  @Output() groupeFerme = new EventEmitter<void>();

  indexActif = 0;
  survolOffset: number | null = null;
  groupesFiltres: GroupeCadranVue[] = [];
  cartesVisibles: CarteCadran3D[] = [];

  constructor(private readonly cdr: ChangeDetectorRef) {}

  onSurvolCarte(offset: number): void {
    this.survolOffset = offset;
    this.cdr.markForCheck();
  }

  onQuitterSurvol(): void {
    this.survolOffset = null;
    this.cdr.markForCheck();
  }

  /**
   * Calcule la transformation 3D :
   * Quand le curseur passe dessus, la carte s'avance franchement vers le spectateur (translateZ + 85px),
   * s'élève au-dessus du rang (translateY -26px), se redresse face caméra et grossit (scale * 1.25).
   */
  obtenirTransformCarte(item: CarteCadran3D): string {
    if (this.survolOffset === item.offset) {
      const angleDeg = item.offset * 6; // redressement partiel face au regard
      const translateX = item.offset * 144;
      const translateZ = (-Math.abs(item.offset) * 42) + 85; // s'avance franchement vers l'avant
      const translateY = -26; // monte au-dessus des autres cartes
      const baseScale = item.offset === 0 ? 1.08 : Math.max(0.72, 1 - Math.abs(item.offset) * 0.09);
      const scale = baseScale * 1.25;
      return `translateX(${translateX}px) translateY(${translateY}px) translateZ(${translateZ}px) rotateY(${angleDeg}deg) scale(${scale})`;
    }
    return item.transform;
  }

  obtenirZIndexCarte(item: CarteCadran3D): number {
    if (this.survolOffset === item.offset) return 99;
    return item.zIndex;
  }

  obtenirOpaciteCarte(item: CarteCadran3D): number {
    if (this.survolOffset === item.offset) return 1;
    return item.opacity;
  }

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

      const angleDeg = offset * 14;
      const translateX = offset * 142;
      const translateZ = -Math.abs(offset) * 42;
      const scale = offset === 0 ? 1.05 : Math.max(0.72, 1 - Math.abs(offset) * 0.09);
      const opacity = offset === 0 ? 1 : Math.max(0.45, 1 - Math.abs(offset) * 0.18);
      const zIndex = 30 - Math.abs(offset);

      const drapeau = this.drapeauParCode(groupe.paysOrigine?.codeIso) || groupe.drapeau || '🌐';
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

  /**
   * Rotation à gauche via la flèche (<) :
   * Fait tourner le cadran et le globe SANS ouvrir le tiroir de détail
   */
  tournerGauche(): void {
    if (this.groupesFiltres.length === 0) return;
    this.indexActif = (this.indexActif - 1 + this.groupesFiltres.length) % this.groupesFiltres.length;
    this.recalculerCartes3D();
    this.rotationChange.emit(this.groupesFiltres[this.indexActif]);
  }

  /**
   * Rotation à droite via la flèche (>) :
   * Fait tourner le cadran et le globe SANS ouvrir le tiroir de détail
   */
  tournerDroite(): void {
    if (this.groupesFiltres.length === 0) return;
    this.indexActif = (this.indexActif + 1) % this.groupesFiltres.length;
    this.recalculerCartes3D();
    this.rotationChange.emit(this.groupesFiltres[this.indexActif]);
  }

  /**
   * Sélection via les points de pagination : fait tourner le cadran SANS forcer l'ouverture du tiroir
   */
  choisirIndex(index: number): void {
    if (index >= 0 && index < this.groupesFiltres.length) {
      this.indexActif = index;
      this.recalculerCartes3D();
      this.rotationChange.emit(this.groupesFiltres[this.indexActif]);
    }
  }

  /**
   * Clic explicite sur une carte :
   * - Si la carte est active et son détail est ouvert -> le ferme
   * - Si la carte est active et son détail est fermé -> l'ouvre
   * - Si c'est une carte latérale -> fait tourner vers elle ET ouvre son détail
   */
  clicCarte(item: CarteCadran3D): void {
    if (item.estActive) {
      if (this.groupeSelectionneId === item.groupe.id) {
        this.groupeFerme.emit();
      } else {
        this.groupeClique.emit(item.groupe);
      }
    } else {
      this.indexActif = item.indexOriginal;
      this.recalculerCartes3D();
      this.rotationChange.emit(item.groupe);
      this.groupeClique.emit(item.groupe);
    }
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
