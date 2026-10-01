package ml.dogo.notification.application;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/** Simulation : le SMS apparaît dans les logs de l'application. À remplacer par un fournisseur réel. */
@Component
public class PasserelleSmsSimulee implements PasserelleSms {

    private static final Logger LOG = LoggerFactory.getLogger("dogo.sms");

    @Override
    public boolean envoyer(String telephone, String message) {
        String masque = message != null
                ? message.replaceAll("(?i)(PIN de retrait\\s*:\\s*)\\d+", "$1******")
                         .replaceAll("(?i)(code\\s*(?:de vérification)?\\s*(?:est|:)\\s*)\\d+", "$1******")
                         .replaceAll("(?i)(code\\s*:\\s*)\\d+", "$1******")
                : null;
        LOG.info("[SMS simulé] -> {} : {}", telephone, masque);
        return true;
    }
}
