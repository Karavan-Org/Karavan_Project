package ml.dogo.finance.application;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import ml.dogo.finance.persistence.Sequestre;
import ml.dogo.finance.persistence.SequestreRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Consultation administrative du portefeuille de séquestres de la plateforme (RG-36, RG-38).
 */
@Service
public class SequestreAdminService {

    public record SequestreVue(Long id, Long paiementId, BigDecimal montantBloque, String statut,
                               boolean gele, Instant dateBlocage, Instant dateLiberation) {
    }

    public record SequestreDashboardVue(BigDecimal totalBloque, int nombreSequestres, List<SequestreVue> sequestres) {
    }

    private final SequestreRepository sequestres;

    public SequestreAdminService(SequestreRepository sequestres) {
        this.sequestres = sequestres;
    }

    @Transactional(readOnly = true)
    public SequestreDashboardVue dashboard() {
        List<Sequestre> liste = sequestres.tousLesSequestres();
        BigDecimal total = sequestres.montantTotalBloque();
        List<SequestreVue> vues = liste.stream().map(SequestreAdminService::vue).toList();
        return new SequestreDashboardVue(total, vues.size(), vues);
    }

    private static SequestreVue vue(Sequestre s) {
        return new SequestreVue(s.getId(), s.getPaiementId(), s.getMontantBloque(), s.getStatut().name(),
                s.isGele(), s.getDateBlocage(), s.getDateLiberation());
    }
}
