import { Injectable } from '@angular/core';

export interface PaysInfo {
  codeIso: string;
  nomFr: string;
  nomEn: string;
  drapeauEmoji: string;
}

@Injectable({
  providedIn: 'root'
})
export class PaysResolverService {
  private static readonly referentiel: PaysInfo[] = [
    { codeIso: 'ML', nomFr: 'Mali', nomEn: 'Mali', drapeauEmoji: '🇲🇱' },
    { codeIso: 'TR', nomFr: 'Turquie', nomEn: 'Turkey', drapeauEmoji: '🇹🇷' },
    { codeIso: 'CN', nomFr: 'Chine', nomEn: 'China', drapeauEmoji: '🇨🇳' },
    { codeIso: 'BR', nomFr: 'Brésil', nomEn: 'Brazil', drapeauEmoji: '🇧🇷' },
    { codeIso: 'CI', nomFr: "Côte d'Ivoire", nomEn: 'Ivory Coast', drapeauEmoji: '🇨🇮' },
    { codeIso: 'SN', nomFr: 'Sénégal', nomEn: 'Senegal', drapeauEmoji: '🇸🇳' },
    { codeIso: 'GH', nomFr: 'Ghana', nomEn: 'Ghana', drapeauEmoji: '🇬🇭' },
    { codeIso: 'MA', nomFr: 'Maroc', nomEn: 'Morocco', drapeauEmoji: '🇲🇦' },
    { codeIso: 'AE', nomFr: 'Émirats arabes unis', nomEn: 'United Arab Emirates', drapeauEmoji: '🇦🇪' },
    { codeIso: 'FR', nomFr: 'France', nomEn: 'France', drapeauEmoji: '🇫🇷' },
    { codeIso: 'IN', nomFr: 'Inde', nomEn: 'India', drapeauEmoji: '🇮🇳' },
    { codeIso: 'NG', nomFr: 'Nigéria', nomEn: 'Nigeria', drapeauEmoji: '🇳🇬' },
    { codeIso: 'TG', nomFr: 'Togo', nomEn: 'Togo', drapeauEmoji: '🇹🇬' },
    { codeIso: 'BJ', nomFr: 'Bénin', nomEn: 'Benin', drapeauEmoji: '🇧🇯' },
    { codeIso: 'BF', nomFr: 'Burkina Faso', nomEn: 'Burkina Faso', drapeauEmoji: '🇧🇫' },
    { codeIso: 'GN', nomFr: 'Guinée', nomEn: 'Guinea', drapeauEmoji: '🇬🇳' },
    { codeIso: 'NE', nomFr: 'Niger', nomEn: 'Niger', drapeauEmoji: '🇳🇪' },
    { codeIso: 'CM', nomFr: 'Cameroun', nomEn: 'Cameroon', drapeauEmoji: '🇨🇲' },
    { codeIso: 'ES', nomFr: 'Espagne', nomEn: 'Spain', drapeauEmoji: '🇪🇸' },
    { codeIso: 'DE', nomFr: 'Allemagne', nomEn: 'Germany', drapeauEmoji: '🇩🇪' },
    { codeIso: 'IT', nomFr: 'Italie', nomEn: 'Italy', drapeauEmoji: '🇮🇹' },
    { codeIso: 'US', nomFr: 'États-Unis', nomEn: 'United States', drapeauEmoji: '🇺🇸' },
    { codeIso: 'VN', nomFr: 'Vietnam', nomEn: 'Vietnam', drapeauEmoji: '🇻🇳' },
    { codeIso: 'TH', nomFr: 'Thaïlande', nomEn: 'Thailand', drapeauEmoji: '🇹🇭' },
    { codeIso: 'SA', nomFr: 'Arabie saoudite', nomEn: 'Saudi Arabia', drapeauEmoji: '🇸🇦' },
    { codeIso: 'EG', nomFr: 'Égypte', nomEn: 'Egypt', drapeauEmoji: '🇪🇬' },
    { codeIso: 'ZA', nomFr: 'Afrique du Sud', nomEn: 'South Africa', drapeauEmoji: '🇿🇦' },
    { codeIso: 'DZ', nomFr: 'Algérie', nomEn: 'Algeria', drapeauEmoji: '🇩🇿' },
    { codeIso: 'TN', nomFr: 'Tunisie', nomEn: 'Tunisia', drapeauEmoji: '🇹🇳' },
    { codeIso: 'PT', nomFr: 'Portugal', nomEn: 'Portugal', drapeauEmoji: '🇵🇹' },
    { codeIso: 'GB', nomFr: 'Royaume-Uni', nomEn: 'United Kingdom', drapeauEmoji: '🇬🇧' },
    { codeIso: 'BE', nomFr: 'Belgique', nomEn: 'Belgium', drapeauEmoji: '🇧🇪' },
    { codeIso: 'NL', nomFr: 'Pays-Bas', nomEn: 'Netherlands', drapeauEmoji: '🇳🇱' },
    { codeIso: 'CH', nomFr: 'Suisse', nomEn: 'Switzerland', drapeauEmoji: '🇨🇭' },
    { codeIso: 'CA', nomFr: 'Canada', nomEn: 'Canada', drapeauEmoji: '🇨🇦' },
    { codeIso: 'JP', nomFr: 'Japon', nomEn: 'Japan', drapeauEmoji: '🇯🇵' },
    { codeIso: 'KR', nomFr: 'Corée du Sud', nomEn: 'South Korea', drapeauEmoji: '🇰🇷' },
    { codeIso: 'ID', nomFr: 'Indonésie', nomEn: 'Indonesia', drapeauEmoji: '🇮🇩' },
    { codeIso: 'MY', nomFr: 'Malaisie', nomEn: 'Malaysia', drapeauEmoji: '🇲🇾' },
    { codeIso: 'PK', nomFr: 'Pakistan', nomEn: 'Pakistan', drapeauEmoji: '🇵🇰' },
    { codeIso: 'BD', nomFr: 'Bangladesh', nomEn: 'Bangladesh', drapeauEmoji: '🇧🇩' }
  ];

