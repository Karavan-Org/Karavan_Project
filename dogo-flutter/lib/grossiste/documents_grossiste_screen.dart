import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Écran "Mes documents" du Grossiste (Licences export, KYC, Registre commerce, Contrats)
class DocumentsGrossisteScreen extends StatelessWidget {
  const DocumentsGrossisteScreen({super.key});

  final List<Map<String, dynamic>> _docs = const [
    {
      "titre": "Licence d'Exportation Internationale",
      "reference": "LIC-EXP-2026-WZ-99",
      "date": "Validité jusqu'au 31 déc. 2027",
      "statut": "Vérifié & Approuvé",
      "icon": Icons.verified_user_rounded,
    },
    {
      "titre": "Certificat d'Enregistrement Usine (Wenzhou)",
      "reference": "REG-IND-882104-CN",
      "date": "Délivré le 15 janv. 2024",
      "statut": "Actif",
      "icon": Icons.business_rounded,
    },
    {
      "titre": "Contrat Cadre Transitaire DoGo Transit",
      "reference": "CTR-DOGO-LOG-2026",
      "date": "Agréé CEMAC/UEMOA",
      "statut": "Signé",
      "icon": Icons.handshake_rounded,
    },
    {
      "titre": "Attestation Bancaire SWIFT (USD / CNY)",
      "reference": "SWIFT-BOC-55091",
      "date": "Bank of China / Ecobank Mali",
      "statut": "Validé",
      "icon": Icons.account_balance_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF2C241E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Mes Documents & Certifications",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF2C241E)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_rounded, color: Color(0xFF9E6738)),
            tooltip: "Ajouter un document",
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Sélection de document PDF / Photo pour mise à jour KYC")),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
        children: [
          // Bandeau d'information
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9E6),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5A100).withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_rounded, color: Color(0xFFD48800), size: 26),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    "Votre compte est vérifié et couvert par la garantie DoGo.",
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF6A4C00), height: 1.35),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          ..._docs.map((doc) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEFE9E0)),
              boxShadow: const [
                BoxShadow(color: Color(0x0646321E), blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7EFE7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(doc["icon"] as IconData, color: const Color(0xFF9E6738), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc["titre"] as String,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF2C241E)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        doc["reference"] as String,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF9E6738), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        doc["date"] as String,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    doc["statut"] as String,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.success),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
