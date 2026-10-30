import { Injectable, computed, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { API_URL } from '../api';
import { AuthService } from './auth.service';

/** Notification reçue par l'administrateur (NotificationVue du backend) : ENVOYEE tant qu'elle n'est pas lue. */
export interface NotificationAdmin {
  id: number;
  contenu: string;
  canal: string;
  statut: string;
  date: string;
}

/**
 * Notifications de l'administrateur : nouveaux dossiers KYC, groupes prêts à publier, étapes de colis signalées
 * par les grossistes, réceptions… Le backend les crée ; ici on les relève toutes les 30 s et on les marque lues.
 */
@Injectable({ providedIn: 'root' })
export class NotificationService {
  private readonly http = inject(HttpClient);
  private readonly auth = inject(AuthService);
  private minuterie?: ReturnType<typeof setInterval>;

  readonly notifications = signal<NotificationAdmin[]>([]);
  readonly nonLues = computed(() => this.notifications().filter(n => n.statut !== 'LUE').length);

  demarrer(): void {
    if (this.minuterie) {
      return;
    }
    this.rafraichir();
    this.minuterie = setInterval(() => this.rafraichir(), 30_000);
  }

  arreter(): void {
    clearInterval(this.minuterie);
    this.minuterie = undefined;
    this.notifications.set([]);
  }

  rafraichir(): void {
    if (!this.auth.obtenirJeton()) {
      return;
    }
    this.http.get<NotificationAdmin[]>(`${API_URL}/moi/notifications`, { params: { taille: 50 } }).subscribe({
      next: liste => this.notifications.set(liste ?? []),
      error: () => {
        /* la cloche reste sur la dernière liste connue */
      }
    });
  }

  marquerLue(notification: NotificationAdmin): void {
    if (notification.statut === 'LUE') {
      return;
    }
    this.http.post<void>(`${API_URL}/moi/notifications/${notification.id}/lue`, {}).subscribe({
      next: () =>
        this.notifications.update(liste =>
          liste.map(n => (n.id === notification.id ? { ...n, statut: 'LUE' } : n))
        )
    });
  }

  toutMarquerLu(): void {
    this.notifications().filter(n => n.statut !== 'LUE').forEach(n => this.marquerLue(n));
  }
}
