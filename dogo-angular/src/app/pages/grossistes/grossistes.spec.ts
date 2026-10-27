import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter } from '@angular/router';
import { GrossistesComponent } from './grossistes';

describe('GrossistesComponent', () => {
  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [GrossistesComponent],
      providers: [provideHttpClient(), provideHttpClientTesting(), provideRouter([])]
    }).compileComponents();
  });

  it('se crée sans erreur', () => {
    const fixture = TestBed.createComponent(GrossistesComponent);
    fixture.detectChanges();
    expect(fixture.componentInstance).toBeTruthy();
  });
});
