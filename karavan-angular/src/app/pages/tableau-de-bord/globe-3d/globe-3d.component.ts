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
  ViewChild,
  inject
} from '@angular/core';
import { CommonModule, isPlatformBrowser } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { MatIconModule } from '@angular/material/icon';
import { GroupeCadranVue, RepartitionPaysVue } from '../tableau-de-bord.service';
import { PaysResolverService } from '../../../core/services/pays-resolver.service';

/** Densité de pixels maximale du rendu WebGL (au-delà, coût GPU sans gain visible) */
const PIXEL_RATIO_MAX = 1.5;
/** Frontières juste au-dessus de la texture, sous les pays teintés (altitude 0.004) */
const ALTITUDE_FRONTIERES = 0.002;
/** Durée d'un déplacement de caméra vers un pays */
const DUREE_CAMERA_MS = 900;

function echapperHtml(texte: string): string {
  return String(texte ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]!));
}

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
      <!-- Canevas WebGL Globe 3D -->
      <div #globeDiv class="globe-viewport"></div>

      <!-- Superposition des commandes du globe -->
      <div class="globe-overlay-top">
        <div class="hub-badge">
          <span class="fi fi-ml hub-drapeau"></span>
          <span class="hub-label">Hub de destination : <strong>Bamako, Mali</strong></span>
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
      background: linear-gradient(180deg, #13212F 0%, #0C1620 100%);
      border-radius: 16px;
      overflow: hidden;
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
      gap: 8px;
      background: rgba(255, 255, 255, 0.96);
      padding: 6px 12px;
      border-radius: 8px;
      border: 1px solid rgba(15, 23, 42, 0.08);
      color: #1F2937;
      font-size: 12.5px;
      pointer-events: auto;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.25);
    }

    .hub-drapeau {
      width: 18px;
      height: 13px;
      border-radius: 2px;
      box-shadow: inset 0 0 0 0.5px rgba(0, 0, 0, 0.15);
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
      background: rgba(255, 255, 255, 0.08);
      border: 1px solid rgba(255, 255, 255, 0.16);
      color: #E5E7EB;
      font-size: 12px;
      font-weight: 600;
      padding: 6px 12px;
      border-radius: 8px;
      cursor: pointer;
      transition: background 0.15s ease, border-color 0.15s ease;

      mat-icon {
        font-size: 16px;
        width: 16px;
        height: 16px;
      }

      &:hover {
        background: rgba(255, 255, 255, 0.14);
        border-color: rgba(255, 255, 255, 0.28);
      }

      &.active {
        background: #FFFFFF;
        border-color: #FFFFFF;
        color: #111827;
      }
    }

    .filtre-actif-pill {
      position: absolute;
      top: 58px;
      left: 74px;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: #FFFFFF;
      border: 1px solid rgba(15, 23, 42, 0.08);
      color: #1F2937;
      font-size: 12px;
      padding: 5px 10px;
      border-radius: 8px;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.25);
      z-index: 10;

      .btn-fermer-filtre {
        background: transparent;
        border: none;
        color: #6B7280;
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

  private readonly paysResolver = inject(PaysResolverService);
  private globeInstance: any = null;
  autoRotationActive = true;
  private resizeObserver: ResizeObserver | null = null;
  /** Module three.js chargé à la demande avec globe.gl (même version, déjà dans le bundle de la page) */
  private three: any = null;
  private paysGeoJson: any[] = [];
  private frontieres: any = null;
  private repriseRotation?: ReturnType<typeof setTimeout>;
  private suspenduParPage = false;

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
    clearTimeout(this.repriseRotation);
    document.removeEventListener('visibilitychange', this.surVisibilite);
    this.frontieres?.geometry.dispose();
    this.frontieres?.material.dispose();
    if (this.globeInstance?._destructor) {
      this.globeInstance._destructor();
    }
  }

  private async initialiserGlobe(): Promise<void> {
    try {
      const [{ default: Globe }, THREE] = await Promise.all([import('globe.gl'), import('three')]);
      this.three = THREE;
      const container = this.globeDiv.nativeElement;
      const largeur = container.clientWidth || 800;
      const hauteur = container.clientHeight || 600;

      this.globeInstance = new Globe(container, {
        rendererConfig: { antialias: true, alpha: true, powerPreference: 'high-performance' }
      })
        .width(largeur)
        .height(hauteur)
        .backgroundColor('rgba(0, 0, 0, 0)')
        .showAtmosphere(true)
        .atmosphereColor('#A9BCD0')
        .atmosphereAltitude(0.1)
        .globeImageUrl('//unpkg.com/three-globe/example/img/earth-blue-marble.jpg')
        .arcStartLat('startLat')
        .arcStartLng('startLng')
        .arcEndLat('endLat')
        .arcEndLng('endLng')
        .arcColor('color')
        .arcAltitude(0.2)
        .arcStroke('stroke')
        // Pas de morphing des arcs, polygones et étiquettes à chaque mise à jour des données
        .arcsTransitionDuration(0)
        .polygonsTransitionDuration(0)
        .htmlTransitionDuration(0)
        // Étiquettes passées derrière la planète : masquées plutôt que superposées à l'hémisphère visible
        .htmlElementVisibilityModifier((el: HTMLElement, visible: boolean) => {
          el.style.opacity = visible ? '1' : '0';
          el.style.pointerEvents = visible ? 'auto' : 'none';
        })
        .htmlElementsData([])
        .htmlElement((d: any) => {
          const el = document.createElement('div');
          el.style.transform = 'translate(-50%, -100%)';
          el.style.cursor = d.isHub ? 'default' : 'pointer';
          const code = d.isHub ? 'ml' : String(d.codeIso).toLowerCase().replace(/[^a-z]/g, '');
          const libelle = d.isHub ? 'Bamako' : echapperHtml(d.name);
          const compteur = d.isHub
            ? '<span style="color:#6B7280; font-weight:500;">Destination</span>'
            : `<span style="color:#6B7280; font-weight:500;">${d.nombreGroupes} groupe${d.nombreGroupes > 1 ? 's' : ''}</span>`;
          el.innerHTML = `
            <div style="display:flex; flex-direction:column; align-items:center;">
              <div style="background:#FFFFFF; color:#111827; padding:4px 8px; border-radius:6px; font:600 11px/1.2 var(--font-texte, sans-serif); border:1px solid rgba(15,23,42,0.08); box-shadow:0 2px 6px rgba(0,0,0,0.3); white-space:nowrap; display:flex; align-items:center; gap:6px;">
                <span class="fi fi-${code}" style="width:16px; height:12px; border-radius:2px; box-shadow:inset 0 0 0 0.5px rgba(0,0,0,0.15);"></span>
                <span>${libelle}</span>
                ${compteur}
              </div>
              <div style="width:1px; height:8px; background:rgba(255,255,255,0.7);"></div>
              <div style="width:5px; height:5px; border-radius:50%; background:#FFFFFF;"></div>
            </div>
          `;
          if (!d.isHub) {
            el.onclick = () => {
              this.selectionnerPays(d.codeIso);
              if (d.groupePrincipal) {
                this.groupeChoisi.emit(d.groupePrincipal);
              }
            };
          }
          return el;
        });

      // Densité de pixels plafonnée : sur un écran haute résolution, le rendu natif coûte jusqu'à 4× plus de
      // pixels pour une différence invisible sur une sphère texturée en mouvement
      this.globeInstance.renderer().setPixelRatio(Math.min(window.devicePixelRatio || 1, PIXEL_RATIO_MAX));

      // Vue initiale centrée au-dessus de l'Afrique et surélevée (altitude 1.82) pour dégager les pins des cartes
      this.animerCamera({ lat: 18, lng: 4, altitude: 1.82 }, 1000);

      const controls = this.globeInstance.controls();
      controls.autoRotate = true;
      controls.autoRotateSpeed = 0.4;
      controls.enableDamping = true;
      controls.dampingFactor = 0.08;
      controls.rotateSpeed = 0.6;
      controls.zoomSpeed = 0.8;

      // Onglet masqué : aucune image calculée en arrière-plan
      document.addEventListener('visibilitychange', this.surVisibilite);

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
        this.paysGeoJson = geoJson.features ?? [];
        this.tracerFrontieres(this.paysGeoJson);
        this.mettreAJourPaysTeintes();
      },
      error: () => {}
    });
  }

  /**
   * Toutes les frontières en UN seul maillage de segments (un seul appel de dessin), au lieu d'un polygone 3D
   * transparent par pays (~350 objets triés et dessinés à chaque image) : c'était la principale cause de saccades.
   */
  private tracerFrontieres(features: any[]): void {
    const THREE = this.three;
    if (!THREE || !this.globeInstance) return;
    const sommets: number[] = [];
    const ajouterAnneau = (anneau: number[][]) => {
      for (let i = 0; i < anneau.length - 1; i++) {
        const a = this.globeInstance.getCoords(anneau[i][1], anneau[i][0], ALTITUDE_FRONTIERES);
        const b = this.globeInstance.getCoords(anneau[i + 1][1], anneau[i + 1][0], ALTITUDE_FRONTIERES);
        sommets.push(a.x, a.y, a.z, b.x, b.y, b.z);
      }
    };
    for (const f of features) {
      const g = f.geometry;
      if (g?.type === 'Polygon') {
        g.coordinates.forEach(ajouterAnneau);
      } else if (g?.type === 'MultiPolygon') {
        g.coordinates.forEach((poly: number[][][]) => poly.forEach(ajouterAnneau));
      }
    }
    const geometrie = new THREE.BufferGeometry();
    geometrie.setAttribute('position', new THREE.Float32BufferAttribute(sommets, 3));
    this.frontieres = new THREE.LineSegments(geometrie,
      new THREE.LineBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.22, depthWrite: false }));
    this.globeInstance.scene().add(this.frontieres);
  }

  /** Seuls le Mali et les pays d'origine des groupes restent des polygones (teinte), soit une poignée d'objets */
  private mettreAJourPaysTeintes(): void {
    if (!this.globeInstance || !this.paysGeoJson.length) return;
    const origines = new Set(this.repartitionPays.map(p => p.codeIso?.toUpperCase()));
    (this.groupes || []).forEach(g => g.paysOrigine?.codeIso && origines.add(g.paysOrigine.codeIso.toUpperCase()));
    // Natural Earth code France/Norvège en ISO_A2 = -99 : ISO_A2_EH porte le vrai code
    const codeDe = (d: any) => d.properties?.ISO_A2_EH || d.properties?.ISO_A2;
    this.globeInstance
      .polygonsData(this.paysGeoJson.filter(d => codeDe(d) === 'ML' || origines.has(codeDe(d))))
      .polygonAltitude(0.004)
      .polygonSideColor(() => 'rgba(0, 0, 0, 0)')
      .polygonStrokeColor(() => false)
      .polygonCapColor((d: any) => codeDe(d) === 'ML' ? 'rgba(255, 255, 255, 0.35)' : 'rgba(238, 168, 35, 0.35)');
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
      const groupesDuPays = (this.groupes || []).filter(
        g => g.paysOrigine?.codeIso?.toUpperCase() === pays.codeIso
      );
      const groupePrincipal = groupesDuPays[0] || null;
      const nbGroupes = Math.max(pays.nombreGroupes, groupesDuPays.length);
      const estFiltre = this.paysFiltre === pays.codeIso;
      const nomFr = this.paysResolver.resoudre(pays.codeIso).nomFr || pays.nomFr;

      arcs.push({
        startLat: pays.latitude,
        startLng: pays.longitude,
        endLat: this.BAMAKO_LAT,
        endLng: this.BAMAKO_LNG,
        color: estFiltre ? ['rgba(238, 168, 35, 0.9)', 'rgba(255, 255, 255, 0.9)'] : ['rgba(238, 168, 35, 0.55)', 'rgba(255, 255, 255, 0.55)'],
        name: nomFr,
        codeIso: pays.codeIso,
        nombreGroupes: nbGroupes,
        stroke: estFiltre ? 0.9 : 0.5
      });

      htmlPoints.push({
        lat: pays.latitude,
        lng: pays.longitude,
        name: nomFr,
        codeIso: pays.codeIso,
        nombreGroupes: nbGroupes,
        isHub: false,
        groupes: groupesDuPays,
        groupePrincipal: groupePrincipal
      });
    }

    this.globeInstance.arcsData(arcs);
    this.globeInstance.htmlElementsData(htmlPoints);
    this.mettreAJourPaysTeintes();
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
    this.animerCamera({ lat: 18, lng: 4, altitude: 1.82 }, DUREE_CAMERA_MS);
  }

  basculerRotation(): void {
    this.autoRotationActive = !this.autoRotationActive;
    if (this.globeInstance) {
      const controls = this.globeInstance.controls();
      controls.autoRotate = this.autoRotationActive;
    }
  }

  /**
   * Déplacement de caméra sans à-coup : la rotation automatique déplace elle aussi la caméra à chaque image et se
   * battait avec l'interpolation (saccades à chaque cran du cadran). Elle est suspendue le temps du trajet, puis
   * reprend si l'administrateur ne l'a pas mise en pause.
   */
  private animerCamera(vue: { lat: number; lng: number; altitude: number }, dureeMs: number): void {
    if (!this.globeInstance) return;
    const controls = this.globeInstance.controls();
    controls.autoRotate = false;
    clearTimeout(this.repriseRotation);
    this.globeInstance.pointOfView(vue, dureeMs);
    this.repriseRotation = setTimeout(() => {
      if (this.globeInstance) {
        this.globeInstance.controls().autoRotate = this.autoRotationActive;
      }
    }, dureeMs + 600);
  }

  /** Planète entièrement recouverte (tiroir ouvert) : plus aucune image calculée, le GPU sert l'animation du tiroir */
  suspendre(): void {
    this.suspenduParPage = true;
    this.globeInstance?.pauseAnimation();
  }

  reprendre(): void {
    this.suspenduParPage = false;
    if (!document.hidden) {
      this.globeInstance?.resumeAnimation();
    }
  }

  private readonly surVisibilite = (): void => {
    if (document.hidden) {
      this.globeInstance?.pauseAnimation();
    } else if (!this.suspenduParPage) {
      this.globeInstance?.resumeAnimation();
    }
  };

  private animerCameraVersPays(codeIso: string): void {
    const code = codeIso?.toUpperCase();
    const paysRep = this.repartitionPays.find(p => p.codeIso.toUpperCase() === code);
    const paysGrp = this.groupes.map(g => g.paysOrigine).find(p => p?.codeIso?.toUpperCase() === code);
    const lat = paysRep?.latitude ?? paysGrp?.latitude;
    const lng = paysRep?.longitude ?? paysGrp?.longitude;

    if (lat != null && lng != null) {
      this.animerCamera(
        {
          lat: lat * 0.72 + this.BAMAKO_LAT * 0.28,
          lng: lng * 0.72 + this.BAMAKO_LNG * 0.28,
          altitude: 1.68
        },
        DUREE_CAMERA_MS
      );
    }
  }

}
