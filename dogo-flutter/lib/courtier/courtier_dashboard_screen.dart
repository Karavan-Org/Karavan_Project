import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/api/api_config.dart';
import '../widgets/zone_portefeuille_neumorphic.dart';
import 'gestion_convoi_screen.dart';
import 'creer_groupe_courtier_screen.dart';
import 'portefeuille_courtier_screen.dart';
import 'scanner_retrait_screen.dart';

/// Tableau de bord d'accueil du Courtier (Frame 7 - accueil 1 de la planche)
class CourtierDashboardScreen extends StatefulWidget {
  final bool showBottomNav;

  const CourtierDashboardScreen({
    super.key,
    this.showBottomNav = true,
  });

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
        title: ValueListenableBuilder<UtilisateurProfil?>(
          valueListenable: AuthService.instance.profilNotifier,
          builder: (context, user, _) {
            final nom = user?.nomComplet.isNotEmpty == true ? user!.nomComplet : "Courtier Partenaire";
            final structure = user?.structure?.isNotEmpty == true ? user!.structure! : "Transit & Logistique SARL • Certifié";
            final bool aPhoto = user?.photoUrl != null && user!.photoUrl!.isNotEmpty;

            return Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppTheme.primary,
                  backgroundImage: aPhoto
                      ? NetworkImage(ApiConfig.resolutionImageUrl(user.photoUrl))
                      : null,
                  child: !aPhoto
                      ? const Icon(Icons.person, color: Colors.white, size: 20)
                      : null,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nom,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                    ),
                    Text(
                      structure,
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.success, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.textDark),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Aucune nouvelle notification."),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: widget.showBottomNav
          ? BottomNavigationBar(
              currentIndex: _bottomIndex,
              onTap: (index) {
                setState(() => _bottomIndex = index);
                if (index == 1) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const GestionConvoiScreen()));
                } else if (index == 2) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreerGroupeCourtierScreen()));
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
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- ZONE PORTEFEUILLE NEUMORPHIQUE SOFT 3D (Style Maquette) ---
            ZonePortefeuilleNeumorphic(
              compact: true,
              titre: "Portefeuille Commissions",
              sousTitre: "Commissions de transit & convois",
              montantSolde: "0 FCFA",
              infoSequestre: "Garantie Séquestre DoGo • Versements Orange / Moov",
              iconeInfo: Icons.security_rounded,
              texteBoutonAction: "Gérer & Retirer mes Fonds",
              onTapAction: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PortefeuilleCourtierScreen()),
                );
              },
              couleurBouton: const [
                Color(0xFFC07A3E),
                Color(0xFF9E5C23),
                Color(0xFF7A4012),
              ],
              couleurEmbleme: const [
                Color(0xFFFFFFFF),
                Color(0xFFE5A100),
                Color(0xFF9E5C23),
              ],
            ),

            const SizedBox(height: 20),

            // --- CARTE D'ACTION RAPIDE : CRÉER UN GROUPE / CONVOI ---
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreerGroupeCourtierScreen()));
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
                            style: TextStyle(color: Color(0xFFF3EAE2), fontSize: 11.5),
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
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEFE8E0)),
              ),
              child: Column(
                children: [
                  Icon(Icons.local_shipping_outlined, size: 36, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 10),
                  const Text(
                    "Aucun convoi en cours",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Créez ou prenez en charge un convoi pour démarrer le groupage.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerRetraitScreen()));
                    },
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text("Scanner un QR Code au retrait", maxLines: 1, overflow: TextOverflow.ellipsis),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      minimumSize: const Size(double.infinity, 48),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
