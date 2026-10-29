import {
  ChangeDetectionStrategy,
  ChangeDetectorRef,
  Component,
  DestroyRef,
  OnInit,
  ViewChild,
  computed,
  inject,
  signal
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { MatIconModule } from '@angular/material/icon';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { AdminApiService, Convoi, DossierKyc } from '../../core/services/admin-api.service';
import { AuthService } from '../../core/services/auth.service';
import {
  ActiviteRecenteVue,
  GroupeCadranVue,
  GroupeDetailVue,
  PaysReference,
  ResumeTableauDeBord,
  TableauDeBordService
} from './tableau-de-bord.service';
import { Globe3dComponent } from './globe-3d/globe-3d.component';
import { CadranGroupesComponent } from './cadran-groupes/cadran-groupes.component';
import { DetailTiroirComponent } from './detail-tiroir/detail-tiroir.component';
import { ModalAssignerPaysComponent } from './modal-assigner-pays/modal-assigner-pays.component';
import { DrapeauPaysComponent } from '../../components/drapeau-pays/drapeau-pays.component';

@Component({
  selector: 'app-tableau-de-bord',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    MatIconModule,
    Globe3dComponent,
    CadranGroupesComponent,
    DetailTiroirComponent,
    ModalAssignerPaysComponent,
    DrapeauPaysComponent
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './tableau-de-bord.html',
  styleUrl: './tableau-de-bord.scss'
})
export class TableauDeBordComponent implements OnInit {
  @ViewChild(Globe3dComponent) globe3d?: Globe3dComponent;
  @ViewChild(CadranGroupesComponent) cadranGroupes?: CadranGroupesComponent;

  private readonly tbService = inject(TableauDeBordService);
  private readonly adminApi = inject(AdminApiService);
  private readonly router = inject(Router);
  readonly auth = inject(AuthService);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly destroyRef = inject(DestroyRef);

  readonly resume = signal<ResumeTableauDeBord | null>(null);
  readonly groupes = signal<GroupeCadranVue[]>([]);
  readonly listePays = signal<PaysReference[]>([]);
  readonly paysFiltre = signal<string | null>(null);
  readonly groupeDetail = signal<GroupeDetailVue | null>(null);

  /**
   * Le panneau Statistiques Générales est situé À L'INTÉRIEUR de la scène 3D.
   * Il est fermé par défaut (miniature discrète), s'ouvre au clic et se ferme via la croix (✕).
   */
  readonly panneauStatsOuvert = this.tbService.panneauStatsOuvert;
  readonly rechercheTexte = signal<string>('');

  readonly groupesAffiches = computed(() => {
    const q = this.rechercheTexte().toLowerCase().trim();
    const liste = this.groupes();
    if (!q) return liste;
    return liste.filter(g =>
      g.titre.toLowerCase().includes(q) ||
      g.paysOrigine?.nomFr?.toLowerCase().includes(q) ||
      g.grossiste?.nom?.toLowerCase().includes(q) ||
      g.id.toString().includes(q)
    );
  });

  modalRattrapageOuverte = false;
  chargement = false;
  erreur = '';

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

    // 1. Résumé du tableau de bord (protégé par takeUntilDestroyed)
    this.tbService.getResume()
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: r => {
          this.resume.set(r);
          this.cdr.markForCheck();
        },
        error: () => {
          this.erreur = 'Impossible de charger le résumé du tableau de bord.';
          this.cdr.markForCheck();
        }
      });

    // 2. Groupes pour le cadran
    this.tbService.getGroupes({ taille: 200 })
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
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
    this.tbService.getPaysActifs()
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: pays => {
          this.listePays.set(pays || []);
          this.cdr.markForCheck();
        }
      });

    // 4. Données annexes
    this.adminApi.sequestres()
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: s => {
          this.totalSequestre = s?.totalBloque ?? 0;
          this.cdr.markForCheck();
        }
      });

    this.adminApi.dossiersKyc()
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: d => {
          this.kycEnAttente = d ?? [];
          this.cdr.markForCheck();
        }
      });

    this.adminApi.convois()
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: c => {
          this.convoisTransit = (c ?? []).filter(item => item.statut === 'EN_TRANSIT' || item.statut === 'BLOQUE_DOUANE');
          this.cdr.markForCheck();
        }
      });
  }

  ouvrirPanneauStats(): void {
    this.tbService.ouvrirPanneauStats();
    this.cdr.markForCheck();
  }

  fermerPanneauStats(): void {
    this.tbService.fermerPanneauStats();
    this.cdr.markForCheck();
  }

  basculerPanneauStats(): void {
    this.tbService.basculerPanneauStats();
    this.cdr.markForCheck();
  }

  onPaysChoisi(codeIso: string | null): void {
    if (this.paysFiltre() === codeIso) return;
    this.paysFiltre.set(codeIso);
    this.cdr.markForCheck();
  }

  /**
   * Rotation du cadran (flèche gauche/droite, molette, points de pagination) :
   * - Oriente la caméra 3D du globe sur le pays
   * - NE FAIT PAS APPARAÎTRE LE TIROIR DE DÉTAIL SI CELUI-CI EST FERMÉ !
   * - Si et seulement si le tiroir est DÉJÀ ouvert, met à jour son contenu.
   */
  onRotationCadran(g: GroupeCadranVue): void {
    if (g.paysOrigine?.codeIso) {
      this.globe3d?.focaliserSurPays(g.paysOrigine.codeIso);
    }

    if (this.groupeDetail() !== null) {
      this.chargerDetailGroupe(g.id);
    }
  }

  /**
   * Clic explicite sur une carte du cadran :
   * - Si déjà ouvert sur ce même groupe -> on le ferme
   * - Sinon -> on focalise la caméra et on ouvre le détail
   */
  onGroupeClique(g: GroupeCadranVue): void {
    if (this.groupeDetail()?.id === g.id) {
      this.fermerDetail();
      return;
    }

    if (g.paysOrigine?.codeIso) {
      this.globe3d?.focaliserSurPays(g.paysOrigine.codeIso);
    }

    this.chargerDetailGroupe(g.id);
  }

  private chargerDetailGroupe(id: number): void {
    this.tbService.getDetailGroupe(id)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: detail => {
          this.groupeDetail.set(detail);
          this.cdr.markForCheck();
        },
        error: () => {
          const g = this.groupes().find(item => item.id === id);
          if (!g) return;
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
            produitPhotoUrl: g.produitPhotoUrl || null,
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

  formatTempsEcoule(dateStr?: string | null): string {
    if (!dateStr) return 'Récemment';
    try {
      const diffMs = Date.now() - new Date(dateStr).getTime();
      const diffMin = Math.floor(diffMs / 60000);
      if (diffMin < 1) return "À l'instant";
      if (diffMin < 60) return `Il y a ${diffMin} min`;
      const diffH = Math.floor(diffMin / 60);
      if (diffH < 24) return `Il y a ${diffH} h`;
      const diffJ = Math.floor(diffH / 24);
      return `Il y a ${diffJ} j`;
    } catch {
      return 'Récemment';
    }
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
