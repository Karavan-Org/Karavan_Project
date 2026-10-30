import { Component, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { DomSanitizer, SafeResourceUrl } from '@angular/platform-browser';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { MatIconModule } from '@angular/material/icon';
import { forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { dateCourte, dateRelative, messageErreur } from '../../core/api';
import { AdminSecuriteService } from '../../core/services/admin-securite.service';
import {
  AdminApiService,
  Courtier,
  DocumentKyc,
  DossierKyc,
  Grossiste
} from '../../core/services/admin-api.service';

/** RG-04 : pièces exigées selon le type d'acteur (TypeDocument.obligatoiresPour côté backend) */
const PIECES_OBLIGATOIRES: Record<string, string[]> = {
  GROSSISTE: ['PIECE_IDENTITE', 'NIF', 'REGISTRE_COMMERCE'],
  COURTIER: ['PIECE_IDENTITE', 'LICENCE_TRANSIT']
};

const LIBELLES_PIECES: Record<string, string> = {
  PIECE_IDENTITE: 'Pièce d’identité (CNI / NINA)',
  NIF: 'NIF Fiscal DGI',
  REGISTRE_COMMERCE: 'Registre du commerce (RCCM)',
  LICENCE_TRANSIT: 'Licence / agrément de transit',
  RELEVE_BANCAIRE: 'Relevé bancaire',
  AUTRE: 'Autre document'
};

export interface ControleKyc {
  titre: string;
  detail: string;
  ok: boolean;
}

/**
 * Validation des dossiers KYC des grossistes et courtiers (RG-04, RG-05) : mêmes règles que l'inscription mobile.
 * Seul un administrateur du rôle VALIDATION peut décider ; le backend notifie l'acteur et active son compte.
 */
@Component({
  selector: 'app-kyc-validation',
  standalone: true,
  imports: [CommonModule, MatIconModule, RouterLink],
  templateUrl: './kyc-validation.html',
  styleUrl: './kyc-validation.scss'
})
export class KycValidationComponent implements OnInit, OnDestroy {
  private readonly api = inject(AdminApiService);
  private readonly sanitizer = inject(DomSanitizer);
  private readonly route = inject(ActivatedRoute);
  private readonly securite = inject(AdminSecuriteService);

  readonly dossiers = signal<DossierKyc[]>([]);
  readonly selection = signal<DossierKyc | null>(null);
  readonly documentActif = signal<DocumentKyc | null>(null);
  readonly chargement = signal(true);
  readonly erreur = signal('');
  readonly message = signal('');
  readonly envoi = signal(false);
  readonly zoom = signal(100);

  // Aperçu du document : image, PDF ou texte dans un cadre ; Word, Excel… proposés au téléchargement
  readonly apercuUrl = signal<SafeResourceUrl | null>(null);
  readonly apercuImage = signal(false);
  readonly telechargement = signal<{ url: string; nom: string } | null>(null);
  readonly apercuChargement = signal(false);
  readonly apercuErreur = signal('');
  private urlBlob: string | null = null;

  // Fiches entreprise (NIF, RCCM, licence…) des grossistes et courtiers, par identifiant utilisateur
  private readonly grossistes = signal(new Map<number, Grossiste>());
  private readonly courtiers = signal(new Map<number, Courtier>());

  readonly relatif = dateRelative;
  readonly dateCourte = dateCourte;

  ngOnInit(): void {
    this.charger();
  }

  ngOnDestroy(): void {
    this.libererApercu();
  }

  charger(): void {
    this.chargement.set(true);
    this.erreur.set('');
    forkJoin({
      dossiers: this.api.dossiersKyc(),
      grossistes: this.api.grossistes().pipe(catchError(() => of([] as Grossiste[]))),
      courtiers: this.api.courtiers().pipe(catchError(() => of([] as Courtier[])))
    }).subscribe({
      next: ({ dossiers, grossistes, courtiers }) => {
        this.grossistes.set(new Map(grossistes.map(g => [g.id, g])));
        this.courtiers.set(new Map(courtiers.map(c => [c.id, c])));
        this.dossiers.set(dossiers ?? []);
        const actuel = this.selection();
        // Ouvert depuis la fiche d'un acteur (?utilisateur=) : son dossier est sélectionné d'emblée
        const demande = Number(this.route.snapshot.queryParamMap.get('utilisateur'));
        const suivant =
          dossiers.find(d => d.id === actuel?.id) ?? dossiers.find(d => d.utilisateurId === demande) ?? dossiers[0] ?? null;
        this.chargement.set(false);
        this.selectDossier(suivant);
      },
      error: e => {
        this.erreur.set(messageErreur(e, 'Impossible de charger les dossiers KYC.'));
        this.chargement.set(false);
      }
    });
  }

  selectDossier(dossier: DossierKyc | null): void {
    this.selection.set(dossier);
    this.message.set('');
    this.zoom.set(100);
    this.selectDoc(dossier?.documents?.[0] ?? null);
  }

  selectDoc(doc: DocumentKyc | null): void {
    this.documentActif.set(doc);
    this.libererApercu();
    const dossier = this.selection();
    if (!doc || !dossier) {
      return;
    }
    this.apercuChargement.set(true);
    this.apercuErreur.set('');
    this.api.documentKyc(dossier.id, doc.id).subscribe({
      next: blob => {
        this.urlBlob = URL.createObjectURL(blob);
        if (blob.type.startsWith('image/') || blob.type.startsWith('text/') || blob.type === 'application/pdf') {
          this.apercuImage.set(blob.type.startsWith('image/'));
          this.apercuUrl.set(this.sanitizer.bypassSecurityTrustResourceUrl(this.urlBlob));
        } else {
          this.telechargement.set({ url: this.urlBlob, nom: doc.type.toLowerCase() + extensionDocument(blob.type) });
        }
        this.apercuChargement.set(false);
      },
      error: e => {
        this.apercuErreur.set(messageErreur(e, 'Document illisible.'));
        this.apercuChargement.set(false);
      }
    });
  }

  zoomer(pas: number): void {
    this.zoom.update(z => Math.min(200, Math.max(50, z + pas)));
  }

  private libererApercu(): void {
    if (this.urlBlob) {
      URL.revokeObjectURL(this.urlBlob);
      this.urlBlob = null;
    }
    this.apercuUrl.set(null);
    this.telechargement.set(null);
  }

  // ---------------------------------------------------------------- présentation

  /** Nom de l'entreprise déclaré à l'inscription (à défaut, le nom du gérant) */
  entreprise(d: DossierKyc): string {
    return (
      (d.typeActeur === 'GROSSISTE'
        ? this.grossistes().get(d.utilisateurId)?.nomBoutiqueMarche
        : this.courtiers().get(d.utilisateurId)?.nomSocieteImport) || d.nom
    );
  }

  identifiantFiscal(d: DossierKyc): string {
    if (d.typeActeur === 'GROSSISTE') {
      const g = this.grossistes().get(d.utilisateurId);
      return [g?.numeroNif && `NIF : ${g.numeroNif}`, g?.registreCommerce && `RCCM : ${g.registreCommerce}`]
        .filter(Boolean)
        .join(' · ') || 'NIF non déclaré';
    }
    const c = this.courtiers().get(d.utilisateurId);
    return c?.licenceTransit ? `Licence : ${c.licenceTransit}` : 'Licence non déclarée';
  }

  domiciliation(d: DossierKyc): string {
    return d.typeActeur === 'COURTIER'
      ? this.courtiers().get(d.utilisateurId)?.adresseDepot || 'Non renseignée'
      : this.grossistes().get(d.utilisateurId)?.nomBoutiqueMarche || 'Non renseignée';
  }

  initiales(d: DossierKyc): string {
    return this.entreprise(d)
      .trim()
      .split(/\s+/)
      .map(m => m[0])
      .slice(0, 2)
      .join('')
      .toUpperCase();
  }

  libellePiece(type: string): string {
    return LIBELLES_PIECES[type] ?? type.replace(/_/g, ' ');
  }

  resumePieces(d: DossierKyc): string {
    const n = d.documents?.length ?? 0;
    return `${n} pièce${n > 1 ? 's' : ''} : ${(d.documents ?? []).map(x => this.libellePiece(x.type)).join(', ') || 'aucune'}`;
  }

  lienWhatsApp(d: DossierKyc): string {
    return `https://wa.me/${d.telephone.replace(/[^0-9]/g, '')}`;
  }

  /** Points de contrôle calculés à partir du dossier réel (pièces RG-04, empreintes, identité déclarée) */
  readonly controles = computed<ControleKyc[]>(() => {
    const d = this.selection();
    if (!d) {
      return [];
    }
    const fournies = new Set((d.documents ?? []).map(x => x.type));
    const manquantes = (PIECES_OBLIGATOIRES[d.typeActeur] ?? []).filter(t => !fournies.has(t));
    const fiche = d.typeActeur === 'GROSSISTE' ? this.grossistes().get(d.utilisateurId) : this.courtiers().get(d.utilisateurId);
    const empreintes = (d.documents ?? []).every(x => !!x.empreinteSha256);
    return [
      {
        titre: 'Pièces obligatoires (RG-04)',
        detail: manquantes.length ? `Manquant : ${manquantes.map(t => this.libellePiece(t)).join(', ')}` : 'Toutes les pièces sont fournies',
        ok: manquantes.length === 0
      },
      {
        titre: 'Intégrité des fichiers',
        detail: empreintes ? 'Empreinte SHA-256 enregistrée pour chaque pièce' : 'Empreinte absente sur une pièce',
        ok: empreintes
      },
      {
        titre: 'Fiche entreprise',
        detail: fiche ? this.identifiantFiscal(d) : 'Fiche introuvable pour ce compte',
        ok: !!fiche
      }
    ];
  });

  readonly dossierComplet = computed(() => this.controles().every(c => c.ok));

  // ---------------------------------------------------------------- décisions

  async valider(): Promise<void> {
    const d = this.selection();
    if (!d || this.envoi()) {
      return;
    }
    if (!this.dossierComplet() && !confirm('Des contrôles ne sont pas satisfaits. Valider quand même ce dossier ?')) {
      return;
    }
    try {
      await this.securite.demanderConfirmation({
        titre: 'Validation de Dossier KYC',
        description: `Validation et approbation du dossier KYC de « ${this.entreprise(d)} ». Son compte sera activé.`,
        actionTexte: 'Valider le dossier',
        icone: 'verified_user'
      });
      this.decider(d, 'APPROUVE', 'Dossier conforme', `Dossier approuvé : ${this.entreprise(d)} est activé et notifié.`);
    } catch {
      // Annulé
    }
  }

  demanderComplement(): void {
    const d = this.selection();
    if (!d || this.envoi()) {
      return;
    }
    const fournies = new Set((d.documents ?? []).map(x => x.type));
    const manquantes = (PIECES_OBLIGATOIRES[d.typeActeur] ?? []).filter(t => !fournies.has(t)).map(t => this.libellePiece(t));
    const piece = prompt('Document complémentaire à demander :', manquantes.join(', ') || '');
    if (!piece?.trim()) {
      return;
    }
    // Le backend n'a pas d'état « incomplet » : le dossier est rejeté avec un motif, l'acteur renvoie son dossier
    this.decider(d, 'REJETE', `Document complémentaire demandé : ${piece.trim()}`,
      `Demande envoyée à ${this.entreprise(d)} : il complétera son dossier depuis l'application.`);
  }

  async rejeter(): Promise<void> {
    const d = this.selection();
    if (!d || this.envoi()) {
      return;
    }
    const motif = prompt('Motif du rejet (envoyé à l’acteur) :');
    if (!motif?.trim()) {
      return;
    }
    try {
      await this.securite.demanderConfirmation({
        titre: 'Rejet de Dossier KYC',
        description: `Rejet du dossier KYC de « ${this.entreprise(d)} » pour le motif : « ${motif.trim()} ».`,
        actionTexte: 'Rejeter le dossier',
        icone: 'cancel',
        danger: true
      });
      this.decider(d, 'REJETE', motif.trim(), `Dossier rejeté : ${this.entreprise(d)} est notifié du motif.`);
    } catch {
      // Annulé
    }
  }

  private decider(d: DossierKyc, decision: 'APPROUVE' | 'REJETE', commentaire: string, succes: string): void {
    this.envoi.set(true);
    this.message.set('');
    this.api.deciderKyc(d.id, decision, commentaire).subscribe({
      next: () => {
        this.envoi.set(false);
        this.dossiers.update(liste => liste.filter(x => x.id !== d.id));
        this.selectDossier(this.dossiers()[0] ?? null);
        this.message.set(succes);
      },
      error: e => {
        this.envoi.set(false);
        this.message.set(messageErreur(e, 'Décision impossible.'));
      }
    });
  }
}

/** Extension du fichier téléchargé, d'après le type renvoyé par le backend */
function extensionDocument(type: string): string {
  const extensions: Record<string, string> = {
    'application/msword': '.doc',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': '.docx',
    'application/vnd.ms-excel': '.xls',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': '.xlsx',
    'application/vnd.oasis.opendocument.text': '.odt',
    'application/vnd.oasis.opendocument.spreadsheet': '.ods',
    'application/rtf': '.rtf'
  };
  return extensions[type.split(';')[0]] ?? '';
}
