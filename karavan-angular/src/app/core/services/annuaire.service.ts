import { Injectable, computed, inject, signal } from '@angular/core';
import { Observable, forkJoin, of } from 'rxjs';
import { catchError, finalize, map, shareReplay, tap } from 'rxjs/operators';
import { LIBELLES_TYPE } from '../permissions';
import {
  AdminApiService,
  Administrateur,
  Commercant,
  Courtier,
  Groupe,
  Grossiste,
  Sequestre
} from './admin-api.service';
import { AuthService } from './auth.service';

export type TypeActeur = 'COMMERCANT' | 'GROSSISTE' | 'COURTIER' | 'ADMINISTRATEUR';

/** Un compte de la plateforme, quel que soit son type, avec ses informations métier mises à plat */
export interface Membre {
  id: number;
  type: TypeActeur;
  nom: string;
  telephone: string;
  statut: string;
  photoUrl?: string | null;
  /** Boutique (commerçant), boutique du marché (grossiste), société d'import (courtier), matricule (admin) */
  entreprise: string | null;
  details: { libelle: string; valeur: string }[];
  dateCreation: string | null;
  /** Texte de recherche : nom, téléphone, entreprise, NIF, RCCM, licence, quartier… */
  recherche: string;
}

/** Lien d'un compte avec un autre, déduit des groupes, des séquestres et des commandes */
export interface Relation {
  membre: Membre | null;
  id: number;
  nom: string;
  type: TypeActeur;
  /** « 3 groupes en commun », « Acheteur de 2 groupes »… */
  role: string;
  groupes: number[];
}

/** Tout ce qui relie un compte au reste du réseau dɔgɔ */
export interface Reseau {
  groupes: Groupe[];
  sequestres: Sequestre[];
  partenaires: Relation[];
}

/** Minuscules sans accents : forme du champ {@link Membre.recherche} */
export function normaliser(texte: string): string {
  return texte.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
}

function membre(
  id: number,
  type: TypeActeur,
  nom: string,
  telephone: string,
  statut: string,
  photoUrl: string | null | undefined,
  entreprise: string | null,
  dateCreation: string | null,
  details: [string, string | number | null | undefined][]
): Membre {
  const lignes = details
    .filter(([, v]) => v !== null && v !== undefined && v !== '')
    .map(([libelle, v]) => ({ libelle, valeur: String(v) }));
  return {
    id,
    type,
    nom,
    telephone,
    statut,
    photoUrl: photoUrl ?? null,
    entreprise,
    details: lignes,
    dateCreation,
    recherche: normaliser([nom, telephone, entreprise, LIBELLES_TYPE[type], ...lignes.map(l => l.valeur)].join(' '))
  };
}

const deCommercant = (c: Commercant): Membre =>
  membre(c.id, 'COMMERCANT', c.nom, c.telephone, c.statut, c.photoUrl, c.nomBoutique, c.dateCreation, [
    ['Boutique', c.nomBoutique],
    ['Quartier (Bamako)', c.quartierBamako],
    ['Adresse de livraison', c.adresseLivraison],
    ['Canal de vente', c.canalVente]
  ]);

const deGrossiste = (g: Grossiste): Membre =>
  membre(g.id, 'GROSSISTE', g.nom, g.telephone, g.statut, g.photoUrl, g.nomBoutiqueMarche, g.dateCreation, [
    ['Boutique / marché', g.nomBoutiqueMarche],
    ['NIF', g.numeroNif],
    ['Registre du commerce', g.registreCommerce],
    ['Note de fiabilité', g.noteFiabilite]
  ]);

const deCourtier = (c: Courtier): Membre =>
  membre(c.id, 'COURTIER', c.nom, c.telephone, c.statut, c.photoUrl, c.nomSocieteImport, c.dateCreation, [
    ['Société d’import', c.nomSocieteImport],
    ['Licence de transit', c.licenceTransit],
    ['Adresse du dépôt', c.adresseDepot],
    ['Note de fiabilité', c.noteFiabilite]
  ]);

