import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterOutlet, Router, NavigationEnd } from '@angular/router';
import { filter } from 'rxjs/operators';
import { HeaderComponent } from './components/header/header';
import { SidebarComponent } from './components/sidebar/sidebar';
import { ModalSecuriteCodeComponent } from './components/modal-securite-code/modal-securite-code.component';
import { AdminSecuriteService } from './core/services/admin-securite.service';
import { AuthService } from './core/services/auth.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [
    CommonModule,
    RouterOutlet,
    HeaderComponent,
    SidebarComponent,
    ModalSecuriteCodeComponent
  ],
  templateUrl: './app.html',
  styleUrl: './app.scss'
})
export class AppComponent implements OnInit {
  // Détection page de login et contrôle du code de sécurité
  isLoginPage = false;
  isDashboardPage = false;
  private readonly router = inject(Router);
  private readonly securite = inject(AdminSecuriteService);
  private readonly auth = inject(AuthService);

  ngOnInit(): void {
    // Détecte chaque changement de page
    this.router.events.pipe(
      filter(event => event instanceof NavigationEnd)
    ).subscribe((event: any) => {
      const url = event.urlAfterRedirects || this.router.url;
      this.isLoginPage = url.includes('/login');
      this.isDashboardPage = url === '/admin' || url === '/' || url.startsWith('/admin?');

      if (!this.isLoginPage && this.auth.obtenirProfil()?.type === 'ADMINISTRATEUR') {
        this.securite.chargerStatut().subscribe({
          next: (st) => {
            // Si l'administrateur n'a pas encore configuré son code, on lui propose immédiatement
            if (!st.configure) {
              this.securite.ouvrirConfiguration();
            }
          },
          error: () => undefined
        });
      }
    });
  }
}