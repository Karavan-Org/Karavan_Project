package ml.dogo.audit.api;

import java.time.Instant;
import java.util.Collection;
import java.util.List;

/** Point d'entrée des autres modules pour tracer une action sensible (RG-66) et relire les traces d'acteurs. */
public interface AuditApi {

    /** Trace relue par un autre module : {@code detail} est l'état « après », à défaut l'état « avant ». */
    record TraceInfo(long id, Long acteurId, String action, String detail, Instant date) {
    }

    /**
     * Ajoute une ligne au journal d'audit chaîné. S'exécute dans la transaction de l'appelant :
     * si l'opération métier est annulée, la trace l'est aussi.
     */
    void tracer(Long acteurId, String action, String avant, String apres);

    /** Dernières traces laissées par les acteurs donnés, les plus récentes d'abord (lecture seule). */
    List<TraceInfo> dernieresTracesDe(Collection<Long> acteurIds, int taille);
}
