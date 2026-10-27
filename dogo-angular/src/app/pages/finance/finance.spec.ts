import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter } from '@angular/router';
import { FinanceComponent } from './finance';

describe('FinanceComponent', () => {
  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [FinanceComponent],
      providers: [provideHttpClient(), provideHttpClientTesting(), provideRouter([])]
    }).compileComponents();
  });

  it('se crée sans erreur', () => {
    const fixture = TestBed.createComponent(FinanceComponent);
    fixture.detectChanges();
    expect(fixture.componentInstance).toBeTruthy();
  });
});
