import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'creer_groupe_grossiste_screen.dart';

/// Écran "Mes groupes" du Grossiste
/// Liste des campagnes d'achats groupés lancées, suivi des réservations et des jauges
class MesGroupesGrossisteScreen extends StatefulWidget {
  const MesGroupesGrossisteScreen({super.key});

  @override
  State<MesGroupesGrossisteScreen> createState() => _MesGroupesGrossisteScreenState();
}

class _MesGroupesGrossisteScreenState extends State<MesGroupesGrossisteScreen> {
  String _filtre = "Tous";

  final List<Map<String, dynamic>> _groupes = [];

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
          "Mes Groupes d'Achat",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF2C241E)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF9E6738)),
            tooltip: "Nouveau groupe",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreerGroupeGrossisteScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filtres
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip("Tous"),
                const SizedBox(width: 8),
                _buildFilterChip("En cours"),
                const SizedBox(width: 8),
                _buildFilterChip("Atteints"),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Liste des groupes
          Expanded(
            child: _groupes.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.groups_outlined,
                              size: 40,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Aucun groupe d'achat",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF2C241E),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Créez un premier groupe pour proposer vos lots aux commerçants de Bamako.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              itemCount: _groupes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final g = _groupes[index];
                final double ratio = (g["piecesReservees"] as int) / (g["objectifPieces"] as int);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFEFE9E0)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0646321E), blurRadius: 10, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7EFE7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              g["id"] as String,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF9E6738),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (g["statutColor"] as Color).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              g["statut"] as String,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: g["statutColor"] as Color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        g["titre"] as String,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF2C241E)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Origine : ${g["origine"]} • ${g["tempsRestant"]}",
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF8C7E74)),
                      ),
                      const SizedBox(height: 12),

                      // Jauge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${g["piecesReservees"]} / ${g["objectifPieces"]} pièces réservées",
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF2C241E)),
                          ),
                          Text(
                            "${(ratio * 100).toInt()}%",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: g["statutColor"] as Color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFEFE9E0),
                          valueColor: AlwaysStoppedAnimation<Color>(g["statutColor"] as Color),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${g["commercants"]} commerçants engagés",
                            style: const TextStyle(fontSize: 12, color: Color(0xFF8C7E74)),
                          ),
                          Text(
                            g["prixGros"] as String,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF9E6738)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filtre == label;
    return GestureDetector(
      onTap: () => setState(() => _filtre = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF9E6738) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isSelected ? const Color(0xFF9E6738) : const Color(0xFFE5DDD5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF5A493B),
          ),
        ),
      ),
    );
  }
}
