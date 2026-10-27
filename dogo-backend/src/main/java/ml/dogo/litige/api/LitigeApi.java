package ml.dogo.litige.api;

import java.time.Instant;
import java.util.List;

/** Interface publique du module litiges pour la consultation par les autres modules. */
public interface LitigeApi {

    record LitigeInfo(long id, long commandeId, String motif, String statut,
                      Instant dateOuverture, Instant dateResolution) {
    }

    List<LitigeInfo> lister();
}
