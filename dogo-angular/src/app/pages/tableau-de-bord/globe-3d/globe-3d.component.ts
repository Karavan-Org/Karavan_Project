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
import { RepartitionPaysVue } from '../tableau-de-bord.service';

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
      <!-- Anneaux orbitaux concentriques / Radar halo (comme sur le modèle de référence) -->
      <div class="orbital-rings-backdrop">
        <div class="orbital-ring ring-1"></div>
        <div class="orbital-ring ring-2"></div>
        <div class="orbital-ring ring-3"></div>
        <div class="orbital-ring ring-4"></div>
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
            title="Recentrer la caméra sur le Mali (Bamako)"
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

      <!-- Légende Karavan -->
      <div class="globe-legende">
        <div class="legende-item">
          <span class="ligne-flux"></span>
          <span>Flux d'importation vers Bamako</span>
        </div>
        <div class="legende-item">
          <span class="point-source"></span>
          <span>Pays partenaires actifs</span>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .globe-container {
      position: relative;
      width: 100%;
      height: 100%;
      min-height: 540px;
      background: radial-gradient(circle at 50% 50%, #2A211B 0%, #17120F 75%, #0F0B09 100%);
      border-radius: 24px;
      overflow: hidden;
      box-shadow: inset 0 2px 10px rgba(0, 0, 0, 0.4), 0 10px 36px rgba(45, 35, 28, 0.18);
      border: 1px solid rgba(238, 168, 35, 0.22);
    }

    // Anneaux orbitaux concentriques (arrière-plan inspiré de la capture de référence)
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
      transition: all 0.5s ease;

      &.ring-1 {
        width: 500px;
        height: 500px;
        border: 1.5px solid rgba(238, 168, 35, 0.22);
        box-shadow: 0 0 50px rgba(238, 168, 35, 0.12);
      }

      &.ring-2 {
        width: 660px;
        height: 660px;
        border: 1px solid rgba(255, 255, 255, 0.1);
        box-shadow: 0 0 70px rgba(143, 98, 67, 0.08);
      }

      &.ring-3 {
        width: 840px;
        height: 840px;
        border: 1px dashed rgba(255, 255, 255, 0.07);
      }

      &.ring-4 {
        width: 1020px;
        height: 1020px;
        border: 1px solid rgba(255, 255, 255, 0.04);
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
      background: rgba(45, 35, 28, 0.88);
      backdrop-filter: blur(8px);
      padding: 8px 16px;
      border-radius: 30px;
      border: 1px solid rgba(238, 168, 35, 0.4);
      color: #FAF8F5;
      font-size: 13px;
      letter-spacing: 0.2px;
      pointer-events: auto;
      box-shadow: 0 4px 14px rgba(0, 0, 0, 0.3);
    }

    .pulsing-dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
      background: #EEA823;
      box-shadow: 0 0 10px #EEA823;
      animation: pulse 1.8s infinite;
    }

    @keyframes pulse {
      0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(238, 168, 35, 0.8); }
      70% { transform: scale(1.15); box-shadow: 0 0 0 8px rgba(238, 168, 35, 0); }
      100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(238, 168, 35, 0); }
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
      background: rgba(45, 35, 28, 0.85);
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
        color: #EEA823;
      }

      &:hover {
        background: #8F6243;
        border-color: #EEA823;
      }

      &.active {
        border-color: #EEA823;
        background: rgba(238, 168, 35, 0.25);
      }
    }

    .filtre-actif-pill {
      position: absolute;
      top: 66px;
      left: 18px;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: #8F6243;
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

    .globe-legende {
      position: absolute;
      bottom: 16px;
      left: 18px;
      display: flex;
      flex-direction: column;
      gap: 6px;
      background: rgba(30, 23, 18, 0.85);
      backdrop-filter: blur(6px);
      padding: 10px 14px;
      border-radius: 12px;
      border: 1px solid rgba(255, 255, 255, 0.1);
      font-size: 11.5px;
      color: #FAF8F5;
      z-index: 10;
      pointer-events: none;
    }

    .legende-item {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .ligne-flux {
      width: 18px;
      height: 3px;
      border-radius: 2px;
      background: linear-gradient(90deg, #EEA823, #8F6243);
    }

    .point-source {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: #EEA823;
      border: 1.5px solid #FFFFFF;
    }
  `]
})
export class Globe3dComponent implements AfterViewInit, OnChanges, OnDestroy {
  @ViewChild('globeDiv', { static: true }) globeDiv!: ElementRef<HTMLDivElement>;

  @Input() repartitionPays: RepartitionPaysVue[] = [];
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
    if (changes['repartitionPays'] && this.globeInstance) {
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
      const largeur = container.clientWidth || 700;
      const hauteur = container.clientHeight || 560;

      this.globeInstance = new Globe(container)
        .width(largeur)
        .height(hauteur)
        .backgroundColor('rgba(0, 0, 0, 0)')
        .showAtmosphere(true)
        .atmosphereColor('#8F6243')
        .atmosphereAltitude(0.16)
        .globeImageUrl('//unpkg.com/three-globe/example/img/earth-night.jpg')
        .bumpImageUrl('//unpkg.com/three-globe/example/img/earth-topology.png')
        .arcStartLat('startLat')
        .arcStartLng('startLng')
        .arcEndLat('endLat')
        .arcEndLng('endLng')
        .arcColor('color')
        .arcAltitude(0.24)
        .arcStroke('stroke')
        .arcDashLength(0.4)
        .arcDashGap(0.2)
        .arcDashInitialGap(() => Math.random())
        .arcDashAnimateTime(2000)
        .htmlElementsData([
          {
            lat: this.BAMAKO_LAT,
            lng: this.BAMAKO_LNG,
            name: '🇲🇱 Bamako (Hub Karavan)',
            isHub: true
          }
        ])
        .htmlElement((d: any) => {
          const el = document.createElement('div');
          if (d.isHub) {
            el.innerHTML = `
              <div style="display:flex; align-items:center; gap:6px; background:#8F6243; color:#FAF8F5; padding:4px 10px; border-radius:14px; font-size:11px; font-weight:700; border:1px solid #EEA823; box-shadow:0 0 14px rgba(238,168,35,0.7); pointer-events:none; white-space:nowrap;">
                <span style="display:inline-block; width:8px; height:8px; border-radius:50%; background:#EEA823;"></span>
                Bamako
              </div>
            `;
          } else {
            el.innerHTML = `
              <div style="cursor:pointer; background:rgba(45,35,28,0.92); color:#FAF8F5; padding:3px 8px; border-radius:12px; font-size:10.5px; font-weight:600; border:1px solid rgba(238,168,35,0.4); box-shadow:0 2px 8px rgba(0,0,0,0.4); white-space:nowrap;">
                ${d.name} (${d.nombreGroupes})
              </div>
            `;
            el.onclick = () => this.selectionnerPays(d.codeIso);
          }
          return el;
        });

      // Altitude réduite à 1.62 pour faire apparaître la planète très grosse (comme sur la capture de référence)
      this.globeInstance.pointOfView({ lat: 15, lng: 5, altitude: 1.62 }, 1000);

      // Auto-rotation fluide
      const controls = this.globeInstance.controls();
      controls.autoRotate = true;
      controls.autoRotateSpeed = 0.5;
      controls.enableDamping = true;
      controls.dampingFactor = 0.08;

      // Charger les contours des pays en GeoJSON
      this.chargerContoursGeoJson();

      // Mettre à jour les arcs et points
      this.mettreAJourDonneesGlobe();

      // Resize observer
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
            if (code === 'MLI' || code === 'ML') return '#EEA823';
            const aDesGroupes = this.repartitionPays.some(p => p.codeIso === code);
            return aDesGroupes ? '#8F6243' : 'rgba(255, 255, 255, 0.12)';
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
        name: '🇲🇱 Bamako (Hub Karavan)',
        isHub: true
      }
    ];

    for (const pays of this.repartitionPays) {
      if (pays.latitude && pays.longitude) {
        arcs.push({
          startLat: pays.latitude,
          startLng: pays.longitude,
          endLat: this.BAMAKO_LAT,
          endLng: this.BAMAKO_LNG,
          color: ['#EEA823', '#8F6243'],
          name: pays.nomFr,
          codeIso: pays.codeIso,
          nombreGroupes: pays.nombreGroupes,
          stroke: Math.min(2.5, Math.max(0.8, pays.nombreGroupes * 0.4))
        });

        htmlPoints.push({
          lat: pays.latitude,
          lng: pays.longitude,
          name: pays.nomFr,
          codeIso: pays.codeIso,
          nombreGroupes: pays.nombreGroupes,
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
    this.globeInstance.pointOfView({ lat: 15, lng: 5, altitude: 1.62 }, 1200);
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
}