const deAdministrateur = (a: Administrateur): Membre =>
  membre(a.id, 'ADMINISTRATEUR', a.nom, a.telephone, a.statut, a.photoUrl, a.matricule, a.dateCreation, [
    ['Matricule', a.matricule],
    ['Rôle administratif', a.roleAdministratif]
  ]);

/**
 * Annuaire unique des comptes (commerçants, grossistes, courtiers et, pour le rôle TECHNIQUE, administrateurs)
 * et calcul des liens entre eux : un grossiste est relié aux courtiers qui montent des groupes sur ses produits et
 * aux commerçants qui les achètent ; un courtier à ses grossistes fournisseurs et à ses acheteurs ; un commerçant
 * aux grossistes et courtiers des groupes qu'il a payés. Chaque liste est lue à la demande (permissions du rôle).
 */
@Injectable({ providedIn: 'root' })
export class AnnuaireService {
  private readonly api = inject(AdminApiService);
  private readonly auth = inject(AuthService);
  private enCours?: Observable<Membre[]>;

  readonly membres = signal<Membre[]>([]);
  readonly groupes = signal<Groupe[]>([]);
  readonly sequestres = signal<Sequestre[]>([]);
  readonly charge = signal(false);
  readonly chargement = signal(false);

  private readonly parId = computed(() => new Map(this.membres().map(m => [m.id, m])));

  /** Relit les comptes, les groupes et les séquestres ; les appels partagent la même requête en vol */
  charger(force = false): Observable<Membre[]> {
    if (this.enCours) {
      return this.enCours;
    }
    if (this.charge() && !force) {
      return of(this.membres());
    }
    // Une liste refusée (403 selon le rôle) ou en erreur n'empêche pas d'afficher les autres
    const vide = <T>(o: Observable<T[]>): Observable<T[]> => o.pipe(catchError(() => of([] as T[])));
    this.chargement.set(true);
    this.enCours = forkJoin({
      commercants: vide<Commercant>(this.api.commercants()),
      grossistes: vide<Grossiste>(this.api.grossistes()),
      courtiers: vide<Courtier>(this.api.courtiers()),
      administrateurs: this.auth.peut('ADMIN_CREER') ? vide<Administrateur>(this.api.administrateurs()) : of([] as Administrateur[]),
      groupes: vide<Groupe>(this.api.groupes()),
      sequestres: this.auth.peut('REMBOURSEMENT_APPROUVER', 'AUDIT_LIRE', 'PORTEFEUILLE_RETIRER')
        ? vide<Sequestre>(this.api.sequestres().pipe(map(t => t?.sequestres ?? [])))
        : of([] as Sequestre[])
    }).pipe(
      map(r => {
        this.groupes.set(r.groupes ?? []);
        this.sequestres.set(r.sequestres ?? []);
        return [
          ...(r.grossistes ?? []).map(deGrossiste),
          ...(r.courtiers ?? []).map(deCourtier),
          ...(r.commercants ?? []).map(deCommercant),
          ...(r.administrateurs ?? []).map(deAdministrateur)
        ];
      }),
      tap(liste => {
        this.membres.set(liste);
        this.charge.set(true);
      }),
      finalize(() => {
        this.chargement.set(false);
        this.enCours = undefined;
      }),
      shareReplay(1)
    );
    return this.enCours;
  }

  membre(id: number): Membre | null {
    return this.parId().get(id) ?? null;
  }

  /** Recherche insensible aux accents et à la casse sur tous les champs du compte */
  rechercher(texte: string, limite = 8): Membre[] {
    const mots = normaliser(texte).split(/\s+/).filter(Boolean);
    if (!mots.length) {
      return [];
    }
    return this.membres().filter(m => mots.every(mot => m.recherche.includes(mot))).slice(0, limite);
  }

