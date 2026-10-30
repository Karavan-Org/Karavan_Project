import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { CadranGroupesComponent } from './cadran-groupes.component';
import { GroupeCadranVue } from '../tableau-de-bord.service';

function groupe(id: number): GroupeCadranVue {
  return {
    id, titre: 'Groupe ' + id, statut: 'OUVERT', quantiteCible: 10, quantiteConfirmee: 2, quantiteReservee: 1,
    progressionPourcentage: 30, prixUnitaire: 1000, dateLancement: '', dateLimite: '',
    grossiste: { id: 1, nom: 'G' }, courtier: { id: 2, nom: 'C' }
  };
}

function pointeur(type: string, x: number): PointerEvent {
  return { type, clientX: x, clientY: 0, button: 0, pointerType: 'mouse', pointerId: 1,
    target: document.createElement('div'), currentTarget: document.createElement('div') } as unknown as PointerEvent;
}

describe('CadranGroupesComponent', () => {
  let cadran: CadranGroupesComponent;

  beforeEach(() => {
    cadran = TestBed.createComponent(CadranGroupesComponent).componentInstance;
    cadran.groupes = [groupe(1), groupe(2), groupe(3)];
    cadran.ngOnChanges({ groupes: {} as never });
  });

  it('un simple clic sur une carte ouvre le détail du groupe (pas de glissement)', () => {
    const clique = vi.fn();
    cadran.groupeClique.subscribe(clique);

    cadran.onPointerDown(pointeur('pointerdown', 100));
    cadran.onPointerMove(pointeur('pointermove', 103));   // tremblement sous le seuil
    cadran.onPointerUp(pointeur('pointerup', 103));
    expect(cadran.glissementActif).toBe(false);

    const laterale = cadran.cartesVisibles.find(c => !c.estActive)!;
    cadran.clicCarte(laterale);
    expect(clique).toHaveBeenCalledWith(laterale.groupe);
  });

  it('un vrai glissement fait tourner le cadran sans ouvrir de détail', () => {
    const clique = vi.fn();
    cadran.groupeClique.subscribe(clique);

    cadran.onPointerDown(pointeur('pointerdown', 300));
    cadran.onPointerMove(pointeur('pointermove', 200));
    expect(cadran.glissementActif).toBe(true);
    cadran.onPointerUp(pointeur('pointerup', 200));

    cadran.clicCarte(cadran.cartesVisibles[0]);
    expect(clique).not.toHaveBeenCalled();
  });
});
