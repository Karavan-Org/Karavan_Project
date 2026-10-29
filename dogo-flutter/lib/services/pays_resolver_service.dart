part 'pays_iso_data.dart';

/// Pays du référentiel ISO 3166-1 (nom français CLDR).
class PaysInfo {
  final String codeIso; // ex : "TR" (vide si la saisie n'a pas été reconnue)
  final String codeIso3; // ex : "TUR"
  final String nomFr; // ex : "Turquie"
  final String nomEn; // ex : "Türkiye"
  final List<String> alias;

  const PaysInfo({
    required this.codeIso,
    required this.codeIso3,
    required this.nomFr,
    required this.nomEn,
    this.alias = const [],
  });

  /// Saisie libre non reconnue : on affiche le texte tel quel, sans jamais deviner un pays.
  const PaysInfo.inconnu(String saisie)
      : codeIso = '',
        codeIso3 = '',
        nomFr = saisie,
        nomEn = saisie,
        alias = const [];

  bool get estReconnu => codeIso.isNotEmpty;

  /// Indicatif téléphonique international (vide si non référencé).
  String get indicatifTel => PaysResolverService._indicatifs[codeIso] ?? '';

  @override
  String toString() => estReconnu ? '$nomFr ($codeIso)' : nomFr;
}

/// Résolution d'un pays à partir d'un code ISO (2 ou 3 lettres), d'un nom français ou anglais,
/// avec ou sans accents, ou d'une ville d'approvisionnement courante (« Guangzhou », « Dubaï »…).
/// La correspondance est exacte après normalisation : « Niger » ne devient jamais « Nigeria ».
class PaysResolverService {
  PaysResolverService._();
  static final PaysResolverService instance = PaysResolverService._();

  static const Map<String, String> _indicatifs = {
    'ML': '+223', 'CI': '+225', 'SN': '+221', 'GH': '+233', 'GN': '+224', 'BF': '+226',
    'NE': '+227', 'TG': '+228', 'BJ': '+229', 'NG': '+234', 'CM': '+237', 'MR': '+222',
    'MA': '+212', 'DZ': '+213', 'TN': '+216', 'EG': '+20', 'ZA': '+27', 'TR': '+90',
    'CN': '+86', 'BR': '+55', 'FR': '+33', 'AE': '+971', 'IN': '+91', 'ES': '+34',
    'DE': '+49', 'IT': '+39', 'US': '+1', 'CA': '+1', 'GB': '+44', 'BE': '+32',
    'CH': '+41', 'NL': '+31', 'PT': '+351', 'SA': '+966', 'VN': '+84', 'TH': '+66',
    'ID': '+62', 'MY': '+60', 'JP': '+81', 'KR': '+82', 'PK': '+92', 'BD': '+880',
  };

  late final Map<String, PaysInfo> _index = _construireIndex();

  Map<String, PaysInfo> _construireIndex() {
    final index = <String, PaysInfo>{};
    // Codes d'abord, puis noms officiels, puis alias : une clé déjà prise n'est jamais écrasée.
    for (final p in _referentielIso) {
      index[p.codeIso.toLowerCase()] = p;
      index[p.codeIso3.toLowerCase()] = p;
    }
    for (final p in _referentielIso) {
      index.putIfAbsent(_cle(p.nomFr), () => p);
      index.putIfAbsent(_cle(p.nomEn), () => p);
    }
    for (final p in _referentielIso) {
      for (final a in p.alias) {
        index.putIfAbsent(_cle(a), () => p);
      }
    }
    return index;
  }

  /// Minuscules, sans accents ni ponctuation : « Côte d’Ivoire » → « cote d ivoire ».
  static String normaliser(String texte) {
    const avec = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿœæ';
    const sans = 'aaaaaaceeeeiiiinooooouuuuyyoa';
    final buffer = StringBuffer();
    for (final rune in texte.trim().toLowerCase().runes) {
      final c = String.fromCharCode(rune);
      final i = avec.indexOf(c);
      buffer.write(i >= 0 ? sans[i] : c);
    }
    return buffer
        .toString()
        .replaceAll(RegExp(r"[^a-z0-9]+"), ' ')
        .trim();
  }

  /// Clé d'index insensible aux espaces et à la ponctuation : « cote divoire » = « Côte d’Ivoire ».
  static String _cle(String texte) => normaliser(texte).replaceAll(' ', '');

  /// Pays correspondant à la saisie, ou [PaysInfo.inconnu] si rien ne correspond exactement.
  PaysInfo resoudre(String? saisie) {
    if (saisie == null || saisie.trim().isEmpty) return const PaysInfo.inconnu('');
    final cle = _cle(saisie);
    final trouve = _index[cle];
    if (trouve != null) return trouve;
    if (saisie.contains('?')) {
      final pattern = '^${_cle(saisie.replaceAll('?', '.'))}\$';
      final reg = RegExp(pattern);
      for (final p in _referentielIso) {
        if (reg.hasMatch(_cle(p.nomFr)) || reg.hasMatch(_cle(p.nomEn))) return p;
      }
    }
    return PaysInfo.inconnu(saisie.trim());
  }

  /// Indicatif téléphonique international (« +223 » par défaut : plateforme malienne).
  String indicatif(String? saisie) {
    final ind = resoudre(saisie).indicatifTel;
    return ind.isNotEmpty ? ind : '+223';
  }

  /// Tous les pays, triés par nom français.
  List<PaysInfo> get tousLesPays => _referentielIso;

  /// Auto-complétion : préfixe sur le nom, le nom anglais, un alias ou le code.
  List<PaysInfo> rechercher(String query) {
    final q = normaliser(query);
    if (q.isEmpty) return tousLesPays;
    return _referentielIso.where((p) {
      if (p.codeIso.toLowerCase() == q || p.codeIso3.toLowerCase() == q) return true;
      bool commence(String s) {
        final n = normaliser(s);
        return n.startsWith(q) || n.contains(' $q');
      }
      return commence(p.nomFr) || commence(p.nomEn) || p.alias.any(commence);
    }).toList();
  }
}
