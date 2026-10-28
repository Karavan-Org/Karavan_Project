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
import { RouterLink } from '@angular/router';
import {
  ResumeTableauDeBord
} from '../tableau-de-bord.service';

@Component({
  selector: 'app-statistiques-droite',
  standalone: true,
  imports: [CommonModule, FormsModule, MatIconModule, RouterLink],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="stats-droite-container">
      <!-- 1. CARTE ACTEURS ENGAGÉS (Most Engaged) -->
      <div class="carte-droite acteurs-engages-card">
        <div class="card-entete">
          <span class="card-titre">Acteurs engagés</span>
          <a routerLink="/utilisateurs" class="lien-voir-tout">
            <span>Voir tout</span>
            <mat-icon>chevron_right</mat-icon>
          </a>
        </div>

        <div class="liste-engages">
          <!-- Item 1: Tous les acteurs -->
          <div class="engage-item">
            <div class="icone-bulle icone-violet">
              <mat-icon>groups</mat-icon>
            </div>
            <div class="engage-corps">
              <span class="engage-label">Tous les acteurs</span>
              <div class="engage-chiffre-ligne">
                <span class="engage-valeur">{{ (resume?.utilisateurs?.total || 2340).toLocaleString('fr-FR') }}</span>
                <span class="badge-hausse badge-vert">
                  <mat-icon>arrow_drop_up</mat-icon> 145
                </span>
              </div>
            </div>
          </div>

          <!-- Item 2: Acteurs uniques récents -->
          <div class="engage-item">
            <div class="icone-bulle icone-cyan">
              <mat-icon>workspace_premium</mat-icon>
            </div>
            <div class="engage-corps">
              <span class="engage-label">Acteurs uniques récents</span>
              <div class="engage-chiffre-ligne">
                <span class="engage-valeur">1 203 540</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 2. CARTE PRÉVISIONS (Forecast) -->
      <div class="carte-droite forecast-card">
        <div class="card-entete">
          <span class="card-titre">Prévisions d'importation</span>
        </div>

        <!-- Mensuel -->
        <div class="forecast-section">
          <div class="forecast-ligne-titre">
            <span class="forecast-periode">Mensuel</span>
            <div class="valeur-avec-badge">
              <span class="forecast-valeur">32 875</span>
              <span class="badge-hausse badge-vert">
                <mat-icon>arrow_drop_up</mat-icon> 4%
              </span>
            </div>
          </div>
          <span class="forecast-sub">Par rapport à 21 490 le mois dernier</span>
        </div>

        <div class="separateur-fin"></div>

        <!-- Annuel -->
        <div class="forecast-section">
          <div class="forecast-ligne-titre">
            <span class="forecast-periode">Annuel</span>
            <div class="valeur-avec-badge">
              <span class="forecast-valeur">1 387 122</span>
              <span class="badge-hausse badge-vert">
                <mat-icon>arrow_drop_up</mat-icon> 12%
              </span>
            </div>
          </div>
          <span class="forecast-sub">Par rapport à 521 490 l'an passé</span>
        </div>
      </div>

      <!-- 3. CARTE STATISTIQUES TEMPORELLES (Time Statistic) -->
      <div class="carte-droite time-statistic-card">
        <div class="card-entete">
          <span class="card-titre">Statistiques temporelles</span>
        </div>

        <div class="time-stat-top">
          <div class="valeur-avec-badge">
            <span class="time-gros-chiffre">16 073</span>
            <span class="badge-hausse badge-vert">
              <mat-icon>arrow_drop_up</mat-icon> 10%
            </span>
          </div>
          <span class="forecast-sub">Par rapport à 11 490 l'an passé</span>
        </div>

        <div class="liste-barres-temporelles">
          <!-- Janvier -->
          <div class="barre-temps-item">
            <div class="barre-temps-entete">
              <span class="mois-lbl">Janvier</span>
              <span class="mois-val">8 320</span>
            </div>
            <div class="piste-progression-horizontale">
              <div class="barre-remplie barre-violette" style="width: 78%;"></div>
            </div>
          </div>

          <!-- Février -->
          <div class="barre-temps-item">
            <div class="barre-temps-entete">
              <span class="mois-lbl">Février</span>
              <span class="mois-val">6 320</span>
            </div>
            <div class="piste-progression-horizontale">
              <div class="barre-remplie barre-corail" style="width: 58%;"></div>
            </div>
          </div>

          <!-- Mars -->
          <div class="barre-temps-item">
            <div class="barre-temps-entete">
              <span class="mois-lbl">Mars</span>
              <span class="mois-val">1 433</span>
            </div>
            <div class="piste-progression-horizontale">
              <div class="barre-remplie barre-ambre" style="width: 22%;"></div>
            </div>
          </div>
        </div>
      </div>

      <!-- 4. ENCLAVE RATTRAPAGE PAYS (si d'anciens groupes n'ont pas d'origine) -->
      @if (resume && resume.groupesSansPays > 0) {
        <div class="carte-droite encart-rattrapage">
          <div class="rattrapage-header">
            <mat-icon>warning_amber</mat-icon>
            <span>{{ resume.groupesSansPays }} groupe(s) sans pays</span>
          </div>
          <button
            type="button"
            class="btn-rattrapage-mini"
            (click)="onOuvrirRattrapage.emit()"
          >
            Assigner pays d'origine
          </button>
        </div>
      }
    </div>
  `,
  styles: [`
    .stats-droite-container {
      display: flex;
      flex-direction: column;
      gap: 14px;
      width: 270px;
      z-index: 20;
    }

    .carte-droite {
      background: #FFFFFF;
      border-radius: 20px;
      padding: 16px 18px;
      box-shadow: 0 4px 20px rgba(45, 35, 28, 0.06);
      border: 1px solid rgba(143, 98, 67, 0.12);
      transition: transform 0.2s ease, box-shadow 0.2s ease;

      &:hover {
        transform: translateY(-2px);
        box-shadow: 0 8px 24px rgba(45, 35, 28, 0.1);
      }
    }

    .card-entete {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 12px;

      .card-titre {
        font-size: 13.5px;
        font-weight: 800;
        color: #2D231C;
        letter-spacing: -0.2px;
      }

      .lien-voir-tout {
        display: inline-flex;
        align-items: center;
        gap: 2px;
        font-size: 11px;
        font-weight: 700;
        color: #8C7E74;
        text-decoration: none;
        transition: color 0.2s ease;

        mat-icon {
          font-size: 14px;
          width: 14px;
          height: 14px;
        }

        &:hover {
          color: #8F6243;
        }
      }
    }

    // 1. Acteurs engagés
    .liste-engages {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }

    .engage-item {
      display: flex;
      align-items: center;
      gap: 12px;

      .icone-bulle {
        width: 38px;
        height: 38px;
        border-radius: 12px;
        display: flex;
        align-items: center;
        justify-content: center;

        mat-icon {
          font-size: 20px;
          width: 20px;
          height: 20px;
        }

        &.icone-violet {
          background: rgba(139, 92, 246, 0.12);
          color: #8B5CF6;
        }

        &.icone-cyan {
          background: rgba(6, 182, 212, 0.12);
          color: #0891B2;
        }
      }

      .engage-corps {
        display: flex;
        flex-direction: column;

        .engage-label {
          font-size: 11px;
          font-weight: 600;
          color: #8C7E74;
        }

        .engage-chiffre-ligne {
          display: flex;
          align-items: center;
          gap: 6px;

          .engage-valeur {
            font-size: 15px;
            font-weight: 900;
            color: #2D231C;
          }
        }
      }
    }

    .badge-hausse {
      display: inline-flex;
      align-items: center;
      font-size: 10px;
      font-weight: 800;
      padding: 1px 4px;
      border-radius: 6px;

      mat-icon {
        font-size: 14px;
        width: 14px;
        height: 14px;
        margin-left: -2px;
      }

      &.badge-vert {
        color: #10B981;
        background: rgba(16, 185, 129, 0.1);
      }
    }

    // 2. Forecast
    .forecast-section {
      display: flex;
      flex-direction: column;
      gap: 2px;

      .forecast-ligne-titre {
        display: flex;
        justify-content: space-between;
        align-items: baseline;

        .forecast-periode {
          font-size: 11px;
          font-weight: 700;
          color: #8C7E74;
        }

        .valeur-avec-badge {
          display: flex;
          align-items: center;
          gap: 6px;

          .forecast-valeur {
            font-size: 16px;
            font-weight: 900;
            color: #2D231C;
          }
        }
      }

      .forecast-sub {
        font-size: 10px;
        color: #A3968C;
      }
    }

    .separateur-fin {
      height: 1px;
      background: rgba(143, 98, 67, 0.08);
      margin: 10px 0;
    }

    // 3. Time statistic
    .time-stat-top {
      display: flex;
      flex-direction: column;
      margin-bottom: 12px;

      .valeur-avec-badge {
        display: flex;
        align-items: center;
        gap: 6px;

        .time-gros-chiffre {
          font-size: 18px;
          font-weight: 900;
          color: #2D231C;
        }
      }

      .forecast-sub {
        font-size: 10px;
        color: #A3968C;
        margin-top: 2px;
      }
    }

    .liste-barres-temporelles {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }

    .barre-temps-item {
      display: flex;
      flex-direction: column;
      gap: 4px;

      .barre-temps-entete {
        display: flex;
        justify-content: space-between;
        font-size: 11px;

        .mois-lbl {
          color: #8C7E74;
          font-weight: 600;
        }

        .mois-val {
          color: #2D231C;
          font-weight: 800;
        }
      }

      .piste-progression-horizontale {
        height: 6px;
        background: #FAF8F5;
        border-radius: 4px;
        overflow: hidden;

        .barre-remplie {
          height: 100%;
          border-radius: 4px;
          transition: width 0.5s ease;

          &.barre-violette {
            background: linear-gradient(90deg, #8B5CF6, #A78BFA);
          }

          &.barre-corail {
            background: linear-gradient(90deg, #F43F5E, #FB7185);
          }

          &.barre-ambre {
            background: linear-gradient(90deg, #EEA823, #FBBF24);
          }
        }
      }
    }

    // 4. Rattrapage
    .encart-rattrapage {
      background: #FFFBEB;
      border-color: rgba(238, 168, 35, 0.4);
      padding: 12px 14px;
      display: flex;
      flex-direction: column;
      gap: 8px;

      .rattrapage-header {
        display: flex;
        align-items: center;
        gap: 6px;
        color: #B45309;
        font-size: 11px;
        font-weight: 700;

        mat-icon {
          font-size: 16px;
          width: 16px;
          height: 16px;
        }
      }

      .btn-rattrapage-mini {
        background: #8F6243;
        color: #FFFFFF;
        border: none;
        border-radius: 8px;
        padding: 6px 10px;
        font-size: 10.5px;
        font-weight: 700;
        cursor: pointer;
        transition: background 0.2s ease;

        &:hover {
          background: #734c31;
        }
      }
    }
  `]
})
export class StatistiquesDroiteComponent {
  @Input() resume: ResumeTableauDeBord | null = null;
  @Input() volumeSequestre = 0;
  @Input() paysSelectionne: string | null = null;
  @Output() onPaysClic = new EventEmitter<string>();
  @Output() onOuvrirRattrapage = new EventEmitter<void>();
}
