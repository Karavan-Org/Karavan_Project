package ml.dogo.identite.application;

import ml.dogo.identite.domain.RoleAdministratif;
import ml.dogo.identite.persistence.UtilisateurRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/**
 * Au premier démarrage, crée l'administrateur TECHNIQUE à partir de DOGO_ADMIN_TEL / DOGO_ADMIN_PIN
 * (sans ces variables, rien n'est créé). C'est lui qui crée ensuite les autres administrateurs.
 */
@Component
public class AmorcageAdministrateur {

    private static final Logger LOG = LoggerFactory.getLogger(AmorcageAdministrateur.class);

    private final AdministrateurService administrateurs;
    private final UtilisateurRepository utilisateurs;
    private final String telephone;
    private final String pin;

    public AmorcageAdministrateur(AdministrateurService administrateurs, UtilisateurRepository utilisateurs,
                                  @Value("${dogo.admin.telephone:}") String telephone,
                                  @Value("${dogo.admin.pin:}") String pin) {
        this.administrateurs = administrateurs;
        this.utilisateurs = utilisateurs;
        this.telephone = telephone;
        this.pin = pin;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void amorcer() {
        if (telephone.isBlank() || pin.isBlank()) {
            return;
        }
        if (utilisateurs.nombreAdministrateurs() > 0) {
            return;
        }
        administrateurs.creerInitial(telephone, "Administrateur technique", pin, "ADM-0001", RoleAdministratif.TECHNIQUE);
        LOG.info("Administrateur technique créé pour le numéro {}", telephone);
    }
}
