import { Component, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../core/services/auth.service';
import { AdminSecuriteService } from '../../core/services/admin-securite.service';
import { forkJoin, of, Observable } from 'rxjs';
import { catchError } from 'rxjs/operators';
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { LIBELLES_CONVOI, LIBELLES_GROUPE, dateCourte, messageErreur } from '../../core/api';
import {
  AdminApiService,
  Convoi,
  EtapeSignalee,
  Groupe,
  PointRetrait
} from '../../core/services/admin-api.service';

/** Groupe en acheminement, avec son convoi (suivi officiel vu par les commerçants) s'il est ouvert */
export interface Expedition {
  groupe: Groupe;
  convoi: Convoi | null;
}

export interface ActionColis {
  libelle: string;
  executer: () => void;
}

/** États où la marchandise est en chemin : de l'objectif atteint jusqu'au retrait des colis */
const ETATS_ACHEMINEMENT = ['OBJECTIF_ATTEINT', 'EN_EXPEDITION', 'LIVRE'];

/**
 * Corridors & convois : l'administrateur suit chaque groupe en acheminement, reçoit les étapes signalées par les
 * grossistes qui acheminent eux-mêmes, et met à jour le suivi officiel (convoi, réception au dépôt, point de
 * retrait). Chaque mise à jour est notifiée par le backend aux commerçants du groupe, au grossiste et au porteur.
 */
@Component({
  selector: 'app-corridors',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './corridors.html',
  styleUrl: './corridors.scss'
})
export class CorridorsComponent implements OnInit, OnDestroy {
  private readonly api = inject(AdminApiService);
  private readonly securite = inject(AdminSecuriteService);
  readonly peutGererPoints = inject(AuthService).peut('POINT_RETRAIT_GERER');
  nouveauPoint = { nom: '', adresse: '', quartier: '', lienGoogleMap: '' };
  readonly pointEnEdition = signal<PointRetrait | null>(null);
  private minuterie?: ReturnType<typeof setInterval>;

  readonly groupes = signal<Groupe[]>([]);
  readonly convoisListe = signal<Convoi[]>([]);
  readonly points = signal<PointRetrait[]>([]);
  readonly chargement = signal(true);
  readonly erreur = signal('');
  readonly message = signal('');
  readonly envoi = signal(false);

  readonly selectionId = signal<number | null>(null);
  readonly etapes = signal<EtapeSignalee[]>([]);
  readonly commandes = signal<{ statut: string }[]>([]);

  readonly modalGroupesEnAttente = signal(false);
  readonly filtreModal = signal<'TOUS' | 'OBJECTIF_ATTEINT' | 'EN_COURS'>('TOUS');
  readonly rechercheModal = signal('');
  readonly groupeBloquePopup = signal<Groupe | null>(null);

  readonly dateCourte = dateCourte;

  ngOnInit(): void {
    this.charger();
    // Les grossistes signalent leurs étapes à tout moment : la page se relit toutes les 60 s
    this.minuterie = setInterval(() => this.charger(false), 60_000);
  }

  ngOnDestroy(): void {
    clearInterval(this.minuterie);
  }

  charger(afficherChargement = true): void {
    if (afficherChargement) {
      this.chargement.set(true);
    }
    this.erreur.set('');
    forkJoin({
      groupes: this.api.groupes(),
      convois: this.api.convois(),
      points: this.api.pointsRetrait().pipe(catchError(() => of([] as PointRetrait[])))
    }).subscribe({
      next: ({ groupes, convois, points }) => {
        this.groupes.set(groupes ?? []);
        this.convoisListe.set(convois ?? []);
        this.points.set(points ?? []);
        this.chargement.set(false);
        const id = this.selectionId() ?? this.expeditions()[0]?.groupe.id ?? null;
        if (id !== null) {
          this.selectionner(id, false);
        }
      },
      error: e => {
        this.erreur.set(messageErreur(e, 'Impossible de charger les convois.'));
        this.chargement.set(false);
      }
    });
  }

  // ---------------------------------------------------------------- vues calculées

  /** Groupes en acheminement (et ceux dont un convoi est encore ouvert), les plus récents d'abord */
  readonly expeditions = computed<Expedition[]>(() => {
    const parGroupe = new Map(this.convoisListe().map(c => [c.groupeId, c]));
    return this.groupes()
      .filter(g => ETATS_ACHEMINEMENT.includes(g.statut) || (parGroupe.has(g.id) && g.statut !== 'TERMINE'))
      .map(g => ({ groupe: g, convoi: parGroupe.get(g.id) ?? null }));
  });

  readonly selection = computed<Expedition | null>(
    () => this.expeditions().find(e => e.groupe.id === this.selectionId()) ?? null
  );

  readonly convoisActifs = computed(() => this.convoisListe().filter(c => c.statut !== 'ARRIVE').length);

  readonly colisEnTransit = computed(() =>
    this.groupes()
      .filter(g => g.statut === 'EN_EXPEDITION')
      .reduce((total, g) => total + g.quantiteConfirmee, 0)
  );

  /** Axes = pays d'origine des marchandises en chemin, avec leur état (douane = ralenti) */
  readonly corridors = computed(() => {
    const axes = new Map<string, { nombre: number; douane: boolean }>();
    for (const e of this.expeditions()) {
      const pays = e.groupe.produit?.paysOrigine || 'Origine inconnue';
      const axe = axes.get(pays) ?? { nombre: 0, douane: false };
      axe.nombre++;
      axe.douane ||= e.convoi?.statut === 'BLOQUE_DOUANE';
      axes.set(pays, axe);
    }
    return [...axes.entries()].map(([pays, axe]) => ({
      name: `${pays} ➔ Bamako`,
      state: axe.douane ? 'Attente Douane' : `${axe.nombre} groupe${axe.nombre > 1 ? 's' : ''} · Fluide`,
      color: axe.douane ? 'orange' : 'green'
    }));
  });

  reference(e: Expedition): string {
    return e.convoi?.reference ?? `Groupe #${e.groupe.id}`;
  }

  route(e: Expedition): string {
    return `${e.groupe.titre} · ${e.groupe.produit?.paysOrigine || '?'} ➔ Bamako`;
  }

  responsable(e: Expedition): string {
    return e.groupe.porteParGrossiste
      ? `${e.groupe.grossiste.nom} (grossiste, acheminement propre)`
      : e.groupe.courtier?.nom ?? '—';
  }

  statut(e: Expedition): string {
    return e.convoi ? LIBELLES_CONVOI[e.convoi.statut] ?? e.convoi.statut : LIBELLES_GROUPE[e.groupe.statut] ?? e.groupe.statut;
  }

  badge(e: Expedition): string {
    if (e.convoi?.statut === 'BLOQUE_DOUANE') return 'yellow';
    if (e.convoi?.statut === 'ARRIVE' || e.groupe.statut === 'LIVRE') return 'green';
    return 'orange';
  }

  libelleEvenement(statut: string): string {
    return LIBELLES_CONVOI[statut] ?? (statut === 'CREATION_CONVOI' ? 'Suivi ouvert' : statut);
  }

  // ---------------------------------------------------------------- sélection

  selectionner(groupeId: number, effacerMessage = true): void {
    this.selectionId.set(groupeId);
    if (effacerMessage) {
      this.message.set('');
    }
    const e = this.expeditions().find(x => x.groupe.id === groupeId);
    this.etapes.set([]);
    this.commandes.set([]);
    if (!e) {
      return;
    }
    if (e.groupe.porteParGrossiste) {
      this.api.etapesSignalees(groupeId).subscribe({ next: liste => this.etapes.set(liste ?? []), error: () => undefined });
    }
    this.chargerCommandes(groupeId);
  }

  private chargerCommandes(groupeId: number): void {
    this.api
      .commandesDuGroupe(groupeId)
      .subscribe({ next: liste => this.commandes.set(liste ?? []), error: () => this.commandes.set([]) });
  }

  /** Actions possibles selon l'état réel du groupe et de son convoi (mêmes transitions que le backend) */
  readonly actions = computed<ActionColis[]>(() => {
    const e = this.selection();
    if (!e) {
      return [];
    }
    const g = e.groupe;
    const liste: ActionColis[] = [];
    const commandes = this.commandes();
    const toutesPreparees = commandes.length > 0 && commandes.every(c => c.statut === 'PREPAREE');

    // Groupe porté par un grossiste : l'administrateur fait avancer les commandes à sa place
    if (g.porteParGrossiste && g.statut === 'OBJECTIF_ATTEINT') {
      if (!toutesPreparees) {
        liste.push({ libelle: 'Marquer les commandes préparées', executer: () => this.lancer(this.api.preparerCommandes(g.id), 'Commandes préparées.') });
      } else {
        liste.push({ libelle: 'Déclarer l’expédition', executer: () => this.lancer(this.api.expedierCommandes(g.id), 'Expédition déclarée : les commerçants sont prévenus.') });
      }
    }
    if (!e.convoi && ['OBJECTIF_ATTEINT', 'EN_EXPEDITION'].includes(g.statut)) {
      liste.push({ libelle: 'Ouvrir le suivi officiel', executer: () => this.ouvrirSuivi(g) });
    }
    if (e.convoi) {
      const c = e.convoi;
      switch (c.statut) {
        case 'ACHETE':
          liste.push({ libelle: 'Remis au transitaire', executer: () => this.avancer(c, 'transitaire', true) });
          break;
        case 'CHEZ_TRANSITAIRE':
          liste.push({ libelle: 'Lancer le transit', executer: () => this.avancer(c, 'transit', false) });
          break;
        case 'EN_TRANSIT':
          liste.push({ libelle: 'Contrôle douanier', executer: () => this.avancer(c, 'douane', true) });
          liste.push({ libelle: 'Arrivé à destination', executer: () => this.avancer(c, 'arrivee', true) });
          break;
        case 'BLOQUE_DOUANE':
          liste.push({ libelle: 'Sortie de douane', executer: () => this.avancer(c, 'transit', false) });
          break;
      }
      if (this.etapes().length) {
        liste.push({ libelle: 'Publier la dernière étape du grossiste', executer: () => this.publierEtape(c) });
      }
    }
    if (g.statut === 'EN_EXPEDITION') {
      liste.push({ libelle: 'Valider la réception au dépôt', executer: () => this.lancer(this.api.validerReception(g.id), 'Réception validée : commerçants et porteur notifiés.') });
    }
    if (this.estDerniereEtapeDepot() || (g.statut === 'LIVRE' && g.porteParGrossiste) || g.statut === 'EN_EXPEDITION') {
      liste.push({ libelle: 'Notifier l’arrivée au dépôt (avec Google Maps)', executer: () => this.notifierDepotAvecGoogleMap(g) });
    }
    if (g.statut === 'LIVRE' && g.porteParGrossiste) {
      liste.push({ libelle: 'Disponible au point de retrait', executer: () => this.pointRetrait(g) });
    }
    return liste;
  });

  readonly estDerniereEtapeDepot = computed(() => {
    const e = this.selection();
    if (!e) return false;
    const etapes = this.etapes();
    if (!etapes.length) return false;
    const derniere = etapes[etapes.length - 1];
    const nom = (derniere?.etape || '').toLowerCase();
    return nom.includes('dépôt') || nom.includes('depot');
  });

  progression(g: Groupe): number {
    return g.quantiteCible ? Math.min(100, Math.round((g.quantiteConfirmee / g.quantiteCible) * 100)) : 0;
  }

  estEligible(g: Groupe): boolean {
    return this.progression(g) >= 100 || ['OBJECTIF_ATTEINT', 'EN_EXPEDITION', 'LIVRE'].includes(g.statut);
  }

  /** Groupes sans convoi officiel, en attente de déblocage */
  readonly groupesEnAttente = computed(() => {
    const avecConvoi = new Set(this.convoisListe().map(c => c.groupeId));
    const statutActif = ['OUVERT', 'OBJECTIF_ATTEINT', 'EN_EXPEDITION', 'LIVRE'];
    const recherche = this.rechercheModal().trim().toLowerCase();
    const filtre = this.filtreModal();

    return this.groupes()
      .filter(g => !avecConvoi.has(g.id) && statutActif.includes(g.statut))
      .filter(g => {
        const eligible = this.estEligible(g);
        if (filtre === 'OBJECTIF_ATTEINT') return eligible;
        if (filtre === 'EN_COURS') return !eligible;
        return true;
      })
      .filter(g => {
        if (!recherche) return true;
        const texte = `${g.id} ${g.titre} ${g.produit?.nom ?? ''} ${g.produit?.paysOrigine ?? ''} ${g.grossiste?.nom ?? ''} ${g.courtier?.nom ?? ''}`.toLowerCase();
        return texte.includes(recherche);
      });
  });

  nombreGroupesEnAttente(filtre: 'TOUS' | 'OBJECTIF_ATTEINT' | 'EN_COURS'): number {
    const avecConvoi = new Set(this.convoisListe().map(c => c.groupeId));
    const statutActif = ['OUVERT', 'OBJECTIF_ATTEINT', 'EN_EXPEDITION', 'LIVRE'];
    const base = this.groupes().filter(g => !avecConvoi.has(g.id) && statutActif.includes(g.statut));
    if (filtre === 'OBJECTIF_ATTEINT') return base.filter(g => this.estEligible(g)).length;
    if (filtre === 'EN_COURS') return base.filter(g => !this.estEligible(g)).length;
    return base.length;
  }

  // ---------------------------------------------------------------- actions

  ouvrirModalSuivi(): void {
    this.rechercheModal.set('');
    this.filtreModal.set('TOUS');
    this.groupeBloquePopup.set(null);
    this.modalGroupesEnAttente.set(true);
  }

  fermerModalGroupes(): void {
    this.modalGroupesEnAttente.set(false);
  }

  tenterOuvrirSuivi(g: Groupe): void {
    if (!this.estEligible(g)) {
      this.groupeBloquePopup.set(g);
      return;
    }
    this.fermerModalGroupes();
    this.ouvrirSuivi(g);
  }

  fermerPopupBloque(): void {
    this.groupeBloquePopup.set(null);
  }

  ouvrirCouloir(): void {
    this.ouvrirModalSuivi();
  }

  private ouvrirSuivi(g: Groupe): void {
    const transporteur = g.porteParGrossiste
      ? `${g.grossiste.nom} (moyens propres)`
      : g.courtier?.nom ?? 'Karavan Transit';
    const reference = `CNV-${g.id}-${Date.now().toString(36).toUpperCase()}`;
    this.lancer(this.api.creerConvoi(g.id, reference, transporteur),
      `Suivi officiel ${reference} ouvert : les étapes d'acheminement sont débloquées pour ce groupe.`);
    this.selectionner(g.id);
  }

  private avancer(c: Convoi, action: 'transitaire' | 'transit' | 'douane' | 'arrivee', demanderLieu: boolean): void {
    let lieu: string | undefined;
    if (demanderLieu) {
      const saisi = prompt('Localisation (ville, poste frontière, entrepôt…) :', action === 'arrivee' ? 'Bamako' : '');
      if (saisi === null) {
        return;
      }
      lieu = saisi.trim() || undefined;
    }
    this.lancer(this.api.avancerConvoi(c.id, action, lieu), 'Suivi mis à jour : les commerçants du groupe sont notifiés.');
  }

  /** Reprend l'étape signalée par le grossiste dans le suivi officiel vu par les commerçants */
  private publierEtape(c: Convoi): void {
    const derniere = this.etapes()[this.etapes().length - 1];
    if (!derniere) {
      return;
    }
    this.lancer(
      this.api.ajouterEvenementConvoi(c.id, derniere.etape, derniere.commentaire || 'Signalé par le grossiste'),
      `« ${derniere.etape} » publiée dans le suivi des commerçants.`
    );
  }

  private pointRetrait(g: Groupe): void {
    const points = this.points();
    if (!points.length) {
      this.message.set('Aucun point de retrait enregistré.');
      return;
    }
    const choix = prompt(
      `Point de retrait pour le groupe #${g.id} :\n` + points.map((p, i) => `${i + 1}. ${p.nom} (${p.quartier})`).join('\n'),
      '1'
    );
    const point = points[Number(choix) - 1];
    if (!point) {
      return;
    }
    this.lancer(this.api.confirmerPointRetrait(g.id, point.id),
      `Colis disponibles à ${point.nom} : chaque commerçant reçoit son code de retrait.`);
  }

  async notifierDepotAvecGoogleMap(g: Groupe): Promise<void> {
    const points = this.points();
    if (!points.length) {
      this.message.set('Aucun point de retrait enregistré. Créez d’abord un point avec son lien Google Maps.');
      return;
    }
    const apercu = points
      .map((p, i) => `${i + 1}. ${p.nom} (${p.quartier || 'Bamako'})\n   Adresse : ${p.adresse}\n   Google Maps : ${p.lienGoogleMap || 'Non renseigné'}`)
      .join('\n\n');

    const choix = prompt(
      `Sélectionnez le dépôt de récupération du colis pour le groupe #${g.id} (${g.titre}) :\n\n` +
      apercu +
      `\n\nEntrez le numéro du dépôt (1 à ${points.length}) :`,
      '1'
    );
    if (choix === null) return;
    const point = points[Number(choix) - 1];
    if (!point) {
      alert('Numéro de dépôt invalide.');
      return;
    }

    let lien = point.lienGoogleMap;
    if (!lien) {
      const saisie = prompt(
        `Le dépôt « ${point.nom} » n'a pas encore de lien Google Maps.\n` +
        `Indiquez le lien Google Maps pour guider les commerçants :`,
        'https://maps.google.com/?q=12.6174,-7.9942'
      );
      if (saisie !== null && saisie.trim()) {
        lien = saisie.trim();
        this.api.modifierPointRetrait(point.id, point.nom, point.adresse, point.quartier || '', lien)
          .subscribe(() => this.charger(false));
      }
    }

    try {
      await this.securite.demanderConfirmation({
        titre: "Notification d'arrivée au dépôt",
        description: `Envoi groupé de la notification d'arrivée au dépôt « ${point.nom} » (avec géolocalisation GPS) aux commerçants du groupe #${g.id}.`,
        actionTexte: 'Envoyer la notification',
        icone: 'notifications_active'
      });
      this.lancer(
        this.api.notifierArriveeDepot(g.id, point.id),
        `Notification envoyée aux commerçants avec la localisation Google Maps de « ${point.nom} » !`
      );
    } catch {
      // Annulé
    }
  }

  editerPoint(p: PointRetrait): void {
    this.pointEnEdition.set(p);
    this.nouveauPoint = {
      nom: p.nom,
      adresse: p.adresse,
      quartier: p.quartier || '',
      lienGoogleMap: p.lienGoogleMap || ''
    };
  }

  annulerEdition(): void {
    this.pointEnEdition.set(null);
    this.nouveauPoint = { nom: '', adresse: '', quartier: '', lienGoogleMap: '' };
  }

  creerPoint(): void {
    this.sauvegarderPoint();
  }

  sauvegarderPoint(): void {
    const p = this.nouveauPoint;
    const enEdition = this.pointEnEdition();
    if (enEdition) {
      this.lancer(
        this.api.modifierPointRetrait(enEdition.id, p.nom.trim(), p.adresse.trim(), p.quartier.trim(), p.lienGoogleMap.trim()),
        `Point de retrait « ${p.nom.trim()} » mis à jour avec son lien Google Maps.`
      );
      this.annulerEdition();
    } else {
      this.lancer(
        this.api.creerPointRetrait(p.nom.trim(), p.adresse.trim(), p.quartier.trim(), p.lienGoogleMap.trim()),
        `Point de retrait « ${p.nom.trim()} » ajouté avec son lien Google Maps.`
      );
      this.nouveauPoint = { nom: '', adresse: '', quartier: '', lienGoogleMap: '' };
    }
  }

  private lancer(appel: Observable<unknown>, succes: string): void {
    this.envoi.set(true);
    this.message.set('');
    appel.subscribe({
      next: () => {
        this.envoi.set(false);
        this.message.set(succes);
        this.charger(false);
      },
      error: e => {
        this.envoi.set(false);
        this.message.set(messageErreur(e, 'Action impossible.'));
      }
    });
  }

  /** Manifeste du groupe sélectionné : commandes, étapes du grossiste et suivi officiel */
  genererManifeste(): void {
    const e = this.selection();
    if (!e) {
      this.message.set('Sélectionnez un convoi pour générer son manifeste.');
      return;
    }
    const pdf = new jsPDF();
    pdf.setFontSize(16);
    pdf.text(`Karavan - Manifeste ${this.reference(e)}`, 14, 18);
    pdf.setFontSize(10);
    pdf.text(`Groupe #${e.groupe.id} : ${e.groupe.titre}`, 14, 27);
    pdf.text(`Produit : ${e.groupe.produit?.nom ?? ''} · Origine : ${e.groupe.produit?.paysOrigine ?? ''}`, 14, 33);
    pdf.text(`Responsable : ${this.responsable(e)}`, 14, 39);
    pdf.text(`Quantite confirmee : ${e.groupe.quantiteConfirmee} pcs · Etat : ${this.statut(e)}`, 14, 45);
    autoTable(pdf, {
      startY: 52,
      head: [['Date', 'Etape', 'Lieu / precision', 'Source']],
      body: [
        ...this.etapes().map(x => [dateCourte(x.date), x.etape, x.commentaire ?? '', 'Grossiste']),
        ...(e.convoi?.evenements ?? []).map(x => [dateCourte(x.date), this.libelleEvenement(x.statut), x.localisation, 'Suivi Karavan'])
      ],
      styles: { fontSize: 8 },
      headStyles: { fillColor: [45, 55, 72] }
    });
    pdf.save(`manifeste-${this.reference(e)}.pdf`);
  }
}
