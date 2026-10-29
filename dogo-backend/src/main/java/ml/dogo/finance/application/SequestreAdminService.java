package ml.dogo.finance.application;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import ml.dogo.finance.domain.StatutSequestre;
import ml.dogo.finance.persistence.FraisPlateforme;
import ml.dogo.finance.persistence.FraisPlateformeRepository;
import ml.dogo.finance.persistence.PaiementRepository;
import ml.dogo.finance.persistence.Sequestre;
import ml.dogo.finance.persistence.SequestreRepository;
import ml.dogo.groupeachat.api.GroupeAchatApi;
import ml.dogo.identite.api.IdentiteApi;
import ml.dogo.participation.api.ParticipationApi;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Consultation administrative du portefeuille de séquestres de la plateforme (RG-36, RG-38) : chaque séquestre est
 * relié à son groupe, à son acheteur et au bénéficiaire (le porteur du groupe : courtier, ou grossiste sans courtier).
 */
@Service
public class SequestreAdminService {

    public record SequestreVue(Long id, Long paiementId, BigDecimal montantBloque, String statut,
                               boolean gele, Instant dateBlocage, Instant dateLiberation, Long groupeId,
                               String groupeTitre, String groupeStatut, int quantite, String acheteur,
                               String beneficiaire, Long participationId, Long acheteurId, Long beneficiaireId,
                               Long grossisteId, Long courtierId) {
    }

    public record SequestreDashboardVue(BigDecimal totalBloque, int nombreSequestres, List<SequestreVue> sequestres,
                                        BigDecimal totalLibere, BigDecimal totalRestitue, BigDecimal totalGele,
                                        BigDecimal commissions) {
    }

    private final SequestreRepository sequestres;
    private final PaiementRepository paiements;
    private final FraisPlateformeRepository frais;
    private final ParticipationApi participations;
    private final GroupeAchatApi groupes;
    private final IdentiteApi identite;

    public SequestreAdminService(SequestreRepository sequestres, PaiementRepository paiements,
                                 FraisPlateformeRepository frais, ParticipationApi participations,
                                 GroupeAchatApi groupes, IdentiteApi identite) {
        this.sequestres = sequestres;
        this.paiements = paiements;
        this.frais = frais;
        this.participations = participations;
        this.groupes = groupes;
        this.identite = identite;
    }

    @Transactional(readOnly = true)
    public SequestreDashboardVue dashboard() {
        List<Sequestre> liste = sequestres.tousLesSequestres();
        BigDecimal total = sequestres.montantTotalBloque();
        List<SequestreVue> vues = liste.stream().map(this::vue).toList();
        return new SequestreDashboardVue(total, vues.size(), vues,
                somme(liste, StatutSequestre.LIBERE), somme(liste, StatutSequestre.RESTITUE),
                liste.stream().filter(Sequestre::isGele).map(Sequestre::getMontantBloque)
                        .reduce(BigDecimal.ZERO, BigDecimal::add),
                frais.findAll().stream().map(FraisPlateforme::getMontant).reduce(BigDecimal.ZERO, BigDecimal::add));
    }

    private static BigDecimal somme(List<Sequestre> liste, StatutSequestre statut) {
        return liste.stream().filter(s -> s.getStatut() == statut).map(Sequestre::getMontantBloque)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private SequestreVue vue(Sequestre s) {
        ParticipationApi.ParticipationInfo part = paiements.findById(s.getPaiementId())
                .flatMap(p -> participations.participation(p.getParticipationId())).orElse(null);
        GroupeAchatApi.GroupeInfo g = part == null ? null : groupes.groupe(part.groupeId()).orElse(null);
        return new SequestreVue(s.getId(), s.getPaiementId(), s.getMontantBloque(), s.getStatut().name(),
                s.isGele(), s.getDateBlocage(), s.getDateLiberation(),
                g == null ? null : g.id(), g == null ? null : g.produitNom(), g == null ? null : g.statut(),
                part == null ? 0 : part.quantite(),
                part == null ? null : nom(part.commercantId()),
                g == null ? null : nom(g.porteurId()),
                part == null ? null : part.id(), part == null ? null : part.commercantId(),
                g == null ? null : g.porteurId(), g == null ? null : g.grossisteId(), g == null ? null : g.courtierId());
    }

    private String nom(long utilisateurId) {
        return identite.acteur(utilisateurId).map(IdentiteApi.ActeurInfo::nom).orElse("?");
    }
}
