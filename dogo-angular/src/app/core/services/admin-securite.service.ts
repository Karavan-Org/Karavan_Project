import { Injectable, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, tap, catchError, throwError } from 'rxjs';
import { API_URL, messageErreur } from '../api';
import { AuthService } from './auth.service';

export interface StatutSecurite {
  configure: boolean;
  dateConfiguration?: string;
  matricule?: string;
}

export interface OptionsConfirmationSecurite {
  titre: string;
  description?: string;
  actionTexte?: string;
  icone?: string;
  danger?: boolean;
}

@Injectable({
  providedIn: 'root'
})
export class AdminSecuriteService {
  private readonly http = inject(HttpClient);
  private readonly auth = inject(AuthService);

  // État du statut du code de sécurité de l'administrateur
  readonly statut = signal<StatutSecurite | null>(null);

  // État de la modal
  readonly modalOuverte = signal(false);
  readonly modalMode = signal<'CONFIRMATION' | 'CONFIGURATION'>('CONFIRMATION');
  readonly configAction = signal<OptionsConfirmationSecurite | null>(null);

  // Callbacks Promise
  private resolveAttente: ((code: string) => void) | null = null;
  private rejectAttente: ((raison?: any) => void) | null = null;

  /**
   * Charge le statut de configuration du code PIN à 4 chiffres de l'admin.
   */
  chargerStatut(): Observable<StatutSecurite> {
    return this.http
      .get<StatutSecurite>(`${API_URL}/admin/securite/statut`, {
        withCredentials: true
      })
      .pipe(
        tap((res) => {
          this.statut.set(res);
        })
      );
  }

  /**
   * Configure ou met à jour le code de sécurité à 4 chiffres.
   */
  configurerCode(nouveauCode: string, ancienCode?: string, motDePasse?: string): Observable<any> {
    return this.http
      .post<any>(
        `${API_URL}/admin/securite/configurer`,
        { nouveauCode, ancienCode, motDePasse },
        { withCredentials: true }
      )
      .pipe(
        tap(() => {
          this.chargerStatut().subscribe();
        })
      );
  }

  /**
   * Vérifie la validité du code de sécurité à 4 chiffres auprès du serveur.
   */
  verifierCode(code: string): Observable<any> {
    return this.http.post<any>(
      `${API_URL}/admin/securite/verifier`,
      { code },
      { withCredentials: true }
    );
  }

  /**
   * Ouvre la modale de configuration / modification du code de sécurité.
   */
  ouvrirConfiguration(): void {
    this.modalMode.set('CONFIGURATION');
    this.modalOuverte.set(true);
  }

  /**
   * Ouvre la modale de confirmation pour une action sensible.
   * Retourne une promesse résolue avec le code à 4 chiffres vérifié avec succès.
   */
  demanderConfirmation(options: OptionsConfirmationSecurite): Promise<string> {
    // Si le code n'est pas encore configuré, on ouvre d'abord la configuration
    if (!this.statut()?.configure) {
      this.ouvrirConfiguration();
      return Promise.reject(new Error("Code de sécurité non configuré. Veuillez le configurer avant de continuer."));
    }

    return new Promise<string>((resolve, reject) => {
      this.resolveAttente = resolve;
      this.rejectAttente = reject;
      this.configAction.set({
        titre: options.titre,
        description: options.description || "Veuillez entrer votre code de sécurité à 4 chiffres pour confirmer cette opération.",
        actionTexte: options.actionTexte || "Confirmer l'opération",
        icone: options.icone || "lock",
        danger: options.danger || false
      });
      this.modalMode.set('CONFIRMATION');
      this.modalOuverte.set(true);
    });
  }

  /**
   * Appelée par le composant modal lorsque le code est validé avec succès par le serveur.
   */
  validerAction(code: string): void {
    if (this.resolveAttente) {
      this.resolveAttente(code);
      this.resolveAttente = null;
      this.rejectAttente = null;
    }
    this.fermerModal();
  }

  /**
   * Fermeture de la modale sans validation.
   */
  fermerModal(): void {
    this.modalOuverte.set(false);
    if (this.rejectAttente) {
      this.rejectAttente(new Error("Action annulée par l'administrateur."));
      this.resolveAttente = null;
      this.rejectAttente = null;
    }
  }
}
