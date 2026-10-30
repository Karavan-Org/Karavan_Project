import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { API_URL } from '../api';
import { Groupe, Sequestre } from './admin-api.service';
import { AnnuaireService } from './annuaire.service';
import { AuthService } from './auth.service';
import { vi } from 'vitest';

function creerAuthFactice() {
  return { peut: vi.fn((..._permissions: string[]) => true) };
}

const groupe = (id: number, grossiste: [number, string], courtier: [number, string] | null, statut = 'OUVERT'): Groupe =>
  ({
    id,
    titre: `Groupe ${id}`,
    statut,
    produit: { id, nom: 'Basket', categorie: 'Chaussures', paysOrigine: 'Chine', photoUrl: null },
    grossiste: { id: grossiste[0], nom: grossiste[1] },
    courtier: courtier && { id: courtier[0], nom: courtier[1] },
    porteParGrossiste: !courtier,
    quantiteCible: 100,
    quantiteConfirmee: 40,
    quantiteReservee: 0,
    quantiteRestante: 60,
    prixUnitaire: 5000
  }) as unknown as Groupe;

const sequestre = (id: number, groupeId: number, acheteur: [number, string], porteur: number, grossisteId: number, courtierId: number | null): Sequestre =>
  ({
    id,
    paiementId: id,
    montantBloque: 10000,
    statut: 'BLOQUE',
    gele: false,
    groupeId,
    groupeTitre: `Groupe ${groupeId}`,
    quantite: 2,
    acheteur: acheteur[1],
    acheteurId: acheteur[0],
    beneficiaireId: porteur,
    grossisteId,
    courtierId
  }) as unknown as Sequestre;

describe('AnnuaireService', () => {
  let annuaire: AnnuaireService;
  let http: HttpTestingController;
  let auth: ReturnType<typeof creerAuthFactice>;

  beforeEach(() => {
    auth = creerAuthFactice();
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting(), { provide: AuthService, useValue: auth }]
    });
    annuaire = TestBed.inject(AnnuaireService);
    http = TestBed.inject(HttpTestingController);

    annuaire.charger().subscribe();
    http.expectOne(`${API_URL}/admin/commercants`).flush([
      { id: 30, nom: 'Awa', telephone: '+22376000030', statut: 'ACTIF', nomBoutique: 'Boutique Awa', quartierBamako: 'Badalabougou' },
      { id: 31, nom: 'Moussa', telephone: '+22376000031', statut: 'SUSPENDU', nomBoutique: 'Chez Moussa' }
    ]);
    http.expectOne(`${API_URL}/admin/grossistes`).flush([
      { id: 10, nom: 'Sidibé', telephone: '+22376000010', statut: 'ACTIF', nomBoutiqueMarche: 'Dabanani', numeroNif: 'NIF-0042' }
    ]);
    http.expectOne(`${API_URL}/admin/courtiers`).flush([
      { id: 20, nom: 'Keita Import', telephone: '+22376000020', statut: 'ACTIF', nomSocieteImport: 'KI SARL' }
    ]);
    http.expectOne(`${API_URL}/admin/administrateurs`).flush([]);
    http.expectOne(`${API_URL}/admin/groupes`).flush([
      groupe(1, [10, 'Sidibé'], [20, 'Keita Import']),
      groupe(2, [10, 'Sidibé'], null)
    ]);
    http.expectOne(`${API_URL}/admin/finance/sequestres`).flush({
      sequestres: [sequestre(100, 1, [30, 'Awa'], 20, 10, 20), sequestre(101, 2, [31, 'Moussa'], 10, 10, null)]
    });
  });

  afterEach(() => {
    http.verify();
    localStorage.clear();
  });

  it('relie le grossiste à son courtier et aux commerçants qui ont payé ses groupes', () => {
    const r = annuaire.reseau(annuaire.membre(10)!);
    expect(r.groupes.map(g => g.id)).toEqual([1, 2]);
    expect(r.partenaires.map(p => `${p.type}:${p.id}`)).toEqual(['COURTIER:20', 'COMMERCANT:30', 'COMMERCANT:31']);
  });

  it('relie le courtier à son grossiste fournisseur et à ses seuls acheteurs', () => {
    const r = annuaire.reseau(annuaire.membre(20)!);
    expect(r.groupes.map(g => g.id)).toEqual([1]);
    expect(r.partenaires.map(p => `${p.type}:${p.id}`)).toEqual(['GROSSISTE:10', 'COMMERCANT:30']);
  });

  it('relie le commerçant aux grossistes et courtiers des groupes payés', () => {
    const r = annuaire.reseau(annuaire.membre(30)!);
    expect(r.groupes.map(g => g.id)).toEqual([1]);
    expect(r.partenaires.map(p => `${p.type}:${p.id}`)).toEqual(['GROSSISTE:10', 'COURTIER:20']);
    expect(r.sequestres.map(s => s.id)).toEqual([100]);
  });

  it('cherche sans accent ni casse, y compris dans le NIF et le quartier', () => {
    expect(annuaire.rechercher('sidibe').map(m => m.id)).toEqual([10]);
    expect(annuaire.rechercher('nif-0042').map(m => m.id)).toEqual([10]);
    expect(annuaire.rechercher('badalabougou awa').map(m => m.id)).toEqual([30]);
  });

  it('ne relit pas le serveur tant que les données sont chargées', () => {
    annuaire.charger().subscribe();
    http.expectNone(`${API_URL}/admin/commercants`);
  });
});
