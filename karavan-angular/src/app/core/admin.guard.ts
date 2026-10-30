import { CanActivateFn, Router } from '@angular/router';
import { inject } from '@angular/core';
import { AuthService } from './services/auth.service';

/**
 * Les pages de supervision sont réservées aux administrateurs connectés. Une page dont le rôle administratif
 * ne détient aucune des permissions (route.data.permissions) renvoie vers le tableau de bord, accessible à tous.
 * Un mot de passe provisoire (RG-07b) ferme toutes les pages tant qu'il n'est pas remplacé.
 */
export const adminGuard: CanActivateFn = (route) => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (!auth.obtenirJeton() || auth.obtenirProfil()?.type !== 'ADMINISTRATEUR') {
    auth.deconnecter();
    return router.createUrlTree(['/login']);
  }
  if (auth.motDePasseProvisoire()) {
    return router.createUrlTree(['/premiere-connexion']);
  }
  const exigees: string[] = route.data?.['permissions'] ?? [];
  return auth.peut(...exigees) ? true : router.createUrlTree(['/dashboard']);
};

/** Page de première connexion : uniquement pour un administrateur connecté dont le mot de passe est provisoire. */
export const premiereConnexionGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (!auth.obtenirJeton() || auth.obtenirProfil()?.type !== 'ADMINISTRATEUR') {
    return router.createUrlTree(['/login']);
  }
  return auth.motDePasseProvisoire() ? true : router.createUrlTree(['/admin']);
};
