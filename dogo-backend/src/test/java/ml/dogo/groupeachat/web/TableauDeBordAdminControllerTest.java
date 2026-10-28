package ml.dogo.groupeachat.web;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import ml.dogo.groupeachat.application.GroupeService;
import ml.dogo.groupeachat.application.TableauDeBordAdminService;
import ml.dogo.shared.security.UtilisateurCourant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class TableauDeBordAdminControllerTest {

    private final TableauDeBordAdminService service = mock(TableauDeBordAdminService.class);
    private TableauDeBordAdminController controller;

    @BeforeEach
    void setUp() {
        controller = new TableauDeBordAdminController(service);
    }

    @Test
    void resumeRenvoieLesDonneesDuService() {
        TableauDeBordAdminService.ResumeVue mockVue = new TableauDeBordAdminService.ResumeVue(
                new TableauDeBordAdminService.UtilisateursResume(100, 10, 5, 115),
                20,
                Map.of("OUVERT", 10L),
                List.of(new TableauDeBordAdminService.RepartitionPaysVue("CN", "Chine", 10L, 50.0, 35.86, 104.19)),
                2,
                5,
                65.4,
                8,
                0
        );

        when(service.resume()).thenReturn(mockVue);

        TableauDeBordAdminService.ResumeVue res = controller.resume();
        assertNotNull(res);
        assertEquals(20, res.totalGroupes());
        assertEquals(2, res.groupesSansPays());
        assertEquals(1, res.repartitionPays().size());
    }

    @Test
    void groupesPourCadranTransmetLesFiltres() {
        when(service.groupesPourCadran(any(), any(), any(), anyInt(), anyInt())).thenReturn(List.of());

        List<TableauDeBordAdminService.GroupeCadranVue> res = controller.groupes(null, "CN", "test", 0, 50);
        assertNotNull(res);
        verify(service).groupesPourCadran(null, "CN", "test", 0, 50);
    }

    @Test
    void assignerPaysAppelleServiceAvecAdminCourant() {
        UtilisateurCourant admin = new UtilisateurCourant(1L, "ADMINISTRATEUR", List.of("ADMIN_CREER"), 100L);
        when(service.assignerPays(anyLong(), anyLong(), anyString())).thenReturn(mock(GroupeService.GroupeVue.class));

        controller.assignerPays(admin, 42L, new TableauDeBordAdminController.PaysAssignationRequete("TR"));
        verify(service).assignerPays(1L, 42L, "TR");
    }
}
