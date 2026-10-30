package ml.dogo.participation.application;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.stream.Collectors;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.groupeachat.api.GroupeAchatApi;
import ml.dogo.identite.api.IdentiteApi;
import ml.dogo.participation.domain.StatutParticipation;
import ml.dogo.participation.persistence.Participation;
import ml.dogo.participation.persistence.ParticipationRepository;
import ml.dogo.shared.errors.ErreurMetier;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Supervision des membres d'un groupe pour l'administrateur : le porteur (grossiste, courtier éventuel) et chaque
 * commerçant participant, avec l'état de son compte, l'état de sa participation et ses dernières actions tracées
 * sur la plateforme (journal d'audit, RG-66).
 */
@Service
@Transactional(readOnly = true)
public class MembresGroupeService {

    /** Nombre d'actions renvoyées par membre : de quoi juger l'activité récente sans surcharger la réponse. */
    static final int ACTIONS_PAR_MEMBRE = 15;

    /** Ordre de priorité pour résumer plusieurs participations (variantes) d'un même commerçant. */
    private static final List<StatutParticipation> PRIORITE = List.of(StatutParticipation.CONFIRMEE,
            StatutParticipation.RESERVEE, StatutParticipation.DEMANDEE, StatutParticipation.ANNULEE,
            StatutParticipation.EXPIREE);

    public record ActionVue(String action, String detail, Instant date) {
    }

    /**
     * {@code statutParticipation}, {@code quantite} et {@code dateParticipation} ne concernent que les commerçants ;
     * {@code quantite} additionne les participations encore actives (une par variante).
     */
    public record MembreVue(long utilisateurId, String nom, String role, String statutCompte,
                            String statutParticipation, int quantite, Instant dateParticipation,
                            List<ActionVue> actions) {
    }

    public record MembresGroupeVue(long groupeId, int totalMembres, int totalParticipants,
                                   Map<String, Long> parStatutCompte, List<MembreVue> membres) {
    }

    private final ParticipationRepository participations;
    private final GroupeAchatApi groupes;
    private final IdentiteApi identite;
    private final AuditApi audit;

    public MembresGroupeService(ParticipationRepository participations, GroupeAchatApi groupes,
                                IdentiteApi identite, AuditApi audit) {
        this.participations = participations;
        this.groupes = groupes;
        this.identite = identite;
        this.audit = audit;
    }

    public MembresGroupeVue membres(long groupeId) {
        GroupeAchatApi.GroupeInfo groupe = groupes.groupe(groupeId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Groupe", groupeId));

        // Porteur d'abord : grossiste du produit, puis courtier s'il y en a un
        Map<Long, String> roles = new LinkedHashMap<>();
        roles.put(groupe.grossisteId(), "GROSSISTE");
        if (groupe.courtierId() != null) {
            roles.put(groupe.courtierId(), "COURTIER");
        }

        Map<Long, List<Participation>> parCommercant = participations.findByGroupeIdOrderByIdAsc(groupeId).stream()
                .collect(Collectors.groupingBy(Participation::getCommercantId, LinkedHashMap::new, Collectors.toList()));
        parCommercant.keySet().forEach(id -> roles.putIfAbsent(id, "COMMERCANT"));

        Map<Long, List<ActionVue>> actions = actionsRecentes(roles.keySet().stream().toList());

        List<MembreVue> membres = new ArrayList<>();
        roles.forEach((id, role) -> {
            IdentiteApi.ActeurInfo acteur = identite.acteur(id).orElse(null);
            String nom = acteur != null ? acteur.nom() : "Utilisateur n° " + id;
            String statutCompte = acteur != null ? acteur.statut() : "INCONNU";
            List<Participation> siennes = parCommercant.getOrDefault(id, List.of());
            membres.add(new MembreVue(id, nom, role, statutCompte,
                    siennes.isEmpty() ? null : statutResume(siennes),
                    siennes.stream().filter(p -> p.getStatut().active()).mapToInt(Participation::getQuantite).sum(),
                    siennes.stream().map(Participation::getDateCreation).min(Comparator.naturalOrder()).orElse(null),
                    actions.getOrDefault(id, List.of())));
        });

        Map<String, Long> parStatutCompte = membres.stream()
                .collect(Collectors.groupingBy(MembreVue::statutCompte, TreeMap::new, Collectors.counting()));
        return new MembresGroupeVue(groupeId, membres.size(), parCommercant.size(), parStatutCompte, membres);
    }

    private Map<Long, List<ActionVue>> actionsRecentes(List<Long> ids) {
        Map<Long, List<ActionVue>> resultat = new LinkedHashMap<>();
        for (AuditApi.TraceInfo t : audit.dernieresTracesDe(ids, ids.size() * ACTIONS_PAR_MEMBRE)) {
            List<ActionVue> siennes = resultat.computeIfAbsent(t.acteurId(), k -> new ArrayList<>());
            if (siennes.size() < ACTIONS_PAR_MEMBRE) {
                siennes.add(new ActionVue(t.action(), t.detail(), t.date()));
            }
        }
        return resultat;
    }

    private static String statutResume(List<Participation> siennes) {
        return siennes.stream().map(Participation::getStatut)
                .min(Comparator.comparingInt(PRIORITE::indexOf))
                .map(Enum::name)
                .orElse(null);
    }
}
