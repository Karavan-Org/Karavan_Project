import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';
import '../services/logistique_api_service.dart';
import '../services/api/api_exception.dart';

/// Écran de scan du QR Code ou saisie du PIN de retrait par le Courtier (Frame 15, RG-53 à RG-55)
/// La caméra lit le QR code affiché par l'application du commerçant ; sans QR code, le courtier saisit le
/// numéro de commande et le PIN reçu par SMS. Le backend libère alors le séquestre et notifie le commerçant.
class ScannerRetraitScreen extends StatefulWidget {
  const ScannerRetraitScreen({super.key});

  @override
  State<ScannerRetraitScreen> createState() => _ScannerRetraitScreenState();
}

class _ScannerRetraitScreenState extends State<ScannerRetraitScreen> {
  final _commandeController = TextEditingController();
  final _pinController = TextEditingController();
  final _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.qrCode],
  );
  Map<String, dynamic>? _retrait;
  bool _enCours = false;
  bool _torcheActive = false;

  @override
  void dispose() {
    _commandeController.dispose();
    _pinController.dispose();
    _camera.dispose();
    super.dispose();
  }

  /// Nettoie le jeton pour éliminer espaces, préfixes URL ou clés (ex: "https://.../token" ou "TOKEN:token")
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

  /// QR code détecté par la caméra : son contenu est le jeton de retrait de la commande
  void _surDetection(BarcodeCapture capture) {
    if (_enCours || _retrait != null) return;
    final brut = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (brut == null || brut.trim().isEmpty) return;
    final jeton = _nettoyerJeton(brut);
    if (jeton.isEmpty) return;
    _valider(qrToken: jeton);
  }

  void _validerParPin() {
    final commande = int.tryParse(_commandeController.text.trim().replaceAll(RegExp(r'[^0-9]'), ''));
    final pin = _pinController.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (commande == null) {
      _erreur("Saisissez un numéro de commande valide");
      return;
    }
    if (pin.length != 6) {
      _erreur("Le code PIN doit comporter 6 chiffres (reçu par SMS)");
      return;
    }
    _valider(commandeId: commande, pin: pin);
  }

  Future<void> _valider({String? qrToken, int? commandeId, String? pin}) async {
    setState(() => _enCours = true);
    try {
      await _camera.stop();
    } catch (_) {}
    try {
      final r = await LogistiqueApiService.instance.validerRetrait(
        qrToken: qrToken,
        commandeId: commandeId,
        pin: pin,
      );
      if (!mounted) return;
      setState(() => _retrait = r);
    } catch (e) {
      if (!mounted) return;
      _erreur(e is ApiException ? e.messageComplet : 'Code invalide ou expiré');
      try {
        await _camera.start();
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  void _erreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.danger),
    );
  }

  void _nouveauRetrait() {
    _commandeController.clear();
    _pinController.clear();
    setState(() => _retrait = null);
    try {
      _camera.start();
    } catch (_) {}
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
        title: Text("Validation du Retrait", style: TextStyle(fontFamily: AppTheme.policeTitre, fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.couleurTexte(context))),
        backgroundColor: AppTheme.couleurCarte(context),
        foregroundColor: AppTheme.couleurTexte(context),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (_retrait == null) ...[
              // --- VISEUR : CAMÉRA RÉELLE ---
              Container(
                width: double.infinity,
                height: 260,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 6)),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MobileScanner(
                      controller: _camera,
                      onDetect: _surDetection,
                      errorBuilder: (context, erreur) => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            "Caméra indisponible : autorisez-la dans les réglages, ou utilisez le numéro de commande et le PIN.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 12.5),
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.secondary, width: 3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    // Boutons de contrôle caméra (Lampe torche & Bascule caméra)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: IconButton(
                        tooltip: "Lampe torche",
                        icon: Icon(
                          _torcheActive ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          color: _torcheActive ? AppTheme.secondary : Colors.white,
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
                        "Pointez vers le QR Code du commerçant",
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Text(
                "— OU NUMÉRO DE COMMANDE + PIN —",
                style: TextStyle(color: AppTheme.couleurTexteAttenue(context), fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _commandeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.couleurTexte(context)),
                decoration: _decoration("N° de commande (ex. 12)"),
              ),
              const SizedBox(height: 12),

              // Champ PIN 6 chiffres (reçu par SMS par le commerçant)
              TextField(
                controller: _pinController,
                maxLength: 6,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.bold, color: AppTheme.couleurTexte(context)),
                decoration: _decoration("••••••").copyWith(
                  counterText: "",
                  hintStyle: TextStyle(letterSpacing: 8, color: AppTheme.couleurTexteAttenue(context)),
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: _enCours ? null : _validerParPin,
                icon: _enCours ? const SizedBox.shrink() : const Icon(Icons.check_circle_rounded),
                label: _enCours
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text("Valider la remise du colis"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ] else ...[
              // --- CONFIRMATION RETRAIT RÉUSSI ET FONDS DÉBLOQUÉS ---
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.couleurCarte(context),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 20)],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, color: AppTheme.oliveProfond, size: 48),
                    ),
                    const SizedBox(height: 16),
                    Text("Retrait Confirmé !", style: TextStyle(fontFamily: AppTheme.policeTitre, fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.couleurTexte(context))),
                    const SizedBox(height: 6),
                    Text(
                      "Commande #${_retrait!['commandeId'] ?? ''} remise au commerçant "
                      "(${_retrait!['mode'] == 'QR' ? 'QR code' : 'PIN'}). Les fonds séquestrés sont libérés.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.couleurTexteAttenue(context), fontSize: 13),
                    ),
                    Divider(height: 30, color: AppTheme.couleurBordure(context)),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.couleurFond(context),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Statut du paiement :", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.couleurTexte(context))),
                          const Text(
                            "Fonds libérés",
                            style: TextStyle(color: AppTheme.oliveProfond, fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _nouveauRetrait,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text("Scanner un autre retrait"),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text("Retour au tableau de bord"),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String indice) => InputDecoration(
        hintText: indice,
        hintStyle: TextStyle(color: AppTheme.couleurTexteAttenue(context)),
        filled: true,
        fillColor: AppTheme.couleurCarte(context),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: AppTheme.couleurBordure(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: AppTheme.couleurBordure(context)),
        ),
      );
}
