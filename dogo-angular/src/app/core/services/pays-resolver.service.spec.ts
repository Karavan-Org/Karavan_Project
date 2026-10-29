import { TestBed } from '@angular/core/testing';
import { PaysResolverService } from './pays-resolver.service';

describe('PaysResolverService', () => {
  let pays: PaysResolverService;

  beforeEach(() => {
    pays = TestBed.inject(PaysResolverService);
  });

  it('couvre tout le référentiel ISO 3166-1', () => {
    expect(pays.tousLesPays.length).toBeGreaterThanOrEqual(249);
  });

  it('ramène codes, noms et variantes au même pays', () => {
    for (const s of ['CN', 'chn', 'Chine', 'china', 'Guangzhou']) {
      expect(pays.resoudre(s).codeIso).toBe('CN');
    }
    for (const s of ["Côte d'Ivoire", 'Côte d’Ivoire', 'cote divoire', 'CIV']) {
      expect(pays.resoudre(s).codeIso).toBe('CI');
    }
    expect(pays.resoudre('Turkey').nomFr).toBe('Turquie');
  });

  it('ne confond jamais deux pays par sous-chaîne', () => {
    expect(pays.resoudre('Niger').codeIso).toBe('NE');
    expect(pays.resoudre('Nigéria').codeIso).toBe('NG');
    expect(pays.resoudre('Somalie').codeIso).toBe('SO');
    expect(pays.resoudre('Congo').codeIso).toBe('CG');
    expect(pays.resoudre('RDC').codeIso).toBe('CD');
  });

  it('rattrape les corruptions d encodage avec points d interrogation', () => {
    expect(pays.resoudre('Br?sil').codeIso).toBe('BR');
    expect(pays.resoudre('Br?sil').nomFr).toBe('Brésil');
    expect(pays.resoudre('C?te d\'Ivoire').codeIso).toBe('CI');
    expect(pays.resoudre('B?nin').codeIso).toBe('BJ');
    expect(pays.resoudre('S?n?gal').codeIso).toBe('SN');
    expect(pays.resoudre('?tats-Unis').codeIso).toBe('US');
  });

  it('laisse une saisie inconnue telle quelle au lieu de deviner « Mali »', () => {
    const inconnu = pays.resoudre('Atlantide');
    expect(inconnu.reconnu).toBe(false);
    expect(inconnu.nomFr).toBe('Atlantide');
    expect(pays.resoudre('').reconnu).toBe(false);
  });
});
