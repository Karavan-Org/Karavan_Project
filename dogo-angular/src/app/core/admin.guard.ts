import { CanActivateFn, Router } from '@angular/router';
import { inject } from '@angular/core';
import { AuthService } from './services/auth.service';

/**
 * Les pages de supervision sont réservées aux administrateurs connectés. Une page dont le rôle administratif
 * ne détient aucune des permissions (route.data.permissions) renvoie vers le tableau de bord, accessible à tous.
 */
export const adminGuard: CanActivateFn = (route) => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (!auth.obtenirJeton() || auth.obtenirProfil()?.type !== 'ADMINISTRATEUR') {
    auth.deconnecter();
    return router.createUrlTree(['/login']);
  }
  const exigees: string[] = route.data?.['permissions'] ?? [];
  return auth.peut(...exigees) ? true : router.createUrlTree(['/dashboard']);
};
