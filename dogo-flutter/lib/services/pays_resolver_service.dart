/// Information normalisée d'un pays avec drapeau officiel
class PaysInfo {
  final String codeIso; // ex: "TR"
  final String nomFr;   // ex: "Turquie"
  final String nomEn;   // ex: "Turkey"
  final String drapeauEmoji; // ex: "🇹🇷"
  final String indicatifTel; // ex: "+223", "+225", "+90"

  const PaysInfo({
    required this.codeIso,
    required this.nomFr,
    required this.nomEn,
    required this.drapeauEmoji,
    this.indicatifTel = '+223',
  });

  /// URL haute résolution du drapeau officiel (FlagCDN CDN mondial ultra-rapide)
  String urlDrapeau({int largeur = 40}) {
    final code = codeIso.toLowerCase();
    // Largeurs supportées : 20, 40, 80, 160
    return 'https://flagcdn.com/w$largeur/$code.png';
  }

  /// URL SVG vectorielle pure
  String get urlDrapeauSvg => 'https://flagcdn.com/${codeIso.toLowerCase()}.svg';

  @override
  String toString() => '$nomFr ($codeIso)';
}

/// Service intelligent de résolution et d'identification automatique des pays
/// Permet de déduire le drapeau et le pays officiel à partir de :
/// - Un nom de pays en français ("Turquie", "Brésil", "Chine", "Côte d'Ivoire"...)
/// - Un nom en anglais ("Turkey", "Brazil", "China", "Ivory Coast"...)
/// - Un code ISO à 2 lettres ("TR", "BR", "CN", "CI", "ML"...)
/// - Un code ISO à 3 lettres ("TUR", "BRA", "CHN", "CIV", "MLI"...)
/// - Une saisie approximative / sans accent ("bresil", "turk", "cote divoire"...)
class PaysResolverService {
  PaysResolverService._();
  static final PaysResolverService instance = PaysResolverService._();

