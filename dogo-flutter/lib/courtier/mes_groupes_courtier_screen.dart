import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'lancer_convoi_screen.dart';

/// Écran "Mes groupes" du Courtier (Groupes & Convois logistiques pris en charge)
class MesGroupesCourtierScreen extends StatefulWidget {
  const MesGroupesCourtierScreen({super.key});

  @override
  State<MesGroupesCourtierScreen> createState() => _MesGroupesCourtierScreenState();
}

class _MesGroupesCourtierScreenState extends State<MesGroupesCourtierScreen> {
  String _filtre = "Tous";

  final List<Map<String, dynamic>> _groupesConvois = [];

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
          "Mes Groupes & Convois",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF2C241E)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF9E6738)),
            tooltip: "Lancer un convoi",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LancerConvoiScreen()),
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
                _buildFilterChip("En transit"),
                const SizedBox(width: 8),
                _buildFilterChip("Prêt retrait"),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Liste des groupes
          Expanded(
            child: _groupesConvois.isEmpty
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
                              Icons.hub_outlined,
                              size: 40,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Aucun groupe pris en charge",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF2C241E),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Lancez ou prenez en charge un convoi pour démarrer les opérations.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              itemCount: _groupesConvois.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final c = _groupesConvois[index];
                final double ratio = c["capaciteRatio"] as double;

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
                              c["code"] as String,
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
                              color: (c["statutColor"] as Color).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              c["statut"] as String,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: c["statutColor"] as Color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        c["trajet"] as String,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF2C241E)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Marchandises : ${c["lotsAssocies"]}",
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8C7E74)),
                      ),
                      const SizedBox(height: 12),

                      // Jauge de capacité
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Capacité fret : ${c["poidsTotal"]}",
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF2C241E)),
                          ),
                          Text(
                            "${(ratio * 100).toInt()}%",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: c["statutColor"] as Color,
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
                          valueColor: AlwaysStoppedAnimation<Color>(c["statutColor"] as Color),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.people_outline, size: 16, color: Color(0xFF8C7E74)),
                              const SizedBox(width: 4),
                              Text(
                                "${c["commercants"]} commerçants rattachés",
                                style: const TextStyle(fontSize: 12, color: Color(0xFF8C7E74)),
                              ),
                            ],
                          ),
                          Text(
                            "Com. : ${c["commissionEstimee"]}",
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF9E6738)),
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
