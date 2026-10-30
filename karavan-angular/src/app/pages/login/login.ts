import { ChangeDetectorRef, Component, OnInit, OnDestroy, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatIconModule } from '@angular/material/icon';
import {
  FormBuilder,
  FormGroup,
  ReactiveFormsModule,
  Validators
} from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../core/services/auth.service';
import { messageErreur } from '../../core/api';

declare const google: any;

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, MatIconModule],
  templateUrl: './login.html',
  styleUrl: './login.scss'
})
export class LoginComponent implements OnInit, OnDestroy {
  private readonly fb = inject(FormBuilder);
  private readonly router = inject(Router);
  private readonly authService = inject(AuthService);
  private readonly cdr = inject(ChangeDetectorRef);

  loginForm!: FormGroup;
  completionForm!: FormGroup;
  isLoading = false;
  errorMessage = '';
  afficherMotDePasse = false;

  // État complétion profil Google
  modeGoogleCompletion = false;
  donneesGoogle: {
    jetonInscription: string;
    sub?: string;
    email?: string;
    emailVerified?: boolean;
    nom?: string;
    photoUrl?: string;
  } | null = null;
  otpEnvoye = false;
  secondesRestantes = 60;
  private timerOtp: any = null;

  ngOnInit(): void {
    if (this.authService.obtenirJeton() && this.authService.obtenirProfil()?.type === 'ADMINISTRATEUR') {
      this.ouvrirConsole();
    }

    this.loginForm = this.fb.group({
      telephone: ['', [Validators.required]],
      motDePasse: ['', [Validators.required]]
    });

    this.completionForm = this.fb.group({
      telephone: ['', [Validators.required, Validators.minLength(8)]],
      codeOtp: ['', [Validators.minLength(4)]]
    });

    this.initialiserGoogleGIS();
  }

  /** Tableau de bord, ou d'abord le remplacement du mot de passe provisoire (RG-07b) */
  private ouvrirConsole(): void {
    void this.router.navigate([this.authService.motDePasseProvisoire() ? '/premiere-connexion' : '/admin']);
  }

  ngOnDestroy(): void {
    if (this.timerOtp) {
      clearInterval(this.timerOtp);
    }
  }

  initialiserGoogleGIS(): void {
    try {
      if (typeof google !== 'undefined' && google.accounts?.id) {
        google.accounts.id.initialize({
          client_id: '462534787008-7c48fkvh3n0nu65po72p005qr5qo05ot.apps.googleusercontent.com',
          callback: (response: any) => this.gererReponseGoogle(response.credential),
          auto_select: false,
          cancel_on_tap_outside: true
        });
      }
    } catch {
      // Ignoré si le script Google n'est pas encore prêt
    }
  }

  declencherGoogleSignIn(): void {
    try {
      if (typeof google !== 'undefined' && google.accounts?.id) {
        google.accounts.id.prompt((notification: any) => {
          if (notification.isNotDisplayed() || notification.isSkippedMoment()) {
            this.signalerGoogleIndisponible();
          }
        });
      } else {
        this.signalerGoogleIndisponible();
      }
    } catch {
      this.signalerGoogleIndisponible();
    }
  }

  /** Jamais de connexion simulée : sans fenêtre Google, l'administrateur passe par téléphone + mot de passe */
  private signalerGoogleIndisponible(): void {
    this.errorMessage =
      'La connexion Google est indisponible sur ce navigateur. Utilisez votre numéro de téléphone et votre mot de passe.';
    this.cdr.markForCheck();
  }

  gererReponseGoogle(idToken: string): void {
    this.isLoading = true;
    this.errorMessage = '';
    this.cdr.markForCheck();

    this.authService.authentifierGoogle(idToken).subscribe({
      next: (res) => {
        this.isLoading = false;
        if (res.statut === 'CONNECTE' && res.jeton) {
          if (res.profil?.type !== 'ADMINISTRATEUR') {
            this.authService.deconnecter();
            this.errorMessage =
              'Ce compte est associé au rôle ' + (res.profil?.type || 'COMMERCANT') +
              '. La console web est réservée aux administrateurs Karavan. Veuillez utiliser l’application mobile.';
            this.cdr.markForCheck();
            return;
          }
          this.ouvrirConsole();
        } else if (res.statut === 'PROFIL_INCOMPLET') {
          this.modeGoogleCompletion = true;
          this.donneesGoogle = {
            jetonInscription: res.jetonInscription,
            sub: res.sub,
            email: res.email,
            emailVerified: res.emailVerified,
            nom: res.nom,
            photoUrl: res.photoUrl
          };
          this.cdr.markForCheck();
        } else {
          this.errorMessage = res.message || 'Réponse inattendue lors de la connexion Google.';
          this.cdr.markForCheck();
        }
      },
      error: (err) => {
        this.isLoading = false;
        this.errorMessage = messageErreur(err, "Impossible de s'authentifier avec Google.");
        this.cdr.markForCheck();
      }
    });
  }

