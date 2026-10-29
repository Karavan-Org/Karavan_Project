import '../widgets/bouton_bascule_theme.dart';
import 'package:flutter/material.dart';
import '../models/role_acteur.dart';
import '../theme/app_theme.dart';
import '../widgets/karavan_planet_3d_widget.dart';
import '../widgets/karavan_logo.dart';
import '../commercant/commercant_connexion_screen.dart';
import '../grossiste/grossiste_connexion_screen.dart';

/// Écran d'accueil Onboarding unifié avec animation 3D Three.js
/// Adaptable dynamiquement pour les 3 acteurs : Commerçant, Grossiste, Courtier.
class OnboardingScreen extends StatefulWidget {
  final RoleActeur initialRole;

  const OnboardingScreen({
    super.key,
    this.initialRole = RoleActeur.commercant,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late PageController _pageController;
  late RoleActeur _currentRole;
  int _currentIndex = 0;

  final List<RoleActeur> _roles = [
    RoleActeur.commercant,
    RoleActeur.grossiste,
    RoleActeur.courtier,
  ];

  @override
  void initState() {
    super.initState();
    _currentRole = widget.initialRole;
    _currentIndex = _roles.indexOf(widget.initialRole);
    if (_currentIndex == -1) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onRoleChanged(int index) {
    setState(() {
      _currentIndex = index;
      _currentRole = _roles[index];
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _naviguerVersEspace(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _currentRole == RoleActeur.grossiste
            ? const GrossisteConnexionScreen()
            : CommercantConnexionScreen(role: _currentRole),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.couleurFond(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 560;
            final veryCompact = constraints.maxHeight < 420;
            final narrow = constraints.maxWidth < 360;
            return Column(
              children: [
                // --- EN-TÊTE AVEC LOGO KARAVAN (SANS BOUTON PASSER) ---
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: narrow ? 16 : 24,
                      vertical: veryCompact
                          ? 0
                          : compact
                              ? 4
                              : 10),
                  child: Row(
                    children: [
                      const KaravanLogo(taille: 34),
                      const SizedBox(width: 10),
                      Text(
                        'KARAVAN',
                        style: TextStyle(
                          fontSize: narrow ? 17 : 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.couleurEncre(context),
                          letterSpacing: narrow ? 2 : 3,
                        ),
                      ),
                      const Spacer(),
                      const BoutonBasculeTheme(compact: true),
                    ],
                  ),
                ),

                // --- SÉLECTEUR RAPIDE DES 3 PROFILS (COMMERÇANT / GROSSISTE / COURTIER) ---
                Container(
                  margin: EdgeInsets.symmetric(
                      horizontal: 20, vertical: veryCompact ? 1 : 4),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.couleurCarte(context),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: List.generate(_roles.length, (index) {
                      final role = _roles[index];
                      final isSelected = index == _currentIndex;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _onRoleChanged(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              role.libelle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.couleurTexteAttenue(context),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // --- BADGES FLOTTANTS D'IMPORT-EXPORT ---
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 20, vertical: compact ? 2 : 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: _buildFloatingBadge(
                        icon: Icons.check_circle,
                        iconColor: AppTheme.success,
                        label: "Fret Maritime & Aérien",
                      )),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _buildFloatingBadge(
                        icon: Icons.public,
                        iconColor: AppTheme.secondary,
                        label: "Chine • Dubaï • Bamako",
                      )),
                    ],
                  ),
                ),

                // --- ANIMATION 3D THREE.JS (PLANÈTE, CARGO SUR MER, AVION, CARTON) ---
                const Expanded(
                  child: KaravanPlanet3DWidget(),
                ),

                // --- CARTE INFÉRIEURE AVEC TEXTE DYNAMIQUE DU RÔLE ---
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                      narrow ? 20 : 28,
                      veryCompact
                          ? 8
                          : compact
                              ? 12
                              : 24,
                      narrow ? 20 : 28,
                      veryCompact
                          ? 8
                          : compact
                              ? 12
                              : 20),
                  decoration: BoxDecoration(
                    color: AppTheme.couleurCarte(context),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(36),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0F46321E),
                        blurRadius: 30,
                        offset: Offset(0, -10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Indicateurs de carrousel (3 points)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_roles.length, (index) {
                          final isActive = index == _currentIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            height: 7,
                            width: isActive ? 24 : 7,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppTheme.primary
                                  : const Color(0xFFE2D8CF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      SizedBox(
                          height: veryCompact
                              ? 4
                              : compact
                                  ? 8
                                  : 16),

                      // Contenu texte dynamique selon le profil actif
                      SizedBox(
                        height: veryCompact
                            ? 72
                            : compact
                                ? 112
                                : 120,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentIndex = index;
                              _currentRole = _roles[index];
                            });
                          },
                          itemCount: _roles.length,
                          itemBuilder: (context, index) {
                            final role = _roles[index];
                            return Column(
                              children: [
                                Text(
                                  role.titreAccueil,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontSize: veryCompact
                                            ? 17
                                            : compact
                                                ? 20
                                                : 23,
                                        fontWeight: FontWeight.w800,
                                        height: 1.25,
                                      ),
                                ),
                                SizedBox(height: veryCompact ? 4 : 8),
                                Text(
                                  role.sousTitreAccueil,
                                  textAlign: TextAlign.center,
                                  maxLines: veryCompact ? 2 : 3,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontSize: veryCompact
                                            ? 10.5
                                            : compact
                                                ? 11.5
                                                : 12.5,
                                        color: AppTheme.couleurTexteAttenue(
                                            context),
                                        height: 1.45,
                                      ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      SizedBox(
                          height: veryCompact
                              ? 4
                              : compact
                                  ? 8
                                  : 12),

                      // Bouton principal d'action conforme à la charte (16px, border-radius 30px)
                      ElevatedButton(
                        onPressed: () => _naviguerVersEspace(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          minimumSize: Size(
                              double.infinity,
                              veryCompact
                                  ? 44
                                  : compact
                                      ? 48
                                      : 56),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Suivant",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFloatingBadge({
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.couleurCarte(context).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