  static const List<PaysInfo> _referentiel = [
    PaysInfo(codeIso: 'ML', nomFr: 'Mali', nomEn: 'Mali', drapeauEmoji: '🇲🇱'),
    PaysInfo(codeIso: 'TR', nomFr: 'Turquie', nomEn: 'Turkey', drapeauEmoji: '🇹🇷'),
    PaysInfo(codeIso: 'CN', nomFr: 'Chine', nomEn: 'China', drapeauEmoji: '🇨🇳'),
    PaysInfo(codeIso: 'BR', nomFr: 'Brésil', nomEn: 'Brazil', drapeauEmoji: '🇧🇷'),
    PaysInfo(codeIso: 'CI', nomFr: "Côte d'Ivoire", nomEn: 'Ivory Coast', drapeauEmoji: '🇨🇮'),
    PaysInfo(codeIso: 'SN', nomFr: 'Sénégal', nomEn: 'Senegal', drapeauEmoji: '🇸🇳'),
    PaysInfo(codeIso: 'GH', nomFr: 'Ghana', nomEn: 'Ghana', drapeauEmoji: '🇬🇭'),
    PaysInfo(codeIso: 'MA', nomFr: 'Maroc', nomEn: 'Morocco', drapeauEmoji: '🇲🇦'),
    PaysInfo(codeIso: 'AE', nomFr: 'Émirats arabes unis', nomEn: 'United Arab Emirates', drapeauEmoji: '🇦🇪'),
    PaysInfo(codeIso: 'FR', nomFr: 'France', nomEn: 'France', drapeauEmoji: '🇫🇷'),
    PaysInfo(codeIso: 'IN', nomFr: 'Inde', nomEn: 'India', drapeauEmoji: '🇮🇳'),
    PaysInfo(codeIso: 'NG', nomFr: 'Nigéria', nomEn: 'Nigeria', drapeauEmoji: '🇳🇬'),
    PaysInfo(codeIso: 'TG', nomFr: 'Togo', nomEn: 'Togo', drapeauEmoji: '🇹🇬'),
    PaysInfo(codeIso: 'BJ', nomFr: 'Bénin', nomEn: 'Benin', drapeauEmoji: '🇧🇯'),
    PaysInfo(codeIso: 'BF', nomFr: 'Burkina Faso', nomEn: 'Burkina Faso', drapeauEmoji: '🇧🇫'),
    PaysInfo(codeIso: 'GN', nomFr: 'Guinée', nomEn: 'Guinea', drapeauEmoji: '🇬🇳'),
    PaysInfo(codeIso: 'NE', nomFr: 'Niger', nomEn: 'Niger', drapeauEmoji: '🇳🇪'),
    PaysInfo(codeIso: 'CM', nomFr: 'Cameroun', nomEn: 'Cameroon', drapeauEmoji: '🇨🇲'),
    PaysInfo(codeIso: 'ES', nomFr: 'Espagne', nomEn: 'Spain', drapeauEmoji: '🇪🇸'),
    PaysInfo(codeIso: 'DE', nomFr: 'Allemagne', nomEn: 'Germany', drapeauEmoji: '🇩🇪'),
    PaysInfo(codeIso: 'IT', nomFr: 'Italie', nomEn: 'Italy', drapeauEmoji: '🇮🇹'),
    PaysInfo(codeIso: 'US', nomFr: 'États-Unis', nomEn: 'United States', drapeauEmoji: '🇺🇸'),
    PaysInfo(codeIso: 'VN', nomFr: 'Vietnam', nomEn: 'Vietnam', drapeauEmoji: '🇻🇳'),
    PaysInfo(codeIso: 'TH', nomFr: 'Thaïlande', nomEn: 'Thailand', drapeauEmoji: '🇹🇭'),
    PaysInfo(codeIso: 'SA', nomFr: 'Arabie saoudite', nomEn: 'Saudi Arabia', drapeauEmoji: '🇸🇦'),
    PaysInfo(codeIso: 'EG', nomFr: 'Égypte', nomEn: 'Egypt', drapeauEmoji: '🇪🇬'),
    PaysInfo(codeIso: 'ZA', nomFr: 'Afrique du Sud', nomEn: 'South Africa', drapeauEmoji: '🇿🇦'),
    PaysInfo(codeIso: 'DZ', nomFr: 'Algérie', nomEn: 'Algeria', drapeauEmoji: '🇩🇿'),
    PaysInfo(codeIso: 'TN', nomFr: 'Tunisie', nomEn: 'Tunisia', drapeauEmoji: '🇹🇳'),
    PaysInfo(codeIso: 'PT', nomFr: 'Portugal', nomEn: 'Portugal', drapeauEmoji: '🇵🇹'),
    PaysInfo(codeIso: 'GB', nomFr: 'Royaume-Uni', nomEn: 'United Kingdom', drapeauEmoji: '🇬🇧'),
    PaysInfo(codeIso: 'BE', nomFr: 'Belgique', nomEn: 'Belgium', drapeauEmoji: '🇧🇪'),
    PaysInfo(codeIso: 'NL', nomFr: 'Pays-Bas', nomEn: 'Netherlands', drapeauEmoji: '🇳🇱'),
    PaysInfo(codeIso: 'CH', nomFr: 'Suisse', nomEn: 'Switzerland', drapeauEmoji: '🇨🇭'),
    PaysInfo(codeIso: 'CA', nomFr: 'Canada', nomEn: 'Canada', drapeauEmoji: '🇨🇦'),
    PaysInfo(codeIso: 'JP', nomFr: 'Japon', nomEn: 'Japan', drapeauEmoji: '🇯🇵'),
    PaysInfo(codeIso: 'KR', nomFr: 'Corée du Sud', nomEn: 'South Korea', drapeauEmoji: '🇰🇷'),
    PaysInfo(codeIso: 'ID', nomFr: 'Indonésie', nomEn: 'Indonesia', drapeauEmoji: '🇮🇩'),
    PaysInfo(codeIso: 'MY', nomFr: 'Malaisie', nomEn: 'Malaysia', drapeauEmoji: '🇲🇾'),
    PaysInfo(codeIso: 'PK', nomFr: 'Pakistan', nomEn: 'Pakistan', drapeauEmoji: '🇵🇰'),
    PaysInfo(codeIso: 'BD', nomFr: 'Bangladesh', nomEn: 'Bangladesh', drapeauEmoji: '🇧🇩'),
  ];