  private static readonly aliasMap: Record<string, string> = {
    // Turquie
    tr: 'TR', tur: 'TR', turquie: 'TR', turkey: 'TR', turkiye: 'TR', istanbul: 'TR',
    // Chine
    cn: 'CN', chn: 'CN', chine: 'CN', china: 'CN', guangzhou: 'CN', yiwu: 'CN', shenzhen: 'CN',
    // Mali
    ml: 'ML', mli: 'ML', mali: 'ML', bamako: 'ML',
    // Brésil
    br: 'BR', bra: 'BR', bresil: 'BR', brésil: 'BR', brazil: 'BR', 'sao paulo': 'BR',
    // Côte d'Ivoire
    ci: 'CI', civ: 'CI', 'cote d ivoire': 'CI', "cote d'ivoire": 'CI', "côte d'ivoire": 'CI', 'ivory coast': 'CI', abidjan: 'CI',
    // Sénégal
    sn: 'SN', sen: 'SN', senegal: 'SN', sénégal: 'SN', dakar: 'SN',
    // Ghana
    gh: 'GH', gha: 'GH', ghana: 'GH', accra: 'GH',
    // Maroc
    ma: 'MA', mar: 'MA', maroc: 'MA', morocco: 'MA', casablanca: 'MA',
    // Émirats
    ae: 'AE', are: 'AE', uae: 'AE', dubai: 'AE', dubaï: 'AE', emirats: 'AE', 'emirats arabes unis': 'AE',
    // France
    fr: 'FR', fra: 'FR', france: 'FR', paris: 'FR',
    // Inde
    in: 'IN', ind: 'IN', inde: 'IN', india: 'IN', mumbai: 'IN', delhi: 'IN',
    // Nigéria
    ng: 'NG', nga: 'NG', nigeria: 'NG', nigéria: 'NG', lagos: 'NG',
    // Togo
    tg: 'TG', tgo: 'TG', togo: 'TG', lome: 'TG', lomé: 'TG',
    // Bénin
    bj: 'BJ', ben: 'BJ', benin: 'BJ', bénin: 'BJ', cotonou: 'BJ',
    // Burkina
    bf: 'BF', bfa: 'BF', burkina: 'BF', 'burkina faso': 'BF', ouagadougou: 'BF',
    // Guinée
    gn: 'GN', gin: 'GN', guinee: 'GN', guinée: 'GN', conakry: 'GN',
    // Niger
    ne: 'NE', ner: 'NE', niger: 'NE', niamey: 'NE',
    // Cameroun
    cm: 'CM', cmr: 'CM', cameroun: 'CM', cameroon: 'CM', yaounde: 'CM', douala: 'CM',
    // États-Unis
    us: 'US', usa: 'US', 'etats unis': 'US', 'etats-unis': 'US', 'états-unis': 'US', 'united states': 'US',
    // Espagne
    es: 'ES', esp: 'ES', espagne: 'ES', spain: 'ES', madrid: 'ES',
    // Allemagne
    de: 'DE', deu: 'DE', allemagne: 'DE', germany: 'DE', berlin: 'DE',
    // Italie
    it: 'IT', ita: 'IT', italie: 'IT', italy: 'IT', rome: 'IT', milan: 'IT',
    // Vietnam
    vn: 'VN', vnm: 'VN', vietnam: 'VN',
    // Thaïlande
    th: 'TH', tha: 'TH', thailande: 'TH', thaïlande: 'TH', thailand: 'TH', bangkok: 'TH',
    // Arabie
    sa: 'SA', sau: 'SA', arabie: 'SA', 'arabie saoudite': 'SA', 'saudi arabia': 'SA',
    // Égypte
    eg: 'EG', egy: 'EG', egypte: 'EG', égypte: 'EG', egypt: 'EG', caire: 'EG',
    // Afrique du Sud
    za: 'ZA', zaf: 'ZA', 'afrique du sud': 'ZA', 'south africa': 'ZA',
    // Algérie
    dz: 'DZ', dza: 'DZ', algerie: 'DZ', algérie: 'DZ', alger: 'DZ',
    // Tunisie
    tn: 'TN', tun: 'TN', tunisie: 'TN', tunis: 'TN',
    // Royaume-Uni
    gb: 'GB', gbr: 'GB', uk: 'GB', 'royaume-uni': 'GB', 'united kingdom': 'GB', londres: 'GB'
  };

