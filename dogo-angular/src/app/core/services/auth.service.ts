
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, catchError, firstValueFrom, map, of, tap } from 'rxjs';
import { API_URL } from '../api';

export interface ProfilConnecte {
  id: number;
  type: string;
  nom: string;
  telephone: string;
  statut: string;
  permissions: string[];
}

export interface ReponseConnexion {
  jeton: string;
  refreshToken?: string;
  expiration: string;
  refreshExpiration?: string;
  profil: ProfilConnecte;
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private readonly http = inject(HttpClient);
  private readonly apiUrl = API_URL;
  private readonly authHeaders = { 'X-Client-Platform': 'admin-console' };

  private accessToken: string | null = null;
  private profil: ProfilConnecte | null = null;
  private initialisationPromise: Promise<boolean> | null = null;
  estInitialise = false;

  /**
   * Connexion administrateur avec envoi des identifiants et réception du cookie HttpOnly.
   */
  connecter(
    telephone: string,
    motDePasse: string
  ): Observable<ReponseConnexion> {
    return this.http
      .post<ReponseConnexion>(
        `${this.apiUrl}/auth/connexion`,
        { telephone, motDePasse, pin: motDePasse },
        { withCredentials: true, headers: this.authHeaders }
      )
      .pipe(
        tap((reponse) => {
          this.accessToken = reponse.jeton;
          this.profil = reponse.profil;
          this.estInitialise = true;
          // Nettoyage de l'ancien stockage
          localStorage.removeItem('dogo_token');
          localStorage.removeItem('dogo_profil');
        })
      );
  }

  /**
   * Restaure la session au démarrage (APP_INITIALIZER) via le cookie HttpOnly de rafraîchissement.
   */
  restaurerSession(): Promise<boolean> {
    if (this.initialisationPromise) {
      return this.initialisationPromise;
    }

    this.initialisationPromise = firstValueFrom(
      this.http
        .post<ReponseConnexion>(
          `${this.apiUrl}/auth/refresh`,
          {},
          { withCredentials: true, headers: this.authHeaders }
        )
        .pipe(
          tap((reponse) => {
            this.accessToken = reponse.jeton;
            this.profil = reponse.profil;
            this.estInitialise = true;
          }),
          map(() => true),
          catchError(() => {
            this.accessToken = null;
            this.profil = null;
            this.estInitialise = true;
            return of(false);
          })
        ),
      { defaultValue: false }
    );

    return this.initialisationPromise;
  }

  attendreInitialisation(): Promise<boolean> {
    if (this.estInitialise) {
      return Promise.resolve(!!this.obtenirJeton());
    }
    return this.initialisationPromise ?? this.restaurerSession();
  }

  /**
   * Renouvelle l'access token court à l'aide du refresh token en cookie HttpOnly.
   */
  rafraichirJeton(): Observable<ReponseConnexion> {
    return this.http
      .post<ReponseConnexion>(
        `${this.apiUrl}/auth/refresh`,
        {},
        { withCredentials: true, headers: this.authHeaders }
      )
      .pipe(
        tap((reponse) => {
          this.accessToken = reponse.jeton;
          this.profil = reponse.profil;
        })
      );
  }

  /**
   * Re-authentification pour les opérations sensibles (ex: validation financière).
   */
  reauthentifier(pin: string): Observable<boolean> {
    const p = this.obtenirProfil();
    if (!p) {
      return of(false);
    }
    return this.connecter(p.telephone, pin).pipe(
      map(() => true),
      catchError(() => of(false))
    );
  }

  obtenirJeton(): string | null {
    return this.accessToken;
  }

  obtenirProfil(): ProfilConnecte | null {
    if (this.profil) {
      return this.profil;
    }
    return null;
  }

  /**
   * Authentification via ID Token Google pour l'espace administration.
   */
  authentifierGoogle(idToken: string): Observable<any> {
    return this.http
      .post<any>(
        `${this.apiUrl}/auth/google`,
        { idToken, deviceId: 'admin-console' },
        { withCredentials: true, headers: this.authHeaders }
      )
      .pipe(
        tap((reponse) => {
          if (reponse.statut === 'CONNECTE' && reponse.jeton) {
            this.accessToken = reponse.jeton;
            this.profil = reponse.profil;
            this.estInitialise = true;
            localStorage.removeItem('dogo_token');
            localStorage.removeItem('dogo_profil');
          }
        })
      );
  }

  /**
   * Étape 1 : Demande de code OTP SMS pour lier le numéro malien au compte Google.
   */
  demanderOtpGoogle(jetonInscription: string, telephone: string): Observable<any> {
    return this.http.post<any>(
      `${this.apiUrl}/auth/google/demander-otp`,
      { jetonInscription, telephone },
      { withCredentials: true, headers: this.authHeaders }
    );
  }

  /**
   * Étape 2 : Vérification OTP et ouverture de session pour le compte Google.
   */
  completerGoogle(jetonInscription: string, telephone: string, codeOtp: string): Observable<ReponseConnexion> {
    return this.http
      .post<ReponseConnexion>(
        `${this.apiUrl}/auth/google/completer`,
        { jetonInscription, telephone, codeOtp, deviceId: 'admin-console' },
        { withCredentials: true, headers: this.authHeaders }
      )
      .pipe(
        tap((reponse) => {
          this.accessToken = reponse.jeton;
          this.profil = reponse.profil;
          this.estInitialise = true;
          localStorage.removeItem('dogo_token');
          localStorage.removeItem('dogo_profil');
        })
      );
  }

  /**
   * Vrai si l'administrateur connecté détient au moins une des permissions (son rôle TECHNIQUE, VALIDATION,
   * FINANCE ou SUPPORT les fixe côté backend). Sans argument : simplement connecté.
   */
  peut(...permissions: string[]): boolean {
    const accordees = this.obtenirProfil()?.permissions ?? [];
    return permissions.length === 0 || permissions.some(p => accordees.includes(p));
  }

  deconnecter(): void {
    this.accessToken = null;
    this.profil = null;
    localStorage.removeItem('dogo_token');
    localStorage.removeItem('dogo_profil');
  }

  /** Invalide la session côté serveur et révoque le refresh token, puis efface localement. */
  fermerSession(): void {
    this.http
      .post(`${this.apiUrl}/auth/logout`, {}, { withCredentials: true, headers: this.authHeaders })
      .subscribe({ error: () => undefined });
    this.deconnecter();
  }
}
