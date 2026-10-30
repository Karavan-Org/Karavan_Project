package ml.dogo.groupeachat.application;

import java.util.List;
import ml.dogo.groupeachat.persistence.Pays;
import ml.dogo.groupeachat.persistence.PaysRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Service applicatif pour la consultation des pays d'origine d'importation.
 */
@Service
@Transactional(readOnly = true)
public class PaysService {

    public record PaysVue(String codeIso, String codeIso3, String nomFr, Double latitude, Double longitude) {
        public static PaysVue de(Pays p) {
            return new PaysVue(p.getCodeIso(), p.getCodeIso3(), p.getNomFr(), p.getLatitude(), p.getLongitude());
        }
    }

    private final PaysRepository paysRepository;

    public PaysService(PaysRepository paysRepository) {
        this.paysRepository = paysRepository;
    }

    public List<PaysVue> listerActifs() {
        return paysRepository.findByActifTrueOrderByNomFrAsc()
                .stream()
                .map(PaysVue::de)
                .toList();
    }

    /**
     * Résout intelligemment un pays à partir d'un code ISO-2, ISO-3, ou de son nom français (avec ou sans accents).
     * Exemples reconnus automatiquement : "ML", "MLI", "Mali", "mali", "TR", "TUR", "Turquie", "CN", "Chine",
     * "Sénégal", "Senegal", "Côte d'Ivoire", "Cote d'Ivoire", "Brésil", "Bresil", "France", "Ghana", "Maroc"...
     */
    public java.util.Optional<Pays> resoudre(String saisie) {
        if (saisie == null || saisie.isBlank()) {
            return java.util.Optional.empty();
        }
        String clean = saisie.trim();

        // 1. Recherche directe par code ISO-2 (2 lettres : ML, CN, TR, CI, SN, GH, BR...)
        if (clean.length() == 2) {
            java.util.Optional<Pays> p = paysRepository.findById(clean.toUpperCase());
            if (p.isPresent()) return p;
        }

        // 2. Recherche par code ISO-3 (3 lettres : MLI, CHN, TUR, CIV, SEN, GHA, BRA...)
        if (clean.length() == 3) {
            java.util.Optional<Pays> p = paysRepository.findByCodeIso3IgnoreCase(clean);
            if (p.isPresent()) return p;
        }

        // 3. Recherche par nom exact ou sans accent
        String normSaisie = normaliser(clean);
        List<Pays> tous = paysRepository.findAll();
        for (Pays p : tous) {
            if (normaliser(p.getNomFr()).equals(normSaisie)
                    || normaliser(p.getCodeIso()).equals(normSaisie)
                    || (p.getCodeIso3() != null && normaliser(p.getCodeIso3()).equals(normSaisie))) {
                return java.util.Optional.of(p);
            }
        }

        // 4. Recherche par inclusion (ex: "Emirats" -> Émirats arabes unis)
        for (Pays p : tous) {
            String normNom = normaliser(p.getNomFr());
            if (!normSaisie.isEmpty() && (normNom.contains(normSaisie) || normSaisie.contains(normNom))) {
                return java.util.Optional.of(p);
            }
        }

        return java.util.Optional.empty();
    }

    public static String normaliser(String texte) {
        if (texte == null) return "";
        return java.text.Normalizer.normalize(texte, java.text.Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "")
                .replaceAll("[^a-zA-Z0-9]", "")
                .toLowerCase(java.util.Locale.ROOT);
    }
}

