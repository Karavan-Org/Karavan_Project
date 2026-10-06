import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/logistique_api_service.dart';
import '../services/api/api_exception.dart';

/// Écran de scan du QR Code ou saisie du PIN de retrait par le Courtier (Frame 15)
class ScannerRetraitScreen extends StatefulWidget {
  const ScannerRetraitScreen({super.key});

  @override
  State<ScannerRetraitScreen> createState() => _ScannerRetraitScreenState();
}

class _ScannerRetraitScreenState extends State<ScannerRetraitScreen> {
  final _pinController = TextEditingController();
  bool _valide = false;
  bool _enCours = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _validerRetrait() async {
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez saisir le code PIN de retrait à 4 chiffres")),
      );
      return;
    }

    setState(() => _enCours = true);

    try {
      await LogistiqueApiService.instance.validerRetrait(
        pin: pin,
        commandeId: 1,
      );
      if (!mounted) return;
      setState(() {
        _valide = true;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.messageComplet : 'Code invalide ou expiré';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: const Color(0xFFC0392B)),
      );
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Validation du Retrait", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (!_valide) ...[
              // --- CADRE VISEUR SCANNER QR CODE ---
              Container(
                width: double.infinity,
                height: 240,
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
                    Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.secondary, width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2_rounded, color: Colors.white70, size: 70),
                        SizedBox(height: 8),
                        Text(
                          "Pointez vers le QR Code du client",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text("— OU SAISISSEZ LE PIN DE RETRAIT —", style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Champ PIN 4 chiffres
              TextField(
                controller: _pinController,
                maxLength: 6,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "••••",
                  hintStyle: const TextStyle(letterSpacing: 8, color: Color(0xFFC7BCB2)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFFE2D8CF)),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: _enCours ? null : _validerRetrait,
                icon: _enCours
                    ? const SizedBox.shrink()
                    : const Icon(Icons.check_circle_rounded),
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
                  color: Colors.white,
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
                      child: const Icon(Icons.check_rounded, color: AppTheme.success, size: 48),
                    ),
                    const SizedBox(height: 16),
                    const Text("Retrait Confirmé !", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const Text(
                      "Le colis a été remis au commerçant. Les fonds séquestrés ont été libérés avec succès.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                    const Divider(height: 30),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F6F2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Statut du paiement :", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text("Fonds libérés", style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w800, fontSize: 15)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
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
}
