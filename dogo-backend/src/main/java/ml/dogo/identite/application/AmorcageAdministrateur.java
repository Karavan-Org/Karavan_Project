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
    private final String motDePasse;

    public AmorcageAdministrateur(AdministrateurService administrateurs, UtilisateurRepository utilisateurs,
                                  @Value("${dogo.admin.telephone:${dogo.admin.tel:}}") String telephone,
                                  @Value("${dogo.admin.mot-de-passe:${dogo.admin.password:${dogo.admin.pin:}}}") String motDePasse) {
        this.administrateurs = administrateurs;
        this.utilisateurs = utilisateurs;
        this.telephone = telephone;
        this.motDePasse = motDePasse;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void amorcer() {
        if (telephone.isBlank() || motDePasse.isBlank()) {
            LOG.info("Amorçage administrateur : aucune variable (DOGO_ADMIN_TELEPHONE / DOGO_ADMIN_MOT_DE_PASSE) renseignée.");
            return;
        }
        if (utilisateurs.nombreAdministrateurs() > 0) {
            return;
        }
        administrateurs.creerInitial(telephone, "Administrateur technique", motDePasse, "ADM-0001", RoleAdministratif.TECHNIQUE);
        LOG.info("Administrateur technique créé pour le numéro {}", telephone);
    }
}
