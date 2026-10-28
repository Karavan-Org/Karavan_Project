import {
  ChangeDetectionStrategy,
  ChangeDetectorRef,
  Component,
  EventEmitter,
  Input,
  OnInit,
  Output,
  inject
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatIconModule } from '@angular/material/icon';
import {
  GroupeCadranVue,
  PaysReference,
  TableauDeBordService
} from '../tableau-de-bord.service';

@Component({
  selector: 'app-modal-assigner-pays',
  standalone: true,
  imports: [CommonModule, FormsModule, MatIconModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="modal-backdrop" (click)="onFermer.emit()"></div>
    <div class="modal-dialog">
      <div class="modal-header">
        <div class="titres">
          <mat-icon class="icone-entete">edit_location_alt</mat-icon>
          <h3>Assignation du Pays d'Origine</h3>
        </div>
        <button type="button" class="btn-fermer" (click)="onFermer.emit()">
          <mat-icon>close</mat-icon>
        </button>
      </div>

      <div class="modal-corps">
        <p class="description">
          Les groupes d'achat ci-dessous ont été créés avant l'introduction du pays d'origine obligatoire.
          Sélectionnez leur pays source pour relier leurs flux au Globe 3D de Bamako.
        </p>

        @if (chargement) {
          <div class="chargement-box">
            <mat-icon class="spin">sync</mat-icon>
            <span>Chargement des groupes...</span>
          </div>
        } @else if (groupesSansPays.length === 0) {
          <div class="succes-box">
            <mat-icon>check_circle</mat-icon>
            <p>Parfait ! Tous les groupes d'achat possèdent désormais un pays d'origine.</p>
          </div>
        } @else {
          <div class="liste-groupes-sans-pays">
            @for (g of groupesSansPays; track g.id) {
              <div class="groupe-row">
                <div class="groupe-infos">
                  <span class="id-badge">n° {{ g.id }}</span>
                  <span class="titre">{{ g.titre }}</span>
                  <span class="acteur">Grossiste : {{ g.grossiste.nom }}</span>
                </div>

                <div class="select-action">
                  <select
                    [(ngModel)]="selections[g.id]"
                    [disabled]="enregistrement[g.id]"
                    class="select-pays"
                  >
                    <option value="" disabled selected>Choisir un pays...</option>
                    @for (p of listePays; track p.codeIso) {
                      <option [value]="p.codeIso">
                        {{ drapeau(p.codeIso) }} {{ p.nomFr }} ({{ p.codeIso }})
                      </option>
                    }
                  </select>

                  <button
                    type="button"
                    class="btn-valider"
                    [disabled]="!selections[g.id] || enregistrement[g.id]"
                    (click)="validerPays(g)"
                  >
                    @if (enregistrement[g.id]) {
                      <mat-icon class="spin">sync</mat-icon>
                    } @else {
                      <mat-icon>check</mat-icon>
                    }
                    Assigner
                  </button>
                </div>
              </div>
            }
          </div>
        }
      </div>

      <div class="modal-pied">
        <button type="button" class="btn-fermer-modal" (click)="onFermer.emit()">
          Fermer
        </button>
      </div>
    </div>
  `,
  styles: [`
    .modal-backdrop {
      position: fixed;
      inset: 0;
      background: rgba(0, 0, 0, 0.45);
      backdrop-filter: blur(3px);
      z-index: 120;
    }

    .modal-dialog {
      position: fixed;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      width: 640px;
      max-width: 92vw;
      max-height: 85vh;
      background: #FFFFFF;
      border-radius: 20px;
      box-shadow: 0 10px 40px rgba(45, 35, 28, 0.25);
      border: 1px solid rgba(143, 98, 67, 0.2);
      z-index: 121;
      display: flex;
      flex-direction: column;
    }

    .modal-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 18px 22px;
      border-bottom: 1px solid rgba(45, 35, 28, 0.08);

      .titres {
        display: flex;
        align-items: center;
        gap: 10px;

        .icone-entete {
          color: #8F6243;
          font-size: 24px;
          width: 24px;
          height: 24px;
        }

        h3 {
          margin: 0;
          font-size: 16px;
          font-weight: 800;
          color: #2D231C;
        }
      }

      .btn-fermer {
        background: #FAF8F5;
        border: none;
        border-radius: 50%;
        width: 32px;
        height: 32px;
        display: flex;
        align-items: center;
        justify-content: center;
        color: #8C7E74;
        cursor: pointer;

        &:hover {
          background: #8F6243;
          color: #FFFFFF;
        }
      }
    }

    .modal-corps {
      flex: 1;
      overflow-y: auto;
      padding: 18px 22px;

      .description {
        margin: 0 0 16px 0;
        font-size: 13px;
        color: #5D4037;
        line-height: 1.5;
      }
    }

    .liste-groupes-sans-pays {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }

    .groupe-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 14px;
      background: #FAF8F5;
      border: 1px solid rgba(45, 35, 28, 0.08);
      border-radius: 12px;
      padding: 12px 14px;

      .groupe-infos {
        display: flex;
        flex-direction: column;
        gap: 2px;
        min-width: 0;
        flex: 1;

        .id-badge {
          font-size: 11px;
          font-weight: 700;
          color: #8F6243;
        }

        .titre {
          font-size: 13.5px;
          font-weight: 700;
          color: #2D231C;
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
        }

        .acteur {
          font-size: 11.5px;
          color: #8C7E74;
        }
      }

      .select-action {
        display: flex;
        align-items: center;
        gap: 8px;
        flex-shrink: 0;
      }

      .select-pays {
        padding: 6px 10px;
        border-radius: 10px;
        border: 1px solid rgba(45, 35, 28, 0.15);
        background: #FFFFFF;
        font-size: 12px;
        color: #2D231C;
        outline: none;
        max-width: 170px;
      }

      .btn-valider {
        display: inline-flex;
        align-items: center;
        gap: 4px;
        background: #8F6243;
        color: #FFFFFF;
        border: none;
        padding: 7px 12px;
        border-radius: 10px;
        font-size: 12px;
        font-weight: 700;
        cursor: pointer;

        &:disabled {
          opacity: 0.4;
          cursor: not-allowed;
        }

        mat-icon {
          font-size: 16px;
          width: 16px;
          height: 16px;
        }
      }
    }

    .succes-box {
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 30px;
      text-align: center;
      color: #2E7D32;

      mat-icon {
        font-size: 44px;
        width: 44px;
        height: 44px;
        margin-bottom: 10px;
      }

      p {
        margin: 0;
        font-weight: 700;
        font-size: 14px;
      }
    }

    .chargement-box {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      padding: 30px;
      color: #8F6243;
      font-weight: 600;
      font-size: 13px;
    }

    .spin {
      animation: spin 1s linear infinite;
    }

    @keyframes spin {
      from { transform: rotate(0deg); }
      to { transform: rotate(360deg); }
    }

    .modal-pied {
      padding: 14px 22px;
      border-top: 1px solid rgba(45, 35, 28, 0.08);
      display: flex;
      justify-content: flex-end;

      .btn-fermer-modal {
        background: #FAF8F5;
        border: 1px solid rgba(45, 35, 28, 0.15);
        color: #2D231C;
        font-size: 13px;
        font-weight: 700;
        padding: 8px 18px;
        border-radius: 20px;
        cursor: pointer;

        &:hover {
          background: #8F6243;
          color: #FFFFFF;
        }
      }
    }
  `]
})
export class ModalAssignerPaysComponent implements OnInit {
  @Input() listePays: PaysReference[] = [];
  @Output() onFermer = new EventEmitter<void>();
  @Output() onPaysAssigne = new EventEmitter<void>();

  private readonly service = inject(TableauDeBordService);
  private readonly cdr = inject(ChangeDetectorRef);

  chargement = true;
  groupesSansPays: GroupeCadranVue[] = [];
  selections: Record<number, string> = {};
  enregistrement: Record<number, boolean> = {};

  ngOnInit(): void {
    this.chargerGroupesSansPays();
  }

  chargerGroupesSansPays(): void {
    this.chargement = true;
    this.service.getGroupes({ taille: 200 }).subscribe({
      next: groupes => {
        this.groupesSansPays = (groupes || []).filter(g => !g.paysOrigine);
        this.chargement = false;
        this.cdr.markForCheck();
      },
      error: () => {
        this.chargement = false;
        this.cdr.markForCheck();
      }
    });
  }

  validerPays(g: GroupeCadranVue): void {
    const code = this.selections[g.id];
    if (!code) return;

    this.enregistrement[g.id] = true;
    this.cdr.markForCheck();

    this.service.assignerPays(g.id, code).subscribe({
      next: () => {
        this.groupesSansPays = this.groupesSansPays.filter(item => item.id !== g.id);
        delete this.enregistrement[g.id];
        delete this.selections[g.id];
        this.onPaysAssigne.emit();
        this.cdr.markForCheck();
      },
      error: () => {
        delete this.enregistrement[g.id];
        this.cdr.markForCheck();
      }
    });
  }

  drapeau(codeIso: string): string {
    if (!codeIso || codeIso.length !== 2) return '🌐';
    const p = codeIso.toUpperCase().charCodeAt(0) - 65 + 0x1F1E6;
    const s = codeIso.toUpperCase().charCodeAt(1) - 65 + 0x1F1E6;
    return String.fromCodePoint(p, s);
  }
}
