import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { dateCourte, messageErreur, urlImage } from '../../core/api';
import { LIBELLES_COMPTE, LIBELLES_ROLE_ADMIN } from '../../core/permissions';
import { AdminApiService, Administrateur, NouvelAdministrateur, RoleAdministratif } from '../../core/services/admin-api.service';
import { AnnuaireService } from '../../core/services/annuaire.service';
import { AuthService } from '../../core/services/auth.service';
import { AdminSecuriteService } from '../../core/services/admin-securite.service';

const MISSIONS: Record<RoleAdministratif, string> = {
  TECHNIQUE: 'Accès complet : supervision système, gestion des comptes admins, configuration des points de retrait (Seul rôle avec tous les accès)',
  VALIDATION: 'KYC & Stocks : validation des dossiers grossistes/courtiers et conformité des stocks',
  FINANCE: 'Finances : libération des séquestres, gestion des remboursements et validation des virements',
  SUPPORT: 'Support : suivi des utilisateurs, litiges et réclamations, assistance commerçants/grossistes/courtiers et diffusion d’informations',
  LOGISTIQUE: 'Logistique : suivi des colis, étapes de livraison, localisation des dépôts Google Maps et validation des retraits'
};

/**
 * Équipe d'administration : chaque administrateur a un rôle (TECHNIQUE, VALIDATION, FINANCE, SUPPORT) qui fixe
 * ses permissions. Seul un administrateur TECHNIQUE peut en créer un autre (RG-06).
 */
@Component({
  selector: 'app-administrateurs',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './administrateurs.html',
  styleUrl: './administrateurs.scss'
})
export class AdministrateursComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  private readonly annuaire = inject(AnnuaireService);
  private readonly securite = inject(AdminSecuriteService);
  readonly auth = inject(AuthService);

  readonly liste = signal<Administrateur[]>([]);
  readonly chargement = signal(true);
  readonly erreur = signal('');
  readonly message = signal('');
  readonly echec = signal(false);
  readonly envoi = signal(false);

  readonly roles = Object.keys(MISSIONS) as RoleAdministratif[];
  readonly missions = MISSIONS;
  readonly libellesRole = LIBELLES_ROLE_ADMIN;
  readonly libellesCompte = LIBELLES_COMPTE;
  readonly dateCourte = dateCourte;
  readonly urlImage = urlImage;

  nouveau: NouvelAdministrateur = this.vide();

  ngOnInit(): void {
    this.charger();
  }

  charger(): void {
    this.chargement.set(true);
    this.erreur.set('');
    this.api.administrateurs().subscribe({
      next: l => {
        this.liste.set(l ?? []);
        this.chargement.set(false);
      },
      error: e => {
        this.erreur.set(messageErreur(e, 'Impossible de charger les administrateurs.'));
        this.chargement.set(false);
      }
    });
  }

  readonly parRole = computed(() => {
    const c = new Map<string, number>();
    this.liste().forEach(a => c.set(a.roleAdministratif, (c.get(a.roleAdministratif) ?? 0) + 1));
    return c;
  });

  readonly estTechnique = computed(() => this.liste().some(a => a.id === this.auth.obtenirProfil()?.id && a.roleAdministratif === 'TECHNIQUE'));

  async creer(): Promise<void> {
    const a = { ...this.nouveau, telephone: this.nouveau.telephone.trim(), nom: this.nouveau.nom.trim(), matricule: this.nouveau.matricule.trim() };
    const mdp = (a.motDePasse || a.pin || '').trim();
    const valide = mdp.length >= 8 && /[A-Z]/.test(mdp) && /[a-z]/.test(mdp) && /[0-9]/.test(mdp);
    if (!valide) {
      this.echec.set(true);
      this.message.set('Le mot de passe doit comporter au moins 8 caractères, dont une majuscule, une minuscule et un chiffre.');
      return;
    }

    try {
      await this.securite.demanderConfirmation({
        titre: 'Création d’un nouvel administrateur',
        description: `Création du compte administrateur « ${a.nom} » avec le rôle ${LIBELLES_ROLE_ADMIN[a.role]}.`,
        actionTexte: 'Créer l’administrateur',
        icone: 'admin_panel_settings'
      });
      this.envoi.set(true);
      this.message.set('');
      this.api.creerAdministrateur({ ...a, motDePasse: mdp, pin: mdp }).subscribe({
        next: () => {
          this.envoi.set(false);
          this.echec.set(false);
          this.message.set(`${a.nom} (${LIBELLES_ROLE_ADMIN[a.role]}) peut se connecter avec ${a.telephone} et son mot de passe.`);
          this.nouveau = this.vide();
          this.charger();
          this.annuaire.charger(true).subscribe({ error: () => undefined });
        },
        error: e => {
          this.envoi.set(false);
          this.echec.set(true);
          this.message.set(messageErreur(e, 'Création impossible.'));
        }
      });
    } catch {
      // Annulé
    }
  }

  private vide(): NouvelAdministrateur {
    return { telephone: '', nom: '', motDePasse: '', pin: '', matricule: '', role: 'SUPPORT' };
  }
}
