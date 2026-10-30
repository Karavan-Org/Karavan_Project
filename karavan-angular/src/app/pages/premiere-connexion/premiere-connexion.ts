import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../core/services/auth.service';
import { messageErreur } from '../../core/api';

/** Règle RG-07 du backend, vérifiée ici pour guider la saisie (le serveur reste seul juge). */
const MOT_DE_PASSE_ROBUSTE = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,64}$/;

/**
 * RG-07b : première connexion d'un administrateur dont le mot de passe a été fixé par un tiers (1234 pour
 * l'administrateur principal, mot de passe provisoire pour les autres). Tant qu'il n'est pas remplacé, le backend
 * refuse toute autre action ; cette page est donc la seule accessible.
 */
@Component({
  selector: 'app-premiere-connexion',
  standalone: true,
  imports: [CommonModule, FormsModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './premiere-connexion.html',
  styleUrls: ['../login/login.scss', './premiere-connexion.scss']
})
export class PremiereConnexionComponent {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);

  readonly nom = this.auth.obtenirProfil()?.nom ?? '';

  ancien = '';
  nouveau = '';
  confirmation = '';
  afficher = false;

  readonly enCours = signal(false);
  readonly erreur = signal('');

  get robuste(): boolean {
    return MOT_DE_PASSE_ROBUSTE.test(this.nouveau);
  }

  valider(): void {
    if (this.enCours()) return;
    if (!this.ancien) {
      this.erreur.set('Saisissez le mot de passe provisoire qui vous a été communiqué.');
      return;
    }
    if (!this.robuste) {
      this.erreur.set('Le mot de passe doit comporter 8 à 64 caractères, avec une majuscule, une minuscule et un chiffre.');
      return;
    }
    if (this.nouveau === this.ancien) {
      this.erreur.set('Le nouveau mot de passe doit être différent du mot de passe provisoire.');
      return;
    }
    if (this.nouveau !== this.confirmation) {
      this.erreur.set('La confirmation ne correspond pas au nouveau mot de passe.');
      return;
    }

    this.enCours.set(true);
    this.erreur.set('');
    this.auth.remplacerMotDePasseProvisoire(this.ancien, this.nouveau).subscribe({
      next: () => void this.router.navigate(['/admin']),
      error: err => {
        this.enCours.set(false);
        this.erreur.set(messageErreur(err, 'Impossible de changer le mot de passe.'));
      }
    });
  }

  seDeconnecter(): void {
    this.auth.fermerSession();
    void this.router.navigate(['/login']);
  }
}
