import { Component, ElementRef, OnDestroy, OnInit, ViewChild, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { Observable, forkJoin, of } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import jsQR from 'jsqr';
import { dateCourte, fcfa, messageErreur } from '../../core/api';
import { AdminApiService, CommandeGroupe, Groupe } from '../../core/services/admin-api.service';
import { AuthService } from '../../core/services/auth.service';

type Mode = 'CAMERA' | 'LECTEUR' | 'PIN';

/** Commande prête à être retirée au point de retrait, avec son groupe */
export interface CommandePrete extends CommandeGroupe {
  groupe: Groupe;
}

/** Retrait validé pendant la séance (RetraitVue du backend) */
export interface RetraitValide {
  commandeId: number;
  statut: string;
  date: string;
  mode: string;
}

/**
 * Retraits au dépôt (RG-53 à RG-55) : l'administrateur valide la remise d'une commande en scannant le QR code du
 * commerçant (caméra de l'ordinateur ou lecteur USB, qui « tape » le code), ou avec le numéro de commande et le PIN
 * reçu par SMS. À la validation, le backend libère le séquestre et notifie le commerçant.
 */
@Component({
  selector: 'app-retraits',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './retraits.html',
  styleUrl: './retraits.scss'
})
export class RetraitsComponent implements OnInit, OnDestroy {
  private readonly api = inject(AdminApiService);
  readonly auth = inject(AuthService);

  @ViewChild('video') video?: ElementRef<HTMLVideoElement>;
  @ViewChild('canvas') canvas?: ElementRef<HTMLCanvasElement>;

  readonly mode = signal<Mode>('CAMERA');
  readonly cameraActive = signal(false);
  readonly envoi = signal(false);
  readonly message = signal('');
  readonly echec = signal(false);
  readonly prete = signal<CommandePrete[]>([]);
  readonly chargement = signal(true);
  readonly historique = signal<RetraitValide[]>([]);

  codeLecteur = '';
  commandeId: number | null = null;
  pin = '';

  readonly fcfa = fcfa;
  readonly dateCourte = dateCourte;

  private flux?: MediaStream;
  private boucle?: number;

  readonly enAttente = computed(() => this.prete().length);

  ngOnInit(): void {
    this.chargerCommandes();
  }

  ngOnDestroy(): void {
    this.arreterCamera();
  }

  /** Commandes EN_ATTENTE_RETRAIT des groupes livrés (la liste aide à saisir le n° de commande) */
  chargerCommandes(): void {
    this.chargement.set(true);
    this.api
      .groupes()
      .pipe(catchError(() => of([] as Groupe[])))
      .subscribe(groupes => {
        const livres = (groupes ?? []).filter(g => g.statut === 'LIVRE');
        const appels: Observable<CommandePrete[]>[] = livres.map(g =>
          this.api.commandesDuGroupe(g.id).pipe(
            map(liste => (liste ?? []).filter(c => c.statut === 'EN_ATTENTE_RETRAIT').map(c => ({ ...c, groupe: g }))),
            catchError(() => of([] as CommandePrete[]))
          )
        );
        (appels.length ? forkJoin(appels) : of([] as CommandePrete[][])).subscribe(listes => {
          this.prete.set(listes.flat());
          this.chargement.set(false);
        });
      });
  }

  changerMode(mode: Mode): void {
    this.mode.set(mode);
    this.message.set('');
    if (mode !== 'CAMERA') {
      this.arreterCamera();
    }
  }

  // ---------------------------------------------------------------- caméra

  async demarrerCamera(): Promise<void> {
    this.message.set('');
    if (!navigator.mediaDevices?.getUserMedia) {
      this.afficher('Ce navigateur ne donne pas accès à la caméra. Utilisez un lecteur de QR code ou le PIN.', true);
      return;
    }
    try {
      this.flux = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' }, audio: false });
    } catch {
      this.afficher('Caméra refusée ou absente : autorisez-la dans le navigateur, ou utilisez le lecteur / le PIN.', true);
      return;
    }
    this.cameraActive.set(true);
    // La balise <video> n'existe qu'une fois la caméra active : on attend le rendu
    setTimeout(() => {
      const video = this.video?.nativeElement;
      if (!video || !this.flux) return;
      video.srcObject = this.flux;
      void video.play();
      this.analyser();
    });
  }

  arreterCamera(): void {
    if (this.boucle) cancelAnimationFrame(this.boucle);
    this.boucle = undefined;
    this.flux?.getTracks().forEach(t => t.stop());
    this.flux = undefined;
    this.cameraActive.set(false);
  }

  /** Lit chaque image de la caméra jusqu'à trouver un QR code */
  private analyser(): void {
    const video = this.video?.nativeElement;
    const canvas = this.canvas?.nativeElement;
    if (!video || !canvas || !this.flux) return;
    if (video.readyState === video.HAVE_ENOUGH_DATA && video.videoWidth) {
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      const ctx = canvas.getContext('2d', { willReadFrequently: true });
      if (ctx) {
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
        const image = ctx.getImageData(0, 0, canvas.width, canvas.height);
        const qr = jsQR(image.data, image.width, image.height, { inversionAttempts: 'attemptBoth' });
        if (qr?.data) {
          this.arreterCamera();
          this.validerJeton(qr.data);
          return;
        }
      }
    }
    this.boucle = requestAnimationFrame(() => this.analyser());
  }

  // ---------------------------------------------------------------- validation

  private extraireJeton(texte: string): string {
    let t = (texte ?? '').trim();
    if (t.includes('/')) {
      t = t.substring(t.lastIndexOf('/') + 1).trim();
    }
    if (t.includes(':')) {
      t = t.substring(t.lastIndexOf(':') + 1).trim();
    }
    return t;
  }

  validerLecteur(): void {
    const code = this.extraireJeton(this.codeLecteur);
    if (code) {
      this.validerJeton(code);
      this.codeLecteur = '';
    }
  }

  private validerJeton(jeton: string): void {
    const clean = this.extraireJeton(jeton);
    if (!clean) return;
    this.valider(this.api.validerRetrait({ qrToken: clean }) as Observable<RetraitValide>);
  }

  validerPin(): void {
    if (!this.commandeId || !this.pin.trim()) return;
    const cleanPin = this.pin.replace(/\s+/g, '').trim();
    if (cleanPin.length !== 6) {
      this.afficher('Le code PIN doit comporter exactement 6 chiffres (reçu par SMS).', true);
      return;
    }
    this.valider(this.api.validerRetrait({ commandeId: this.commandeId, pin: cleanPin }) as Observable<RetraitValide>);
  }

  choisir(c: CommandePrete): void {
    this.changerMode('PIN');
    this.commandeId = c.id;
    this.pin = '';
  }

  /** RG-54 : code perdu ou bloqué → nouveau code envoyé par SMS au commerçant */
  regenerer(c: CommandePrete): void {
    if (!confirm(`Envoyer un nouveau code de retrait au commerçant de la commande #${c.id} ? L'ancien ne fonctionnera plus.`)) return;
    this.envoi.set(true);
    this.api.regenererCodeRetrait(c.id).subscribe({
      next: () => {
        this.envoi.set(false);
        this.afficher(`Nouveau code envoyé par SMS pour la commande #${c.id}.`, false);
      },
      error: e => {
        this.envoi.set(false);
        this.afficher(messageErreur(e, 'Régénération impossible.'), true);
      }
    });
  }

  private valider(appel: Observable<RetraitValide>): void {
    this.envoi.set(true);
    this.message.set('');
    appel.subscribe({
      next: r => {
        this.envoi.set(false);
        this.historique.update(h => [r, ...h]);
        const c = this.prete().find(x => x.id === r.commandeId);
        this.afficher(
          `Retrait validé : commande #${r.commandeId}${c ? ` (${c.quantite} × ${c.groupe.produit?.nom}, ${c.commercantNom ?? 'commerçant'})` : ''}. ` +
            'Le séquestre est libéré et le commerçant est notifié.',
          false
        );
        this.commandeId = null;
        this.pin = '';
        this.chargerCommandes();
      },
      error: e => {
        this.envoi.set(false);
        this.afficher(messageErreur(e, 'Retrait refusé.'), true);
      }
    });
  }

  private afficher(texte: string, erreur: boolean): void {
    this.echec.set(erreur);
    this.message.set(texte);
  }
}
