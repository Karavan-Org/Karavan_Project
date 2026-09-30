package ml.dogo.logistique.application;

import java.util.List;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.logistique.persistence.PointRetrait;
import ml.dogo.logistique.persistence.PointRetraitRepository;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Points de retrait où les commerçants récupèrent leurs commandes. */
@Service
public class PointRetraitService {

    public record PointVue(long id, String nom, String adresse, String quartier) {
        static PointVue de(PointRetrait p) {
            return new PointVue(p.getId(), p.getNom(), p.getAdresse(), p.getQuartier());
        }
    }

    private final PointRetraitRepository points;
    private final AuditApi audit;

    public PointRetraitService(PointRetraitRepository points, AuditApi audit) {
        this.points = points;
        this.audit = audit;
    }

    @Transactional(readOnly = true)
    public List<PointVue> lister() {
        return points.findAllByOrderByNomAsc().stream().map(PointVue::de).toList();
    }

    @Transactional
    public PointVue creer(long administrateurId, String nom, String adresse, String quartier) {
        if (nom == null || nom.isBlank() || adresse == null || adresse.isBlank()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, null, "Le nom et l'adresse sont obligatoires");
        }
        PointRetrait p = points.save(new PointRetrait(nom.strip(), adresse.strip(),
                quartier == null || quartier.isBlank() ? null : quartier.strip()));
        audit.tracer(administrateurId, "POINT_RETRAIT_CREE", null, "point=" + p.getId() + " " + p.getNom());
        return PointVue.de(p);
    }
}
