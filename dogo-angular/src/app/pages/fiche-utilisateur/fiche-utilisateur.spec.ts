import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter } from '@angular/router';
import { FicheUtilisateurComponent } from './fiche-utilisateur';

describe('FicheUtilisateurComponent', () => {
  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [FicheUtilisateurComponent],
      providers: [provideHttpClient(), provideHttpClientTesting(), provideRouter([])]
    }).compileComponents();
  });

  it('se crée sans erreur', () => {
    const fixture = TestBed.createComponent(FicheUtilisateurComponent);
    fixture.detectChanges();
    expect(fixture.componentInstance).toBeTruthy();
  });
});
