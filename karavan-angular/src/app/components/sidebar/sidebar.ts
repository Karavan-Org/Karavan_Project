import { Component, HostBinding, HostListener, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
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

  private readonly CLE_STORAGE = 'karavan_sidebar_reduite';

  /**
   * Mode miniature/réduit (rail compact à icônes).
   * L'état est synchronisé avec le layout parent : quand la barre s'ouvre,
   * le contenu de la page s'adapte en symbiose (aucun chevauchement).
   */
  readonly estReduite = signal<boolean>(false);

  @HostBinding('class.sidebar-reduite')
  get isReduite(): boolean {
    return this.estReduite();
  }

  @HostBinding('class.sidebar-etendue')
  get isEtendue(): boolean {
    return !this.estReduite();
  }

  /** Compteurs de badges (relus périodiquement) */
  readonly kycEnAttente = signal(0);
  readonly groupesAModerer = signal(0);

  ngOnInit(): void {
    const stocke = localStorage.getItem(this.CLE_STORAGE);
    if (stocke !== null) {
      this.estReduite.set(stocke === 'true');
    } else {
      // Par défaut : ouvert pour une expérience riche et directe, adaptable en 1 clic
      this.estReduite.set(false);
    }

    this.chargerBadges();
    this.minuterie = setInterval(() => this.chargerBadges(), 60_000);
  }

  ngOnDestroy(): void {
    clearInterval(this.minuterie);
  }

  basculerReduite(): void {
    const nv = !this.estReduite();
    this.estReduite.set(nv);
    try {
      localStorage.setItem(this.CLE_STORAGE, String(nv));
    } catch (_) {}
  }

  ouvrirSidebar(): void {
    this.estReduite.set(false);
    try {
      localStorage.setItem(this.CLE_STORAGE, 'false');
    } catch (_) {}
  }

  fermerSidebar(): void {
    this.estReduite.set(true);
    try {
      localStorage.setItem(this.CLE_STORAGE, 'true');
    } catch (_) {}
  }

  onSidebarClick(event: MouseEvent): void {
    if (this.estReduite()) {
      const target = event.target as HTMLElement;
      // Ne pas intercepter de clic sur un lien de navigation, déconnexion ou bouton de sécurité
      if (
        !target.closest('.nav-item') &&
        !target.closest('.logout-pill-btn') &&
        !target.closest('.security-mini-btn') &&
        !target.closest('.btn-expand-bottom')
      ) {
        this.ouvrirSidebar();
      }
    }
  }

  private chargerBadges(): void {
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
      title: 'Pilotage',
      items: [
        { label: 'Tableau de bord', icon: 'public', route: '/admin' },
        { label: "Groupes d'achat", icon: 'groups', route: '/groupes' }
      ]
    },
    {
      title: 'Opérations',
      items: [
        { label: 'Validations KYC', icon: 'verified_user', route: '/kyc-validation' },
        { label: 'Portefeuille & Séquestre', icon: 'account_balance_wallet', route: '/finance' },
        { label: 'Suivi des colis', icon: 'local_shipping', route: '/corridors' },
        { label: 'Retraits de colis', icon: 'qr_code_scanner', route: '/retraits' }
      ]
    },
    {
      title: 'Utilisateurs',
      items: [
        { label: 'Annuaire', icon: 'people', route: '/utilisateurs' },
        { label: 'Grossistes', icon: 'storefront', route: '/grossistes' },
        { label: 'Courtiers', icon: 'badge', route: '/courtiers' },
        { label: 'Commerçants', icon: 'shopping_cart', route: '/commercants' },
        { label: 'Administrateurs', icon: 'admin_panel_settings', route: '/administrateurs' }
      ]
    },
    {
      title: 'Conformité',
      items: [
        { label: "Journal d'audit", icon: 'fact_check', route: '/audit' }
      ]
    }
  ];

  get adminProfile() {
    const profil = this.authService.obtenirProfil();

    const name = profil?.nom || 'Admin Karavan';
    const initials = name
      .trim()
      .split(/\s+/)
      .map(part => part[0])
      .slice(0, 2)
      .join('')
      .toUpperCase();

    return {
      initials: initials || 'AD',
      name,
      role: this.roleAdministratif(profil?.permissions ?? [])
    };
  }

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
