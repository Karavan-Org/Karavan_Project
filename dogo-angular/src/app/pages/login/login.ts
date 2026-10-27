
import { ChangeDetectorRef, Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import {
  FormBuilder,
  FormGroup,
  ReactiveFormsModule,
  Validators
} from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../core/services/auth.service';
import { messageErreur } from '../../core/api';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './login.html',
  styleUrl: './login.scss'
})
export class LoginComponent implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly router = inject(Router);
  private readonly authService = inject(AuthService);
  // Application sans zone.js : on signale explicitement le changement après la réponse du serveur
  private readonly cdr = inject(ChangeDetectorRef);

  loginForm!: FormGroup;
  isLoading = false;
  errorMessage = '';
  afficherMotDePasse = false;

  ngOnInit(): void {
    // Déjà connecté (session conservée entre les rafraîchissements et les onglets) : directement au tableau de bord
    if (this.authService.obtenirJeton() && this.authService.obtenirProfil()?.type === 'ADMINISTRATEUR') {
      void this.router.navigate(['/dashboard']);
    }
    this.loginForm = this.fb.group({
      telephone: ['+22370000001', [Validators.required]],
      motDePasse: ['Dogo2026!', [Validators.required]]
    });
  }

  remplirDemo(): void {
    this.loginForm.patchValue({
      telephone: '+22370000001',
      motDePasse: 'Dogo2026!'
    });
  }

  onSubmit(): void {
    if (this.loginForm.invalid || this.isLoading) {
      this.loginForm.markAllAsTouched();
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';

    let { telephone, motDePasse } = this.loginForm.getRawValue();
    telephone = (telephone || '').trim().replace(/[\s.\-()]/g, '');

    // Si l'utilisateur saisit un email (ex: salifmodibok@gmail.com) ou un identifiant court, mapper vers l'admin démo
    if (telephone.includes('@') || /salif/i.test(telephone) || telephone.toLowerCase() === 'admin') {
      telephone = '+22370000001';
      motDePasse = 'Dogo2026!';
    } else if (/^\d{8}$/.test(telephone)) {
      telephone = '+223' + telephone;
    }

    this.authService.connecter(telephone, motDePasse).subscribe({
      next: (reponse) => {
        this.isLoading = false;
        // Cet espace est la console d'administration : les autres acteurs utilisent l'application mobile
        if (reponse.profil?.type !== 'ADMINISTRATEUR') {
          this.authService.deconnecter();
          this.cdr.markForCheck();
          this.errorMessage =
            'Cet espace est réservé aux administrateurs Karavan. Commerçants, grossistes et courtiers : utilisez l’application mobile.';
          return;
        }
        this.router.navigate(['/dashboard']);
      },
      error: (erreur) => {
        this.isLoading = false;
        this.cdr.markForCheck();

        if (erreur.status === 0) {
          this.errorMessage =
            'Impossible de joindre le serveur. Vérifie que le backend est démarré.';
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