  /** Groupes d'un compte : ceux qu'il fournit (grossiste), pilote (courtier) ou a payés (commerçant) */
  groupesDe(m: Membre): Groupe[] {
    const groupes = this.groupes();
    switch (m.type) {
      case 'GROSSISTE':
        return groupes.filter(g => g.grossiste?.id === m.id);
      case 'COURTIER':
        return groupes.filter(g => g.courtier?.id === m.id);
      case 'COMMERCANT': {
        const ids = new Set(this.sequestresDe(m).map(s => s.groupeId));
        return groupes.filter(g => ids.has(g.id));
      }
      default:
        return [];
    }
  }

  /** Séquestres où le compte est acheteur, bénéficiaire, grossiste ou courtier */
  sequestresDe(m: Membre): Sequestre[] {
    return this.sequestres().filter(
      s => s.acheteurId === m.id || s.beneficiaireId === m.id || s.grossisteId === m.id || s.courtierId === m.id
    );
  }

  /**
   * Réseau d'un compte. `acheteursConnus` complète les séquestres avec les commandes déjà lues
   * (commerçants des groupes en acheminement), pour les rôles qui n'ont pas accès aux finances.
   */
  reseau(m: Membre, acheteursConnus: { groupeId: number; commercantId: number | null; commercantNom: string | null }[] = []): Reseau {
    const groupes = this.groupesDe(m);
    const sequestres = this.sequestresDe(m);
    const liens = new Map<string, Relation>();
    const lier = (id: number | null | undefined, nom: string | null | undefined, type: TypeActeur, groupeId: number) => {
      if (id === null || id === undefined || id === m.id) {
        return;
      }
      const cle = `${type}:${id}`;
      const lien = liens.get(cle) ?? { membre: this.membre(id), id, nom: nom || this.membre(id)?.nom || `#${id}`, type, role: '', groupes: [] };
      if (!lien.groupes.includes(groupeId)) {
        lien.groupes.push(groupeId);
      }
      liens.set(cle, lien);
    };

    const ids = new Set(groupes.map(g => g.id));
    for (const g of groupes) {
      lier(g.grossiste?.id, g.grossiste?.nom, 'GROSSISTE', g.id);
      lier(g.courtier?.id, g.courtier?.nom, 'COURTIER', g.id);
    }
    if (m.type !== 'COMMERCANT') {
      for (const s of this.sequestres().filter(x => x.groupeId !== null && ids.has(x.groupeId))) {
        lier(s.acheteurId, s.acheteur, 'COMMERCANT', s.groupeId!);
      }
      for (const c of acheteursConnus.filter(x => ids.has(x.groupeId))) {
        lier(c.commercantId, c.commercantNom, 'COMMERCANT', c.groupeId);
      }
    }

    const partenaires = [...liens.values()].map(l => ({ ...l, role: this.role(m.type, l) }));
    const ordre: TypeActeur[] = ['GROSSISTE', 'COURTIER', 'COMMERCANT', 'ADMINISTRATEUR'];
    partenaires.sort((a, b) => ordre.indexOf(a.type) - ordre.indexOf(b.type) || b.groupes.length - a.groupes.length);
    return { groupes, sequestres, partenaires };
  }

  private role(moi: TypeActeur, l: Relation): string {
    const n = l.groupes.length;
    const pluriel = `${n} groupe${n > 1 ? 's' : ''}`;
    switch (l.type) {
      case 'GROSSISTE':
        return moi === 'COMMERCANT' ? `Fournisseur de ${pluriel} payé(s)` : `Fournisseur de ${pluriel}`;
      case 'COURTIER':
        return moi === 'GROSSISTE' ? `A monté ${pluriel} sur ses produits` : `Courtier de ${pluriel}`;
      case 'COMMERCANT':
        return `Acheteur de ${pluriel}`;
      default:
        return pluriel;
    }
  }
}
