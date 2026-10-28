import { Component, ElementRef, ViewChildren, QueryList, inject, signal, effect } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AdminSecuriteService } from '../../core/services/admin-securite.service';
import { messageErreur } from '../../core/api';

@Component({
  selector: 'app-modal-securite-code',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './modal-securite-code.component.html',
  styleUrl: './modal-securite-code.component.scss'
})
export class ModalSecuriteCodeComponent {
  readonly securite = inject(AdminSecuriteService);

  @ViewChildren('digitInput') digitInputs!: QueryList<ElementRef<HTMLInputElement>>;

  // Chiffres saisis pour la confirmation (tableau de 4 caractères)
  chiffresConfirmation: string[] = ['', '', '', ''];

  // Formulaire de configuration
  ancienCode = '';
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
    this.ancienCode = '';
    this.nouveauCode = ['', '', '', ''];
    this.confirmationCode = ['', '', '', ''];
    this.messageErreur.set('');
    this.messageSucces.set('');
    this.enCours.set(false);
  }

  focusPremier(): void {
    if (this.digitInputs && this.digitInputs.first) {
      this.digitInputs.first.nativeElement.focus();
    }
  }

  // Gestion de la saisie case par case avec focus automatique
  onDigitInput(event: any, index: number, cible: 'confirmation' | 'nouveau' | 'confirmer'): void {
    const input = event.target as HTMLInputElement;
    const valeur = input.value;

    // Gestion du collage (ex: coller '1234')
    if (valeur.length > 1) {
      const nettoye = valeur.replace(/\D/g, '').slice(0, 4);
      for (let i = 0; i < nettoye.length; i++) {
        if (cible === 'confirmation') this.chiffresConfirmation[i] = nettoye[i];
        else if (cible === 'nouveau') this.nouveauCode[i] = nettoye[i];
        else if (cible === 'confirmer') this.confirmationCode[i] = nettoye[i];
      }
      return;
    }

    if (/^\d$/.test(valeur)) {
      if (cible === 'confirmation') this.chiffresConfirmation[index] = valeur;
      else if (cible === 'nouveau') this.nouveauCode[index] = valeur;
      else if (cible === 'confirmer') this.confirmationCode[index] = valeur;

      // Saut automatique vers la case suivante
      if (index < 3) {
        const inputsArray = this.digitInputs.toArray();
        inputsArray[index + 1]?.nativeElement.focus();
      }
    } else {
      input.value = '';
      if (cible === 'confirmation') this.chiffresConfirmation[index] = '';
      else if (cible === 'nouveau') this.nouveauCode[index] = '';
      else if (cible === 'confirmer') this.confirmationCode[index] = '';
    }
  }

  onKeyDown(event: KeyboardEvent, index: number, cible: 'confirmation' | 'nouveau' | 'confirmer'): void {
    if (event.key === 'Backspace') {
      const tableau = cible === 'confirmation' ? this.chiffresConfirmation : (cible === 'nouveau' ? this.nouveauCode : this.confirmationCode);
      if (!tableau[index] && index > 0) {
        const inputsArray = this.digitInputs.toArray();
        inputsArray[index - 1]?.nativeElement.focus();
      }
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
    const nouveau = this.nouveauCode.join('');
    const confirmation = this.confirmationCode.join('');

    if (nouveau.length !== 4 || confirmation.length !== 4) {
      this.messageErreur.set('Le code doit comporter exactement 4 chiffres.');
      return;
    }

    if (nouveau !== confirmation) {
      this.messageErreur.set('La confirmation ne correspond pas au nouveau code.');
      return;
    }

    if (this.securite.statut()?.configure && (!this.ancienCode || this.ancienCode.length !== 4)) {
      this.messageErreur.set("Veuillez saisir votre ancien code de sécurité à 4 chiffres.");
      return;
    }

    this.enCours.set(true);
    this.messageErreur.set('');

    this.securite.configurerCode(nouveau, this.ancienCode || undefined).subscribe({
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

  fermer(): void {
    this.securite.fermerModal();
  }
}

