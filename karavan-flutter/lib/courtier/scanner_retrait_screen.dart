import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api/api_exception.dart';
import '../services/logistique_api_service.dart';
import '../theme/app_theme.dart';

/// Écran de scan pour agent de retrait / courtier / admin (RG-53 à RG-56)
/// - Scan haute vitesse avec `mobile_scanner`
/// - Gestion du refus de permission caméra avec message clair en français
/// - Détection automatique du type de QR (KVR. pour retrait, KVC. pour arrivée colis)
/// - Résultats vert / rouge à fort contraste visuel
/// - Bouton dédié « Saisir le code court »
class ScannerRetraitScreen extends StatefulWidget {
  const ScannerRetraitScreen({super.key});

  @override
  State<ScannerRetraitScreen> createState() => _ScannerRetraitScreenState();
}

class _ScannerRetraitScreenState extends State<ScannerRetraitScreen> {
  final _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _enCours = false;
  bool _torcheActive = false;

  Map<String, dynamic>? _resultatSucces;
  String? _erreurScan;
  String? _typeScan; // 'RETRAIT' ou 'COLIS'

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  /// Nettoie le jeton pour éliminer espaces, préfixes URL ou séparateurs
  String _nettoyerJeton(String brut) {
    var t = brut.trim();
    if (t.contains('/')) {
      t = t.split('/').last.trim();
    }
    if (t.contains(':')) {
      t = t.split(':').last.trim();
    }
    return t;
  }

  /// Détection caméra : aiguillage automatique selon le préfixe KVR / KVC
  void _surDetection(BarcodeCapture capture) {
    if (_enCours || _resultatSucces != null || _erreurScan != null) return;
    final brut = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (brut == null || brut.trim().isEmpty) return;
    final jeton = _nettoyerJeton(brut);
    if (jeton.isEmpty) return;

    if (jeton.startsWith("KVC.")) {
      _validerArriveeColis(jeton);
    } else {
      _validerRetrait(qrToken: jeton);
    }
  }

  Future<void> _validerRetrait({String? qrToken, int? commandeId, String? codeCourt}) async {
    setState(() {
      _enCours = true;
      _erreurScan = null;
      _typeScan = 'RETRAIT';
    });
    try {
      await _camera.stop();
    } catch (_) {}

    try {
      final res = await LogistiqueApiService.instance.validerRetrait(
        qrToken: qrToken,
        commandeId: commandeId,
        codeCourt: codeCourt,
      );
      if (!mounted) return;
      setState(() {
        _resultatSucces = res;
        _enCours = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreurScan = e is ApiException ? e.messageComplet : 'Code de retrait invalide ou expiré ($e)';
        _enCours = false;
      });
    }
  }

  Future<void> _validerArriveeColis(String jetonOuCodeCourt) async {
    setState(() {
      _enCours = true;
      _erreurScan = null;
      _typeScan = 'COLIS';
    });
    try {
      await _camera.stop();
    } catch (_) {}

    try {
      final res = await LogistiqueApiService.instance.validerArriveeColis(
        jetonOuCodeCourt: jetonOuCodeCourt,
      );
      if (!mounted) return;
      setState(() {
        _resultatSucces = res;
        _enCours = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreurScan = e is ApiException ? e.messageComplet : 'QR Colis invalide ou expiré ($e)';
        _enCours = false;
      });
    }
  }

  void _recommencer() {
    setState(() {
      _resultatSucces = null;
      _erreurScan = null;
      _typeScan = null;
    });
    try {
      _camera.start();
    } catch (_) {}
  }

