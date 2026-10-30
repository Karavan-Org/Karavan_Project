import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { ligneCsv, messageErreur, telechargerTexte } from '../../core/api';
import { AdminApiService, LigneAudit, VerificationAudit } from '../../core/services/admin-api.service';

type Famille = 'manifests' | 'escrow' | 'kyc' | 'other';

export interface AuditLog {
  source: LigneAudit;
  famille: Famille;
  time: string;
  date: string;
  type: string;
  badgeClass: 'gray' | 'green' | 'yellow';
  actor: string;
  entity: string;
  detail: string;
  subDetail: string;
  hash: string;
}

/** Famille d'un acte selon son code d'audit (journal en ajout seul, RG-66) */
function familleDe(action: string): Famille {
  if (action.startsWith('KYC') || action === 'TELEPHONE_VERIFIE' || action.startsWith('COMPTE')) return 'kyc';
  if (/SEQUESTRE|PAIEMENT|RETRAIT|REMBOURSEMENT/.test(action)) return 'escrow';
  if (/GROUPE|COMMANDES|RECEPTION|ETAPE|POINT_RETRAIT|CONVOI|PRODUIT/.test(action)) return 'manifests';
  return 'other';
}

/**
 * Journal d'audit (RG-66, RG-67) : lecture seule, chaque ligne est chaînée à la précédente par son empreinte ;
 * la vérification recalcule toute la chaîne côté serveur.
 */
@Component({
  selector: 'app-audit',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './audit.html',
  styleUrl: './audit.scss'
})
export class AuditComponent implements OnInit {
  private readonly api = inject(AdminApiService);

  readonly selectedFilter = signal<'all' | 'manifests' | 'escrow' | 'kyc'>('all');
  readonly lignes = signal<LigneAudit[]>([]);
  readonly verification = signal<VerificationAudit | null>(null);
  readonly chargement = signal(true);
  readonly erreur = signal('');
  readonly message = signal('');

  ngOnInit(): void {
    this.charger();
  }

  charger(): void {
    this.chargement.set(true);
    this.erreur.set('');
    forkJoin({
      lignes: this.api.journalAudit(500),
      verification: this.api.verifierAudit().pipe(catchError(() => of(null)))
    }).subscribe({
      next: ({ lignes, verification }) => {
        this.lignes.set(lignes ?? []);
        this.verification.set(verification);
        this.chargement.set(false);
      },
      error: e => {
        this.erreur.set(messageErreur(e, 'Impossible de lire le journal d’audit.'));
        this.chargement.set(false);
      }
    });
  }

  readonly logs = computed<AuditLog[]>(() =>
    this.lignes().map(l => {
      const famille = familleDe(l.action);
      const d = new Date(l.date);
      const aujourdHui = new Date().toDateString() === d.toDateString();
      return {
        source: l,
        famille,
        time: new Intl.DateTimeFormat('fr-FR', { timeZone: 'Africa/Bamako', timeStyle: 'medium' }).format(d) + ' GMT',
        date: aujourdHui ? 'Aujourd’hui' : new Intl.DateTimeFormat('fr-FR', { timeZone: 'Africa/Bamako', dateStyle: 'short' }).format(d),
        type: l.action.replace(/_/g, ' '),
        badgeClass: famille === 'escrow' ? 'green' : famille === 'kyc' ? 'yellow' : 'gray',
        actor: l.acteurId ? `Utilisateur #${l.acteurId}` : 'Système',
        entity: l.avant ?? '—',
        detail: l.apres ?? '',
        subDetail: `ligne #${l.id}`,
        hash: l.hash ? `sha256:${l.hash.slice(0, 8)}…` : '—'
      };
    })
  );

  readonly filtres = computed(() => {
    const f = this.selectedFilter();
    return f === 'all' ? this.logs() : this.logs().filter(l => l.famille === f);
  });

  readonly nombre = (famille: Famille) => this.logs().filter(l => l.famille === famille).length;
  readonly remises = computed(() => this.lignes().filter(l => l.action === 'RETRAIT_VALIDE').length);
  readonly dernierActeLogistique = computed(() => this.logs().find(l => l.famille === 'manifests') ?? null);

  setFilter(filter: 'all' | 'manifests' | 'escrow' | 'kyc'): void {
    this.selectedFilter.set(filter);
  }

  downloadLogs(): void {
    const lignes = [
      ligneCsv(['Id', 'Date', 'Action', 'Acteur', 'Avant', 'Après', 'Empreinte']),
      ...this.lignes().map(l => ligneCsv([l.id, l.date, l.action, l.acteurId ?? 'SYSTEME', l.avant, l.apres, l.hash]))
    ];
    telechargerTexte(`journal-audit-${new Date().toISOString().slice(0, 10)}.csv`, lignes.join('\n'));
  }

  exporterJson(): void {
    telechargerTexte(`journal-audit-${new Date().toISOString().slice(0, 10)}.json`,
      JSON.stringify(this.lignes(), null, 2), 'application/json');
  }

  verifyIntegrity(): void {
    this.message.set('Vérification en cours…');
    this.api.verifierAudit().subscribe({
      next: v => {
        this.verification.set(v);
        this.message.set(
          v.chaineIntacte
            ? `Chaîne intacte : ${v.lignesVerifiees} ligne(s) vérifiée(s).`
            : `Chaîne ROMPUE à la ligne #${v.premiereLigneFausse} : le journal a été altéré.`
        );
      },
      error: e => this.message.set(messageErreur(e, 'Vérification impossible.'))
    });
  }
}
