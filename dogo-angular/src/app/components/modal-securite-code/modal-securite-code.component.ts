import { Component, ElementRef, inject, signal, effect } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatIconModule } from '@angular/material/icon';
import { AdminSecuriteService } from '../../core/services/admin-securite.service';
import { messageErreur } from '../../core/api';

/** Groupe de 4 cases auquel appartient un chiffre saisi */
type Cible = 'confirmation' | 'ancien' | 'nouveau' | 'confirmer';

@Component({
  selector: 'app-modal-securite-code',
  standalone: true,
  imports: [CommonModule, FormsModule, MatIconModule],
  templateUrl: './modal-securite-code.component.html',
  styleUrl: './modal-securite-code.component.scss'
})
export class ModalSecuriteCodeComponent {
  readonly securite = inject(AdminSecuriteService);
  private readonly hote = inject<ElementRef<HTMLElement>>(ElementRef);

  // Chiffres saisis pour la confirmation (tableau de 4 caractères)
  chiffresConfirmation: string[] = ['', '', '', ''];

  // Formulaire de configuration
  ancienCode: string[] = ['', '', '', ''];
  // Code oublié : ré-authentification par le mot de passe de connexion
  viaMotDePasse = false;
  motDePasse = '';
  nouveauCode: string[] = ['', '', '', ''];
  confirmationCode: string[] = ['', '', '', ''];

  enCours = signal(false);
  messageErreur = signal('');
  messageSucces = signal('');

  constructor() {
    // Réinitialise les champs à chaque ouverture
    effect(() => {
      if (this.securite.modalOuverte()) {
        this.reinitialiserChamps();
        setTimeout(() => this.focusPremier(), 150);
      }
    });
  }

  reinitialiserChamps(): void {
    this.chiffresConfirmation = ['', '', '', ''];
    this.ancienCode = ['', '', '', ''];
    this.viaMotDePasse = false;
    this.motDePasse = '';
    this.nouveauCode = ['', '', '', ''];
    this.confirmationCode = ['', '', '', ''];
    this.messageErreur.set('');
    this.messageSucces.set('');
    this.enCours.set(false);
  }

  /** Premier champ de la modale : première case, ou mot de passe en mode « code oublié » */
  focusPremier(): void {
    this.hote.nativeElement.querySelector<HTMLInputElement>('.modal-card input')?.focus();
  }

  private tableau(cible: Cible): string[] {
    switch (cible) {
      case 'confirmation': return this.chiffresConfirmation;
      case 'ancien': return this.ancienCode;
      case 'nouveau': return this.nouveauCode;
      default: return this.confirmationCode;
    }
  }

  /** Toutes les cases visibles, dans l'ordre : le focus enchaîne d'un groupe au suivant. */
  private cases(): HTMLInputElement[] {
    return Array.from(this.hote.nativeElement.querySelectorAll<HTMLInputElement>('input.digit-box'));
  }

  private focusCase(depuis: HTMLInputElement, decalage: number): void {
    const cases = this.cases();
    const suivante = cases[cases.indexOf(depuis) + decalage];
    if (suivante) {
      suivante.focus();
      suivante.select();
    }
  }

  // Gestion de la saisie case par case avec focus automatique
  onDigitInput(event: Event, index: number, cible: Cible): void {
    const input = event.target as HTMLInputElement;
    const tableau = this.tableau(cible);
    const chiffres = input.value.replace(/\D/g, '');

    if (!chiffres) {
      tableau[index] = '';
      input.value = '';
      return;
    }

    // Collage (ex : « 1234 ») : répartit les chiffres sur les cases suivantes du groupe
    if ((event as InputEvent).inputType === 'insertFromPaste' && chiffres.length > 1) {
      const colles = chiffres.slice(0, 4 - index);
      for (let i = 0; i < colles.length; i++) tableau[index + i] = colles[i];
      input.value = tableau[index];
      this.focusCase(input, colles.length);
    } else {
      // Frappe : le dernier chiffre tapé remplace le précédent
      tableau[index] = chiffres.slice(-1);
      input.value = tableau[index];
      this.focusCase(input, 1);
    }

    if (cible === 'confirmation' && this.codeConfirmationComplet()) {
      this.validerConfirmation();
    }
  }

