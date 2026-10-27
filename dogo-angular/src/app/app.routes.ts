import { Routes } from '@angular/router';
import { adminGuard } from './core/admin.guard';
import { PERMISSIONS_PAGES } from './core/permissions';

/** Page interne protégée : connexion administrateur + au moins une des permissions de la page */
const protegee = (page: string) => ({ canActivate: [adminGuard], data: { permissions: PERMISSIONS_PAGES[page] ?? [] } });

export const routes: Routes = [
  // 1. Lancement : le tableau de bord si une session est ouverte (sinon le garde renvoie vers la connexion)
  { path: '', redirectTo: 'dashboard', pathMatch: 'full' },

  // 2. Route de connexion (hors sidebar / plein écran)
  {
    path: 'login',
    loadComponent: () => import('./pages/login/login').then(m => m.LoginComponent)
  },

  // 3. Pages internes de l'application
  {
    path: 'dashboard',
    ...protegee('dashboard'),
    loadComponent: () => import('./pages/dashboard/dashboard').then(m => m.DashboardComponent)
  },
  {
    path: 'kyc-validation',
    ...protegee('kyc-validation'),
    loadComponent: () => import('./pages/kyc-validation/kyc-validation').then(m => m.KycValidationComponent)
  },
  {
    path: 'finance',
    ...protegee('finance'),
    loadComponent: () => import('./pages/finance/finance').then(m => m.FinanceComponent)
  },
  {
    path: 'corridors',
    ...protegee('corridors'),
    loadComponent: () => import('./pages/corridors/corridors').then(m => m.CorridorsComponent)
  },
  {
    path: 'groupes',
    ...protegee('groupes'),
    loadComponent: () => import('./pages/groupes/groupes').then(m => m.GroupesComponent)
  },
  {
    path: 'utilisateurs',
    ...protegee('utilisateurs'),
    loadComponent: () => import('./pages/utilisateurs/utilisateurs').then(m => m.UtilisateursComponent)
  },
  {
    path: 'utilisateurs/:id',
    ...protegee('utilisateurs'),
    loadComponent: () => import('./pages/fiche-utilisateur/fiche-utilisateur').then(m => m.FicheUtilisateurComponent)
  },
  {
    path: 'grossistes',
    ...protegee('grossistes'),
    loadComponent: () => import('./pages/grossistes/grossistes').then(m => m.GrossistesComponent)
  },
  {
    path: 'courtiers',
    ...protegee('courtiers'),
    loadComponent: () => import('./pages/courtiers/courtiers').then(m => m.CourtiersComponent)
  },
  {
    path: 'commercants',
    ...protegee('commercants'),
    loadComponent: () => import('./pages/commercants/commercants').then(m => m.CommercantsComponent)
  },
  {
    path: 'administrateurs',
    ...protegee('administrateurs'),
    loadComponent: () => import('./pages/administrateurs/administrateurs').then(m => m.AdministrateursComponent)
  },
  {
    path: 'retraits',
    ...protegee('retraits'),
    loadComponent: () => import('./pages/retraits/retraits').then(m => m.RetraitsComponent)
  },
  {
    path: 'audit',
    ...protegee('audit'),
    loadComponent: () => import('./pages/audit/audit').then(m => m.AuditComponent)
  },

  // 4. URL inconnue : tableau de bord (ou connexion si aucune session)
  { path: '**', redirectTo: 'dashboard' }
];
