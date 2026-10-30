package ml.dogo.participation.application;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.groupeachat.api.GroupeAchatApi;
import ml.dogo.identite.api.IdentiteApi;
import ml.dogo.participation.domain.StatutParticipation;
import ml.dogo.participation.persistence.Participation;
import ml.dogo.participation.persistence.ParticipationRepository;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MembresGroupeServiceTest {

    private static final Instant T0 = Instant.parse("2026-10-20T10:00:00Z");

    @Mock private ParticipationRepository participations;
    @Mock private GroupeAchatApi groupes;
    @Mock private IdentiteApi identite;
    @Mock private AuditApi audit;

    private MembresGroupeService service;

    @BeforeEach
    void setup() {
        service = new MembresGroupeService(participations, groupes, identite, audit);
    }

    @Test
    void groupe_inconnu() {
        when(groupes.groupe(9L)).thenReturn(Optional.empty());

        ErreurMetier err = assertThrows(ErreurMetier.class, () -> service.membres(9L));
        assertEquals(CodeErreur.NON_TROUVE, err.code());
    }

    @Test
    void porteur_puis_participants_avec_etat_et_actions() {
        when(groupes.groupe(1L)).thenReturn(Optional.of(groupe(20L, 30L)));

        Participation confirmee = participation(40L, 5, T0.plusSeconds(60));
        confirmee.changerStatut(StatutParticipation.RESERVEE);
        confirmee.changerStatut(StatutParticipation.CONFIRMEE);
        Participation annulee = participation(40L, 3, T0);
        annulee.changerStatut(StatutParticipation.ANNULEE);
        when(participations.findByGroupeIdOrderByIdAsc(1L)).thenReturn(List.of(confirmee, annulee));

        when(identite.acteur(anyLong())).thenAnswer(inv -> {
            long id = inv.getArgument(0);
            String statut = id == 40L ? "SUSPENDU" : "ACTIF";
            return Optional.of(new IdentiteApi.ActeurInfo(id, "X", statut, "Acteur " + id, "+223"));
        });
        when(audit.dernieresTracesDe(anyCollection(), anyInt())).thenReturn(List.of(
                new AuditApi.TraceInfo(2L, 40L, "PARTICIPATION_CONFIRMEE", "5 unités", T0.plusSeconds(120)),
                new AuditApi.TraceInfo(1L, 30L, "GROUPE_PUBLIE", null, T0)));

        var vue = service.membres(1L);

        assertEquals(3, vue.totalMembres());
        assertEquals(1, vue.totalParticipants());
        assertEquals(Map.of("ACTIF", 2L, "SUSPENDU", 1L), vue.parStatutCompte());

        var grossiste = vue.membres().get(0);
        assertEquals("GROSSISTE", grossiste.role());
        assertNull(grossiste.statutParticipation());
        assertEquals(0, grossiste.actions().size());

        assertEquals("COURTIER", vue.membres().get(1).role());
        assertEquals("GROUPE_PUBLIE", vue.membres().get(1).actions().get(0).action());

        var commercant = vue.membres().get(2);
        assertEquals("COMMERCANT", commercant.role());
        assertEquals("SUSPENDU", commercant.statutCompte());
        // La participation confirmée l'emporte ; seule la quantité encore active est comptée
        assertEquals("CONFIRMEE", commercant.statutParticipation());
        assertEquals(5, commercant.quantite());
        assertEquals(T0, commercant.dateParticipation());
        assertEquals(1, commercant.actions().size());
    }

    private static Participation participation(long commercantId, int quantite, Instant date) {
        return new Participation(1L, commercantId, 7L, quantite, date, date.plusSeconds(3600));
    }

    private static GroupeAchatApi.GroupeInfo groupe(long grossisteId, Long courtierId) {
        return new GroupeAchatApi.GroupeInfo(1L, courtierId, grossisteId, 3L, "Riz", "OUVERT", 100, 5, 0,
                BigDecimal.TEN, BigDecimal.ONE, BigDecimal.ZERO, 1, T0.plusSeconds(86_400));
    }
}
