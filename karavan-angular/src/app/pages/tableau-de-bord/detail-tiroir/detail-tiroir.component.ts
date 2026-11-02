import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  EventEmitter,
  Input,
  OnChanges,
  Output,
  SimpleChanges,
  inject,
  signal
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { MatIconModule } from '@angular/material/icon';
import { Subscription } from 'rxjs';
import { GroupeDetailVue } from '../tableau-de-bord.service';
import { AdminApiService, MembresGroupe } from '../../../core/services/admin-api.service';
import { messageErreur, urlImage } from '../../../core/api';
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
            @if (photoUrlAffichee && !photoErreur) {
              <img
                [src]="photoUrlAffichee"
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
              @if (!groupe.paysOrigine?.codeIso) {
                <button type="button" class="btn-lien" (click)="assignerPays.emit()">
                  <mat-icon>add_location_alt</mat-icon>
                  Renseigner le pays d'origine
                </button>
              }
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

          <!-- Utilisateurs du groupe : nombre, état des comptes et actions tracées (chargé à chaque groupe) -->
          <section class="bloc-membres" aria-label="Utilisateurs du groupe">
            <button
              type="button"
              class="membres-resume"
              (click)="basculerMembres()"
              [disabled]="!membres()"
              [attr.aria-expanded]="membresOuverts()"
            >
              <span class="resume-icone"><mat-icon>groups</mat-icon></span>
              <span class="resume-texte">
                <span class="resume-titre">Utilisateurs du groupe</span>
                @if (membres(); as m) {
                  <span class="resume-chiffre">
                    {{ pluriel(m.totalMembres, 'utilisateur') }} · {{ pluriel(m.totalParticipants, 'commerçant participant', 'commerçants participants') }}
                  </span>
                } @else if (erreurMembres()) {
                  <span class="resume-chiffre erreur">{{ erreurMembres() }}</span>
                } @else {
                  <span class="resume-chiffre">Chargement…</span>
                }
              </span>
              @if (membres()) {
                <mat-icon class="chevron">{{ membresOuverts() ? 'expand_less' : 'expand_more' }}</mat-icon>
              }
            </button>

            @if (membres(); as m) {
              <div class="repartition-statuts">
                @for (s of repartition(m); track s.statut) {
                  <span class="pastille-statut" [attr.data-statut]="s.statut">{{ s.libelle }} · {{ s.nombre }}</span>
                }
              </div>

              @if (membresOuverts()) {
                <ul class="liste-membres">
                  @for (u of m.membres; track u.utilisateurId) {
                    <li class="membre">
                      <div class="membre-ligne">
                        <span class="membre-avatar" aria-hidden="true">{{ initiales(u.nom) }}</span>
                        <span class="membre-infos">
                          <a class="membre-nom" [routerLink]="['/utilisateurs', u.utilisateurId]" (click)="fermerTiroir()">{{ u.nom }}</a>
                          <span class="membre-role">
                            {{ libelleRole(u.role) }}
                            @if (u.statutParticipation) {
                              · {{ libelleParticipation(u.statutParticipation) }}
                              @if (u.quantite > 0) { · {{ u.quantite }} pcs }
                            }
                          </span>
                        </span>
                        <span class="pastille-statut" [attr.data-statut]="u.statutCompte">{{ libelleStatut(u.statutCompte) }}</span>
                      </div>

                      @if (u.actions.length) {
                        <button
                          type="button"
                          class="btn-actions"
                          (click)="basculerActions(u.utilisateurId)"
                          [attr.aria-expanded]="actionsDepliees() === u.utilisateurId"
                        >
                          <mat-icon>history</mat-icon>
                          {{ actionsDepliees() === u.utilisateurId ? 'Masquer les actions' : 'Voir ses ' + pluriel(u.actions.length, 'dernière action', 'dernières actions') }}
                        </button>
                        @if (actionsDepliees() === u.utilisateurId) {
                          <ol class="actions">
                            @for (a of u.actions; track $index) {
                              <li>
                                <span class="action-entete">
                                  <span class="action-libelle">{{ libelleAction(a.action) }}</span>
                                  <time [attr.datetime]="a.date">{{ formatDate(a.date) }}</time>
                                </span>
                                @if (a.detail) {
                                  <span class="action-detail">{{ a.detail }}</span>
                                }
                              </li>
                            }
                          </ol>
                        }
                      } @else {
                        <span class="aucune-action">Aucune action tracée sur la plateforme</span>
                      }
                    </li>
                  }
                </ul>
              }
            }
          </section>

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

    .btn-lien {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      margin-top: 6px;
      padding: 0;
      background: none;
      border: none;
      color: #8F6243;
      font-size: 12px;
      font-weight: 700;
      cursor: pointer;

      mat-icon { font-size: 16px; width: 16px; height: 16px; }
      &:hover { text-decoration: underline; }
    }

    .bloc-membres {
      display: flex;
      flex-direction: column;
      gap: 10px;

      .membres-resume {
        display: flex;
        align-items: center;
        gap: 12px;
        width: 100%;
        padding: 12px 14px;
        background: #FAF8F5;
        border: none;
        border-radius: 12px;
        text-align: left;
        cursor: pointer;
        transition: background 0.2s ease;

        &:hover:not(:disabled) { background: #F3EEE8; }
        &:disabled { cursor: default; }
        &:focus-visible { outline: 2px solid #EEA823; outline-offset: 2px; }
      }

      .resume-icone {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 36px;
        height: 36px;
        border-radius: 50%;
        background: rgba(143, 98, 67, 0.12);
        color: #8F6243;
        flex-shrink: 0;
      }

      .resume-texte {
        display: flex;
        flex-direction: column;
        flex: 1;
        min-width: 0;
      }

      .resume-titre {
        font-size: 13px;
        font-weight: 800;
        color: #2D231C;
      }

      .resume-chiffre {
        font-size: 12px;
        color: #8C7E74;

        &.erreur { color: #B42318; }
      }

      .chevron { color: #8C7E74; }
    }

    .repartition-statuts {
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
    }

    // Couleur d'un statut de compte, partagée par la répartition et chaque ligne
    .pastille-statut {
      display: inline-flex;
      align-items: center;
      padding: 3px 9px;
      border-radius: 20px;
      font-size: 11px;
      font-weight: 700;
      white-space: nowrap;
      background: #F1EEEA;
      color: #6B5E55;

      &[data-statut='ACTIF'] { background: rgba(52, 199, 89, 0.14); color: #1E7A3A; }
      &[data-statut='EN_ATTENTE'] { background: rgba(238, 168, 35, 0.16); color: #93600A; }
      &[data-statut='SUSPENDU'] { background: rgba(217, 45, 32, 0.12); color: #B42318; }
    }

    .liste-membres {
      list-style: none;
      margin: 0;
      padding: 0;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }

    .membre {
      display: flex;
      flex-direction: column;
      gap: 6px;
      padding: 10px 12px;
      background: #FFFFFF;
      border-radius: 12px;
      box-shadow: 0 1px 3px rgba(45, 35, 28, 0.1);
    }

    .membre-ligne {
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .membre-avatar {
      display: flex;
      align-items: center;
      justify-content: center;
      width: 32px;
      height: 32px;
      border-radius: 50%;
      background: #8F6243;
      color: #FFFFFF;
      font-size: 11.5px;
      font-weight: 800;
      flex-shrink: 0;
    }

    .membre-infos {
      display: flex;
      flex-direction: column;
      flex: 1;
      min-width: 0;
    }

    .membre-nom {
      font-size: 13px;
      font-weight: 700;
      color: #2D231C;
      text-decoration: none;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;

      &:hover { color: #8F6243; text-decoration: underline; }
    }

    .membre-role {
      font-size: 11.5px;
      color: #8C7E74;
    }

    .btn-actions {
      align-self: flex-start;
      display: inline-flex;
      align-items: center;
      gap: 4px;
      padding: 0;
      background: none;
      border: none;
      color: #8F6243;
      font-size: 11.5px;
      font-weight: 700;
      cursor: pointer;

      mat-icon { font-size: 15px; width: 15px; height: 15px; }
      &:hover { text-decoration: underline; }
    }

    .aucune-action {
      font-size: 11.5px;
      color: #A89B91;
    }

    .actions {
      list-style: none;
      margin: 0;
      padding: 0 0 0 10px;
      display: flex;
      flex-direction: column;
      gap: 8px;
      box-shadow: inset 2px 0 0 rgba(238, 168, 35, 0.5);

      li {
        display: flex;
        flex-direction: column;
        gap: 1px;
        padding-left: 6px;
      }

      .action-entete {
        display: flex;
        justify-content: space-between;
        gap: 8px;
      }

      .action-libelle {
        font-size: 12px;
        font-weight: 700;
        color: #2D231C;
      }

      time {
        font-size: 11px;
        color: #A89B91;
        white-space: nowrap;
      }

      .action-detail {
        font-size: 11.5px;
        color: #8C7E74;
        word-break: break-word;
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
  @Output() assignerPays = new EventEmitter<void>();

  private readonly api = inject(AdminApiService);
  private readonly destroyRef = inject(DestroyRef);
  private chargementMembres?: Subscription;

  photoErreur = false;
  readonly urlImage = urlImage;

  get photoUrlAffichee(): string {
    const raw = this.groupe?.produitPhotoUrl || this.groupe?.grossiste?.photoUrl;
    return raw ? urlImage(raw) : '';
  }

  readonly membres = signal<MembresGroupe | null>(null);
  readonly erreurMembres = signal('');
  readonly membresOuverts = signal(false);
  readonly actionsDepliees = signal<number | null>(null);

  private readonly formatDateHeure = new Intl.DateTimeFormat('fr-FR', {
    timeZone: 'Africa/Bamako',
    dateStyle: 'short',
    timeStyle: 'short'
  });

  constructor() {
    this.destroyRef.onDestroy(() => this.chargementMembres?.unsubscribe());
  }

  ngOnChanges(changes: SimpleChanges): void {
    this.photoErreur = false;
    const precedent = changes['groupe']?.previousValue as GroupeDetailVue | null | undefined;
    if (this.groupe && precedent?.id !== this.groupe.id) {
      this.chargerMembres(this.groupe.id);
    }
  }

  private chargerMembres(groupeId: number): void {
    this.chargementMembres?.unsubscribe();
    this.membres.set(null);
    this.erreurMembres.set('');
    this.membresOuverts.set(false);
    this.actionsDepliees.set(null);
    this.chargementMembres = this.api.membresGroupe(groupeId).subscribe({
      next: m => this.membres.set(m),
      error: err => this.erreurMembres.set(messageErreur(err, 'Utilisateurs du groupe indisponibles.'))
    });
  }

  onPhotoErreur(): void {
    this.photoErreur = true;
  }

  fermerTiroir(): void {
    this.fermer.emit();
  }

  basculerMembres(): void {
    this.membresOuverts.update(v => !v);
  }

  basculerActions(utilisateurId: number): void {
    this.actionsDepliees.update(id => (id === utilisateurId ? null : utilisateurId));
  }

  repartition(m: MembresGroupe): { statut: string; libelle: string; nombre: number }[] {
    return Object.entries(m.parStatutCompte).map(([statut, nombre]) => ({
      statut,
      libelle: this.libelleStatut(statut),
      nombre
    }));
  }

  pluriel(n: number, singulier: string, plurielForme = singulier + 's'): string {
    return `${n} ${n > 1 ? plurielForme : singulier}`;
  }

  initiales(nom: string): string {
    return nom.trim().split(/\s+/).map(p => p[0]).slice(0, 2).join('').toUpperCase() || '?';
  }

  libelleRole(role: string): string {
    return LIBELLES_ROLE[role] ?? role;
  }

  libelleStatut(statut: string): string {
    return LIBELLES_STATUT_COMPTE[statut] ?? statut;
  }

  libelleParticipation(statut: string): string {
    return LIBELLES_PARTICIPATION[statut] ?? statut;
  }

  /** « PARTICIPATION_CONFIRMEE » → « Participation confirmee » : lisible sans maintenir un dictionnaire des actions */
  libelleAction(action: string): string {
    const texte = action.replace(/_/g, ' ').toLowerCase();
    return texte.charAt(0).toUpperCase() + texte.slice(1);
  }

  formatDate(date: string): string {
    const d = new Date(date);
    return Number.isNaN(d.getTime()) ? '' : this.formatDateHeure.format(d);
  }
}

const LIBELLES_ROLE: Record<string, string> = {
  GROSSISTE: 'Grossiste (porteur)',
  COURTIER: 'Courtier',
  COMMERCANT: 'Commerçant'
};

const LIBELLES_STATUT_COMPTE: Record<string, string> = {
  ACTIF: 'Actif',
  EN_ATTENTE: 'En attente',
  SUSPENDU: 'Suspendu',
  DESACTIVE: 'Désactivé',
  INCONNU: 'Inconnu'
};

const LIBELLES_PARTICIPATION: Record<string, string> = {
  DEMANDEE: 'Demandée',
  RESERVEE: 'Réservée',
  CONFIRMEE: 'Payée',
  ANNULEE: 'Annulée',
  EXPIREE: 'Expirée'
};
