import {
  ChangeDetectionStrategy,
  Component,
  EventEmitter,
  Input,
  Output
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatIconModule } from '@angular/material/icon';
import {
  PaysReference,
  RepartitionPaysVue,
  ResumeTableauDeBord
} from '../tableau-de-bord.service';

@Component({
  selector: 'app-statistiques-droite',
  standalone: true,
  imports: [CommonModule, FormsModule, MatIconModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="stats-droite-container">
      <!-- 1. CARTE VOLUME SOUS SÉQUESTRE -->
      <div class="carte-stat finance-card">
        <div class="stat-entete">
          <mat-icon class="icone-finance">account_balance_wallet</mat-icon>
          <span class="label">Volume sous Séquestre</span>
        </div>
        <div class="valeur-majeure">
          {{ volumeSequestre.toLocaleString('fr-FR') }} <span class="devise">FCFA</span>
        </div>
        <div class="sous-texte">
          Fonds sécurisés à 100% jusqu'à livraison à Bamako (RG-35)
        </div>
      </div>

      <!-- 2. RÉPARTITION PAR PAYS D'ORIGINE -->
      <div class="carte-stat repartition-card">
        <div class="stat-entete">
          <mat-icon class="icone-pays">public</mat-icon>
          <span class="label">Flux par Pays d'Origine</span>
        </div>

        @if (resume?.repartitionPays && resume!.repartitionPays.length > 0) {
          <div class="barres-pays">
            @for (p of resume!.repartitionPays; track p.codeIso) {
              <div
                class="ligne-pays"
                (click)="onPaysClic.emit(p.codeIso)"
                [class.actif]="paysSelectionne === p.codeIso"
              >
                <div class="pays-info">
                  <span class="pays-nom">
                    {{ drapeau(p.codeIso) }} {{ p.nomFr }}
                  </span>
                  <span class="pays-chiffres">
                    <strong>{{ p.nombreGroupes }}</strong> grp ({{ p.pourcentage | number:'1.0-1' }}%)
                  </span>
                </div>
                <div class="barre-fond">
                  <div class="barre-remplie" [style.width.%]="p.pourcentage"></div>
                </div>
              </div>
            }
          </div>
        } @else {
          <p class="aucun-flux">Aucun flux d'importation actif enregistré.</p>
        }
      </div>

      <!-- 3. COMPTEURS CLÉS PAR STATUT -->
      <div class="carte-stat statuts-card">
        <div class="stat-entete">
          <mat-icon class="icone-statut">donut_large</mat-icon>
          <span class="label">État des Achats Groupés</span>
        </div>

        <div class="grille-statuts">
          <div class="mini-statut">
            <span class="pastille pastille-ouverts"></span>
            <span class="nom">Ouverts</span>
            <span class="compte">{{ resume?.groupesParStatut?.['OUVERT'] || 0 }}</span>
          </div>
          <div class="mini-statut">
            <span class="pastille pastille-atteints"></span>
            <span class="nom">Objectif atteint</span>
            <span class="compte">{{ resume?.groupesParStatut?.['OBJECTIF_ATTEINT'] || 0 }}</span>
          </div>
          <div class="mini-statut">
            <span class="pastille pastille-transit"></span>
            <span class="nom">En transit</span>
            <span class="compte">
              {{ (resume?.groupesParStatut?.['EN_EXPEDITION'] || 0) + (resume?.groupesParStatut?.['EXPEDIE'] || 0) }}
            </span>
          </div>
          <div class="mini-statut">
            <span class="pastille pastille-termines"></span>
            <span class="nom">Clôturés</span>
            <span class="compte">{{ resume?.groupesParStatut?.['TERMINE'] || 0 }}</span>
          </div>
        </div>
      </div>

      <!-- 4. ENCLAVE GROUPES SANS PAYS D'ORIGINE (si > 0) -->
      @if (resume && resume.groupesSansPays > 0) {
        <div class="carte-stat encart-rattrapage">
          <div class="stat-entete alerte-entete">
            <mat-icon class="icone-alerte">warning_amber</mat-icon>
            <span class="label">Rattrapage Pays d'Origine</span>
          </div>
          <p class="desc-rattrapage">
            <strong>{{ resume.groupesSansPays }} ancien(s) groupe(s)</strong> sans pays renseigné.
            Assignez le pays d'origine pour les intégrer au Globe 3D.
          </p>
          <button
            type="button"
            class="btn-rattrapage"
            (click)="onOuvrirRattrapage.emit()"
          >
            <mat-icon>edit_location_alt</mat-icon>
            Assigner les pays en 1 clic
          </button>
        </div>
      }

      <!-- 5. ALERTES ET SUPERVISION -->
      <div class="carte-stat alertes-card">
        <div class="stat-entete">
          <mat-icon class="icone-notif">notifications_active</mat-icon>
          <span class="label">Alertes & Convois</span>
        </div>

        <div class="liste-alertes">
          @if ((resume?.retardsSuivi || 0) > 0) {
            <div class="alerte-item alerte-rouge">
              <mat-icon>error_outline</mat-icon>
              <span>{{ resume!.retardsSuivi }} expédition(s) signalée(s) en retard ou blocage douane.</span>
            </div>
          }
          <div class="alerte-item alerte-neutre">
            <mat-icon>check_circle_outline</mat-icon>
            <span>Progression moyenne des groupes : <strong>{{ resume?.progressionMoyenne || 0 | number:'1.0-1' }}%</strong></span>
          </div>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .stats-droite-container {
      display: flex;
      flex-direction: column;
      gap: 14px;
      height: 100%;
      overflow-y: auto;
    }

    .carte-stat {
      background: #FFFFFF;
      border-radius: 18px;
      padding: 16px;
      border: 1px solid rgba(143, 98, 67, 0.12);
      box-shadow: 0 4px 16px rgba(45, 35, 28, 0.05);
    }

    .stat-entete {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 10px;

      mat-icon {
        font-size: 19px;
        width: 19px;
        height: 19px;
      }

      .label {
        font-size: 13px;
        font-weight: 800;
        color: #2D231C;
        text-transform: uppercase;
        letter-spacing: 0.3px;
      }
    }

    .finance-card {
      background: linear-gradient(135deg, #FAF8F5 0%, #FFFFFF 100%);
      border-left: 4px solid #8F6243;

      .icone-finance {
        color: #8F6243;
      }

      .valeur-majeure {
        font-size: 22px;
        font-weight: 900;
        color: #8F6243;
        margin-bottom: 4px;

        .devise {
          font-size: 14px;
          font-weight: 700;
          color: #EEA823;
        }
      }

      .sous-texte {
        font-size: 11px;
        color: #8C7E74;
      }
    }

    .repartition-card {
      .icone-pays {
        color: #EEA823;
      }
    }

    .barres-pays {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }

    .ligne-pays {
      cursor: pointer;
      padding: 4px 6px;
      border-radius: 8px;
      transition: background 0.2s ease;

      &:hover, &.actif {
        background: #FAF8F5;
      }
    }

    .pays-info {
      display: flex;
      justify-content: space-between;
      font-size: 12px;
      margin-bottom: 4px;

      .pays-nom {
        font-weight: 700;
        color: #2D231C;
      }

      .pays-chiffres {
        color: #8C7E74;
        font-size: 11px;

        strong {
          color: #8F6243;
        }
      }
    }

    .barre-fond {
      width: 100%;
      height: 6px;
      background: #FAF8F5;
      border-radius: 4px;
      overflow: hidden;
      border: 1px solid rgba(45, 35, 28, 0.06);
    }

    .barre-remplie {
      height: 100%;
      background: linear-gradient(90deg, #8F6243, #EEA823);
      border-radius: 4px;
      transition: width 0.6s ease;
    }

    .grille-statuts {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 10px;
    }

    .mini-statut {
      background: #FAF8F5;
      border-radius: 12px;
      padding: 10px;
      display: flex;
      flex-direction: column;
      gap: 3px;
      border: 1px solid rgba(45, 35, 28, 0.06);

      .pastille {
        width: 8px;
        height: 8px;
        border-radius: 50%;
        margin-bottom: 2px;

        &.pastille-ouverts { background: #2E7D32; }
        &.pastille-atteints { background: #F57F17; }
        &.pastille-transit { background: #1565C0; }
        &.pastille-termines { background: #78909C; }
      }

      .nom {
        font-size: 11px;
        color: #8C7E74;
        font-weight: 600;
      }

      .compte {
        font-size: 16px;
        font-weight: 800;
        color: #2D231C;
      }
    }

    .encart-rattrapage {
      background: #FFF8E1;
      border: 1.5px dashed #EEA823;

      .alerte-entete {
        .icone-alerte {
          color: #E65100;
        }
        .label {
          color: #E65100;
        }
      }

      .desc-rattrapage {
        font-size: 12px;
        color: #5D4037;
        margin: 0 0 10px 0;
        line-height: 1.4;
      }

      .btn-rattrapage {
        width: 100%;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 6px;
        background: #8F6243;
        color: #FFFFFF;
        font-size: 12px;
        font-weight: 700;
        padding: 8px 14px;
        border-radius: 12px;
        border: none;
        cursor: pointer;
        transition: background 0.2s ease;

        mat-icon {
          font-size: 16px;
          width: 16px;
          height: 16px;
        }

        &:hover {
          background: #734c31;
        }
      }
    }

    .alertes-card {
      .icone-notif {
        color: #8F6243;
      }
    }

    .liste-alertes {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }

    .alerte-item {
      display: flex;
      align-items: flex-start;
      gap: 8px;
      font-size: 11.5px;
      padding: 8px 10px;
      border-radius: 10px;

      mat-icon {
        font-size: 16px;
        width: 16px;
        height: 16px;
        flex-shrink: 0;
      }

      &.alerte-rouge {
        background: #FFEBEE;
        color: #C62828;
      }

      &.alerte-neutre {
        background: #FAF8F5;
        color: #5D4037;
      }
    }

    .aucun-flux {
      font-size: 12px;
      color: #8C7E74;
      margin: 8px 0;
      text-align: center;
    }
  `]
})
export class StatistiquesDroiteComponent {
  @Input() resume: ResumeTableauDeBord | null = null;
  @Input() volumeSequestre = 0;
  @Input() paysSelectionne: string | null = null;
  @Output() onPaysClic = new EventEmitter<string>();
  @Output() onOuvrirRattrapage = new EventEmitter<void>();

  drapeau(codeIso: string): string {
    if (!codeIso || codeIso.length !== 2) return '🌐';
    const p = codeIso.toUpperCase().charCodeAt(0) - 65 + 0x1F1E6;
    const s = codeIso.toUpperCase().charCodeAt(1) - 65 + 0x1F1E6;
    return String.fromCodePoint(p, s);
  }
}

