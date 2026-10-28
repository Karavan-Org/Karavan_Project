import { Component, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
import { AdminApiService } from '../../core/services/admin-api.service';
import { NotificationService } from '../../core/services/notification.service';
import { CommonModule } from '@angular/common';
import { Router, RouterLink, RouterLinkActive } from '@angular/router';
import { MatIconModule } from '@angular/material/icon';
import { AuthService } from '../../core/services/auth.service';
import { AdminSecuriteService } from '../../core/services/admin-securite.service';
import { PERMISSIONS_PAGES } from '../../core/permissions';

interface MenuItem {
  label: string;
  icon: string;
  route: string;
  badge?: number;
}

interface MenuSection {
  title: string;
  items: MenuItem[];
}

@Component({
  selector: 'app-sidebar',
  standalone: true,
  imports: [
    CommonModule,
    RouterLink,
    RouterLinkActive,
    MatIconModule
  ],
  templateUrl: './sidebar.html',
  styleUrl: './sidebar.scss'
})
export class SidebarComponent implements OnInit, OnDestroy {
  private readonly authService = inject(AuthService);
  private readonly router = inject(Router);
  private readonly api = inject(AdminApiService);
  private readonly notifications = inject(NotificationService);
  readonly securite = inject(AdminSecuriteService);
  private minuterie?: ReturnType<typeof setInterval>;

  /** Dossiers KYC et groupes en attente de décision (badges du menu), relus chaque minute */
  readonly kycEnAttente = signal(0);
  readonly groupesAModerer = signal(0);

  ngOnInit(): void {
    this.chargerBadges();
    this.minuterie = setInterval(() => this.chargerBadges(), 60_000);
  }

  ngOnDestroy(): void {
    clearInterval(this.minuterie);
  }

  private chargerBadges(): void {
    // Seuls les rôles qui peuvent décider voient le compteur (sinon le backend répond 403)
    if (this.authService.peut('KYC_VALIDER')) {
      this.api.dossiersKyc().subscribe({
        next: dossiers => this.kycEnAttente.set(dossiers?.length ?? 0),
        error: () => this.kycEnAttente.set(0)
      });
    }
    if (this.authService.peut('GROUPE_PUBLICATION_VALIDER')) {
      this.api.groupesEnValidation().subscribe({
        next: groupes => this.groupesAModerer.set(groupes?.length ?? 0),
        error: () => this.groupesAModerer.set(0)
      });
    }
  }

  /**
   * Menu limité aux pages que le rôle administratif peut ouvrir. Signal calculé (et non getter) : les objets ne
   * changent que si un badge change, sinon *ngFor recréerait chaque lien à chaque détection et routerLinkActive
   * relancerait la détection sans fin (NG0103), notamment pendant la redirection vers /login sur un 401.
   */
  readonly sections = computed<MenuSection[]>(() => {
    const badges: Record<string, number> = {
      '/kyc-validation': this.kycEnAttente(),
      '/groupes': this.groupesAModerer()
    };
    return this.menu
      .map(section => ({
        ...section,
        items: section.items
          .filter(item => this.authService.peut(...(PERMISSIONS_PAGES[item.route.slice(1)] ?? [])))
          .map(item => ({ ...item, badge: badges[item.route] || undefined }))
      }))
      .filter(section => section.items.length);
  });

  parTitre(_: number, section: MenuSection): string {
    return section.title;
  }

  parRoute(_: number, item: MenuItem): string {
    return item.route;
  }

  private readonly menu: MenuSection[] = [
    {
      title: "VUE D'ENSEMBLE",
      items: [
        { label: 'Supervision Réseau', icon: 'grid_view', route: '/dashboard' },
        { label: 'Validations KYC', icon: 'verified_user', route: '/kyc-validation' },
        { label: "Groupes d'achat", icon: 'groups', route: '/groupes' },
        { label: 'Séquestre & Finance', icon: 'account_balance_wallet', route: '/finance' },
        { label: 'Suivi Colis & Dépôts', icon: 'local_shipping', route: '/corridors' },
        { label: 'Retraits Colis (QR / PIN)', icon: 'qr_code_scanner', route: '/retraits' }
      ]
    },
    {
      title: 'GESTION DES UTILISATEURS',
      items: [
        { label: 'Tous les utilisateurs', icon: 'people', route: '/utilisateurs' },
        { label: 'Grossistes (Dépôts)', icon: 'storefront', route: '/grossistes' },
        { label: 'Courtiers Agréés', icon: 'badge', route: '/courtiers' },
        { label: 'Commerçants (Clients)', icon: 'shopping_cart', route: '/commercants' },
        { label: 'Administrateurs', icon: 'admin_panel_settings', route: '/administrateurs' }
      ]
    },
    {
      title: 'CONFORMITÉ',
      items: [
        { label: 'Audit & Logs', icon: 'description', route: '/audit' }
      ]
    }
  ];

  get adminProfile() {
    const profil = this.authService.obtenirProfil();

    const name = profil?.nom || 'Utilisateur connecté';
    const initials = name
      .trim()
      .split(/\s+/)
      .map(part => part[0])
      .slice(0, 2)
      .join('')
      .toUpperCase();

    return {
      initials: initials || 'U',
      name,
      role: this.roleAdministratif(profil?.permissions ?? [])
    };
  }

  /** Le profil de connexion ne porte que les permissions : on en déduit le rôle administratif affiché */
  private roleAdministratif(p: string[]): string {
    if (p.includes('ADMIN_CREER')) return 'Admin Technique';
    if (p.includes('KYC_VALIDER')) return 'Admin Validation';
    if (p.includes('REMBOURSEMENT_APPROUVER')) return 'Admin Finance';
    if (p.includes('POINT_RETRAIT_GERER') || p.includes('RETRAIT_VALIDER')) return 'Admin Logistique';
    if (p.includes('COMPTE_SUSPENDRE') || p.includes('COMMANDE_LIRE')) return 'Admin Support';
    return 'Administrateur';
  }

  deconnecter(): void {
    this.notifications.arreter();
    this.authService.fermerSession();
    void this.router.navigate(['/login']);
  }
}
