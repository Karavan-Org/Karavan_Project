import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter } from '@angular/router';
import { AdministrateursComponent } from './administrateurs';

describe('AdministrateursComponent', () => {
  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [AdministrateursComponent],
      providers: [provideHttpClient(), provideHttpClientTesting(), provideRouter([])]
    }).compileComponents();
  });

  it('se crée sans erreur', () => {
    const fixture = TestBed.createComponent(AdministrateursComponent);
    fixture.detectChanges();
    expect(fixture.componentInstance).toBeTruthy();
  });
});
