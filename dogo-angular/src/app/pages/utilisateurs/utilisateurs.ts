import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { dateCourte, fcfa, ligneCsv, messageErreur, telechargerTexte, urlImage } from '../../core/api';
import { LIBELLES_COMPTE, LIBELLES_TYPE } from '../../core/permissions';
import { AnnuaireService, Membre, TypeActeur } from '../../core/services/annuaire.service';
import { AuthService } from '../../core/services/auth.service';

type Filtre = 'TOUS' | TypeActeur;
type FiltreStatut = 'TOUS' | 'ACTIF' | 'EN_ATTENTE' | 'SUSPENDU';

export interface LigneMembre {
  membre: Membre;
  groupes: number;
  groupesActifs: number;
  partenaires: number;
  sequestre: number;
}

const ETATS_ACTIFS = ['BROUILLON', 'EN_VALIDATION', 'OUVERT', 'OBJECTIF_ATTEINT', 'EN_EXPEDITION', 'LIVRE'];

/**
 * Annuaire de tous les comptes de la plateforme : commerçants, grossistes, courtiers (et administrateurs pour le
 * rôle TECHNIQUE), avec pour chacun le nombre de groupes et de partenaires qui lui sont liés. Chaque ligne ouvre
 * la fiche du compte, où se gèrent la suspension, le KYC et les associations.
 */
@Component({
  selector: 'app-utilisateurs',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './utilisateurs.html',
  styleUrl: './utilisateurs.scss'
})
export class UtilisateursComponent implements OnInit {
  private readonly annuaire = inject(AnnuaireService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  readonly auth = inject(AuthService);

  readonly filtre = signal<Filtre>('TOUS');
  readonly filtreStatut = signal<FiltreStatut>('TOUS');
  readonly texte = signal('');
  readonly erreur = signal('');
  readonly chargement = this.annuaire.chargement;

  readonly libellesType = LIBELLES_TYPE;
  readonly libellesCompte = LIBELLES_COMPTE;
  readonly fcfa = fcfa;
  readonly dateCourte = dateCourte;
  readonly urlImage = urlImage;

  readonly onglets: { cle: Filtre; libelle: string }[] = [
    { cle: 'TOUS', libelle: 'Tous' },
    { cle: 'GROSSISTE', libelle: 'Grossistes' },
    { cle: 'COURTIER', libelle: 'Courtiers' },
    { cle: 'COMMERCANT', libelle: 'Commerçants' },
    { cle: 'ADMINISTRATEUR', libelle: 'Administrateurs' }
  ];

  readonly statuts: { cle: FiltreStatut; libelle: string }[] = [
    { cle: 'TOUS', libelle: 'Tous statuts' },
    { cle: 'ACTIF', libelle: 'Actifs' },
    { cle: 'EN_ATTENTE', libelle: 'KYC en attente' },
    { cle: 'SUSPENDU', libelle: 'Suspendus' }
  ];

  ngOnInit(): void {
    const type = this.route.snapshot.queryParamMap.get('type') as Filtre | null;
    if (type && this.onglets.some(o => o.cle === type)) {
      this.filtre.set(type);
    }
    const statut = this.route.snapshot.queryParamMap.get('statut') as FiltreStatut | null;
    if (statut && this.statuts.some(s => s.cle === statut)) {
      this.filtreStatut.set(statut);
    }
    this.charger();
  }

  charger(force = true): void {
    this.erreur.set('');
    this.annuaire.charger(force).subscribe({
      error: e => this.erreur.set(messageErreur(e, 'Impossible de charger les comptes.'))
    });
  }

  /** Compteurs des onglets, avant filtrage */
  readonly comptes = computed(() => {
    const parType = new Map<Filtre, number>([['TOUS', 0]]);
    for (const m of this.annuaire.membres()) {
      parType.set(m.type, (parType.get(m.type) ?? 0) + 1);
      parType.set('TOUS', parType.get('TOUS')! + 1);
    }
    return parType;
  });

  readonly ongletsVisibles = computed(() =>
    this.onglets.filter(o => o.cle !== 'ADMINISTRATEUR' || this.auth.peut('ADMIN_CREER'))
  );

  readonly lignes = computed<LigneMembre[]>(() => {
    const mots = this.texte().trim();
    const trouves = mots ? new Set(this.annuaire.rechercher(mots, 10_000).map(m => m.id)) : null;
    return this.annuaire
      .membres()
      .filter(m => this.filtre() === 'TOUS' || m.type === this.filtre())
      .filter(m => this.filtreStatut() === 'TOUS' || m.statut === this.filtreStatut())
      .filter(m => !trouves || trouves.has(m.id))
      .map(m => {
        const reseau = this.annuaire.reseau(m);
        return {
          membre: m,
          groupes: reseau.groupes.length,
          groupesActifs: reseau.groupes.filter(g => ETATS_ACTIFS.includes(g.statut)).length,
          partenaires: reseau.partenaires.length,
          sequestre: reseau.sequestres
            .filter(s => s.statut === 'BLOQUE')
            .reduce((t, s) => t + Number(s.montantBloque), 0)
        };
      });
  });

  readonly enAttente = computed(() => this.annuaire.membres().filter(m => m.statut === 'EN_ATTENTE').length);
  readonly suspendus = computed(() => this.annuaire.membres().filter(m => m.statut === 'SUSPENDU').length);

  badgeStatut(statut: string): string {
    return { ACTIF: 'green', EN_ATTENTE: 'yellow', SUSPENDU: 'red' }[statut] ?? '';
  }

  badgeType(type: string): string {
    return { GROSSISTE: 'orange', COURTIER: 'blue', COMMERCANT: 'green', ADMINISTRATEUR: 'violet' }[type] ?? '';
  }

  ouvrir(m: Membre): void {
    void this.router.navigate(['/utilisateurs', m.id]);
  }

  exporter(): void {
    const lignes = [
      ligneCsv(['ID', 'Type', 'Nom', 'Téléphone', 'Entreprise', 'Statut', 'Inscrit le', 'Groupes', 'Partenaires', 'Séquestre bloqué (FCFA)']),
      ...this.lignes().map(l =>
        ligneCsv([
          l.membre.id, LIBELLES_TYPE[l.membre.type], l.membre.nom, l.membre.telephone, l.membre.entreprise,
          LIBELLES_COMPTE[l.membre.statut] ?? l.membre.statut, dateCourte(l.membre.dateCreation), l.groupes,
          l.partenaires, l.sequestre
        ])
      )
    ];
    telechargerTexte(`utilisateurs-karavan-${new Date().toISOString().slice(0, 10)}.csv`, lignes.join('\n'));
  }
}
