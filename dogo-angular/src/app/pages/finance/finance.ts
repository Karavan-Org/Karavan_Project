import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatIconModule } from '@angular/material/icon';
import { Observable, forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import jsPDF from 'jspdf';
import { LIBELLES_GROUPE, dateCourte, fcfa, ligneCsv, messageErreur, telechargerTexte } from '../../core/api';
import { AdminApiService, Remboursement, Sequestre, TableauSequestres } from '../../core/services/admin-api.service';
import { AuthService } from '../../core/services/auth.service';

export interface FinanceTransaction {
  source: Sequestre;
  ref: string;
  group: string;
  buyer: string;
  beneficiary: string;
  amount: string;
  detailText: string;
  status: string;
  classe: 'status-vol' | 'status-libere' | 'status-route' | 'status-douane';
  actionType: 'details' | 'pdf' | 'arbitrate';
}

export interface GatewayBalance {
  name: string;
  subtitle: string;
  amount: string;
  logoClass: string;
  code: string;
}

/**
 * Séquestre & flux financiers (RG-36 à RG-41) : fonds bloqués à chaque paiement, libérés au retrait (QR/PIN),
 * restitués en cas de remboursement. L'arbitrage passe par les remboursements (REMBOURSEMENT_APPROUVER).
 */
@Component({
  selector: 'app-finance',
  standalone: true,
  imports: [CommonModule, MatIconModule],
  templateUrl: './finance.html',
  styleUrl: './finance.scss'
})
export class FinanceComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  private readonly auth = inject(AuthService);

  readonly selectedFilter = signal<'all' | 'blocked' | 'released'>('all');
  readonly tableau = signal<TableauSequestres | null>(null);
  readonly remboursements = signal<Remboursement[]>([]);
  readonly chargement = signal(true);
  readonly erreur = signal('');
  readonly message = signal('');
  readonly envoi = signal(false);
  readonly limite = signal(20);

  readonly fcfa = fcfa;

  ngOnInit(): void {
    this.charger();
  }

  charger(): void {
    this.chargement.set(true);
    this.erreur.set('');
    forkJoin({
      tableau: this.api.sequestres(),
      remboursements: this.api.remboursements().pipe(catchError(() => of([] as Remboursement[])))
    }).subscribe({
      next: ({ tableau, remboursements }) => {
        this.tableau.set(tableau);
        this.remboursements.set(remboursements ?? []);
        this.chargement.set(false);
      },
      error: e => {
        this.erreur.set(messageErreur(e, 'Impossible de charger le séquestre.'));
        this.chargement.set(false);
      }
    });
  }

  // ---------------------------------------------------------------- vues calculées

  private readonly transactions = computed<FinanceTransaction[]>(() =>
    (this.tableau()?.sequestres ?? []).map(s => {
      const bloque = s.statut === 'BLOQUE';
      const etape = LIBELLES_GROUPE[s.groupeStatut ?? ''] ?? s.groupeStatut ?? '';
      const status = s.gele
        ? 'GELÉ / LITIGE'
        : bloque
          ? `BLOQUÉ / ${etape.toUpperCase() || 'EN COURS'}`
          : s.statut === 'LIBERE' ? 'LIBÉRÉ (QR ✓)' : 'RESTITUÉ';
      const classe: FinanceTransaction['classe'] = s.gele
        ? 'status-douane'
        : bloque
          ? (s.groupeStatut === 'EN_EXPEDITION' ? 'status-route' : 'status-vol')
          : 'status-libere';
      return {
        source: s,
        ref: `#SQ-${s.id}`,
        group: s.groupeTitre ? `Groupe #${s.groupeId} · ${s.groupeTitre}` : `Paiement #${s.paiementId}`,
        buyer: s.acheteur ?? '—',
        beneficiary: s.beneficiaire ?? '—',
        amount: fcfa(s.montantBloque),
        detailText: `${s.quantite} pce${s.quantite > 1 ? 's' : ''} · bloqué le ${dateCourte(s.dateBlocage)}`,
        status,
        classe,
        actionType: bloque ? 'arbitrate' : s.statut === 'LIBERE' ? 'pdf' : 'details'
      };
    })
  );

  readonly bloques = computed(() => this.transactions().filter(t => t.source.statut === 'BLOQUE'));
  readonly liberes = computed(() => this.transactions().filter(t => t.source.statut !== 'BLOQUE'));

  readonly filteredTransactions = computed(() => {
    const liste =
      this.selectedFilter() === 'blocked' ? this.bloques() : this.selectedFilter() === 'released' ? this.liberes() : this.transactions();
    return liste.slice(0, this.limite());
  });

  readonly totalAffiche = computed(() => this.filteredTransactions().reduce((t, x) => t + Number(x.source.montantBloque), 0));

  readonly restantes = computed(() => {
    const total =
      this.selectedFilter() === 'blocked' ? this.bloques().length : this.selectedFilter() === 'released' ? this.liberes().length : this.transactions().length;
    return Math.max(0, total - this.filteredTransactions().length);
  });

  /** Répartition des fonds (bloqués / libérés / restitués), à la place des soldes bancaires fictifs */
  readonly gateways = computed<GatewayBalance[]>(() => {
    const t = this.tableau();
    return [
      { name: 'Fonds bloqués', subtitle: `${this.bloques().length} séquestre(s) actif(s)`, amount: fcfa(t?.totalBloque), logoClass: 'bdm', code: 'BLQ' },
      { name: 'Fonds libérés', subtitle: 'Versés au porteur après retrait', amount: fcfa(t?.totalLibere), logoClass: 'om', code: 'LIB' },
      { name: 'Fonds restitués', subtitle: 'Remboursés aux commerçants', amount: fcfa(t?.totalRestitue), logoClass: 'moov', code: 'RMB' }
    ];
  });

  setFilter(filter: 'all' | 'blocked' | 'released'): void {
    this.selectedFilter.set(filter);
    this.limite.set(20);
  }

  voirPlus(): void {
    this.limite.update(l => l + 50);
  }

  // ---------------------------------------------------------------- actions

  /** Vérifie que le total annoncé correspond à la somme des séquestres bloqués */
  rapprochement(): void {
    const t = this.tableau();
    if (!t) {
      return;
    }
    const somme = this.bloques().reduce((x, b) => x + Number(b.source.montantBloque), 0);
    const ecart = Number(t.totalBloque) - somme;
    this.message.set(
      ecart === 0
        ? `Rapprochement OK : ${fcfa(somme)} bloqués sur ${this.bloques().length} séquestre(s).`
        : `Écart de ${fcfa(ecart)} entre le total bloqué et le détail des séquestres : à vérifier.`
    );
  }

  exporterGrandLivre(): void {
    const lignes = [
      ligneCsv(['Référence', 'Paiement', 'Groupe', 'Acheteur', 'Bénéficiaire', 'Montant (FCFA)', 'Statut', 'Gelé', 'Blocage', 'Libération']),
      ...this.transactions().map(t =>
        ligneCsv([
          t.ref, t.source.paiementId, t.group, t.buyer, t.beneficiary, t.source.montantBloque, t.source.statut,
          t.source.gele ? 'oui' : 'non', dateCourte(t.source.dateBlocage), dateCourte(t.source.dateLiberation)
        ])
      )
    ];
    telechargerTexte(`grand-livre-sequestre-${new Date().toISOString().slice(0, 10)}.csv`, lignes.join('\n'));
  }

  details(t: FinanceTransaction): void {
    this.message.set(
      `${t.ref} — paiement #${t.source.paiementId}, ${t.group}, ${t.buyer} ➔ ${t.beneficiary}, ${t.amount}, ` +
        `bloqué le ${dateCourte(t.source.dateBlocage)}` +
        (t.source.dateLiberation ? `, traité le ${dateCourte(t.source.dateLiberation)}` : '') + '.'
    );
  }

  recu(t: FinanceTransaction): void {
    const pdf = new jsPDF();
    pdf.setFontSize(16);
    pdf.text('Karavan - Recu de liberation de sequestre', 14, 20);
    pdf.setFontSize(11);
    [
      `Reference : ${t.ref} (paiement #${t.source.paiementId})`,
      `Groupe : ${t.group}`,
      `Acheteur : ${t.buyer}`,
      `Beneficiaire : ${t.beneficiary}`,
      `Montant : ${t.amount}`,
      `Bloque le : ${dateCourte(t.source.dateBlocage)}`,
      `Libere le : ${dateCourte(t.source.dateLiberation)}`
    ].forEach((ligne, i) => pdf.text(ligne, 14, 34 + i * 8));
    pdf.save(`recu-${t.ref.replace('#', '')}.pdf`);
  }

  /** Litige : rembourse le commerçant (colis perdu ou litige tranché en sa faveur), après approbation */
  arbitrer(t: FinanceTransaction): void {
    const choix = prompt(
      `Arbitrage ${t.ref} (${t.amount}, ${t.buyer}) :\n1. Colis perdu\n2. Litige résolu en faveur du commerçant`,
      '2'
    );
    const motif = choix === '1' ? 'COLIS_PERDU' : choix === '2' ? 'LITIGE_RESOLU' : null;
    if (motif) {
      this.executer(this.api.demanderRemboursement(t.source.paiementId, motif),
        'Remboursement demandé : il apparaît dans l’arbitrage financier pour approbation.');
    }
  }

  approuver(r: Remboursement): void {
    const pin = prompt(`Action financière sensible : confirmez avec votre mot de passe / code PIN pour approuver le remboursement #${r.id} (${fcfa(r.montant)}) :`);
    if (!pin) {
      return;
    }
    this.auth.reauthentifier(pin).subscribe({
      next: (valide) => {
        if (!valide) {
          this.message.set('Échec d’authentification : code incorrect, opération financière annulée.');
          return;
        }
        this.executer(this.api.approuverRemboursement(r.id), `Remboursement #${r.id} approuvé : le commerçant est remboursé.`);
      },
      error: () => {
        this.message.set('Échec d’authentification : opération financière annulée.');
      }
    });
  }

  rejeter(r: Remboursement): void {
    const justification = prompt(`Justification du rejet du remboursement #${r.id} :`);
    if (justification?.trim()) {
      this.executer(this.api.rejeterRemboursement(r.id, justification.trim()), `Remboursement #${r.id} rejeté.`);
    }
  }

  forceRelease(): void {
    const r = this.remboursements()[0];
    if (r) {
      this.approuver(r);
    } else {
      this.message.set('Aucun remboursement en attente. Pour un litige, utilisez « Arbitrer » sur un séquestre bloqué.');
    }
  }

  private executer(appel: Observable<unknown>, succes: string): void {
    this.envoi.set(true);
    this.message.set('');
    appel.subscribe({
      next: () => {
        this.envoi.set(false);
        this.message.set(succes);
        this.charger();
      },
      error: e => {
        this.envoi.set(false);
        this.message.set(messageErreur(e, 'Action impossible.'));
      }
    });
  }
}