  void _ouvrirSaisieCodeCourt() {
    final codeController = TextEditingController();
    final commandeController = TextEditingController();
    String typeSelectionne = "RETRAIT";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.couleurCarte(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final insetsBottom = MediaQuery.of(ctx).viewInsets.bottom;
          final systemBottom = MediaQuery.of(ctx).padding.bottom;
          final bottomPadding = insetsBottom > 0 ? insetsBottom + 16 : systemBottom + 24;

          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: bottomPadding,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Saisie du code court de secours",
                    style: TextStyle(
                      fontFamily: AppTheme.policeTitre,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.couleurTexte(context),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Sélecteur Type (Retrait ou Colis)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: "RETRAIT", label: Text("Retrait client")),
                  ButtonSegment(value: "COLIS", label: Text("Arrivée colis")),
                ],
                selected: {typeSelectionne},
                onSelectionChanged: (set) {
                  setModalState(() => typeSelectionne = set.first);
                },
              ),
              const SizedBox(height: 16),
              if (typeSelectionne == "RETRAIT") ...[
                TextField(
                  controller: commandeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "N° de commande (facultatif si code unique)",
                    hintText: "Ex : 42",
                    filled: true,
                    fillColor: AppTheme.couleurSurfaceDouce(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: codeController,
                maxLength: 8,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 6, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: "Code court (8 chiffres)",
                  hintText: "••••••••",
                  counterText: "",
                  filled: true,
                  fillColor: AppTheme.couleurSurfaceDouce(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  final code = codeController.text.trim();
                  if (code.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Le code de secours doit comporter au moins 6 chiffres (normalement 8)"),
                        backgroundColor: AppTheme.danger,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  if (typeSelectionne == "COLIS") {
                    _validerArriveeColis(code);
                  } else {
                    final cmdId = int.tryParse(commandeController.text.trim());
                    _validerRetrait(codeCourt: code, commandeId: cmdId);
                  }
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text("Valider le code"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
),
);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.couleurTexte(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Scanner de Retrait & Colis",
          style: TextStyle(
            fontFamily: AppTheme.policeTitre,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.couleurTexte(context),
          ),
        ),
        backgroundColor: AppTheme.couleurCarte(context),
        foregroundColor: AppTheme.couleurTexte(context),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Affichage selon l'état : caméra OU résultat succès OU résultat erreur
            if (_resultatSucces != null)
              _carteSucces(_resultatSucces!)
            else if (_erreurScan != null)
              _carteErreur(_erreurScan!)
            else
              _viseurCamera(),

            const SizedBox(height: 20),

            // Bouton permanent « Saisir le code court »
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _enCours ? null : _ouvrirSaisieCodeCourt,
                icon: const Icon(Icons.pin_outlined),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text("Saisir le code court"),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viseurCamera() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 300,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              MobileScanner(
                controller: _camera,
                onDetect: _surDetection,
                errorBuilder: (context, erreur) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    color: Colors.black87,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 48),
                        SizedBox(height: 12),
                        Text(
                          "Permission d'accès à la caméra refusée.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Veuillez autoriser l'appareil photo dans les paramètres de votre téléphone pour scanner, ou utilisez le bouton de saisie du code court ci-dessous.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Cadre de visée
              IgnorePointer(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primary, width: 3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              // Contrôles
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  tooltip: "Lampe torche",
                  icon: Icon(
                    _torcheActive ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    color: _torcheActive ? AppTheme.primary : Colors.white,
                    size: 22,
                  ),
                  style: IconButton.styleFrom(backgroundColor: const Color(0x66000000)),
                  onPressed: () async {
                    try {
                      await _camera.toggleTorch();
                      if (mounted) setState(() => _torcheActive = !_torcheActive);
                    } catch (_) {}
                  },
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: IconButton(
                  tooltip: "Changer de caméra",
                  icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 20),
                  style: IconButton.styleFrom(backgroundColor: const Color(0x66000000)),
                  onPressed: () async {
                    try {
                      await _camera.switchCamera();
                    } catch (_) {}
                  },
                ),
              ),
              if (_enCours)
                const ColoredBox(
                  color: Color(0x88000000),
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
              const Positioned(
                bottom: 12,
                child: Text(
                  "Pointez vers le QR de retrait (KVR) ou QR colis (KVC)",
                  style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Résultat SUCCÈS (Vert très lisible, fort contraste)
  Widget _carteSucces(Map<String, dynamic> r) {
    final estColis = _typeScan == 'COLIS' || r.containsKey('commandesImpactees');
    final titre = estColis ? "Arrivée Colis Confirmée !" : "Retrait Validé avec Succès !";
    final sousTitre = estColis
        ? "Expédition ${r['reference'] ?? ''} enregistrée à destination"
        : "Marchandise remise au client";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.couleurCarte(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.success, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.success.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 16),
          Text(
            titre,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTheme.policeTitre,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sousTitre,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.couleurTexteAttenue(context)),
          ),
          const SizedBox(height: 16),
          Divider(color: AppTheme.couleurBordure(context)),
          const SizedBox(height: 12),

          // Détails de la transaction
          if (!estColis) ...[
            _ligneDetail("Client :", r['nomClient'] ?? 'Commerçant'),
            _ligneDetail("Marchandise :", "${r['quantite'] ?? 1}x ${r['marchandise'] ?? 'Article'}"),
            _ligneDetail("Commande :", "#${r['commandeId'] ?? ''}"),
            _ligneDetail("Mode :", r['mode'] == 'QR' ? 'Scan QR code' : 'Code de secours'),
            _ligneDetail("Statut :", "COLLECTÉE"),
          ] else ...[
            _ligneDetail("Expédition :", "${r['reference'] ?? ''}"),
            _ligneDetail("Commandes prêtes :", "${r['commandesImpactees'] ?? 0}"),
            _ligneDetail("Mode :", r['mode'] ?? 'Scan QR'),
            _ligneDetail("Statut :", "ARRIVÉ À BAMAKO"),
          ],

          const SizedBox(height: 20),

          // Bouton Nouveau Scan
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _recommencer,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text("Scanner un autre code"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Résultat ERREUR / REFUS (Rouge très lisible, fort contraste)
  Widget _carteErreur(String motif) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.couleurCarte(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.danger, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.danger.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.danger,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 16),
          const Text(
            "Validation Refusée",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.policeTitre,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.danger,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            motif,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.couleurTexte(context),
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: AppTheme.couleurBordure(context)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _ouvrirSaisieCodeCourt,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text("Saisir code court"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _recommencer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text("Réessayer le scan"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ligneDetail(String libelle, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(libelle, style: TextStyle(fontSize: 13, color: AppTheme.couleurTexteAttenue(context))),
          Text(
            valeur,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.couleurTexte(context),
            ),
          ),
        ],
      ),
    );
  }
}