  static final Map<String, String> _aliasMap = {
    // Turquie
    'tr': 'TR', 'tur': 'TR', 'turquie': 'TR', 'turkey': 'TR', 'turkiye': 'TR', 'istanbul': 'TR',
    // Chine
    'cn': 'CN', 'chn': 'CN', 'chine': 'CN', 'china': 'CN', 'guangzhou': 'CN', 'yiwu': 'CN', 'shenzhen': 'CN',
    // Mali
    'ml': 'ML', 'mli': 'ML', 'mali': 'ML', 'bamako': 'ML',
    // Brésil
    'br': 'BR', 'bra': 'BR', 'bresil': 'BR', 'brésil': 'BR', 'brazil': 'BR', 'sao paulo': 'BR',
    // Côte d'Ivoire
    'ci': 'CI', 'civ': 'CI', 'cote d ivoire': 'CI', "cote d'ivoire": 'CI', "côte d'ivoire": 'CI', 'ivory coast': 'CI', 'abidjan': 'CI',
    // Sénégal
    'sn': 'SN', 'sen': 'SN', 'senegal': 'SN', 'sénégal': 'SN', 'dakar': 'SN',
    // Ghana
    'gh': 'GH', 'gha': 'GH', 'ghana': 'GH', 'accra': 'GH',
    // Maroc
    'ma': 'MA', 'mar': 'MA', 'maroc': 'MA', 'morocco': 'MA', 'casablanca': 'MA',
    // Émirats
    'ae': 'AE', 'are': 'AE', 'uae': 'AE', 'dubai': 'AE', 'dubaï': 'AE', 'emirats': 'AE', 'emirats arabes unis': 'AE',
    // France
    'fr': 'FR', 'fra': 'FR', 'france': 'FR', 'paris': 'FR',
    // Inde
    'in': 'IN', 'ind': 'IN', 'inde': 'IN', 'india': 'IN', 'mumbai': 'IN', 'delhi': 'IN',
    // Nigéria
    'ng': 'NG', 'nga': 'NG', 'nigeria': 'NG', 'nigéria': 'NG', 'lagos': 'NG',
    // Togo
    'tg': 'TG', 'tgo': 'TG', 'togo': 'TG', 'lome': 'TG', 'lomé': 'TG',
    // Bénin
    'bj': 'BJ', 'ben': 'BJ', 'benin': 'BJ', 'bénin': 'BJ', 'cotonou': 'BJ',
    // Burkina
    'bf': 'BF', 'bfa': 'BF', 'burkina': 'BF', 'burkina faso': 'BF', 'ouagadougou': 'BF',
    // Guinée
    'gn': 'GN', 'gin': 'GN', 'guinee': 'GN', 'guinée': 'GN', 'conakry': 'GN',
    // États-Unis
    'us': 'US', 'usa': 'US', 'etats unis': 'US', 'etats-unis': 'US', 'états-unis': 'US', 'united states': 'US',
    // Espagne
    'es': 'ES', 'esp': 'ES', 'espagne': 'ES', 'spain': 'ES', 'madrid': 'ES',
    // Allemagne
    'de': 'DE', 'deu': 'DE', 'allemagne': 'DE', 'germany': 'DE', 'berlin': 'DE',
    // Italie
    'it': 'IT', 'ita': 'IT', 'italie': 'IT', 'italy': 'IT', 'rome': 'IT', 'milan': 'IT',
    // Vietnam
    'vn': 'VN', 'vnm': 'VN', 'vietnam': 'VN',
    // Thaïlande
    'th': 'TH', 'tha': 'TH', 'thailande': 'TH', 'thaïlande': 'TH', 'thailand': 'TH', 'bangkok': 'TH',
    // Arabie
    'sa': 'SA', 'sau': 'SA', 'arabie': 'SA', 'arabie saoudite': 'SA', 'saudi arabia': 'SA',
    // Égypte
    'eg': 'EG', 'egy': 'EG', 'egypte': 'EG', 'égypte': 'EG', 'egypt': 'EG', 'caire': 'EG',
    // Afrique du Sud
    'za': 'ZA', 'zaf': 'ZA', 'afrique du sud': 'ZA', 'south africa': 'ZA',
    // Algérie
    'dz': 'DZ', 'dza': 'DZ', 'algerie': 'DZ', 'algérie': 'DZ', 'alger': 'DZ',
    // Tunisie
    'tn': 'TN', 'tun': 'TN', 'tunisie': 'TN', 'tunis': 'TN',
    // Royaume-Uni
    'gb': 'GB', 'gbr': 'GB', 'uk': 'GB', 'royaume-uni': 'GB', 'united kingdom': 'GB', 'londres': 'GB',
  };

