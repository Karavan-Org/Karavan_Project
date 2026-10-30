import { HttpErrorResponse, HttpHandlerFn, HttpInterceptorFn, HttpRequest } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { BehaviorSubject, catchError, filter, switchMap, take, throwError } from 'rxjs';
import { API_URL } from './api';
import { AuthService } from './services/auth.service';

let enRafraichissement = false;
const jetonRafraichi$ = new BehaviorSubject<string | null>(null);

/**
 * Ajoute le jeton Bearer et active les cookies avec `withCredentials: true`.
 * En cas de 401 (expiration de l'access token court), effectue un unique rafraîchissement
 * concurrent et rejoue toutes les requêtes en attente avec le nouveau jeton.
 */
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(AuthService);
  const router = inject(Router);
  const versBackend = req.url.startsWith(API_URL);

  let requete = req;
  if (versBackend) {
    const jeton = auth.obtenirJeton();
    const headers = jeton && !req.headers.has('Authorization')
      ? req.headers.set('Authorization', `Bearer ${jeton}`)
      : req.headers;
    requete = req.clone({
      headers,
      withCredentials: true
    });
  }

  return next(requete).pipe(
    catchError((erreur: HttpErrorResponse) => {
      if (
        versBackend &&
        erreur.status === 401 &&
        !req.url.endsWith('/auth/connexion') &&
        !req.url.endsWith('/auth/refresh') &&
        !req.url.endsWith('/auth/logout')
      ) {
        return traiter401(auth, router, req, next);
      }
      // RG-07b : le backend n'accepte rien d'autre que le changement du mot de passe provisoire
      if (versBackend && erreur.status === 403 && erreur.error?.code === 'MOT_DE_PASSE_PROVISOIRE') {
        void router.navigate(['/premiere-connexion']);
      }
      return throwError(() => erreur);
    })
  );
};

function traiter401(auth: AuthService, router: Router, req: HttpRequest<unknown>, next: HttpHandlerFn) {
  if (!enRafraichissement) {
    enRafraichissement = true;
    jetonRafraichi$.next(null);

    return auth.rafraichirJeton().pipe(
      switchMap((reponse) => {
        enRafraichissement = false;
        jetonRafraichi$.next(reponse.jeton);
        return next(
          req.clone({
            setHeaders: { Authorization: `Bearer ${reponse.jeton}` },
            withCredentials: true
          })
        );
      }),
      catchError((erreurRafraichissement) => {
        enRafraichissement = false;
        jetonRafraichi$.next(null);
        auth.deconnecter();
        void router.navigate(['/login']);
        return throwError(() => erreurRafraichissement);
      })
    );
  } else {
    // Un rafraîchissement est déjà en cours d'exécution : on attend son issue
    return jetonRafraichi$.pipe(
      filter((jeton): jeton is string => jeton !== null),
      take(1),
      switchMap((nouveauJeton) =>
        next(
          req.clone({
            setHeaders: { Authorization: `Bearer ${nouveauJeton}` },
            withCredentials: true
          })
        )
      )
    );
  }
}

