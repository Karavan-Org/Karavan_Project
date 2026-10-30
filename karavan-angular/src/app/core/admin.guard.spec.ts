import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { ActivatedRouteSnapshot, RouterStateSnapshot, UrlTree, provideRouter } from '@angular/router';
import { adminGuard, premiereConnexionGuard } from './admin.guard';
import { PERMISSIONS_PAGES } from './permissions';
import { AuthService, ProfilConnecte } from './services/auth.service';
import { vi } from 'vitest';

function creerAuthFactice() {
  return {
    obtenirJeton: vi.fn((): string | null => null),
    obtenirProfil: vi.fn((): ProfilConnecte | null => null),
    peut: vi.fn((...requises: string[]) => requises.length === 0),
    motDePasseProvisoire: vi.fn(() => false),
    deconnecter: vi.fn()
  };
}

let auth: ReturnType<typeof creerAuthFactice>;

function connecter(type: string, permissions: string[]): void {
  auth.obtenirJeton.mockReturnValue('jeton');
  auth.obtenirProfil.mockReturnValue({ id: 1, type, nom: 'X', telephone: '', statut: 'ACTIF', permissions });
  auth.peut.mockImplementation((...requises) => requises.length === 0 || requises.some(p => permissions.includes(p)));
}

function verifier(page: string): string | true {
  const route = { data: { permissions: PERMISSIONS_PAGES[page] } } as unknown as ActivatedRouteSnapshot;
  const resultat = TestBed.runInInjectionContext(() => adminGuard(route, {} as RouterStateSnapshot));
  return resultat instanceof UrlTree ? resultat.toString() : (resultat as true);
}

function premiereConnexion(): string | true {
  const resultat = TestBed.runInInjectionContext(() =>
    premiereConnexionGuard({} as ActivatedRouteSnapshot, {} as RouterStateSnapshot));
  return resultat instanceof UrlTree ? resultat.toString() : (resultat as true);
}

describe('adminGuard', () => {
  beforeEach(() => {
    auth = creerAuthFactice();
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideRouter([]), { provide: AuthService, useValue: auth }]
    });
  });

  it('renvoie à la connexion sans session administrateur', () => {
    expect(verifier('dashboard')).toBe('/login');
    auth.obtenirJeton.mockReturnValue('jeton');
    auth.obtenirProfil.mockReturnValue({ id: 1, type: 'COMMERCANT', nom: 'X', telephone: '', statut: 'ACTIF', permissions: [] });
    expect(verifier('dashboard')).toBe('/login');
  });

  it('limite le rôle FINANCE à ses pages, le support aux utilisateurs et la logistique aux groupes', () => {
    connecter('ADMINISTRATEUR', ['CAMPAGNE_EXPLORER', 'GROUPE_SUIVRE', 'NOTIFICATION_LIRE', 'PORTEFEUILLE_RETIRER', 'PROFIL_GERER', 'REMBOURSEMENT_APPROUVER']);
    expect(verifier('finance')).toBe(true);
    expect(verifier('utilisateurs')).toBe('/dashboard');
    expect(verifier('groupes')).toBe('/dashboard');
    expect(verifier('kyc-validation')).toBe('/dashboard');
    expect(verifier('audit')).toBe('/dashboard');
    expect(verifier('administrateurs')).toBe('/dashboard');

    connecter('ADMINISTRATEUR', ['COMPTE_SUSPENDRE']);
    expect(verifier('utilisateurs')).toBe(true);

    connecter('ADMINISTRATEUR', ['COMMANDE_AVANCER']);
    expect(verifier('groupes')).toBe(true);
  });

  it('ferme toutes les pages tant que le mot de passe provisoire n\'est pas remplacé (RG-07b)', () => {
    connecter('ADMINISTRATEUR', ['ADMIN_CREER']);
    auth.motDePasseProvisoire.mockReturnValue(true);
    expect(verifier('dashboard')).toBe('/premiere-connexion');
    expect(verifier('administrateurs')).toBe('/premiere-connexion');
    expect(premiereConnexion()).toBe(true);

    auth.motDePasseProvisoire.mockReturnValue(false);
    expect(premiereConnexion()).toBe('/admin');
  });

  it('réserve la création des administrateurs au rôle TECHNIQUE', () => {
    connecter('ADMINISTRATEUR', ['KYC_VALIDER', 'GROUPE_PUBLICATION_VALIDER']);
    expect(verifier('administrateurs')).toBe('/dashboard');
    connecter('ADMINISTRATEUR', ['ADMIN_CREER']);
    expect(verifier('administrateurs')).toBe(true);
  });
});
