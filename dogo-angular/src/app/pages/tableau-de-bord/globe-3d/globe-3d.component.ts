import {
  AfterViewInit,
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  EventEmitter,
  Inject,
  Input,
  OnChanges,
  OnDestroy,
  Output,
  PLATFORM_ID,
  SimpleChanges,
  ViewChild
} from '@angular/core';
import { CommonModule, isPlatformBrowser } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { MatIconModule } from '@angular/material/icon';
import { GroupeCadranVue, RepartitionPaysVue } from '../tableau-de-bord.service';

interface ArcData {
  startLat: number;
  startLng: number;
  endLat: number;
  endLng: number;
  color: string[];
  name: string;
  codeIso: string;
  nombreGroupes: number;
  stroke: number;
}

@Component({
  selector: 'app-globe-3d',
  standalone: true,
  imports: [CommonModule, MatIconModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="globe-container">
      <!-- Anneaux orbitaux concentriques / Radar halo -->
      <div class="orbital-rings-backdrop">
        <div class="orbital-ring ring-1"></div>
        <div class="orbital-ring ring-2"></div>
        <div class="orbital-ring ring-3"></div>
      </div>

      <!-- Canevas WebGL Globe 3D -->
      <div #globeDiv class="globe-viewport"></div>

      <!-- Superposition des commandes du globe -->
      <div class="globe-overlay-top">
        <div class="hub-badge">
          <span class="pulsing-dot"></span>
          <span class="hub-label">Hub Karavan : <strong>Bamako, Mali</strong></span>
        </div>

        <div class="globe-actions">
          <button
            type="button"
            class="globe-btn"
            (click)="reinitialiserVue()"
            title="Recentrer la caméra"
          >
            <mat-icon>my_location</mat-icon>
            Recentrer
          </button>
          <button
            type="button"
            class="globe-btn"
            [class.active]="autoRotationActive"
            (click)="basculerRotation()"
            [title]="autoRotationActive ? 'Arrêter la rotation auto' : 'Démarrer la rotation auto'"
          >
            <mat-icon>{{ autoRotationActive ? 'pause' : 'play_arrow' }}</mat-icon>
            {{ autoRotationActive ? 'Pause' : 'Rotation' }}
          </button>
        </div>
      </div>

      <!-- Filtre actif pays -->
      @if (paysFiltre) {
        <div class="filtre-actif-pill">
          <span>Origine : <strong>{{ paysFiltre }}</strong></span>
          <button type="button" class="btn-fermer-filtre" (click)="annulerFiltrePays()">
            <mat-icon>close</mat-icon>
          </button>
        </div>
      }
    </div>
  `,
  styles: [`
    .globe-container {
      position: relative;
      width: 100%;
      height: 100%;
      min-height: 520px;
      background: radial-gradient(circle at 50% 50%, #172544 0%, #0b1325 65%, #050a14 100%);
      border-radius: 24px;
      overflow: hidden;
    }

    .orbital-rings-backdrop {
      position: absolute;
      inset: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      pointer-events: none;
      z-index: 1;
      overflow: hidden;
    }

    .orbital-ring {
      position: absolute;
      border-radius: 50%;
      pointer-events: none;

      &.ring-1 {
        width: 480px;
        height: 480px;
        border: 1.5px solid rgba(59, 130, 246, 0.22);
        box-shadow: 0 0 50px rgba(59, 130, 246, 0.15);
      }

      &.ring-2 {
        width: 680px;
        height: 680px;
        border: 1px solid rgba(255, 255, 255, 0.08);
      }

      &.ring-3 {
        width: 880px;
        height: 880px;
        border: 1px dashed rgba(255, 255, 255, 0.05);
      }
    }

    .globe-viewport {
      position: relative;
      width: 100%;
      height: 100%;
      cursor: grab;
      z-index: 2;

      &:active {
        cursor: grabbing;
      }
    }

    .globe-overlay-top {
      position: absolute;
      top: 16px;
      left: 18px;
      right: 18px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      pointer-events: none;
      z-index: 10;
    }

    .hub-badge {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      background: rgba(15, 23, 42, 0.85);
      backdrop-filter: blur(8px);
      padding: 8px 16px;
      border-radius: 30px;
      border: 1px solid rgba(59, 130, 246, 0.35);
      color: #FAF8F5;
      font-size: 13px;
      pointer-events: auto;
      box-shadow: 0 4px 14px rgba(0, 0, 0, 0.35);
    }

    .pulsing-dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
      background: #10B981;
      box-shadow: 0 0 10px #10B981;
      animation: pulse 1.8s infinite;
    }

    @keyframes pulse {
      0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.8); }
      70% { transform: scale(1.15); box-shadow: 0 0 0 8px rgba(16, 185, 129, 0); }
      100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0); }
    }

    .globe-actions {
      display: flex;
      gap: 8px;
      pointer-events: auto;
    }

    .globe-btn {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: rgba(15, 23, 42, 0.85);
      backdrop-filter: blur(8px);
      border: 1px solid rgba(255, 255, 255, 0.15);
      color: #FAF8F5;
      font-size: 12.5px;
      font-weight: 600;
      padding: 7px 14px;
      border-radius: 20px;
      cursor: pointer;
      transition: all 0.2s ease;

      mat-icon {
        font-size: 17px;
        width: 17px;
        height: 17px;
        color: #3B82F6;
      }

      &:hover {
        background: #2563EB;
        border-color: #3B82F6;
      }

      &.active {
        border-color: #3B82F6;
        background: rgba(59, 130, 246, 0.3);
      }
    }

    .filtre-actif-pill {
      position: absolute;
      top: 66px;
      left: 18px;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: #2563EB;
      color: #FAF8F5;
      font-size: 12.5px;
      padding: 6px 14px;
      border-radius: 20px;
      box-shadow: 0 4px 14px rgba(0, 0, 0, 0.3);
      z-index: 10;

      .btn-fermer-filtre {
        background: transparent;
        border: none;
        color: #FAF8F5;
        cursor: pointer;
        display: flex;
        align-items: center;
        padding: 0;

        mat-icon {
          font-size: 16px;
          width: 16px;
          height: 16px;
        }
      }
    }
  `]
})
export class Globe3dComponent implements AfterViewInit, OnChanges, OnDestroy {
  @ViewChild('globeDiv', { static: true }) globeDiv!: ElementRef<HTMLDivElement>;

  @Input() repartitionPays: RepartitionPaysVue[] = [];
  @Input() groupes: GroupeCadranVue[] = [];
  @Input() paysFiltre: string | null = null;
  @Output() paysChoisi = new EventEmitter<string | null>();

  private globeInstance: any = null;
  autoRotationActive = true;
  private resizeObserver: ResizeObserver | null = null;

  // Coordonnées de Bamako (Point de convergence des importations)
  private readonly BAMAKO_LAT = 12.6392;
  private readonly BAMAKO_LNG = -8.0029;

  constructor(
    @Inject(PLATFORM_ID) private readonly platformId: object,
    private readonly http: HttpClient
  ) {}

  ngAfterViewInit(): void {
    if (!isPlatformBrowser(this.platformId)) return;
    this.initialiserGlobe();
  }

  ngOnChanges(changes: SimpleChanges): void {
    if ((changes['repartitionPays'] || changes['groupes']) && this.globeInstance) {
      this.mettreAJourDonneesGlobe();
    }
  }

  ngOnDestroy(): void {
    this.resizeObserver?.disconnect();
    if (this.globeInstance?._destructor) {
      this.globeInstance._destructor();
    }
  }

  private async initialiserGlobe(): Promise<void> {
    try {
      const Globe = (await import('globe.gl')).default;
      const container = this.globeDiv.nativeElement;
      const largeur = container.clientWidth || 800;
      const hauteur = container.clientHeight || 600;

      this.globeInstance = new Globe(container)
        .width(largeur)
        .height(hauteur)
        .backgroundColor('rgba(0, 0, 0, 0)')
        .showAtmosphere(true)
        .atmosphereColor('#3B82F6')
        .atmosphereAltitude(0.22)
        .globeImageUrl('//unpkg.com/three-globe/example/img/earth-blue-marble.jpg')
        .bumpImageUrl('//unpkg.com/three-globe/example/img/earth-topology.png')
        .arcStartLat('startLat')
        .arcStartLng('startLng')
        .arcEndLat('endLat')
        .arcEndLng('endLng')
        .arcColor('color')
        .arcAltitude(0.22)
        .arcStroke('stroke')
        .arcDashLength(0.4)
        .arcDashGap(0.2)
        .arcDashInitialGap(() => Math.random())
        .arcDashAnimateTime(2000)
        .htmlElementsData([])
        .htmlElement((d: any) => {
          const el = document.createElement('div');
          el.style.transform = 'translate(-50%, -100%)';
          el.style.cursor = 'pointer';

          if (d.isHub) {
            el.innerHTML = `
              <div style="display:flex; flex-direction:column; align-items:center;">
                <div style="background:#10B981; color:#FFFFFF; padding:4px 8px; border-radius:12px; font-size:10px; font-weight:700; box-shadow:0 0 16px rgba(16,185,129,0.8); border:1px solid #FFFFFF; white-space:nowrap;">
                  🇲🇱 Bamako
                </div>
                <div style="width:2px; height:8px; background:#10B981;"></div>
                <div style="width:8px; height:8px; border-radius:50%; background:#10B981; border:2px solid #FFF;"></div>
              </div>
            `;
          } else {
            const couleur = d.couleur || '#3B82F6';
            el.innerHTML = `
              <div style="display:flex; flex-direction:column; align-items:center; transition:transform 0.2s;" onmouseover="this.style.transform='scale(1.15)'" onmouseout="this.style.transform='scale(1)'">
                <div style="background:${couleur}; color:#FFFFFF; padding:3px 8px; border-radius:14px; font-size:11px; font-weight:700; box-shadow:0 0 12px ${couleur}, 0 4px 8px rgba(0,0,0,0.5); border:1.5px solid #FFFFFF; white-space:nowrap; display:flex; align-items:center; gap:4px;">
                  <span>${d.drapeau || '📍'}</span>
                  <span>${d.name}</span>
                </div>
                <div style="width:0; height:0; border-left:5px solid transparent; border-right:5px solid transparent; border-top:6px solid ${couleur}; margin-top:-1px;"></div>
                <div style="width:6px; height:6px; border-radius:50%; background:${couleur}; box-shadow:0 0 8px ${couleur}; margin-top:1px;"></div>
              </div>
            `;
            el.onclick = () => this.selectionnerPays(d.codeIso);
          }
          return el;
        });

      // Vue initiale centrée sur l'Afrique / corridors d'importation
      this.globeInstance.pointOfView({ lat: 14, lng: 2, altitude: 1.55 }, 1000);

      const controls = this.globeInstance.controls();
      controls.autoRotate = true;
      controls.autoRotateSpeed = 0.4;
      controls.enableDamping = true;
      controls.dampingFactor = 0.08;

      this.chargerContoursGeoJson();
      this.mettreAJourDonneesGlobe();

      this.resizeObserver = new ResizeObserver(entries => {
        for (const entry of entries) {
          const { width, height } = entry.contentRect;
          if (width > 0 && height > 0) {
            this.globeInstance?.width(width).height(height);
          }
        }
      });
      this.resizeObserver.observe(container);
    } catch (err) {
      console.warn('GlobeGL fallback :', err);
    }
  }

  private chargerContoursGeoJson(): void {
    this.http.get('/assets/geo/ne_110m_admin_0_countries.geojson').subscribe({
      next: (geoJson: any) => {
        if (!this.globeInstance) return;
        this.globeInstance
          .hexPolygonsData(geoJson.features)
          .hexPolygonResolution(3)
          .hexPolygonMargin(0.3)
          .hexPolygonColor((d: any) => {
            const code = d.properties?.ISO_A2 || d.properties?.ADM0_A3;
            if (code === 'MLI' || code === 'ML') return '#10B981';
            const aDesGroupes = this.repartitionPays.some(p => p.codeIso === code);
            return aDesGroupes ? '#3B82F6' : 'rgba(255, 255, 255, 0.08)';
          });
      },
      error: () => {}
    });
  }

  private mettreAJourDonneesGlobe(): void {
    if (!this.globeInstance) return;

    const arcs: ArcData[] = [];
    const htmlPoints: any[] = [
      {
        lat: this.BAMAKO_LAT,
        lng: this.BAMAKO_LNG,
        name: 'Bamako',
        isHub: true
      }
    ];

    const paletteCouleurs: Record<string, string> = {
      CI: '#F59E0B',
      SN: '#8B5CF6',
      MA: '#EF4444',
      GH: '#EAB308',
      CN: '#EC4899',
      TR: '#F97316',
      BR: '#3B82F6',
      FR: '#6366F1'
    };

    for (const pays of this.repartitionPays) {
      if (pays.latitude && pays.longitude) {
        const couleur = paletteCouleurs[pays.codeIso] || '#3B82F6';
        arcs.push({
          startLat: pays.latitude,
          startLng: pays.longitude,
          endLat: this.BAMAKO_LAT,
          endLng: this.BAMAKO_LNG,
          color: [couleur, '#10B981'],
          name: pays.nomFr,
          codeIso: pays.codeIso,
          nombreGroupes: pays.nombreGroupes,
          stroke: 1.8
        });

        htmlPoints.push({
          lat: pays.latitude,
          lng: pays.longitude,
          name: pays.nomFr,
          codeIso: pays.codeIso,
          nombreGroupes: pays.nombreGroupes,
          couleur: couleur,
          drapeau: this.drapeauParCode(pays.codeIso),
          isHub: false
        });
      }
    }

    this.globeInstance.arcsData(arcs);
    this.globeInstance.htmlElementsData(htmlPoints);
  }

  selectionnerPays(codeIso: string): void {
    this.paysChoisi.emit(codeIso);
    const pays = this.repartitionPays.find(p => p.codeIso === codeIso);
    if (pays && pays.latitude && pays.longitude && this.globeInstance) {
      this.globeInstance.pointOfView(
        {
          lat: (pays.latitude + this.BAMAKO_LAT) / 2,
          lng: (pays.longitude + this.BAMAKO_LNG) / 2,
          altitude: 1.45
        },
        1200
      );
    }
  }

  annulerFiltrePays(): void {
    this.paysChoisi.emit(null);
    this.reinitialiserVue();
  }

  reinitialiserVue(): void {
    if (!this.globeInstance) return;
    this.globeInstance.pointOfView({ lat: 14, lng: 2, altitude: 1.55 }, 1200);
  }

  basculerRotation(): void {
    this.autoRotationActive = !this.autoRotationActive;
    if (this.globeInstance) {
      const controls = this.globeInstance.controls();
      controls.autoRotate = this.autoRotationActive;
    }
  }

  focaliserSurPays(codeIso: string): void {
    this.selectionnerPays(codeIso);
  }

  private drapeauParCode(codeIso?: string | null): string {
    if (!codeIso || codeIso.length !== 2) return '🌐';
    const c = codeIso.toUpperCase();
    const d1 = String.fromCodePoint(0x1F1E6 + (c.charCodeAt(0) - 65));
    const d2 = String.fromCodePoint(0x1F1E6 + (c.charCodeAt(1) - 65));
    return d1 + d2;
  }
}
