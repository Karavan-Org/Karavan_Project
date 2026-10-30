import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { dateCourte, messageErreur, urlImage } from '../../core/api';
import { LIBELLES_COMPTE, LIBELLES_PERMISSION } from '../../core/permissions';
import {
  AdminApiService,
  Administrateur,
  FonctionAdministrative,
  NouvelAdministrateur,
  RoleAdministratif
} from '../../core/services/admin-api.service';
import { AnnuaireService } from '../../core/services/annuaire.service';
import { AuthService } from '../../core/services/auth.service';
import { AdminSecuriteService } from '../../core/services/admin-securite.service';

/** Règles RG-07 du backend pour un mot de passe provisoire : 4 chiffres non identiques, ou mot de passe robuste */
const CODE_4_CHIFFRES = /^\d{4}$/;
const MOT_DE_PASSE_ROBUSTE = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,64}$/;

/**
 * Équipe d'administration. L'administrateur principal (fonction TECHNIQUE, unique) crée les autres administrateurs
 * et leur attribue une fonction (Validation, Finance, Support, Logistique) qui fixe ce qu'ils peuvent faire (RG-06).
 * Chacun reçoit un mot de passe provisoire qu'il remplace à sa première connexion (RG-07b).
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
  readonly fonctions = signal<FonctionAdministrative[]>([]);
  readonly chargement = signal(true);
  readonly erreur = signal('');
  readonly message = signal('');
  readonly echec = signal(false);
  readonly envoi = signal(false);

  readonly libellesCompte = LIBELLES_COMPTE;
  readonly libellesPermission = LIBELLES_PERMISSION;
  readonly dateCourte = dateCourte;
  readonly urlImage = urlImage;

  /** Seul l'administrateur principal crée des comptes (permission ADMIN_CREER, portée par TECHNIQUE) */
  readonly peutCreer = this.auth.peut('ADMIN_CREER');

  readonly attribuables = computed(() => this.fonctions().filter(f => f.attribuable));

  nouveau: NouvelAdministrateur = this.vide();

  ngOnInit(): void {
    this.charger();
    this.api.fonctionsAdministratives().subscribe({
      next: f => this.fonctions.set(f ?? []),
      error: e => this.erreur.set(messageErreur(e, 'Impossible de charger les fonctions administratives.'))
    });
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

  fonction(role: RoleAdministratif): FonctionAdministrative | undefined {
    return this.fonctions().find(f => f.role === role);
  }

  async creer(): Promise<void> {
    const a: NouvelAdministrateur = {
      ...this.nouveau,
      telephone: this.nouveau.telephone.trim(),
      nom: this.nouveau.nom.trim(),
      email: this.nouveau.email?.trim() || undefined,
      matricule: this.nouveau.matricule.trim()
    };
    const mdp = (a.motDePasse ?? '').trim();
    const code4Valide = CODE_4_CHIFFRES.test(mdp) && new Set(mdp).size > 1;
    if (!code4Valide && !MOT_DE_PASSE_ROBUSTE.test(mdp)) {
      this.echec.set(true);
      this.message.set('Mot de passe provisoire : 4 chiffres non identiques, ou 8 caractères minimum avec majuscule, minuscule et chiffre.');
      return;
    }
    const libelle = this.fonction(a.role)?.libelle ?? a.role;

    try {
      await this.securite.demanderConfirmation({
        titre: 'Création d’un administrateur',
        description: `Création du compte « ${a.nom} » avec la fonction ${libelle}.`,
        actionTexte: 'Créer l’administrateur',
        icone: 'admin_panel_settings'
      });
    } catch {
      return; // Annulé
    }

    this.envoi.set(true);
    this.message.set('');
    this.api.creerAdministrateur({ ...a, motDePasse: mdp, pin: mdp }).subscribe({
      next: () => {
        this.envoi.set(false);
        this.echec.set(false);
        this.message.set(`${a.nom} (${libelle}) se connecte avec ${a.telephone} et le mot de passe provisoire que vous lui avez communiqué ; il devra le changer à sa première connexion.`);
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
  }

  private vide(): NouvelAdministrateur {
    return { telephone: '', nom: '', email: '', motDePasse: '', matricule: '', role: 'SUPPORT' };
  }
}
