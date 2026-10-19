import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/kyc_api_service.dart';
import '../theme/app_theme.dart';
import 'grossiste_main_nav.dart';
import 'ajouter_produit_screen.dart';
import '../screens/onboarding_screen.dart';

/// Page d'attente Grossiste conforme au design Figma (Frame "Dossier en examen")
/// Affichée après la soumission des documents légaux dans l'attente de la validation par l'administrateur.
class GrossisteEnAttenteScreen extends StatefulWidget {
  final String nomGrossiste;
  final String? telephone;

  const GrossisteEnAttenteScreen({
    super.key,
    this.nomGrossiste = "Grand Dépôt Mandé",
    this.telephone,
  });

  @override
  State<GrossisteEnAttenteScreen> createState() => _GrossisteEnAttenteScreenState();
}

class _GrossisteEnAttenteScreenState extends State<GrossisteEnAttenteScreen> {
  bool _isChecking = false;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verifierStatutSilencieux();
    });
  }

  Future<void> _verifierStatutSilencieux() async {
    try {
      final res = await KycApiService.instance.verifierStatutCompte();
      final statut = res?['statut']?.toString() ?? AuthService.instance.profilActuel?.statut;
      if (!mounted) return;
      if (statut == 'ACTIF') {
        _verifierStatut();
      }
    } catch (_) {}
  }

  void _ouvrirAjoutProduitDirect() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AjouterProduitScreen()),
    );
  }

  Future<void> _verifierStatut() async {
    setState(() => _isChecking = true);
    try {
      final res = await KycApiService.instance.verifierStatutCompte();
      final statut = res?['statut']?.toString() ?? AuthService.instance.profilActuel?.statut ?? 'EN_ATTENTE';

      if (!mounted) return;

      if (statut == 'ACTIF') {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 28),
                SizedBox(width: 10),
                Text("Compte Activé !"),
              ],
            ),
            content: const Text(
              "Félicitations ! Vos pièces justificatives ont été vérifiées et validées par l'administrateur.\n\nVotre espace Grossiste et votre catalogue sont maintenant débloqués.",
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const GrossisteMainNav()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                child: const Text("Accéder à mon espace"),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text("Dossier toujours en cours d'examen par notre équipe administrative."),
                ),
              ],
            ),
            backgroundColor: Color(0xFFD97706),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vérification effectuée. Dossier en attente d'approbation."),
          backgroundColor: Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _onTabTapped(int index) {
    setState(() => _currentTabIndex = index);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (index == 1 || index == 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Envie d'ajouter vos produits dès maintenant ?"),
          action: SnackBarAction(
            label: "Ajouter Produit",
            textColor: const Color(0xFFFFD54F),
            onPressed: _ouvrirAjoutProduitDirect,
          ),
          backgroundColor: const Color(0xFF4A3728),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.lock_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text("Espace vendeur verrouillé jusqu'à validation de vos documents."),
              ),
            ],
          ),
          backgroundColor: Color(0xFF4A3728),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _deconnecter() {
    AuthService.instance.deconnecter();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryCamel = Color(0xFFA67954);
    final nomAffiche = AuthService.instance.profilActuel?.nom.isNotEmpty == true
        ? AuthService.instance.profilActuel!.nom
        : widget.nomGrossiste;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      body: SafeArea(
        child: Column(
          children: [
            // --- 1. EN-TÊTE FIGMA : Avatar boutique + Espace Vendeur dogo + Cloche ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0E3D6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFDFCABA)),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: primaryCamel,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Espace Vendeur dogo",
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8A786A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          nomAffiche,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E1E24),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _deconnecter,
                    tooltip: "Se déconnecter",
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFF8A786A), size: 22),
                  ),
                  Stack(
                    children: [
                      IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Vous recevrez une alerte dès validation de votre dossier."),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          color: Color(0xFF2C241E),
                          size: 24,
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE65100),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // --- CONTENU DÉFILABLE ---
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 2. BANNIÈRE PRINCIPALE FIGMA "DOSSIER EN EXAMEN" ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9EE),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFF3E3CE), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFA67954).withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ligne badge + délai
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.access_time_filled, color: Color(0xFFD97706), size: 12),
                                    SizedBox(width: 5),
                                    Text(
                                      "DOSSIER EN EXAMEN",
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFB45309),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Text(
                                "Délai : ~6 heures",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8A786A),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Titre principal
                          const Text(
                            "Vérification de vos pièces légales",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2C241E),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Notre équipe RH et légale étudie vos documents administratifs avant d'activer votre compte vendeur.",
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF6B5C50),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // --- STEPPER VISUEL FIGMA (1. Dépôt -> 2. Audit -> 3. Ventes) ---
                          Row(
                            children: [
                              // Étape 1 : Dépôt (validé vert)
                              _buildStepNode(
                                label: "1. Dépôt",
                                isDone: true,
                                isActive: false,
                                icon: Icons.check,
                                color: const Color(0xFF10B981),
                              ),
                              Expanded(
                                child: Container(
                                  height: 2.5,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                              // Étape 2 : Audit (en cours orange)
                              _buildStepNode(
                                label: "2. Audit",
                                isDone: false,
                                isActive: true,
                                icon: Icons.hourglass_top_rounded,
                                color: const Color(0xFFF59E0B),
                              ),
                              Expanded(
                                child: Container(
                                  height: 2.5,
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              // Étape 3 : Ventes (cadenas gris)
                              _buildStepNode(
                                label: "3. Ventes",
                                isDone: false,
                                isActive: false,
                                icon: Icons.lock_rounded,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),
                          const Divider(color: Color(0xFFEFE4D6), height: 1),
                          const SizedBox(height: 12),

                          // Note SMS & notification
                          const Row(
                            children: [
                              Icon(Icons.notifications_active_outlined, size: 16, color: Color(0xFFB45309)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Vous recevrez une notification et un SMS dès validation définitive.",
                                  style: TextStyle(
                                    fontSize: 11.8,
                                    color: Color(0xFF856404),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // --- 3. SECTION "VOTRE DOSSIER & ASSISTANCE" FIGMA ---
                    const Text(
                      "Votre dossier & Assistance",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2C241E),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Card 1 : Documents légaux soumis
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFEFE7DE)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.verified_user_outlined,
                              color: Color(0xFF10B981),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Documents légaux soumis",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: Color(0xFF1E1E24),
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  "RCCM & Pièce d'identité enregistrés",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8A786A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check, size: 12, color: Color(0xFF059669)),
                                SizedBox(width: 4),
                                Text(
                                  "Aucune action requise",
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Card 2 : Équipe d'intégration dogo (WhatsApp)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFEFE7DE)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Color(0xFF25D366),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Équipe d'intégration dogo",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: Color(0xFF1E1E24),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  "Besoin d'accélérer la vérification de votre compte ?",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8A786A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Contact support Bamako : support@dogo.ml / WhatsApp : +223 70 00 00 00"),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    "Échanger sur WhatsApp avec un agent à Bamako →",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF25D366),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Card 3 : Engagement dogo
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F7F5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEFE7DE)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: primaryCamel, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Engagement dogo : Votre catalogue sera instantanément débloqué après validation.",
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF6B5C50),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Card 4 : Accès immédiat & Ajouter un produit
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF4ED),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2C9B6), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFA67954).withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: primaryCamel.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.inventory_2_rounded, color: primaryCamel, size: 22),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Préparer votre catalogue",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14.5,
                                        color: Color(0xFF1E1E24),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      "Ajoutez vos articles dès maintenant",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF8A786A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Vous pouvez saisir vos produits, photos et stocks à l'avance. Ils seront disponibles dès l'activation de votre compte.",
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF4A3728), height: 1.3),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: ElevatedButton.icon(
                                  onPressed: _ouvrirAjoutProduitDirect,
                                  icon: const Icon(Icons.add_rounded, size: 19),
                                  label: const Text(
                                    "Ajouter un produit",
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryCamel,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Bouton Actualiser l'état
                    OutlinedButton.icon(
                      onPressed: _isChecking ? null : _verifierStatut,
                      icon: _isChecking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: primaryCamel),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18, color: primaryCamel),
                      label: Text(
                        _isChecking ? "Vérification en cours..." : "Actualiser le statut de mon dossier",
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: primaryCamel),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: primaryCamel, width: 1.2),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // --- 4. BARRE DE NAVIGATION INFÉRIEURE FIGMA AVEC CADENAS CENTRAL ---
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 64,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildBottomNavItem(0, Icons.home_rounded, "Accueil", _currentTabIndex == 0),
                      _buildBottomNavItem(1, Icons.inventory_2_outlined, "Produits", _currentTabIndex == 1),

                      // Cadenas central doré Figma
                      GestureDetector(
                        onTap: () => _onTabTapped(2),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0E3D6),
                            shape: BoxShape.circle,
                            border: Border.all(color: primaryCamel.withValues(alpha: 0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: primaryCamel.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.lock_rounded, color: primaryCamel, size: 22),
                        ),
                      ),

                      _buildBottomNavItem(3, Icons.groups_outlined, "Groupes", _currentTabIndex == 3),
                      _buildBottomNavItem(4, Icons.person_outline_rounded, "Profil", _currentTabIndex == 4),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepNode({
    required String label,
    required bool isDone,
    required bool isActive,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDone
                ? color
                : isActive
                    ? color.withValues(alpha: 0.15)
                    : const Color(0xFFF3F4F6),
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isDone ? Colors.white : color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive || isDone ? FontWeight.w800 : FontWeight.w600,
            color: isDone
                ? const Color(0xFF10B981)
                : isActive
                    ? const Color(0xFFD97706)
                    : const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavItem(int index, IconData icon, String label, bool isSelected) {
    const primaryCamel = Color(0xFFA67954);
    return InkWell(
      onTap: () => _onTabTapped(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? primaryCamel : const Color(0xFF9CA3AF),
            size: 22,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? primaryCamel : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}
