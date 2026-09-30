package ml.dogo.audit.application;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HexFormat;
import java.util.List;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.audit.persistence.JournalAudit;
import ml.dogo.audit.persistence.JournalAuditRepository;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/** Journal d'audit chaîné par hachage SHA-256, en ajout seul (RG-66, RG-67). */
@Service
public class AuditService implements AuditApi {

    static final String HASH_INITIAL = "0".repeat(64);

    private final JournalAuditRepository depot;
    private final Clock horloge;

    public AuditService(JournalAuditRepository depot, Clock horloge) {
        this.depot = depot;
        this.horloge = horloge;
    }

    @Override
    @Transactional(propagation = Propagation.MANDATORY)
    public void tracer(Long acteurId, String action, String avant, String apres) {
        // La ligne « tête » reste verrouillée jusqu'au commit : deux traces simultanées se suivent, sans fourche.
        String precedent = depot.verrouillerTete();
        Instant date = horloge.instant().truncatedTo(ChronoUnit.MILLIS);
        String hash = calculerHash(precedent, acteurId, action, avant, apres, date);
        depot.save(new JournalAudit(acteurId, action, avant, apres, date, precedent, hash));
        depot.mettreAJourTete(hash);
    }

    /** RG-67 : recalcule toute la chaîne et signale la première ligne modifiée. */
    @Transactional(readOnly = true)
    public ResultatVerification verifierChaine() {
        String precedent = HASH_INITIAL;
        long compteur = 0;
        for (JournalAudit ligne : depot.findAllByOrderByIdAsc()) {
            String attendu = calculerHash(precedent, ligne.getActeurId(), ligne.getAction(), ligne.getAvant(),
                    ligne.getApres(), ligne.getDateAudit());
            if (!ligne.getHashPrecedent().equals(precedent) || !ligne.getHash().equals(attendu)) {
                return new ResultatVerification(false, compteur, ligne.getId());
            }
            precedent = ligne.getHash();
            compteur++;
        }
        return new ResultatVerification(true, compteur, null);
    }

    public record LigneAudit(Long id, Long acteurId, String action, String avant, String apres, Instant date,
                             String hash) {
    }

    @Transactional(readOnly = true)
    public List<LigneAudit> dernieres(int taille) {
        if (taille < 1 || taille > 500) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, null, "La taille doit être entre 1 et 500");
        }
        return depot.dernieres(PageRequest.of(0, taille)).stream()
                .map(j -> new LigneAudit(j.getId(), j.getActeurId(), j.getAction(), j.getAvant(), j.getApres(),
                        j.getDateAudit(), j.getHash()))
                .toList();
    }

    public record ResultatVerification(boolean chaineIntacte, long lignesVerifiees, Long premiereLigneFausse) {
    }

    static String calculerHash(String precedent, Long acteurId, String action, String avant, String apres,
                               Instant date) {
        String contenu = String.join("|", precedent, String.valueOf(acteurId), action,
                avant == null ? "" : avant, apres == null ? "" : apres, String.valueOf(date.toEpochMilli()));
        try {
            byte[] octets = MessageDigest.getInstance("SHA-256").digest(contenu.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(octets);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
