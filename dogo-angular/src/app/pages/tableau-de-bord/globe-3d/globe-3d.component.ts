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
        border: 1.5px solid rgba(238, 168, 35, 0.22);
        box-shadow: 0 0 50px rgba(238, 168, 35, 0.15);
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
      left: 74px; // Dégagement strict pour ne jamais chevaucher le déclencheur de statistiques
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
      background: rgba(24, 54, 48, 0.88);
      backdrop-filter: blur(10px);
      padding: 7px 15px;
      border-radius: 30px;
      border: 1px solid rgba(238, 168, 35, 0.3);
      color: #FAF8F5;
      font-size: 12.5px;
      pointer-events: auto;
      box-shadow: 0 4px 14px rgba(0, 0, 0, 0.35);
    }

    .pulsing-dot {
      width: 9px;
      height: 9px;
      border-radius: 50%;
      background: #34C759; // Olive Karavan
      box-shadow: 0 0 10px #34C759;
      animation: pulse 1.8s infinite;
    }

    @keyframes pulse {
      0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(52, 199, 89, 0.8); }
      70% { transform: scale(1.15); box-shadow: 0 0 0 8px rgba(52, 199, 89, 0); }
      100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(52, 199, 89, 0); }
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
      background: rgba(24, 54, 48, 0.85);
      backdrop-filter: blur(8px);
      border: 1px solid rgba(238, 168, 35, 0.25);
      color: #FAF8F5;
      font-size: 12px;
      font-weight: 600;
      padding: 6px 13px;
      border-radius: 20px;
      cursor: pointer;
      transition: all 0.2s ease;

      mat-icon {
        font-size: 16px;
        width: 16px;
        height: 16px;
        color: #EEA823;
      }

      &:hover {
        background: #AC7F5E;
        border-color: #EEA823;
        color: #FFFFFF;
        transform: translateY(-1px);
        box-shadow: 0 4px 12px rgba(172, 127, 94, 0.4);
      }

      &.active {
        border-color: #EEA823;
        background: rgba(172, 127, 94, 0.35);
        color: #EEA823;
      }
    }

    .filtre-actif-pill {
      position: absolute;
      top: 58px;
      left: 74px;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: #AC7F5E;
      border: 1px solid #EEA823;
      color: #FAF8F5;
      font-size: 12px;
      padding: 5px 12px;
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
  @Output() groupeChoisi = new EventEmitter<GroupeCadranVue>();

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
        .atmosphereColor('#EEA823')
        .atmosphereAltitude(0.18)
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
                <div style="background:#183630; color:#FFFFFF; padding:4px 9px; border-radius:14px; font-size:11px; font-weight:800; box-shadow:0 0 16px rgba(52,199,89,0.8); border:1.5px solid #34C759; white-space:nowrap; display:flex; align-items:center; gap:5px;">
                  <span>🇲🇱</span>
                  <span>Hub Bamako</span>
                </div>
                <div style="width:2px; height:8px; background:#34C759;"></div>
                <div style="width:6px; height:6px; border-radius:50%; background:#34C759; box-shadow:0 0 8px #34C759;"></div>
              </div>
            `;
          } else {
            const couleur = d.couleur || '#EEA823';
            const g = d.groupePrincipal;
            const nbGroupes = d.groupes?.length || d.nombreGroupes || 1;
            const multiBadge = nbGroupes > 1 ? `<span style="background:rgba(255,255,255,0.18); color:#E2E8F0; font-size:9px; padding:1px 4px; border-radius:4px; font-weight:700;">+${nbGroupes - 1}</span>` : '';

            let infoGroupeHtml = '';
            if (g) {
              const titreCourt = g.titre.length > 22 ? g.titre.slice(0, 21) + '…' : g.titre;
              const prixFmt = g.prixUnitaire ? Number(g.prixUnitaire).toLocaleString('fr-FR') : '';
              infoGroupeHtml = `
                <div style="margin-top:4px; padding-top:4px; border-top:1px solid rgba(255,255,255,0.12); display:flex; flex-direction:column; gap:2px;">
                  <div style="display:flex; align-items:center; justify-content:space-between; gap:4px;">
                    <span style="font-size:10px; font-weight:700; color:#FFFFFF; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; max-width:110px;" title="${g.titre}">
                      ${titreCourt}
                    </span>
                    <span style="font-size:9px; color:${couleur}; font-weight:800; background:rgba(238,168,35,0.18); padding:1px 4px; border-radius:4px; border:0.5px solid ${couleur}66;">
                      #${g.id}
                    </span>
                  </div>
                  <div style="display:flex; align-items:center; justify-content:space-between; gap:4px; font-size:9px;">
                    <span style="color:#EEA823; font-weight:700;">${prixFmt} F</span>
                    <span style="color:#34C759; font-weight:700;">${g.progression}%</span>
                  </div>
                </div>
              `;
            }

            el.innerHTML = `
              <div class="globe-pin-bubble" style="
                display:flex; flex-direction:column; align-items:center; transition:transform 0.25s cubic-bezier(0.2, 0.8, 0.2, 1);
                filter: drop-shadow(0 4px 12px rgba(0,0,0,0.65));
              " onmouseover="this.style.transform='scale(1.15) translateY(-4px)'" onmouseout="this.style.transform='scale(1) translateY(0)'">
                <div style="
                  background:rgba(18, 38, 34, 0.95);
                  backdrop-filter:blur(6px);
                  color:#FFFFFF;
                  padding:4px 8px;
                  border-radius:12px;
                  box-shadow:0 0 16px ${couleur}66, inset 0 1px 0 rgba(255,255,255,0.15);
                  border:1.5px solid ${couleur};
                  min-width:115px;
                  max-width:165px;
                ">
                  <div style="display:flex; align-items:center; justify-content:space-between; gap:5px;">
                    <div style="display:flex; align-items:center; gap:4px;">
                      <img src="https://flagcdn.com/w40/${d.codeIso.toLowerCase()}.png" 
                           style="width:15px; height:10px; border-radius:2px; object-fit:cover; display:inline-block;" 
                           alt="${d.codeIso}" 
                           onerror="this.style.display='none'" />
                      <span style="font-size:11px; font-weight:800; color:#FFFFFF; letter-spacing:0.2px;">${d.name}</span>
                    </div>
                    ${multiBadge}
                  </div>
                  ${infoGroupeHtml}
                </div>
                <div style="width:0; height:0; border-left:4px solid transparent; border-right:4px solid transparent; border-top:5px solid ${couleur}; margin-top:-1px;"></div>
                <div style="width:5px; height:5px; border-radius:50%; background:${couleur}; box-shadow:0 0 8px ${couleur}; margin-top:1px;"></div>
              </div>
            `;
            el.onclick = () => {
              this.selectionnerPays(d.codeIso);
              if (d.groupePrincipal) {
                this.groupeChoisi.emit(d.groupePrincipal);
              }
            };
          }
          return el;
        });

      // Vue initiale centrée au-dessus de l'Afrique et surélevée (altitude 1.82) pour dégager les pins des cartes
      this.globeInstance.pointOfView({ lat: 18, lng: 4, altitude: 1.82 }, 1000);

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
            if (code === 'MLI' || code === 'ML') return '#34C759'; // Mali : Olive officiel Karavan
            const aDesGroupes = this.repartitionPays.some(p => p.codeIso === code);
            return aDesGroupes ? '#EEA823' : 'rgba(255, 255, 255, 0.08)'; // Ocre Karavan
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
      CI: '#EEA823', // Ocre Karavan
      SN: '#AC7F5E', // Bissap Karavan
      MA: '#D97706', // Ocre terre
      GH: '#F59E0B', // Ambre doré
      CN: '#E11D48', // Rouge grenat
      TR: '#EA580C', // Terre d'Orient
      BR: '#34C759', // Vert olive
      FR: '#64748B'  // Ardoise neutre
    };

    // Indexation de tous les pays à afficher (depuis repartitionPays et depuis les groupes actifs)
    const paysMap = new Map<string, { codeIso: string; nomFr: string; latitude: number; longitude: number; nombreGroupes: number }>();

    for (const pays of this.repartitionPays) {
      if (pays.latitude && pays.longitude) {
        paysMap.set(pays.codeIso.toUpperCase(), {
          codeIso: pays.codeIso.toUpperCase(),
          nomFr: pays.nomFr,
          latitude: pays.latitude,
          longitude: pays.longitude,
          nombreGroupes: pays.nombreGroupes || 1
        });
      }
    }

    // Inclusion garantie de chaque groupe ayant un pays d'origine avec coordonnées
    for (const g of this.groupes || []) {
      const p = g.paysOrigine;
      if (p && p.codeIso && p.latitude && p.longitude) {
        const code = p.codeIso.toUpperCase();
        if (!paysMap.has(code)) {
          paysMap.set(code, {
            codeIso: code,
            nomFr: p.nomFr || code,
            latitude: p.latitude,
            longitude: p.longitude,
            nombreGroupes: 1
          });
        }
      }
    }

    for (const pays of paysMap.values()) {
      const couleur = paletteCouleurs[pays.codeIso] || '#EEA823';
      const groupesDuPays = (this.groupes || []).filter(
        g => g.paysOrigine?.codeIso?.toUpperCase() === pays.codeIso
      );
      const groupePrincipal = groupesDuPays[0] || null;
      const nbGroupes = Math.max(pays.nombreGroupes, groupesDuPays.length);

      arcs.push({
        startLat: pays.latitude,
        startLng: pays.longitude,
        endLat: this.BAMAKO_LAT,
        endLng: this.BAMAKO_LNG,
        color: [couleur, '#34C759'],
        name: pays.nomFr,
        codeIso: pays.codeIso,
        nombreGroupes: nbGroupes,
        stroke: 1.8
      });

      htmlPoints.push({
        lat: pays.latitude,
        lng: pays.longitude,
        name: pays.nomFr,
        codeIso: pays.codeIso,
        nombreGroupes: nbGroupes,
        couleur: couleur,
        drapeau: this.drapeauParCode(pays.codeIso),
        isHub: false,
        groupes: groupesDuPays,
        groupePrincipal: groupePrincipal
      });
    }

    this.globeInstance.arcsData(arcs);
    this.globeInstance.htmlElementsData(htmlPoints);
  }

  selectionnerPays(codeIso: string): void {
    this.paysChoisi.emit(codeIso);
    this.animerCameraVersPays(codeIso);
  }

  focaliserSurPays(codeIso: string): void {
    this.animerCameraVersPays(codeIso);
  }

  annulerFiltrePays(): void {
    this.paysChoisi.emit(null);
    this.reinitialiserVue();
  }

  reinitialiserVue(): void {
    if (!this.globeInstance) return;
    this.globeInstance.pointOfView({ lat: 18, lng: 4, altitude: 1.82 }, 1200);
  }

  basculerRotation(): void {
    this.autoRotationActive = !this.autoRotationActive;
    if (this.globeInstance) {
      const controls = this.globeInstance.controls();
      controls.autoRotate = this.autoRotationActive;
    }
  }

  private animerCameraVersPays(codeIso: string): void {
    const code = codeIso?.toUpperCase();
    const paysRep = this.repartitionPays.find(p => p.codeIso.toUpperCase() === code);
    const paysGrp = this.groupes.map(g => g.paysOrigine).find(p => p?.codeIso?.toUpperCase() === code);
    const lat = paysRep?.latitude ?? paysGrp?.latitude;
    const lng = paysRep?.longitude ?? paysGrp?.longitude;

    if (lat != null && lng != null && this.globeInstance) {
      this.globeInstance.pointOfView(
        {
          lat: lat * 0.72 + this.BAMAKO_LAT * 0.28,
          lng: lng * 0.72 + this.BAMAKO_LNG * 0.28,
          altitude: 1.68
        },
        1200
      );
    }
  }

  private drapeauParCode(codeIso?: string | null): string {
    if (!codeIso || codeIso.length !== 2) return '🌐';
    const c = codeIso.toUpperCase();
    const d1 = String.fromCodePoint(0x1F1E6 + (c.charCodeAt(0) - 65));
    const d2 = String.fromCodePoint(0x1F1E6 + (c.charCodeAt(1) - 65));
    return d1 + d2;
  }
}
