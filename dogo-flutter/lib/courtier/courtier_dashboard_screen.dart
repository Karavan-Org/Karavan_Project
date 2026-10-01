import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'gestion_convoi_screen.dart';
import 'lancer_convoi_screen.dart';
import 'portefeuille_courtier_screen.dart';
import 'scanner_retrait_screen.dart';

/// Tableau de bord d'accueil du Courtier (Frame 7 - accueil 1 de la planche)
class CourtierDashboardScreen extends StatefulWidget {
  const CourtierDashboardScreen({super.key});

  @override
  State<CourtierDashboardScreen> createState() => _CourtierDashboardScreenState();
}

class _CourtierDashboardScreenState extends State<CourtierDashboardScreen> {
  int _bottomIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Amadou Touré",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                ),
                Text(
                  "Touré Transit & Logistique SARL • Certifié",
                  style: TextStyle(fontSize: 10.5, color: AppTheme.success, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Badge(
              label: Text("3"),
              child: Icon(Icons.notifications_none_rounded, color: AppTheme.textDark),
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomIndex,
        onTap: (index) {
          setState(() => _bottomIndex = index);
          if (index == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const GestionConvoiScreen()));
          } else if (index == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LancerConvoiScreen()));
          } else if (index == 3) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerRetraitScreen()));
          } else if (index == 4) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PortefeuilleCourtierScreen()));
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textMuted,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Accueil"),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping_outlined), label: "Convois"),
          BottomNavigationBarItem(
            icon: CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primary,
              child: Icon(Icons.add, color: Colors.white, size: 20),
            ),
            label: "",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner_rounded), label: "Retraits"),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: "Portefeuille"),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CARTE DU PORTEFEUILLE COMMISSIONS SÉQUESTRÉES ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2C241E), Color(0xFF45362C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Portefeuille Commissions Séquestrées",
                        style: TextStyle(color: Color(0xFFD4C5B9), fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "Garantie Séquestre",
                          style: TextStyle(color: AppTheme.secondary, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "385 000 FCFA",
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Versements directs : Orange Money • Moov",
                        style: TextStyle(color: Color(0xFFA8988B), fontSize: 11),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PortefeuilleCourtierScreen()),
                          );
                        },
                        child: const Row(
                          children: [
                            Text(
                              "Retirer",
                              style: TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.secondary),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- CARTE D'ACTION RAPIDE : CRÉER UN GROUPE / CONVOI ---
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LancerConvoiScreen()));
              },
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.group_add_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Créer votre 1er groupe de clients",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Fédéralisez vos commerçants locaux sans avance de trésorerie.",
                            style: TextStyle(color: Color(0xFFF3EAE2), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- CONVOI EN COURS (ISTANBUL -> BAMAKO) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Convois & Expéditions en Transit",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textDark),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const GestionConvoiScreen()));
                  },
                  child: const Text("Gérer", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEFE8E0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Convoi Istanbul ➔ Bamako (Dabanani)",
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "En transit",
                          style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w700, fontSize: 10.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Jauge d'avancement
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: const LinearProgressIndicator(
                      value: 0.65,
                      minHeight: 8,
                      backgroundColor: Color(0xFFEFE8E0),
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.secondary),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Colis déclarés : 19 / 40", style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      Text(
                        "Commissions : 85 000 FCFA",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerRetraitScreen()));
                    },
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text("Scanner le QR Code d'un commerçant au retrait"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
