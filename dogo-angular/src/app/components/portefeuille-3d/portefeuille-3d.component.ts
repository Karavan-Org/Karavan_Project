import {
  ChangeDetectionStrategy,
  ChangeDetectorRef,
  Component,
  Input
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatIconModule } from '@angular/material/icon';

@Component({
  selector: 'app-portefeuille-3d',
  standalone: true,
  imports: [CommonModule, MatIconModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './portefeuille-3d.component.html',
  styleUrl: './portefeuille-3d.component.scss'
})
export class Portefeuille3dComponent {
  /** Montant affiché ou statut éventuel */
  @Input() soldeAffiche?: number;

  rigTransform = 'rotateX(14deg) rotateY(-18deg)';
  estSurvole = false;

  constructor(private readonly cdr: ChangeDetectorRef) {}

  onMouseMove(event: MouseEvent): void {
    const el = event.currentTarget as HTMLElement;
    if (!el) return;
    const rect = el.getBoundingClientRect();
    const x = event.clientX - rect.left - rect.width / 2;
    const y = event.clientY - rect.top - rect.height / 2;

    const rotY = (x / (rect.width / 2)) * 12 - 18;
    const rotX = -(y / (rect.height / 2)) * 10 + 14;

    this.rigTransform = `rotateX(${rotX.toFixed(1)}deg) rotateY(${rotY.toFixed(1)}deg)`;
    this.estSurvole = true;
    this.cdr.markForCheck();
  }

  onMouseLeave(): void {
    this.rigTransform = 'rotateX(14deg) rotateY(-18deg)';
    this.estSurvole = false;
    this.cdr.markForCheck();
  }
}
