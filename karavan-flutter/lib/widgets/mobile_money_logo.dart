import 'package:flutter/material.dart';

/// Énumération des opérateurs Mobile Money maliens supportés par Karavan
enum OperateurMobileMoney {
  orangeMoney,
  moovMoney,
  wave,
  inconnu;

  static OperateurMobileMoney detecter(String? op) {
    if (op == null) return OperateurMobileMoney.inconnu;
    final s = op.trim().toUpperCase();
    if (s.contains('ORANGE')) return OperateurMobileMoney.orangeMoney;
    if (s.contains('MOOV')) return OperateurMobileMoney.moovMoney;
    if (s.contains('WAVE')) return OperateurMobileMoney.wave;
    return OperateurMobileMoney.inconnu;
  }

  String get assetPath => switch (this) {
    OperateurMobileMoney.orangeMoney => 'assets/logo/orangemoney.png',
    OperateurMobileMoney.moovMoney => 'assets/logo/moovafrica.png',
    OperateurMobileMoney.wave => 'assets/logo/wave.png',
    OperateurMobileMoney.inconnu => '',
  };

  String get nomAffiche => switch (this) {
    OperateurMobileMoney.orangeMoney => 'Orange Money',
    OperateurMobileMoney.moovMoney => 'Moov Africa',
    OperateurMobileMoney.wave => 'Wave',
    OperateurMobileMoney.inconnu => 'Mobile Money',
  };

  Color get couleurMarque => switch (this) {
    OperateurMobileMoney.orangeMoney => const Color(0xFFFF6600),
    OperateurMobileMoney.moovMoney => const Color(0xFF005BA6),
    OperateurMobileMoney.wave => const Color(0xFF1BA6E8),
    OperateurMobileMoney.inconnu => const Color(0xFF888888),
  };
}

/// Logo officiel haute fidélité pour Orange Money, Moov Africa et Wave
class MobileMoneyLogo extends StatelessWidget {
  final String operateur;
  final double taille;
  final bool estCercle;
  final double? rayonArrondi;
  final Color? couleurFond;
  final BoxBorder? bordure;
  final EdgeInsetsGeometry padding;

  const MobileMoneyLogo({
    super.key,
    required this.operateur,
    this.taille = 36,
    this.estCercle = true,
    this.rayonArrondi,
    this.couleurFond,
    this.bordure,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final op = OperateurMobileMoney.detecter(operateur);
    final asset = op.assetPath;

    final shape = estCercle ? BoxShape.circle : BoxShape.rectangle;
    final borderRadius = estCercle ? null : BorderRadius.circular(rayonArrondi ?? 10);

    Widget fallback() {
      return Container(
        width: taille,
        height: taille,
        padding: padding,
        decoration: BoxDecoration(
          color: couleurFond ?? op.couleurMarque.withValues(alpha: 0.15),
          shape: shape,
          borderRadius: borderRadius,
          border: bordure,
        ),
        child: Center(
          child: Icon(
            Icons.phone_android_rounded,
            color: op.couleurMarque,
            size: taille * 0.55,
          ),
        ),
      );
    }

    if (asset.isEmpty) {
      return fallback();
    }

    return Container(
      width: taille,
      height: taille,
      padding: padding,
      decoration: BoxDecoration(
        color: couleurFond ?? Colors.white,
        shape: shape,
        borderRadius: borderRadius,
        border: bordure ?? Border.all(color: Colors.black.withValues(alpha: 0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: Image.asset(
          asset,
          width: taille,
          height: taille,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => fallback(),
        ),
      ),
    );
  }
}