  /**
   * Dictionnaire d'icônes SVG officielles 100% vectorielles et ultra-légères
   * Rendu instantané (0 ms), sans requête réseau, fonctionne partout hors-ligne et sur Windows.
   */
  private static readonly svgMap: Record<string, string> = {
    // Mali (Vert, Jaune, Rouge)
    ML: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="100" height="200" fill="#14B53A"/><rect x="100" width="100" height="200" fill="#FCD116"/><rect x="200" width="100" height="200" fill="#CE1126"/></svg>`,
    // Côte d'Ivoire (Orange, Blanc, Vert)
    CI: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="100" height="200" fill="#F77F00"/><rect x="100" width="100" height="200" fill="#FFFFFF"/><rect x="200" width="100" height="200" fill="#009A44"/></svg>`,
    // Sénégal (Vert, Jaune avec étoile verte, Rouge)
    SN: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="100" height="200" fill="#00853F"/><rect x="100" width="100" height="200" fill="#FDEF42"/><rect x="200" width="100" height="200" fill="#E31B23"/><polygon points="150,70 156,92 178,92 160,105 167,126 150,113 133,126 140,105 122,92 144,92" fill="#00853F"/></svg>`,
    // Ghana (Rouge, Jaune avec étoile noire, Vert)
    GH: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="300" height="66.7" fill="#CE1126"/><rect y="66.7" width="300" height="66.7" fill="#FCD116"/><rect y="133.4" width="300" height="66.7" fill="#006B3F"/><polygon points="150,72 156,90 174,90 159,101 165,118 150,107 135,118 141,101 126,90 144,90" fill="#000000"/></svg>`,
    // Turquie (Rouge avec croissant blanc et étoile)
    TR: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="300" height="200" fill="#E30A17"/><circle cx="120" cy="100" r="60" fill="#FFFFFF"/><circle cx="135" cy="100" r="48" fill="#E30A17"/><polygon points="175,100 162,104 166,91 155,83 169,83 175,70 181,83 195,83 184,91 188,104" fill="#FFFFFF" transform="rotate(-15 175 100)"/></svg>`,
    // Chine (Rouge avec 5 étoiles dorées)
    CN: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="300" height="200" fill="#DE2910"/><polygon points="50,20 56,38 74,38 59,49 65,66 50,55 35,66 41,49 26,38 44,38" fill="#FFDE00"/><circle cx="100" cy="22" r="7" fill="#FFDE00"/><circle cx="118" cy="42" r="7" fill="#FFDE00"/><circle cx="118" cy="70" r="7" fill="#FFDE00"/><circle cx="100" cy="90" r="7" fill="#FFDE00"/></svg>`,
    // Brésil (Vert, Losange Jaune, Disque Bleu avec bande)
    BR: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="300" height="200" fill="#009739"/><polygon points="150,20 280,100 150,180 20,100" fill="#FEDD00"/><circle cx="150" cy="100" r="48" fill="#012169"/><path d="M 104,110 A 48,48 0 0 1 196,90" stroke="#FFFFFF" stroke-width="6" fill="none"/></svg>`,
    // Maroc (Rouge avec pentagramme vert)
    MA: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="300" height="200" fill="#C1272D"/><polygon points="150,50 160,82 194,82 166,102 177,134 150,114 123,134 134,102 106,82 140,82" stroke="#006233" stroke-width="8" fill="none"/></svg>`,
    // France (Bleu, Blanc, Rouge)
    FR: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="100" height="200" fill="#002654"/><rect x="100" width="100" height="200" fill="#FFFFFF"/><rect x="200" width="100" height="200" fill="#CE1126"/></svg>`,
    // Émirats Arabes Unis (Bande rouge + 3 bandes Vert, Blanc, Noir)
    AE: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect x="75" width="225" height="66.7" fill="#00732F"/><rect x="75" y="66.7" width="225" height="66.7" fill="#FFFFFF"/><rect x="75" y="133.4" width="225" height="66.7" fill="#000000"/><rect width="75" height="200" fill="#FF0000"/></svg>`,
    // Togo (5 bandes Vert/Jaune, canton rouge avec étoile blanche)
    TG: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="300" height="40" fill="#006A4E"/><rect y="40" width="300" height="40" fill="#FFCE00"/><rect y="80" width="300" height="40" fill="#006A4E"/><rect y="120" width="300" height="40" fill="#FFCE00"/><rect y="160" width="300" height="40" fill="#006A4E"/><rect width="120" height="120" fill="#D21034"/><polygon points="60,35 66,53 84,53 69,64 75,81 60,70 45,81 51,64 36,53 54,53" fill="#FFFFFF"/></svg>`,
    // Bénin (Vert à gauche, Jaune et Rouge à droite)
    BJ: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="120" height="200" fill="#008751"/><rect x="120" width="180" height="100" fill="#FCD116"/><rect x="120" y="100" width="180" height="100" fill="#E8112D"/></svg>`,
    // Burkina Faso (Rouge, Vert avec étoile dorée)
    BF: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="300" height="100" fill="#EF2B2D"/><rect y="100" width="300" height="100" fill="#009E49"/><polygon points="150,70 156,88 174,88 159,99 165,116 150,105 135,116 141,99 126,88 144,88" fill="#FCD116"/></svg>`,
    // Guinée (Rouge, Jaune, Vert)
    GN: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="100" height="200" fill="#CE1126"/><rect x="100" width="100" height="200" fill="#FCD116"/><rect x="200" width="100" height="200" fill="#009460"/></svg>`,
    // Niger (Orange, Blanc avec disque orange, Vert)
    NE: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="300" height="66.7" fill="#E05206"/><rect y="66.7" width="300" height="66.7" fill="#FFFFFF"/><rect y="133.4" width="300" height="66.7" fill="#0DB02B"/><circle cx="150" cy="100" r="28" fill="#E05206"/></svg>`,
    // Cameroun (Vert, Rouge avec étoile jaune, Jaune)
    CM: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="100" height="200" fill="#007A5E"/><rect x="100" width="100" height="200" fill="#CE1126"/><rect x="200" width="100" height="200" fill="#FCD116"/><polygon points="150,75 155,90 170,90 158,100 162,115 150,105 138,115 142,100 130,90 145,90" fill="#FCD116"/></svg>`,
    // Nigéria (Vert, Blanc, Vert)
    NG: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="100" height="200" fill="#008751"/><rect x="100" width="100" height="200" fill="#FFFFFF"/><rect x="200" width="100" height="200" fill="#008751"/></svg>`,
    // Inde (Safran, Blanc avec chakra bleu, Vert)
    IN: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="300" height="66.7" fill="#FF9933"/><rect y="66.7" width="300" height="66.7" fill="#FFFFFF"/><rect y="133.4" width="300" height="66.7" fill="#138808"/><circle cx="150" cy="100" r="24" stroke="#000080" stroke-width="4" fill="none"/></svg>`,
    // États-Unis (Bandes rouge et blanc, canton bleu)
    US: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="300" height="200" fill="#B22234"/><rect y="15.4" width="300" height="15.4" fill="#FFFFFF"/><rect y="46.2" width="300" height="15.4" fill="#FFFFFF"/><rect y="77" width="300" height="15.4" fill="#FFFFFF"/><rect y="107.8" width="300" height="15.4" fill="#FFFFFF"/><rect y="138.6" width="300" height="15.4" fill="#FFFFFF"/><rect y="169.4" width="300" height="15.4" fill="#FFFFFF"/><rect width="120" height="107.8" fill="#3C3B6E"/></svg>`,
    // Allemagne (Noir, Rouge, Or)
    DE: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="300" height="66.7" fill="#000000"/><rect y="66.7" width="300" height="66.7" fill="#DD0000"/><rect y="133.4" width="300" height="66.7" fill="#FFCE00"/></svg>`,
    // Espagne (Rouge, Jaune, Rouge)
    ES: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="300" height="50" fill="#AA151B"/><rect y="50" width="300" height="100" fill="#F1BF00"/><rect y="150" width="300" height="50" fill="#AA151B"/></svg>`,
    // Italie (Vert, Blanc, Rouge)
    IT: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="100" height="200" fill="#009246"/><rect x="100" width="100" height="200" fill="#FFFFFF"/><rect x="200" width="100" height="200" fill="#CE2B37"/></svg>`,
    // Royaume-Uni (Union Jack)
    GB: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="300" height="200" fill="#012169"/><path d="M0,0 L300,200 M300,0 L0,200" stroke="#FFFFFF" stroke-width="30"/><path d="M0,0 L300,200 M300,0 L0,200" stroke="#C8102E" stroke-width="18"/><path d="M150,0 V200 M0,100 H300" stroke="#FFFFFF" stroke-width="50"/><path d="M150,0 V200 M0,100 H300" stroke="#C8102E" stroke-width="30"/></svg>`
  };

  private normaliser(texte: string): string {
    return texte
      .trim()
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/['\-_]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  resoudre(saisie?: string | null): PaysInfo {
    if (!saisie || !saisie.trim()) {
      return { codeIso: 'ML', nomFr: 'Mali', nomEn: 'Mali', drapeauEmoji: '🇲🇱' };
    }

    const cle = this.normaliser(saisie);

    // 1. Recherche par alias direct
    if (PaysResolverService.aliasMap[cle]) {
      const code = PaysResolverService.aliasMap[cle];
      return this.parCode(code);
    }

    // 2. Recherche par code ISO 2 lettres
    if (cle.length === 2) {
      return this.parCode(cle.toUpperCase());
    }

    // 3. Recherche floue dans le référentiel
    for (const p of PaysResolverService.referentiel) {
      const fr = this.normaliser(p.nomFr);
      const en = this.normaliser(p.nomEn);
      if (fr.includes(cle) || cle.includes(fr) || en.includes(cle)) {
        return p;
      }
    }

    // 4. Code 2 lettres générique
    const cleanAlpha = saisie.trim().toUpperCase().replace(/[^A-Z]/g, '');
    if (cleanAlpha.length === 2) {
      return {
        codeIso: cleanAlpha,
        nomFr: cleanAlpha,
        nomEn: cleanAlpha,
        drapeauEmoji: this.codeVersEmoji(cleanAlpha)
      };
    }

    return { codeIso: 'ML', nomFr: 'Mali', nomEn: 'Mali', drapeauEmoji: '🇲🇱' };
  }

  parCode(codeIso: string): PaysInfo {
    const code = codeIso.toUpperCase();
    const trouve = PaysResolverService.referentiel.find(p => p.codeIso === code);
    if (trouve) return trouve;
    return {
      codeIso: code,
      nomFr: code,
      nomEn: code,
      drapeauEmoji: this.codeVersEmoji(code)
    };
  }

  svgDrapeau(saisie?: string | null): string {
    const info = this.resoudre(saisie);
    const code = info.codeIso.toUpperCase();
    if (PaysResolverService.svgMap[code]) {
      return PaysResolverService.svgMap[code];
    }
    // SVG de secours élégant aux couleurs douces avec code ISO
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200"><rect width="300" height="200" fill="#183630"/><rect x="4" y="4" width="292" height="192" fill="none" stroke="#EEA823" stroke-width="4"/><text x="150" y="125" font-family="sans-serif" font-size="75" font-weight="bold" fill="#EEA823" text-anchor="middle">${code}</text></svg>`;
  }

  dataUriDrapeau(saisie?: string | null): string {
    const svg = this.svgDrapeau(saisie);
    return 'data:image/svg+xml;utf8,' + encodeURIComponent(svg);
  }

  urlDrapeau(saisie?: string | null, largeur = 40): string {
    return this.dataUriDrapeau(saisie);
  }

  urlDrapeauSvg(saisie?: string | null): string {
    return this.dataUriDrapeau(saisie);
  }

  private codeVersEmoji(codeIso: string): string {
    if (!codeIso || codeIso.length !== 2) return '🌐';
    const c = codeIso.toUpperCase();
    const d1 = String.fromCodePoint(0x1F1E6 + (c.charCodeAt(0) - 65));
    const d2 = String.fromCodePoint(0x1F1E6 + (c.charCodeAt(1) - 65));
    return d1 + d2;
  }

  get tousLesPays(): PaysInfo[] {
    return [...PaysResolverService.referentiel];
  }
}
