import { ChangeDetectorRef, Component, OnInit, computed, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { CommonModule } from '@angular/common';
import { MatIconModule } from '@angular/material/icon';
import { Observable } from 'rxjs';
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { messageErreur } from '../../core/api';
import { PERMISSIONS_PAGES } from '../../core/permissions';
import {
  AdminApiService,
  Convoi,
  DossierKyc,
  Groupe,
  StatsSupervision
} from '../../core/services/admin-api.service';
import { AuthService } from '../../core/services/auth.service';

export interface StatutCorridor {
  route: string;
  info: string;
  alerte: boolean;
}

/**
 * Supervision du réseau : chaque indicateur n'est demandé que si le rôle administratif le permet
 * (sinon « Réservé à un autre rôle » au lieu d'une erreur 403).
 */
@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, MatIconModule, RouterLink],
  templateUrl: './dashboard.html',
  styleUrl: './dashboard.scss'
})
export class DashboardComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  private readonly router = inject(Router);
  readonly auth = inject(AuthService);
  // Application sans zone.js : chaque réponse du serveur signale explicitement le rafraîchissement de la vue
  private readonly cdr = inject(ChangeDetectorRef);

  private readonly convoisCharges = signal<Convoi[]>([]);
  private readonly groupesCharges = signal<Groupe[]>([]);

  // KYC
  kycPendingList: DossierKyc[] = [];
  chargementKyc = false;
  erreurKyc = '';

  // Finance
  totalBloque = 0;
  chargementFinance = false;
  erreurFinance = '';

  // Logistique
  nombreConvoisTransit = 0;
  chargementConvois = false;
  erreurConvois = '';

  // Groupes
  groupesClotures = 0;
  chargementGroupes = false;
  erreurGroupes = '';

  /** Comptes inscrits par type */
  readonly stats = signal<StatsSupervision | null>(null);

  readonly groupesAModerer = computed(() => this.groupesCharges().filter(g => g.statut === 'EN_VALIDATION').length);
  readonly groupesOuverts = computed(() => this.groupesCharges().filter(g => g.statut === 'OUVERT').length);
  readonly peutVoirGroupes = this.auth.peut(...PERMISSIONS_PAGES['groupes']);

  // Date dynamique pour l'en-tête
  readonly dateDuJour = new Intl.DateTimeFormat('fr-FR', {
    timeZone: 'Africa/Bamako',
    dateStyle: 'full'
  }).format(new Date());

  get nombreCourtiersEnAttente(): number {
    return this.kycPendingList.filter(dossier => dossier.typeActeur === 'COURTIER').length;
  }

  get nombreGrossistesEnAttente(): number {
    return this.kycPendingList.filter(dossier => dossier.typeActeur === 'GROSSISTE').length;
  }

  /** Axes logistiques réels : groupes en chemin par pays d'origine, en alerte si un convoi est bloqué en douane */
  readonly corridorsCalcules = computed<StatutCorridor[]>(() => {
    const enChemin = this.groupesCharges().filter(g => ['OBJECTIF_ATTEINT', 'EN_EXPEDITION', 'LIVRE'].includes(g.statut));
    const axes = new Map<string, { nombre: number; alerte: boolean }>();
    for (const g of enChemin) {
      const pays = g.produit?.paysOrigine || 'Origine inconnue';
      const axe = axes.get(pays) ?? { nombre: 0, alerte: false };
      axe.nombre++;
      axe.alerte ||= this.convoisCharges().some(c => c.groupeId === g.id && c.statut === 'BLOQUE_DOUANE');
      axes.set(pays, axe);
    }
    return [...axes.entries()].map(([pays, axe]) => ({
      route: `${pays} ➔ Bamako`,
      info: `${axe.nombre} groupe${axe.nombre > 1 ? 's' : ''} en chemin${axe.alerte ? ' (douane)' : ''}`,
      alerte: axe.alerte
    }));
  });

  get corridors(): StatutCorridor[] {
    return this.corridorsCalcules();
  }

  ngOnInit(): void {
    this.charger(this.api.dossiersKyc(), ['KYC_VALIDER'], 'Kyc', dossiers => (this.kycPendingList = dossiers ?? []));
    this.charger(this.api.sequestres(), PERMISSIONS_PAGES['finance'], 'Finance', t => (this.totalBloque = t?.totalBloque ?? 0));
    this.charger(this.api.convois(), PERMISSIONS_PAGES['corridors'], 'Convois', convois => {
      this.convoisCharges.set(convois ?? []);
      this.nombreConvoisTransit = (convois ?? []).filter(c => c.statut === 'EN_TRANSIT' || c.statut === 'BLOQUE_DOUANE').length;
    });
    this.charger(this.api.groupes(), PERMISSIONS_PAGES['groupes'], 'Groupes', groupes => {
      // Un groupe a terminé son cycle quand toutes ses commandes sont retirées (StatutGroupe.TERMINE)
      this.groupesCharges.set(groupes ?? []);
      this.groupesClotures = (groupes ?? []).filter(g => g.statut === 'TERMINE').length;
    });
    if (this.auth.peut('ADMIN_CREER', 'COMPTE_SUSPENDRE', 'AUDIT_LIRE')) {
      this.api.statistiques().subscribe({ next: s => this.stats.set(s), error: () => this.stats.set(null) });
    }
  }

  /** Charge un indicateur si le rôle le permet ; l'état (chargementX / erreurX) pilote l'affichage de sa carte */
  private charger<T>(
    appel: Observable<T>,
    permissions: string[],
    cle: 'Kyc' | 'Finance' | 'Convois' | 'Groupes',
    succes: (valeur: T) => void
  ): void {
    const etat = this as unknown as Record<string, boolean | string>;
    if (!this.auth.peut(...permissions)) {
      etat['erreur' + cle] = 'Réservé à un autre rôle administratif.';
      return;
    }
    etat['chargement' + cle] = true;
    etat['erreur' + cle] = '';
    appel.subscribe({
      next: valeur => {
        succes(valeur);
        etat['chargement' + cle] = false;
        this.cdr.markForCheck();
      },
      error: e => {
        etat['erreur' + cle] = messageErreur(e, 'Données indisponibles.');
        etat['chargement' + cle] = false;
        this.cdr.markForCheck();
      }
    });
  }

  ouvrirDossier(dossier?: DossierKyc): void {
    void this.router.navigate(['/kyc-validation'], { queryParams: dossier ? { utilisateur: dossier.utilisateurId } : undefined });
  }

  ouvrirAudit(): void {
    void this.router.navigate(['/finance']);
  }

  documentsDu(dossier: DossierKyc): string {
    return (dossier.documents ?? [])
      .map(document => document.type.replace(/_/g, ' '))
      .join(' + ');
  }

  dateRelative(date: string): string {
    if (!date) {
      return 'Date inconnue';
    }

    const dateSoumission = new Date(date).getTime();

    if (Number.isNaN(dateSoumission)) {
      return 'Date inconnue';
    }

    const minutes = Math.max(
      0,
      Math.floor((Date.now() - dateSoumission) / 60_000)
    );

    if (minutes < 1) return 'À l’instant';
    if (minutes < 60) return `Il y a ${minutes} min`;

    const heures = Math.floor(minutes / 60);
    if (heures < 24) return `Il y a ${heures} h`;

    const jours = Math.floor(heures / 24);
    if (jours === 1) return 'Hier';

    return `Il y a ${jours} jours`;
  }

  telechargerRapport(): void {
    try {
      const pdf = new jsPDF();

      const dateGeneration = new Intl.DateTimeFormat('fr-FR', {
        timeZone: 'Africa/Bamako',
        dateStyle: 'long',
        timeStyle: 'short'
      }).format(new Date());

      pdf.setFontSize(18);
      pdf.text('Karavan - Rapport de supervision', 14, 20);

      pdf.setFontSize(10);
      pdf.text(`Genere le : ${dateGeneration}`, 14, 29);

      pdf.text(
        `Volume sous sequestre : ${
          this.erreurFinance
            ? 'Indisponible'
            : `${this.totalBloque.toLocaleString('fr-FR')} FCFA`
        }`,
        14,
        37
      );

      pdf.text(
        `Convois en transit : ${
          this.erreurConvois ? 'Indisponible' : this.nombreConvoisTransit
        }`,
        14,
        44
      );

      pdf.text(
        `Groupes clotures : ${
          this.erreurGroupes ? 'Indisponible' : this.groupesClotures
        }`,
        14,
        51
      );

      pdf.text(
        `Dossiers KYC en attente : ${
          this.erreurKyc ? 'Indisponible' : this.kycPendingList.length
        }`,
        14,
        58
      );

      autoTable(pdf, {
        startY: 66,
        head: [[
          'ID',
          'Nom',
          'Telephone',
          'Role',
          'Documents',
          'Date de soumission'
        ]],
        body: this.erreurKyc
          ? [['-', 'Donnees KYC indisponibles', '-', '-', '-', '-']]
          : this.kycPendingList.map(dossier => [
              dossier.id,
              dossier.nom,
              dossier.telephone,
              dossier.typeActeur,
              this.documentsDu(dossier) || 'Aucun document',
              dossier.dateSoumission
                ? new Intl.DateTimeFormat('fr-FR', {
                    timeZone: 'Africa/Bamako',
                    dateStyle: 'short',
                    timeStyle: 'short'
                  }).format(new Date(dossier.dateSoumission))
                : 'Inconnue'
            ]),
        styles: {
          fontSize: 8,
          cellPadding: 3,
          overflow: 'linebreak'
        },
        headStyles: {
          fillColor: [45, 55, 72]
        },
        margin: {
          left: 14,
          right: 14
        }
      });

      pdf.save('rapport-karavan.pdf');
    } catch (erreur) {
      console.error('Erreur lors de la génération du rapport PDF :', erreur);
      alert('Le rapport n’a pas pu être généré. Consulte la console pour plus de détails.');
    }
  }
}
