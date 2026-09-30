package ml.dogo.shared.web;

import java.util.List;
import ml.dogo.shared.errors.ErreurMetier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.PessimisticLockingFailureException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/** Traduit les erreurs en réponses JSON homogènes (RFC 7807), avec le numéro de règle de gestion concernée. */
@RestControllerAdvice
public class GestionnaireErreurs {

    private static final Logger LOG = LoggerFactory.getLogger(GestionnaireErreurs.class);

    @ExceptionHandler(ErreurMetier.class)
    public ProblemDetail metier(ErreurMetier e) {
        ProblemDetail p = ProblemDetail.forStatusAndDetail(HttpStatus.valueOf(e.code().statutHttp()), e.getMessage());
        p.setProperty("code", e.code().name());
        if (e.regle() != null) {
            p.setProperty("regle", e.regle());
        }
        return p;
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail validation(MethodArgumentNotValidException e) {
        ProblemDetail p = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, "Données invalides");
        List<String> champs = e.getBindingResult().getFieldErrors().stream()
                .map(f -> f.getField() + " : " + f.getDefaultMessage()).toList();
        p.setProperty("code", "DONNEES_INVALIDES");
        p.setProperty("erreurs", champs);
        return p;
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ProblemDetail acces(AccessDeniedException e) {
        ProblemDetail p = ProblemDetail.forStatusAndDetail(HttpStatus.FORBIDDEN, "Accès refusé");
        p.setProperty("code", "ACCES_REFUSE");
        return p;
    }

    /** Dernier rempart : une contrainte de la base a refusé l'écriture (les règles du code auraient dû l'attraper). */
    @ExceptionHandler(DataIntegrityViolationException.class)
    public ProblemDetail integrite(DataIntegrityViolationException e) {
        LOG.warn("Violation de contrainte en base", e);
        ProblemDetail p = ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT,
                "L'opération viole une contrainte d'intégrité");
        p.setProperty("code", "CONFLIT");
        return p;
    }

    /**
     * Deux opérations se sont attendues l'une l'autre (interblocage) ou un verrou a expiré : la base a annulé celle-ci,
     * rien n'a été modifié, le client peut simplement recommencer.
     */
    @ExceptionHandler(PessimisticLockingFailureException.class)
    public ProblemDetail verrou(PessimisticLockingFailureException e) {
        LOG.warn("Conflit de verrous, l'opération est à refaire", e);
        ProblemDetail p = ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT,
                "Une autre opération est en cours sur les mêmes données : réessayez dans un instant");
        p.setProperty("code", "CONFLIT");
        return p;
    }
}
