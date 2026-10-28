import {
  ChangeDetectionStrategy,
  ChangeDetectorRef,
  Component,
  OnInit,
  ViewChild,
  inject,
  signal
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { MatIconModule } from '@angular/material/icon';
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { AdminApiService, Convoi, DossierKyc } from '../../core/services/admin-api.service';
import { AuthService } from '../../core/services/auth.service';
import {
  GroupeCadranVue,
  GroupeDetailVue,
  PaysReference,
  ResumeTableauDeBord,
  TableauDeBordService
} from './tableau-de-bord.service';
import { Globe3dComponent } from './globe-3d/globe-3d.component';
import { CadranGroupesComponent } from './cadran-groupes/cadran-groupes.component';
import { StatistiquesDroiteComponent } from './statistiques-droite/statistiques-droite.component';
import { DetailTiroirComponent } from './detail-tiroir/detail-tiroir.component';
import { ModalAssignerPaysComponent } from './modal-assigner-pays/modal-assigner-pays.component';

@Component({
  selector: 'app-tableau-de-bord',
  standalone: true,
  imports: [
    CommonModule,
    MatIconModule,
    Globe3dComponent,
    CadranGroupesComponent,
    StatistiquesDroiteComponent,
    DetailTiroirComponent,
    ModalAssignerPaysComponent
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './tableau-de-bord.html',
  styleUrl: './tableau-de-bord.scss'
})
export class TableauDeBordComponent implements OnInit {
  @ViewChild(Globe3dComponent) globe3d?: Globe3dComponent;

  private readonly tbService = inject(TableauDeBordService);
  private readonly adminApi = inject(AdminApiService);
  private readonly router = inject(Router);
  readonly auth = inject(AuthService);
  private readonly cdr = inject(ChangeDetectorRef);

  readonly resume = signal<ResumeTableauDeBord | null>(null);
  readonly groupes = signal<GroupeCadranVue[]>([]);
  readonly listePays = signal<PaysReference[]>([]);
  readonly paysFiltre = signal<string | null>(null);
  readonly groupeDetail = signal<GroupeDetailVue | null>(null);

  modalRattrapageOuverte = false;
  chargement = false;
  erreur = '';

  // Données conservées pour la compatibilité avec l'ancien tableau de bord et le rapport PDF
  totalSequestre = 0;
  kycEnAttente: DossierKyc[] = [];
  convoisTransit: Convoi[] = [];

  readonly dateDuJour = new Intl.DateTimeFormat('fr-FR', {
    timeZone: 'Africa/Bamako',
    dateStyle: 'full'
  }).format(new Date());

  ngOnInit(): void {
    this.chargerTout();
  }

  chargerTout(): void {
    this.chargement = true;
    this.erreur = '';

    // 1. Résumé du tableau de bord
    this.tbService.getResume().subscribe({
      next: r => {
        this.resume.set(r);
        this.cdr.markForCheck();
      },
      error: err => {
        this.erreur = 'Impossible de charger le résumé du tableau de bord.';
        this.cdr.markForCheck();
      }
    });

    // 2. Groupes pour le cadran
    this.tbService.getGroupes({ taille: 200 }).subscribe({
      next: grps => {
        this.groupes.set(grps || []);
        this.chargement = false;
        this.cdr.markForCheck();
      },
      error: () => {
        this.chargement = false;
        this.cdr.markForCheck();
      }
    });

    // 3. Liste des pays de référence
    this.tbService.getPaysActifs().subscribe({
      next: pays => {
        this.listePays.set(pays || []);
        this.cdr.markForCheck();
      }
    });

    // 4. Données annexes (Séquestre, KYC, Convois)
    this.adminApi.sequestres().subscribe({
      next: s => {
        this.totalSequestre = s?.totalBloque ?? 0;
        this.cdr.markForCheck();
      }
    });

    this.adminApi.dossiersKyc().subscribe({
      next: d => {
        this.kycEnAttente = d ?? [];
        this.cdr.markForCheck();
      }
    });

    this.adminApi.convois().subscribe({
      next: c => {
        this.convoisTransit = (c ?? []).filter(item => item.statut === 'EN_TRANSIT' || item.statut === 'BLOQUE_DOUANE');
        this.cdr.markForCheck();
      }
    });
  }

  onPaysChoisi(codeIso: string | null): void {
    this.paysFiltre.set(codeIso);
    this.cdr.markForCheck();
  }

  onGroupeSelectionne(g: GroupeCadranVue): void {
    if (g.paysOrigine?.codeIso) {
      this.globe3d?.focaliserSurPays(g.paysOrigine.codeIso);
    }
    this.tbService.getDetailGroupe(g.id).subscribe({
      next: detail => {
        this.groupeDetail.set(detail);
        this.cdr.markForCheck();
      },
      error: () => {
        // En cas d'erreur de chargement du détail, affichage basique
        this.groupeDetail.set({
          id: g.id,
          titre: g.titre,
          statut: g.statut,
          paysOrigine: g.paysOrigine,
          quantiteCible: g.quantiteCible,
          quantiteConfirmee: g.quantiteConfirmee,
          quantiteReservee: g.quantiteReservee,
          quantiteRestante: Math.max(0, g.quantiteCible - (g.quantiteConfirmee + g.quantiteReservee)),
          progressionPourcentage: g.progressionPourcentage,
          prixUnitaire: g.prixUnitaire,
          dateLancement: g.dateLancement,
          dateLimite: g.dateLimite,
          disponibiliteValidee: true,
          porteParGrossiste: false,
          grossiste: g.grossiste,
          courtier: g.courtier,
          produitNom: g.titre,
          produitDescription: '',
          produitPhotoUrl: null,
          categorieNom: g.categorieNom,
          prixMarchandise: 0,
          transport: 0,
          fraisPlateforme: 0,
          douane: 0,
          autres: 0,
          devise: 'XOF',
          delaiLivraisonJours: 30,
          politiqueAnnulation: null,
          quantiteMinParCommercant: 1,
          etapesAcheminement: []
        });
        this.cdr.markForCheck();
      }
    });
  }

  fermerDetail(): void {
    this.groupeDetail.set(null);
    this.cdr.markForCheck();
  }

  ouvrirModalRattrapage(): void {
    this.modalRattrapageOuverte = true;
    this.cdr.markForCheck();
  }

  fermerModalRattrapage(): void {
    this.modalRattrapageOuverte = false;
    this.cdr.markForCheck();
  }

  apresAssignationPays(): void {
    this.chargerTout();
  }

  telechargerRapport(): void {
    try {
      const pdf = new jsPDF();
      const dateGen = new Intl.DateTimeFormat('fr-FR', {
        timeZone: 'Africa/Bamako',
        dateStyle: 'long',
        timeStyle: 'short'
      }).format(new Date());

      pdf.setFontSize(18);
      pdf.text('Karavan - Rapport du Tableau de Bord', 14, 20);

      pdf.setFontSize(10);
      pdf.text(`Généré le : ${dateGen}`, 14, 28);
      pdf.text(`Hub de Destination : Bamako, Mali`, 14, 35);
      pdf.text(`Total Groupes Actifs : ${this.resume()?.totalGroupes ?? this.groupes().length}`, 14, 42);
      pdf.text(`Volume sous Séquestre : ${this.totalSequestre.toLocaleString('fr-FR')} FCFA`, 14, 49);
      pdf.text(`Expéditions en Transit : ${this.convoisTransit.length}`, 14, 56);
      pdf.text(`Dossiers KYC en attente : ${this.kycEnAttente.length}`, 14, 63);

      const tableData = this.groupes().map(g => [
        g.id.toString(),
        g.titre,
        g.paysOrigine?.nomFr || 'Non renseigné',
        `${g.quantiteConfirmee + g.quantiteReservee} / ${g.quantiteCible}`,
        g.statut,
        `${(g.prixUnitaire || 0).toLocaleString('fr-FR')} FCFA`
      ]);

      autoTable(pdf, {
        startY: 72,
        head: [['ID', 'Groupe', 'Pays Origine', 'Pièces', 'Statut', 'Prix unitaire']],
        body: tableData.length > 0 ? tableData : [['-', 'Aucun groupe', '-', '-', '-', '-']],
        styles: { fontSize: 8, cellPadding: 3 },
        headStyles: { fillColor: [143, 98, 67] }
      });

      pdf.save('karavan-tableau-de-bord.pdf');
    } catch (e) {
      console.error('Erreur génération rapport PDF :', e);
      alert('Impossible de générer le rapport PDF.');
    }
  }
}
