import {
  ChangeDetectionStrategy,
  Component,
  EventEmitter,
  Input,
  OnChanges,
  Output
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { MatIconModule } from '@angular/material/icon';
import { GroupeDetailVue } from '../tableau-de-bord.service';
import { DrapeauPaysComponent } from '../../../components/drapeau-pays/drapeau-pays.component';

@Component({
  selector: 'app-detail-tiroir',
  standalone: true,
  imports: [CommonModule, RouterLink, MatIconModule, DrapeauPaysComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @if (groupe) {
      <div class="tiroir-backdrop" (click)="fermerTiroir()"></div>
      <div class="tiroir-panneau">
        <div class="tiroir-header">
          <div class="header-titres">
            <span class="sous-titre">Détail du groupe n° {{ groupe.id }}</span>
            <h3>{{ groupe.titre }}</h3>
          </div>
          <button
            type="button"
            class="btn-fermer"
            (click)="fermerTiroir()"
            title="Fermer cette fiche"
            aria-label="Fermer"
          >
            <mat-icon>close</mat-icon>
          </button>
        </div>

        <div class="tiroir-corps">
          <!-- Carte principale du produit -->
          <div class="carte-produit">
            @if (groupe.produitPhotoUrl && !photoErreur) {
              <img
                [src]="groupe.produitPhotoUrl"
                [alt]="groupe.produitNom"
                class="photo-produit"
                (error)="onPhotoErreur()"
              />
            } @else {
              <div class="photo-placeholder">
                <mat-icon>inventory_2</mat-icon>
              </div>
            }

            <div class="produit-details">
              <h4>{{ groupe.produitNom }}</h4>
              <span class="categorie-badge">{{ groupe.categorieNom || 'Importation' }}</span>
              <div class="origine-ligne">
                <app-drapeau-pays [pays]="groupe.paysOrigine?.codeIso || groupe.paysOrigine?.nomFr" [largeur]="20" [hauteur]="14"></app-drapeau-pays>
                <span>
                  Origine : <strong>{{ groupe.paysOrigine?.nomFr || 'Non renseignée' }}</strong>
                  @if (groupe.paysOrigine?.codeIso) { ({{ groupe.paysOrigine?.codeIso }}) }
                </span>
              </div>
            </div>
          </div>

          <!-- Progression et Statut -->
          <div class="section-progression">
            <div class="progression-entete">
              <span class="label">Progression de la cible</span>
              <span class="pourcentage">{{ groupe.progressionPourcentage | number:'1.0-1' }}%</span>
            </div>
            <div class="barre-fond">
              <div class="barre-remplie" [style.width.%]="groupe.progressionPourcentage"></div>
            </div>
            <div class="chiffres-stock">
              <span>Réservé : <strong>{{ groupe.quantiteReservee + groupe.quantiteConfirmee }} pcs</strong></span>
              <span>Cible : <strong>{{ groupe.quantiteCible }} pcs</strong></span>
            </div>
          </div>

          <!-- Grille des coûts unitaires FCFA (RG-17) -->
          <div class="bloc-couts">
            <h5>Décomposition du prix unitaire</h5>
            <div class="lignes-couts">
              <div class="ligne-cout">
                <span>Marchandise</span>
                <strong>{{ (groupe.prixMarchandise || 0).toLocaleString('fr-FR') }} FCFA</strong>
              </div>
              <div class="ligne-cout">
                <span>Transport international</span>
                <strong>{{ (groupe.transport || 0).toLocaleString('fr-FR') }} FCFA</strong>
              </div>
              <div class="ligne-cout">
                <span>Frais de douane</span>
                <strong>{{ (groupe.douane || 0).toLocaleString('fr-FR') }} FCFA</strong>
              </div>
              <div class="ligne-cout">
                <span>Frais plateforme Karavan</span>
                <strong>{{ (groupe.fraisPlateforme || 0).toLocaleString('fr-FR') }} FCFA</strong>
              </div>
              <div class="ligne-cout total">
                <span>Prix final commerçant</span>
                <strong>{{ (groupe.prixUnitaire || 0).toLocaleString('fr-FR') }} FCFA</strong>
              </div>
            </div>
          </div>

          <!-- Intervenants Grossiste et Courtier -->
          <div class="bloc-acteurs">
            <div class="acteur-item">
              <mat-icon>warehouse</mat-icon>
              <div>
                <span class="role-titre">Grossiste</span>
                <span class="nom-acteur">{{ groupe.grossiste.nom }}</span>
              </div>
            </div>
            <div class="acteur-item">
              <mat-icon>support_agent</mat-icon>
              <div>
                <span class="role-titre">Courtier</span>
                <span class="nom-acteur">{{ groupe.courtier.nom }}</span>
              </div>
            </div>
          </div>

          <!-- Étapes d'acheminement si disponibles -->
          @if (groupe.etapesAcheminement && groupe.etapesAcheminement.length > 0) {
            <div class="bloc-etapes">
              <h5>Suivi d'acheminement vers Bamako</h5>
              <div class="timeline">
                @for (e of groupe.etapesAcheminement; track e.id) {
                  <div class="timeline-step">
                    <span class="step-dot"></span>
                    <div class="step-content">
                      <span class="step-titre">{{ e.etape }}</span>
                      @if (e.commentaire) {
                        <p class="step-comm">{{ e.commentaire }}</p>
                      }
                    </div>
                  </div>
                }
              </div>
            </div>
          }
        </div>

        <!-- Pied avec lien vers la fiche complète existante -->
        <div class="tiroir-pied">
          <a
            routerLink="/groupes"
            [queryParams]="{ id: groupe.id }"
            class="btn-fiche-complete"
            (click)="fermerTiroir()"
          >
            <mat-icon>open_in_new</mat-icon>
            Voir la fiche complète du groupe
          </a>
        </div>
      </div>
    }
  `,
  styles: [`
    .tiroir-backdrop {
      position: fixed;
      inset: 0;
      background: rgba(0, 0, 0, 0.45);
      backdrop-filter: blur(3px);
      z-index: 100;
      animation: fadeIn 0.2s ease;
    }

    .tiroir-panneau {
      position: fixed;
      top: 0;
      right: 0;
      bottom: 0;
      width: 440px;
      max-width: 90vw;
      background: #FFFFFF;
      box-shadow: -8px 0 30px rgba(15, 23, 42, 0.25);
      z-index: 101;
      display: flex;
      flex-direction: column;
      animation: slideIn 0.3s cubic-bezier(0.16, 1, 0.3, 1);
    }

    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }

    @keyframes slideIn {
      from { transform: translateX(100%); }
      to { transform: translateX(0); }
    }

    .tiroir-header {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      padding: 20px 22px;
      border-bottom: 1px solid rgba(45, 35, 28, 0.08);

      .header-titres {
        .sous-titre {
          font-size: 11.5px;
          font-weight: 700;
          color: #8F6243;
          text-transform: uppercase;
          letter-spacing: 0.3px;
        }

        h3 {
          margin: 4px 0 0 0;
          font-size: 17px;
          font-weight: 800;
          color: #2D231C;
        }
      }

      .btn-fermer {
        background: #FAF8F5;
        border: 1px solid #EDF2F7;
        border-radius: 50%;
        width: 34px;
        height: 34px;
        display: flex;
        align-items: center;
        justify-content: center;
        color: #8C7E74;
        cursor: pointer;
        transition: all 0.2s ease;

        &:hover {
          background: #8F6243;
          color: #FFFFFF;
          transform: scale(1.08);
        }

        mat-icon {
          font-size: 20px;
          width: 20px;
          height: 20px;
        }
      }
    }

    .tiroir-corps {
      flex: 1;
      overflow-y: auto;
      padding: 20px 22px;
      display: flex;
      flex-direction: column;
      gap: 18px;
    }

    .carte-produit {
      display: flex;
      align-items: center;
      gap: 16px;
      background: #FFFFFF;
      padding: 14px 16px;
      border-radius: 16px;
      border: 1px solid rgba(172, 127, 94, 0.2);
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);

      .photo-produit {
        width: 76px;
        height: 76px;
        min-width: 76px;
        max-width: 76px;
        flex-shrink: 0;
        border-radius: 12px;
        object-fit: cover;
        display: block;
        background: #F1EBE4;
        border: 1px solid rgba(172, 127, 94, 0.2);
      }

      .photo-placeholder {
        width: 76px;
        height: 76px;
        min-width: 76px;
        max-width: 76px;
        flex-shrink: 0;
        border-radius: 12px;
        background: rgba(172, 127, 94, 0.12);
        border: 1px solid rgba(172, 127, 94, 0.2);
        display: flex;
        align-items: center;
        justify-content: center;
        color: #AC7F5E;

        mat-icon {
          font-size: 32px;
          width: 32px;
          height: 32px;
        }
      }

      .produit-details {
        flex: 1;
        min-width: 0;

        h4 {
          margin: 0 0 6px 0;
          font-size: 14px;
          font-weight: 800;
          color: #2D231C;
        }

        .categorie-badge {
          display: inline-block;
          font-size: 11px;
          background: #FFFFFF;
          border: 1px solid rgba(45, 35, 28, 0.12);
          padding: 2px 8px;
          border-radius: 8px;
          color: #8F6243;
          font-weight: 600;
          margin-bottom: 6px;
        }

        .origine-ligne {
          display: flex;
          align-items: center;
          gap: 6px;
          font-size: 12px;
          color: #8C7E74;

          mat-icon {
            font-size: 16px;
            width: 16px;
            height: 16px;
            color: #8F6243;
          }
        }
      }
    }

    .section-progression {
      background: #FAF8F5;
      padding: 14px;
      border-radius: 14px;
      border: 1px solid rgba(45, 35, 28, 0.08);

      .progression-entete {
        display: flex;
        justify-content: space-between;
        font-size: 12px;
        font-weight: 700;
        margin-bottom: 8px;

        .label { color: #8C7E74; }
        .pourcentage { color: #8F6243; font-size: 14px; }
      }

      .barre-fond {
        height: 8px;
        background: #FFFFFF;
        border-radius: 4px;
        overflow: hidden;
        border: 1px solid rgba(45, 35, 28, 0.08);
        margin-bottom: 8px;
      }

      .barre-remplie {
        height: 100%;
        background: linear-gradient(90deg, #8F6243, #EEA823);
        border-radius: 4px;
      }

      .chiffres-stock {
        display: flex;
        justify-content: space-between;
        font-size: 11.5px;
        color: #8C7E74;

        strong { color: #2D231C; }
      }
    }

    .bloc-couts {
      h5 {
        margin: 0 0 10px 0;
        font-size: 13px;
        font-weight: 800;
        color: #2D231C;
        text-transform: uppercase;
        letter-spacing: 0.3px;
      }

      .lignes-couts {
        display: flex;
        flex-direction: column;
        gap: 6px;
        background: #FAF8F5;
        padding: 12px 14px;
        border-radius: 12px;
        border: 1px solid rgba(45, 35, 28, 0.08);
      }

      .ligne-cout {
        display: flex;
        justify-content: space-between;
        font-size: 12px;
        color: #8C7E74;

        strong { color: #2D231C; }

        &.total {
          padding-top: 8px;
          margin-top: 4px;
          border-top: 1px dashed rgba(45, 35, 28, 0.15);
          font-weight: 800;
          color: #8F6243;
          font-size: 13.5px;

          strong { color: #8F6243; }
        }
      }
    }

    .bloc-acteurs {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 10px;

      .acteur-item {
        display: flex;
        align-items: center;
        gap: 10px;
        background: #FAF8F5;
        padding: 10px 12px;
        border-radius: 12px;
        border: 1px solid rgba(45, 35, 28, 0.08);

        mat-icon {
          color: #8F6243;
          font-size: 22px;
          width: 22px;
          height: 22px;
        }

        .role-titre {
          display: block;
          font-size: 10.5px;
          color: #8C7E74;
          font-weight: 600;
          text-transform: uppercase;
        }

        .nom-acteur {
          font-size: 12.5px;
          font-weight: 700;
          color: #2D231C;
        }
      }
    }

    .bloc-etapes {
      h5 {
        margin: 0 0 10px 0;
        font-size: 13px;
        font-weight: 800;
        color: #2D231C;
        text-transform: uppercase;
        letter-spacing: 0.3px;
      }

      .timeline {
        display: flex;
        flex-direction: column;
        gap: 12px;
        padding-left: 6px;
      }

      .timeline-step {
        display: flex;
        align-items: flex-start;
        gap: 12px;

        .step-dot {
          width: 8px;
          height: 8px;
          border-radius: 50%;
          background: #EEA823;
          margin-top: 4px;
        }

        .step-content {
          .step-titre {
            font-size: 12px;
            font-weight: 700;
            color: #2D231C;
          }

          .step-comm {
            margin: 2px 0 0 0;
            font-size: 11.5px;
            color: #8C7E74;
          }
        }
      }
    }

    .tiroir-pied {
      padding: 16px 22px;
      border-top: 1px solid rgba(45, 35, 28, 0.08);
      background: #FFFFFF;

      .btn-fiche-complete {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 8px;
        width: 100%;
        background: #8F6243;
        color: #FFFFFF;
        font-size: 13.5px;
        font-weight: 700;
        padding: 11px 16px;
        border-radius: 30px;
        text-decoration: none;
        transition: background 0.2s ease;

        mat-icon {
          font-size: 18px;
          width: 18px;
          height: 18px;
        }

        &:hover {
          background: #734c31;
        }
      }
    }
  `]
})
export class DetailTiroirComponent implements OnChanges {
  @Input() groupe: GroupeDetailVue | null = null;
  @Output() fermer = new EventEmitter<void>();
  @Output() onFermer = new EventEmitter<void>();

  photoErreur = false;

  ngOnChanges(): void {
    this.photoErreur = false;
  }

  onPhotoErreur(): void {
    this.photoErreur = true;
  }

  fermerTiroir(): void {
    this.fermer.emit();
    this.onFermer.emit();
  }
}
