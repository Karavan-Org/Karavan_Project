import { Component, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
import { AdminApiService } from '../../core/services/admin-api.service';
import { NotificationService } from '../../core/services/notification.service';
import { CommonModule } from '@angular/common';
import { Router, RouterLink, RouterLinkActive } from '@angular/router';
import { MatIconModule } from '@angular/material/icon';
import { AuthService } from '../../core/services/auth.service';
import { AdminSecuriteService } from '../../core/services/admin-securite.service';
import { PERMISSIONS_PAGES } from '../../core/permissions';
import { TableauDeBordService } from '../../pages/tableau-de-bord/tableau-de-bord.service';

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
  private readonly tbService = inject(TableauDeBordService);
  private minuterie?: ReturnType<typeof setInterval>;

  /**
   * Mode miniature/réduit : FERMÉ PAR DÉFAUT conformément à la demande utilisateur.
   * La barre apparaît/s'agrandit uniquement lorsque l'on clique dessus,
   * et se referme en mode miniature lorsqu'on la ferme.
   */
  readonly estReduite = signal<boolean>(true);

  /** Compteurs de badges (relus périodiquement) */
  readonly kycEnAttente = signal(0);
  readonly groupesAModerer = signal(0);

  ngOnInit(): void {
    try {
      const stocke = localStorage.getItem('karavan_sidebar_reduite');
      if (stocke !== null) {
        this.estReduite.set(stocke === 'true');
      } else {
        // Par défaut : fermé en état miniature
        this.estReduite.set(true);
      }
    } catch {
      this.estReduite.set(true);
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
      localStorage.setItem('karavan_sidebar_reduite', String(nv));
    } catch {}
  }

  ouvrirSidebar(): void {
    if (this.estReduite()) {
      this.estReduite.set(false);
      try {
        localStorage.setItem('karavan_sidebar_reduite', 'false');
      } catch {}
    }
  }

  fermerSidebar(): void {
    if (!this.estReduite()) {
      this.estReduite.set(true);
      try {
        localStorage.setItem('karavan_sidebar_reduite', 'true');
      } catch {}
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

  onItemClick(item: MenuItem): void {
    if (item.route === '/admin' && this.router.url === '/admin') {
      this.tbService.basculerPanneauStats();
    }
  }

  private readonly menu: MenuSection[] = [
    {
      title: "VUE D'ENSEMBLE",
      items: [
        { label: 'Tableau de bord', icon: 'public', route: '/admin' },
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
