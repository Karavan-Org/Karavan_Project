package ml.dogo.audit.api;

/** Point d'entrée des autres modules pour tracer une action sensible (RG-66). */
public interface AuditApi {

    /**
     * Ajoute une ligne au journal d'audit chaîné. S'exécute dans la transaction de l'appelant :
     * si l'opération métier est annulée, la trace l'est aussi.
     */
    void tracer(Long acteurId, String action, String avant, String apres);
}