  onKeyDown(event: KeyboardEvent, index: number, cible: Cible): void {
    const input = event.target as HTMLInputElement;
    switch (event.key) {
      case 'Backspace': {
        // Case déjà vide : on recule et on efface la case précédente
        if (!this.tableau(cible)[index]) {
          event.preventDefault();
          const cases = this.cases();
          const precedente = cases[cases.indexOf(input) - 1];
          if (precedente) {
            precedente.value = '';
            precedente.dispatchEvent(new Event('input'));
            precedente.focus();
          }
        }
        break;
      }
      case 'ArrowLeft':
        event.preventDefault();
        this.focusCase(input, -1);
        break;
      case 'ArrowRight':
        event.preventDefault();
        this.focusCase(input, 1);
        break;
      case 'Enter':
        if (cible === 'confirmation') {
          this.validerConfirmation();
        } else if (this.codeNouveauComplet()) {
          this.enregistrerConfiguration();
        }
        break;
    }
  }

  codeConfirmationComplet(): boolean {
    return this.chiffresConfirmation.every(c => /^\d$/.test(c));
  }

  codeNouveauComplet(): boolean {
    return this.nouveauCode.every(c => /^\d$/.test(c)) && this.confirmationCode.every(c => /^\d$/.test(c));
  }

  // Valider le code et confirmer l'action
  validerConfirmation(): void {
    if (!this.codeConfirmationComplet() || this.enCours()) return;

    const code = this.chiffresConfirmation.join('');
    this.enCours.set(true);
    this.messageErreur.set('');

    this.securite.verifierCode(code).subscribe({
      next: () => {
        this.enCours.set(false);
        this.securite.validerAction(code);
      },
      error: (err) => {
        this.enCours.set(false);
        this.chiffresConfirmation = ['', '', '', ''];
        this.messageErreur.set(messageErreur(err, 'Code de sécurité à 4 chiffres incorrect.'));
        setTimeout(() => this.focusPremier(), 100);
      }
    });
  }

  // Sauvegarder la configuration du code
  enregistrerConfiguration(): void {
    if (this.enCours()) return;

    const nouveau = this.nouveauCode.join('');
    const confirmation = this.confirmationCode.join('');
    const ancien = this.ancienCode.join('');

    if (nouveau.length !== 4 || confirmation.length !== 4) {
      this.messageErreur.set('Le code doit comporter exactement 4 chiffres.');
      return;
    }

    if (nouveau !== confirmation) {
      this.messageErreur.set('La confirmation ne correspond pas au nouveau code.');
      return;
    }

    if (this.securite.statut()?.configure) {
      if (this.viaMotDePasse && !this.motDePasse) {
        this.messageErreur.set('Veuillez saisir votre mot de passe de connexion.');
        return;
      }
      if (!this.viaMotDePasse && !/^\d{4}$/.test(ancien)) {
        this.messageErreur.set("Veuillez saisir votre ancien code de sécurité à 4 chiffres.");
        return;
      }
    }

    this.enCours.set(true);
    this.messageErreur.set('');

    const ancienEnvoye = this.viaMotDePasse ? undefined : ancien || undefined;
    const motDePasse = this.viaMotDePasse ? this.motDePasse : undefined;
    this.securite.configurerCode(nouveau, ancienEnvoye, motDePasse).subscribe({
      next: () => {
        this.enCours.set(false);
        this.messageSucces.set('Code de sécurité à 4 chiffres enregistré avec succès !');
        setTimeout(() => {
          this.securite.fermerModal();
        }, 1200);
      },
      error: (err) => {
        this.enCours.set(false);
        this.messageErreur.set(messageErreur(err, 'Erreur lors de la configuration du code de sécurité.'));
      }
    });
  }

  basculerMotDePasse(actif: boolean): void {
    this.viaMotDePasse = actif;
    this.ancienCode = ['', '', '', ''];
    this.motDePasse = '';
    this.messageErreur.set('');
    setTimeout(() => this.focusPremier());
  }

  fermer(): void {
    this.securite.fermerModal();
  }
}