  /// Normalise une chaîne (retire accents, minuscules, caractères spéciaux)
  static String _normaliser(String texte) {
    var res = texte.trim().toLowerCase();
    res = res.replaceAll(RegExp(r'[éèêë]'), 'e');
    res = res.replaceAll(RegExp(r'[àâä]'), 'a');
    res = res.replaceAll(RegExp(r'[îï]'), 'i');
    res = res.replaceAll(RegExp(r'[ôö]'), 'o');
    res = res.replaceAll(RegExp(r'[ùûü]'), 'u');
    res = res.replaceAll(RegExp(r'[ç]'), 'c');
    res = res.replaceAll(RegExp(r"['\-_]"), ' ');
    return res.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Déduit automatiquement les informations du pays et son drapeau à partir de n'importe quelle entrée
  PaysInfo resoudre(String? saisie) {
    if (saisie == null || saisie.trim().isEmpty) {
      return const PaysInfo(codeIso: 'ML', nomFr: 'Mali', nomEn: 'Mali', drapeauEmoji: '🇲🇱');
    }

    final cle = _normaliser(saisie);

    // 1. Recherche par alias direct (noms, capitales, codes)
    if (_aliasMap.containsKey(cle)) {
      final code = _aliasMap[cle]!;
      return _parCode(code);
    }

    // 2. Recherche directe par code ISO 2 lettres
    if (cle.length == 2) {
      final codeMaj = cle.toUpperCase();
      return _parCode(codeMaj);
    }

    // 3. Recherche floue / préfixe dans le référentiel
    for (final p in _referentiel) {
      final nomNorm = _normaliser(p.nomFr);
      final enNorm = _normaliser(p.nomEn);
      if (nomNorm.contains(cle) || cle.contains(nomNorm) || enNorm.contains(cle)) {
        return p;
      }
    }

    // 4. Si c'est un code ISO 2 lettres inconnu mais valide
    final cleanAlpha = saisie.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (cleanAlpha.length == 2) {
      final emoji = _codeVersEmoji(cleanAlpha);
      return PaysInfo(
        codeIso: cleanAlpha,
        nomFr: cleanAlpha,
        nomEn: cleanAlpha,
        drapeauEmoji: emoji,
      );
    }

    // Repli par défaut sur le hub Mali
    return const PaysInfo(codeIso: 'ML', nomFr: 'Mali', nomEn: 'Mali', drapeauEmoji: '🇲🇱');
  }

  static const Map<String, String> _indicatifsMap = {
    'ML': '+223', 'CI': '+225', 'SN': '+221', 'GH': '+233', 'GN': '+224',
    'BF': '+226', 'NE': '+227', 'TG': '+228', 'BJ': '+229', 'NG': '+234',
    'CM': '+237', 'MA': '+212', 'DZ': '+213', 'TN': '+216', 'EG': '+20',
    'ZA': '+27', 'TR': '+90', 'CN': '+86', 'BR': '+55', 'FR': '+33',
    'AE': '+971', 'IN': '+91', 'ES': '+34', 'DE': '+49', 'IT': '+39',
    'US': '+1', 'CA': '+1', 'GB': '+44', 'BE': '+32', 'CH': '+41',
    'NL': '+31', 'PT': '+351', 'SA': '+966', 'VN': '+84', 'TH': '+66',
    'ID': '+62', 'MY': '+60', 'JP': '+81', 'KR': '+82', 'PK': '+92', 'BD': '+880'
  };

  /// Renvoie l'indicatif téléphonique international d'un pays (ex: "+223", "+225")
  String indicatif(String? saisie) {
    final info = resoudre(saisie);
    return _indicatifsMap[info.codeIso] ?? '+223';
  }

  PaysInfo _parCode(String codeIso) {
    final trouve = _referentiel.where((p) => p.codeIso == codeIso);
    final ind = _indicatifsMap[codeIso.toUpperCase()] ?? '+223';
    if (trouve.isNotEmpty) {
      final p = trouve.first;
      return PaysInfo(
        codeIso: p.codeIso,
        nomFr: p.nomFr,
        nomEn: p.nomEn,
        drapeauEmoji: p.drapeauEmoji,
        indicatifTel: ind,
      );
    }
    final emoji = _codeVersEmoji(codeIso);
    return PaysInfo(
      codeIso: codeIso,
      nomFr: codeIso,
      nomEn: codeIso,
      drapeauEmoji: emoji,
      indicatifTel: ind,
    );
  }

  static String _codeVersEmoji(String codeIso) {
    if (codeIso.length != 2) return '🌐';
    final int premier = codeIso.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int second = codeIso.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(premier) + String.fromCharCode(second);
  }

  /// Liste complète des pays pour les sélecteurs
  List<PaysInfo> get tousLesPays => List.unmodifiable(_referentiel);

  /// Recherche dynamique (auto-complétion)
  List<PaysInfo> rechercher(String query) {
    final q = _normaliser(query);
    if (q.isEmpty) return tousLesPays;
    return _referentiel.where((p) {
      final fr = _normaliser(p.nomFr);
      final en = _normaliser(p.nomEn);
      return fr.contains(q) || en.contains(q) || p.codeIso.toLowerCase().contains(q);
    }).toList();
  }
}

