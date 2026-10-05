/// Modèle d'un groupe d'achat / campagne d'importation groupée
class GroupeCampagneModel {
  final String id;
  final String titre;
  final String sousTitre;
  final String imagePath;
  final int prixGroupe;
  final int prixPublic;
  final int quantiteActuelle;
  final int quantiteObjectif;
  final String categorie;
  final String paysOrigine;
  final String courtierNom;
  final String grossisteNom;
  final String tempsRestant;

  const GroupeCampagneModel({
    required this.id,
    required this.titre,
    required this.sousTitre,
    required this.imagePath,
    required this.prixGroupe,
    required this.prixPublic,
    required this.quantiteActuelle,
    required this.quantiteObjectif,
    required this.categorie,
    this.paysOrigine = "Istanbul, Turquie",
    this.courtierNom = "Touré Transit & Logistique SARL",
    this.grossisteNom = "Grossiste Cissé & Fils (Turquie)",
    this.tempsRestant = "3 jours restants",
  });

  double get ratio => (quantiteActuelle / quantiteObjectif).clamp(0.0, 1.0);
  int get reste => quantiteObjectif - quantiteActuelle;
}
