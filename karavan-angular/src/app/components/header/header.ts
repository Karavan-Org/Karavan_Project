import { Component, DestroyRef, HostListener, OnDestroy, OnInit, ChangeDetectorRef, computed, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { NavigationEnd, Router } from '@angular/router';
import { filter } from 'rxjs/operators';
import { NotificationAdmin, NotificationService } from '../../core/services/notification.service';
import { LIBELLES_GROUPE, dateRelative } from '../../core/api';
import { LIBELLES_COMPTE, LIBELLES_TYPE, PERMISSIONS_PAGES } from '../../core/permissions';
import { AnnuaireService } from '../../core/services/annuaire.service';
import { AuthService } from '../../core/services/auth.service';
import { CommonModule } from '@angular/common';
import { MatIconModule } from '@angular/material/icon';
import { MatBadgeModule } from '@angular/material/badge';

/** Résultat de la recherche globale : un compte ou un groupe d'achat */
interface ResultatRecherche {
  icone: string;
  titre: string;
  detail: string;
  lien: unknown[];
  params?: Record<string, unknown>;
}

const ICONES: Record<string, string> = {
  COMMERCANT: 'shopping_cart',
  GROSSISTE: 'storefront',
  COURTIER: 'badge',
  ADMINISTRATEUR: 'admin_panel_settings'
};

@Component({
  selector: 'app-header',
  standalone: true,
  imports: [CommonModule, MatIconModule, MatBadgeModule],
  templateUrl: './header.html',
  styleUrl: './header.scss'
})
export class HeaderComponent implements OnInit, OnDestroy {

  readonly annuaire = inject(AnnuaireService);
  private readonly auth = inject(AuthService);
  readonly recherche = signal('');
  readonly rechercheOuverte = signal(false);

  /** Comptes (nom, téléphone, boutique, NIF, RCCM, licence…) puis groupes (n°, titre, produit) */
  readonly resultats = computed<ResultatRecherche[]>(() => {
    const texte = this.recherche().trim();
    if (!texte) {
      return [];
    }
    const comptes = this.annuaire.rechercher(texte, 6).map(m => ({
      icone: ICONES[m.type] ?? 'person',
      titre: m.entreprise ? `${m.nom} · ${m.entreprise}` : m.nom,
      detail: `${LIBELLES_TYPE[m.type]} · ${m.telephone} · ${LIBELLES_COMPTE[m.statut] ?? m.statut}`,
      lien: ['/utilisateurs', m.id]
    }));
    if (!this.auth.peut(...PERMISSIONS_PAGES['groupes'])) {
      return comptes;
    }
    const cherche = texte.toLowerCase().replace(/^#/, '');
    const groupes = this.annuaire
      .groupes()
      .filter(g => String(g.id) === cherche || `${g.titre} ${g.produit?.nom ?? ''}`.toLowerCase().includes(cherche))
      .slice(0, 4)
      .map(g => ({
        icone: 'groups',
        titre: `Groupe #${g.id} · ${g.titre}`,
        detail: `${LIBELLES_GROUPE[g.statut] ?? g.statut} · ${g.grossiste?.nom ?? ''}${g.courtier ? ' / ' + g.courtier.nom : ''}`,
        lien: ['/groupes'],
        params: { id: g.id }
      }));
    return [...comptes, ...groupes];
  });

  @HostListener('document:keydown', ['$event'])
  raccourci(e: KeyboardEvent): void {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
      e.preventDefault();
      (document.querySelector('.search-bar input') as HTMLInputElement | null)?.focus();
    }
  }

  ouvrirRecherche(): void {
    this.rechercheOuverte.set(true);
    // Annuaire relu à chaque ouverture : les nouveaux inscrits apparaissent sans recharger la page
    this.annuaire.charger(true).subscribe({ error: () => undefined });
  }

  fermerPlusTard(): void {
    setTimeout(() => this.rechercheOuverte.set(false), 150);
  }

  fermerRecherche(champ: HTMLInputElement): void {
    this.recherche.set('');
    this.rechercheOuverte.set(false);
    champ.blur();
  }

  ouvrirPremier(): void {
    const premier = this.resultats()[0];
    if (premier) {
      void this.router.navigate(premier.lien, { queryParams: premier.params });
      this.rechercheOuverte.set(false);
    }
  }

  aller(r: ResultatRecherche, champ: HTMLInputElement): void {
    void this.router.navigate(r.lien, { queryParams: r.params });
    this.fermerRecherche(champ);
  }

  systemStatus = 'Nœud Bamako : 100%';

  currentLocationTime = '';
  currentDate = '';

  private readonly changeDetector = inject(ChangeDetectorRef);
  private readonly destroyRef = inject(DestroyRef);
  private readonly router = inject(Router);
  readonly notifications = inject(NotificationService);
  readonly panneauOuvert = signal(false);
  readonly relatif = dateRelative;
  private clockInterval?: ReturnType<typeof setInterval>;

  readonly routeCourante = signal<string>(this.router.url);

  readonly afficherBoutonRetour = computed(() => {
    const url = this.routeCourante();
    return url !== '/admin' && url !== '/' && !url.startsWith('/login');
  });

  retournerAuDashboard(): void {
    void this.router.navigate(['/admin']);
  }

  ngOnInit(): void {
    this.routeCourante.set(this.router.url);
    this.router.events
      .pipe(
        filter(e => e instanceof NavigationEnd),
        takeUntilDestroyed(this.destroyRef)
      )
      .subscribe(() => {
        this.routeCourante.set(this.router.url);
        this.changeDetector.markForCheck();
      });

    this.updateDateTime();
    this.notifications.demarrer();

    this.clockInterval = setInterval(() => {
      this.updateDateTime();
    }, 1000);
  }

  private updateDateTime(): void {
    const now = new Date();

    const time = new Intl.DateTimeFormat('fr-FR', {
      timeZone: 'Africa/Bamako',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false
    }).format(now);

    this.currentLocationTime = `Bamako · ${time} GMT`;

    this.currentDate = new Intl.DateTimeFormat('fr-FR', {
      timeZone: 'Africa/Bamako',
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric'
    }).format(now);

    this.changeDetector.markForCheck();
  }

  basculerNotifications(): void {
    this.panneauOuvert.update(v => !v);
    if (this.panneauOuvert()) {
      this.notifications.rafraichir();
    }
  }

  /** Marque la notification lue et ouvre la page où l'administrateur doit agir */
  ouvrir(n: NotificationAdmin): void {
    this.notifications.marquerLue(n);
    this.panneauOuvert.set(false);
    const texte = n.contenu.toLowerCase();
    const groupe = /groupe #(\d+)/.exec(texte)?.[1];
    const page = texte.includes('kyc') || texte.includes('dossier')
      ? 'kyc-validation'
      : texte.includes('publication')
        ? 'groupes'
        : texte.includes('rembours') || texte.includes('séquestre') || texte.includes('paiement')
          ? 'finance'
          : texte.includes('groupe') || texte.includes('colis') || texte.includes('convoi')
            ? 'corridors'
            : null;
    // Une page que le rôle ne peut pas ouvrir renverrait au tableau de bord : on reste sur place
    if (page && this.auth.peut(...(PERMISSIONS_PAGES[page] ?? []))) {
      void this.router.navigate(['/' + page], { queryParams: page === 'groupes' && groupe ? { id: groupe } : undefined });
    }
  }

  ngOnDestroy(): void {
    if (this.clockInterval) {
      clearInterval(this.clockInterval);
    }
  }
}