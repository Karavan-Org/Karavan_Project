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
}

