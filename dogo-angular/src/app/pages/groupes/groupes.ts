import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { Observable, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { LIBELLES_COMMANDE, LIBELLES_GROUPE, dateCourte, fcfa, ligneCsv, messageErreur, telechargerTexte } from '../../core/api';
import { LIBELLES_TYPE, PERMISSIONS_PAGES } from '../../core/permissions';
import {
  AdminApiService,
  CommandeGroupe,
  Convoi,
  EtapeSignalee,
  Groupe,
  TransitionGroupe
} from '../../core/services/admin-api.service';
import { AnnuaireService } from '../../core/services/annuaire.service';
import { AuthService } from '../../core/services/auth.service';

type Onglet = 'TOUS' | 'A_MODERER' | 'BROUILLON' | 'OUVERT' | 'ACHEMINEMENT' | 'TERMINE' | 'ARRETE';

const ETATS_ONGLET: Record<Onglet, string[] | null> = {
  TOUS: null,
  A_MODERER: ['EN_VALIDATION'],
  BROUILLON: ['BROUILLON'],
  OUVERT: ['OUVERT'],
  ACHEMINEMENT: ['OBJECTIF_ATTEINT', 'EN_EXPEDITION', 'LIVRE'],
  TERMINE: ['TERMINE'],
  ARRETE: ['ANNULE', 'ECHOUE']
};

/** RG-24 : annulation possible avant l'objectif atteint */
const ANNULABLES = ['BROUILLON', 'EN_VALIDATION', 'OUVERT'];
const ETATS_AVEC_COMMANDES = ['OBJECTIF_ATTEINT', 'EN_EXPEDITION', 'LIVRE', 'TERMINE'];

/** Acheteur d'un groupe : commerçant, quantité, et état de sa commande s'il y en a une */
export interface Acheteur {
  id: number | null;
  nom: string;
  quantite: number;
  etat: string;
}

/**
 * Groupes d'achat : vue complète du cycle de vie (brouillon → validation → ouvert → acheminement → terminé),
 * avec pour chaque groupe son grossiste, son courtier (ou le grossiste porteur), ses acheteurs et son historique.
 * Modération avant publication (RG-18) et annulation motivée (RG-24, RG-68) selon le rôle administratif.
 */
@Component({
  selector: 'app-groupes',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './groupes.html',
  styleUrl: './groupes.scss'
})
export class GroupesComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  private readonly annuaire = inject(AnnuaireService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  readonly auth = inject(AuthService);

  readonly onglet = signal<Onglet>('TOUS');
  readonly texte = signal('');
  readonly selectionId = signal<number | null>(null);
  readonly erreur = signal('');
  readonly message = signal('');
  readonly echec = signal(false);
  readonly envoi = signal(false);
  readonly chargement = this.annuaire.chargement;

  readonly historique = signal<TransitionGroupe[]>([]);
  readonly commandes = signal<CommandeGroupe[]>([]);
  readonly etapes = signal<EtapeSignalee[]>([]);
  readonly convois = signal<Convoi[]>([]);

  /** Formulaire de motif (refus de publication ou annulation) */
  readonly decision = signal<'REFUS' | 'ANNULATION' | null>(null);
  motif = '';

  readonly libellesGroupe = LIBELLES_GROUPE;
  readonly libellesCommande = LIBELLES_COMMANDE;
  readonly fcfa = fcfa;
  readonly dateCourte = dateCourte;

  readonly onglets: { cle: Onglet; libelle: string }[] = [
    { cle: 'TOUS', libelle: 'Tous' },
    { cle: 'A_MODERER', libelle: 'À modérer' },
    { cle: 'OUVERT', libelle: 'Ouverts' },
    { cle: 'ACHEMINEMENT', libelle: 'En acheminement' },
    { cle: 'TERMINE', libelle: 'Terminés' },
    { cle: 'BROUILLON', libelle: 'Brouillons' },
    { cle: 'ARRETE', libelle: 'Annulés / échoués' }
  ];

  ngOnInit(): void {
    let ongletDemande = false;
    this.route.paramMap.subscribe(p => {
      const id = Number(p.get('id'));
      if (id) {
        this.selectionId.set(id);
        ongletDemande = true;
      }
    });
    this.route.queryParamMap.subscribe(p => {
      const id = Number(p.get('id'));
      if (id) {
        this.selectionId.set(id);
        ongletDemande = true;
      }
      const onglet = p.get('onglet') as Onglet | null;
      if (onglet && onglet in ETATS_ONGLET) {
        this.onglet.set(onglet);
        ongletDemande = true;
      }
    });
    this.charger(true, () => {
      // Des groupes attendent la publication : on les montre d'abord à qui peut les publier
      if (!ongletDemande && this.auth.peut('GROUPE_PUBLICATION_VALIDER') && this.comptes().get('A_MODERER')) {
        this.onglet.set('A_MODERER');
      }
    });
  }

  charger(force = true, apres?: () => void): void {
    this.erreur.set('');
    if (this.auth.peut('COMMANDE_AVANCER', 'POINT_RETRAIT_GERER', 'RECEPTION_VALIDER', 'COMMANDE_LIRE')) {
      this.api.convois().pipe(catchError(() => of([] as Convoi[]))).subscribe(c => this.convois.set(c ?? []));
    }
    this.annuaire.charger(force).subscribe({
      next: () => {
        const id = this.selectionId();
        if (id !== null) {
          this.chargerDetail(id);
        }
        apres?.();
      },
      error: e => this.erreur.set(messageErreur(e, 'Impossible de charger les groupes.'))
    });
  }

  // ---------------------------------------------------------------- vues calculées

  readonly comptes = computed(() => {
    const c = new Map<Onglet, number>();
    for (const o of this.onglets) {
      const etats = ETATS_ONGLET[o.cle];
      c.set(o.cle, this.annuaire.groupes().filter(g => !etats || etats.includes(g.statut)).length);
    }
    return c;
  });

  readonly groupes = computed(() => {
    const etats = ETATS_ONGLET[this.onglet()];
    const mots = this.texte().trim().toLowerCase().replace(/^#/, '');
    return this.annuaire
      .groupes()
      .filter(g => !etats || etats.includes(g.statut))
      .filter(
        g =>
          !mots ||
          [String(g.id), g.titre, g.produit?.nom, g.produit?.categorie, g.produit?.paysOrigine, g.grossiste?.nom, g.courtier?.nom]
            .join(' ')
            .toLowerCase()
            .includes(mots)
      );
  });

  readonly selection = computed<Groupe | null>(() => this.annuaire.groupes().find(g => g.id === this.selectionId()) ?? null);

  /** Acheteurs : commandes si elles existent, sinon paiements en séquestre (participations payées) */
  readonly acheteurs = computed<Acheteur[]>(() => {
    const g = this.selection();
    if (!g) return [];
    if (this.commandes().length) {
      return this.commandes().map(c => ({
        id: c.commercantId,
        nom: c.commercantNom ?? `Commerçant #${c.commercantId ?? '?'}`,
        quantite: c.quantite,
        etat: `Commande #${c.id} · ${LIBELLES_COMMANDE[c.statut] ?? c.statut}`
      }));
    }
    return this.annuaire
      .sequestres()
      .filter(s => s.groupeId === g.id)
      .map(s => ({
        id: s.acheteurId,
        nom: s.acheteur ?? '—',
        quantite: s.quantite,
        etat: s.gele ? 'Paiement gelé (litige)' : s.statut === 'BLOQUE' ? 'Payé · en séquestre' : s.statut === 'LIBERE' ? 'Payé · libéré' : 'Remboursé'
      }));
  });

  readonly peutPublier = computed(() => this.selection()?.statut === 'EN_VALIDATION' && this.auth.peut('GROUPE_PUBLICATION_VALIDER'));
  readonly peutAnnuler = computed(() => ANNULABLES.includes(this.selection()?.statut ?? '') && this.auth.peut('GROUPE_ANNULER'));
  readonly peutPiloter = computed(
    () => ['OBJECTIF_ATTEINT', 'EN_EXPEDITION', 'LIVRE'].includes(this.selection()?.statut ?? '') && this.auth.peut(...PERMISSIONS_PAGES['corridors'])
  );

  readonly convoiAssocie = computed(() => {
    const id = this.selectionId();
    return id ? this.convois().find(c => c.groupeId === id) ?? null : null;
  });

  readonly peutOuvrirSuiviDirect = computed(() => {
    const g = this.selection();
    if (!g) return false;
    const statutOk = ['OBJECTIF_ATTEINT', 'EN_EXPEDITION'].includes(g.statut);
    const sansConvoi = !this.convoiAssocie();
    const peutGerer = this.auth.peut('POINT_RETRAIT_GERER', 'COMMANDE_AVANCER', 'RECEPTION_VALIDER');
    return statutOk && sansConvoi && peutGerer;
  });

  badge(statut: string): string {
    if (['TERMINE', 'LIVRE'].includes(statut)) return 'green';
    if (['ANNULE', 'ECHOUE'].includes(statut)) return 'red';
    if (['BROUILLON', 'EN_VALIDATION'].includes(statut)) return 'yellow';
    if (statut === 'OUVERT') return 'blue';
    return 'orange';
  }

  progression(g: Groupe): number {
    return g.quantiteCible ? Math.min(100, Math.round((g.quantiteConfirmee / g.quantiteCible) * 100)) : 0;
  }

  /** « COURTIER:12 » → lien vers la fiche ; « ADMIN:3 », « SYSTEME »… → libellé */
  auteur(t: TransitionGroupe): { libelle: string; id: number | null } {
    const [type, id] = (t.auteur ?? '').split(':');
    const n = Number(id);
    const libelle = type === 'ADMIN' ? 'Administrateur' : LIBELLES_TYPE[type] ?? (type || 'Système');
    const nom = Number.isInteger(n) && n > 0 ? this.annuaire.membre(n)?.nom : null;
    return { libelle: nom ? `${libelle} ${nom}` : n ? `${libelle} #${n}` : libelle, id: Number.isInteger(n) && n > 0 ? n : null };
  }

  // ---------------------------------------------------------------- sélection

  selectionner(g: Groupe): void {
    this.selectionId.set(g.id);
    this.decision.set(null);
    this.message.set('');
    void this.router.navigate([], { queryParams: { id: g.id }, queryParamsHandling: 'merge', replaceUrl: true });
    this.chargerDetail(g.id);
  }

  private chargerDetail(id: number): void {
    const g = this.annuaire.groupes().find(x => x.id === id);
    this.historique.set([]);
    this.commandes.set([]);
    this.etapes.set([]);
    if (!g) {
      return;
    }
    this.api.historiqueGroupe(id).pipe(catchError(() => of([] as TransitionGroupe[]))).subscribe(h => this.historique.set(h ?? []));
    if (ETATS_AVEC_COMMANDES.includes(g.statut) && this.auth.peut('COMMANDE_LIRE')) {
      this.api.commandesDuGroupe(id).pipe(catchError(() => of([] as CommandeGroupe[]))).subscribe(c => this.commandes.set(c ?? []));
    }
    if (g.porteParGrossiste && this.auth.peut('RECEPTION_VALIDER', 'GROUPE_PUBLICATION_VALIDER')) {
      this.api.etapesSignalees(id).pipe(catchError(() => of([] as EtapeSignalee[]))).subscribe(e => this.etapes.set(e ?? []));
    }
  }

  // ---------------------------------------------------------------- actions

  publier(g: Groupe | null = this.selection()): void {
    if (!g) return;
    this.selectionId.set(g.id);
    if (!g.disponibiliteValidee) {
      this.echec.set(true);
      this.message.set('Le grossiste n’a pas encore confirmé son stock (RG-18) : publication impossible.');
      return;
    }
    this.executer(this.api.deciderPublication(g.id, true, 'Conforme'), `« ${g.titre} » est publié : les commerçants peuvent le rejoindre.`);
  }

  confirmerDecision(): void {
    const g = this.selection();
    const motif = this.motif.trim();
    if (!g || !motif) return;
    if (this.decision() === 'REFUS') {
      this.executer(this.api.deciderPublication(g.id, false, motif), `« ${g.titre} » est renvoyé en brouillon à son porteur.`);
    } else {
      this.executer(this.api.annulerGroupe(g.id, motif), `« ${g.titre} » est annulé : le porteur est notifié et les participants remboursés.`);
    }
  }

  piloter(): void {
    void this.router.navigate(['/corridors']);
  }

  ouvrirSuiviDirect(g: Groupe | null = this.selection()): void {
    if (!g) return;
    const transporteur = g.porteParGrossiste
      ? `${g.grossiste?.nom ?? 'Grossiste'} (moyens propres)`
      : g.courtier?.nom ?? 'Karavan Transit';
    const reference = `CNV-${g.id}-${Date.now().toString(36).toUpperCase()}`;
    this.executer(
      this.api.creerConvoi(g.id, reference, transporteur),
      `Suivi officiel ouvert avec succès pour « ${g.titre} » (Réf. ${reference}). Les étapes d'acheminement sont débloquées.`
    );
  }

  exporter(): void {
    const lignes = [
      ligneCsv(['ID', 'Titre', 'Produit', 'Origine', 'Grossiste', 'Courtier', 'État', 'Confirmé', 'Cible', 'Prix unitaire', 'Date limite']),
      ...this.groupes().map(g =>
        ligneCsv([
          g.id, g.titre, g.produit?.nom, g.produit?.paysOrigine, g.grossiste?.nom, g.courtier?.nom ?? '(porté par le grossiste)',
          LIBELLES_GROUPE[g.statut] ?? g.statut, g.quantiteConfirmee, g.quantiteCible, g.prixUnitaire, dateCourte(g.dateLimite)
        ])
      )
    ];
    telechargerTexte(`groupes-karavan-${new Date().toISOString().slice(0, 10)}.csv`, lignes.join('\n'));
  }

  private executer(appel: Observable<unknown>, succes: string): void {
    this.envoi.set(true);
    this.message.set('');
    appel.subscribe({
      next: () => {
        this.envoi.set(false);
        this.echec.set(false);
        this.message.set(succes);
        this.decision.set(null);
        this.motif = '';
        if (this.auth.peut('COMMANDE_AVANCER', 'POINT_RETRAIT_GERER', 'RECEPTION_VALIDER', 'COMMANDE_LIRE')) {
          this.api.convois().pipe(catchError(() => of([] as Convoi[]))).subscribe(c => this.convois.set(c ?? []));
        }
        this.charger();
      },
      error: e => {
        this.envoi.set(false);
        this.echec.set(true);
        this.message.set(messageErreur(e, 'Action impossible.'));
      }
    });
  }
}