  demanderOtpGoogle(): void {
    if (!this.donneesGoogle?.jetonInscription) return;
    const tel = (this.completionForm.get('telephone')?.value || '').trim().replace(/[\s.\-()]/g, '');
    if (tel.length < 8) {
      this.errorMessage = 'Veuillez saisir un numéro de téléphone valide (+223).';
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';
    this.cdr.markForCheck();

    this.authService.demanderOtpGoogle(this.donneesGoogle.jetonInscription, tel).subscribe({
      next: (rep) => {
        this.isLoading = false;
        this.otpEnvoye = true;
        this.demarrerCompteARebours();
        this.cdr.markForCheck();
      },
      error: (err) => {
        this.isLoading = false;
        this.errorMessage = messageErreur(err, "Erreur lors de l'envoi du code SMS.");
        this.cdr.markForCheck();
      }
    });
  }

  demarrerCompteARebours(): void {
    if (this.timerOtp) clearInterval(this.timerOtp);
    this.secondesRestantes = 60;
    this.timerOtp = setInterval(() => {
      if (this.secondesRestantes > 0) {
        this.secondesRestantes--;
        this.cdr.markForCheck();
      } else {
        clearInterval(this.timerOtp);
      }
    }, 1000);
  }

  validerOtpGoogle(): void {
    if (!this.donneesGoogle?.jetonInscription) return;
    const tel = (this.completionForm.get('telephone')?.value || '').trim().replace(/[\s.\-()]/g, '');
    const code = (this.completionForm.get('codeOtp')?.value || '').trim();

    if (!code) {
      this.errorMessage = 'Veuillez entrer le code de vérification reçu par SMS.';
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';
    this.cdr.markForCheck();

    this.authService.completerGoogle(this.donneesGoogle.jetonInscription, tel, code).subscribe({
      next: (rep) => {
        this.isLoading = false;
        if (rep.profil?.type !== 'ADMINISTRATEUR') {
          this.authService.deconnecter();
          this.modeGoogleCompletion = false;
          this.errorMessage =
            'Votre compte a bien été créé avec le rôle ' + (rep.profil?.type || 'COMMERCANT') +
            '. La console web est réservée aux administrateurs. Connectez-vous sur l’application mobile avec ce compte.';
          this.cdr.markForCheck();
          return;
        }
        this.ouvrirConsole();
      },
      error: (err) => {
        this.isLoading = false;
        this.errorMessage = messageErreur(err, 'Code de vérification invalide ou expiré.');
        this.cdr.markForCheck();
      }
    });
  }

  annulerCompletionGoogle(): void {
    this.modeGoogleCompletion = false;
    this.donneesGoogle = null;
    this.otpEnvoye = false;
    this.errorMessage = '';
    if (this.timerOtp) clearInterval(this.timerOtp);
    this.cdr.markForCheck();
  }

  onSubmit(): void {
    if (this.loginForm.invalid || this.isLoading) {
      this.loginForm.markAllAsTouched();
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';

    const { motDePasse } = this.loginForm.getRawValue();
    let telephone = (this.loginForm.getRawValue().telephone || '').trim().replace(/[\s.\-()]/g, '');
    if (/^\d{8}$/.test(telephone)) {
      telephone = '+223' + telephone;
    }

    this.authService.connecter(telephone, motDePasse).subscribe({
      next: (reponse) => {
        this.isLoading = false;
        if (reponse.profil?.type !== 'ADMINISTRATEUR') {
          this.authService.deconnecter();
          this.cdr.markForCheck();
          this.errorMessage =
            'Cet espace est réservé aux administrateurs Karavan. Commerçants, grossistes et courtiers : utilisez l’application mobile.';
          return;
        }
        this.ouvrirConsole();
      },
      error: (erreur) => {
        this.isLoading = false;
        this.cdr.markForCheck();

        if (erreur.status === 0) {
          this.errorMessage =
            'Impossible de joindre le serveur Karavan. Veuillez vérifier votre connexion internet.';
        } else if (erreur.status === 401 || erreur.status === 403) {
          this.errorMessage =
            'Numéro de téléphone ou mot de passe incorrect, ou accès refusé.';
        } else {
          this.errorMessage = messageErreur(erreur, 'Une erreur est survenue lors de la connexion.');
        }
      }
    });
  }
}
