import { TestBed } from '@angular/core/testing';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { Router, provideRouter } from '@angular/router';
import { API_URL } from './api';
import { authInterceptor } from './auth.interceptor';
import { routes } from '../app.routes';
import { AppComponent } from '../app';

/** Session refusée par le backend (jeton expiré, serveur redémarré) pendant l'affichage du tableau de bord */
describe('Session expirée', () => {
  afterEach(() => localStorage.clear());

  it('ramène à la connexion sans erreur non gérée', async () => {
    localStorage.setItem('dogo_token', 'jeton-expire');
    localStorage.setItem('dogo_profil', JSON.stringify({ id: 1, type: 'ADMINISTRATEUR', nom: 'Admin', telephone: '', statut: 'ACTIF', permissions: ['ADMIN_CREER', 'KYC_VALIDER', 'AUDIT_LIRE', 'GROUPE_SUIVRE', 'REMBOURSEMENT_APPROUVER', 'RECEPTION_VALIDER', 'GROUPE_PUBLICATION_VALIDER', 'COMPTE_SUSPENDRE', 'NOTIFICATION_LIRE'] }));
    TestBed.configureTestingModule({
      imports: [AppComponent],
      providers: [provideHttpClient(withInterceptors([authInterceptor])), provideHttpClientTesting(), provideRouter(routes)]
    });
    const fixture = TestBed.createComponent(AppComponent);
    const router = TestBed.inject(Router);
    const http = TestBed.inject(HttpTestingController);
    await router.navigateByUrl('/dashboard');
    fixture.detectChanges();
    await fixture.whenStable();

    // Tous les appels en vol reçoivent 401
    for (const r of http.match(() => true)) {
      r.flush({ status: 401, detail: 'Authentification requise' }, { status: 401, statusText: 'Unauthorized' });
    }
    await fixture.whenStable();
    for (const r of http.match(() => true)) {
      r.flush({}, { status: 401, statusText: 'Unauthorized' });
    }
    await fixture.whenStable();

    expect(router.url).toBe('/login');
    expect(localStorage.getItem('dogo_token')).toBeNull();
    expect(API_URL).toContain('/api');
  });
});
