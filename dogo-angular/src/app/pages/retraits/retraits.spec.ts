import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter } from '@angular/router';
import { RetraitsComponent } from './retraits';

describe('RetraitsComponent', () => {
  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [RetraitsComponent],
      providers: [provideHttpClient(), provideHttpClientTesting(), provideRouter([])]
    }).compileComponents();
  });

  it('se crée sans erreur', () => {
    const fixture = TestBed.createComponent(RetraitsComponent);
    fixture.detectChanges();
    expect(fixture.componentInstance).toBeTruthy();
  });
});
