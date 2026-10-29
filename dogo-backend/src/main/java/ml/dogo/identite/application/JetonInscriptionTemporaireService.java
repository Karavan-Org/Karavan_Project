package ml.dogo.identite.application;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import javax.crypto.SecretKey;
import ml.dogo.shared.config.DogoProperties;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.springframework.stereotype.Service;

/**
 * Gère l'émission et la validation des jetons temporaires d'inscription Google (RG-07).
 * Durée de validité courte (15 minutes), usage unique, cryptographiquement signés.
 * Ne confère aucun droit d'accès aux ressources protégées.
 */
@Service
public class JetonInscriptionTemporaireService {

    private static final Duration DUREE_VALIDITE = Duration.ofMinutes(15);
    private final SecretKey cleSignature;
    private final Set<String> jetonsConsommes = ConcurrentHashMap.newKeySet();

    public JetonInscriptionTemporaireService(DogoProperties proprietes) {
        // Dérive une clé HMAC sécurisée à partir du secret JWT de la plateforme
        byte[] octets = (proprietes.jwt().secret() + "-jeton-inscription-google-2026")
                .getBytes(StandardCharsets.UTF_8);
        this.cleSignature = Keys.hmacShaKeyFor(octets);
    }

    /** Émet un jeton temporaire d'inscription pour un profil Google incomplet. */
    public String emettre(GoogleIdTokenInfo info) {
        Instant maintenant = Instant.now();
        Instant expiration = maintenant.plus(DUREE_VALIDITE);

        return Jwts.builder()
                .subject(info.sub())
                .claim("email", info.email())
                .claim("emailVerified", info.emailVerified())
                .claim("nom", info.nom())
                .claim("photoUrl", info.photoUrl())
                .claim("type", "GOOGLE_INSCRIPTION_TEMP")
                .issuedAt(Date.from(maintenant))
                .expiration(Date.from(expiration))
                .signWith(cleSignature)
                .compact();
    }

    /** Valide le jeton temporaire et extrait les informations du profil Google. */
    public GoogleIdTokenInfo valider(String jeton) {
        if (jeton == null || jeton.isBlank()) {
            throw new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, "RG-07",
                    "Jeton d'inscription temporaire absent");
        }
        if (jetonsConsommes.contains(jeton)) {
            throw new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, "RG-07",
                    "Ce jeton d'inscription a déjà été utilisé");
        }

        try {
            Claims claims = Jwts.parser()
                    .verifyWith(cleSignature)
                    .build()
                    .parseSignedClaims(jeton)
                    .getPayload();

            String type = claims.get("type", String.class);
            if (!"GOOGLE_INSCRIPTION_TEMP".equals(type)) {
                throw new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, "RG-07",
                        "Type de jeton invalide");
            }

            String sub = claims.getSubject();
            String email = claims.get("email", String.class);
            Boolean emailVerified = claims.get("emailVerified", Boolean.class);
            String nom = claims.get("nom", String.class);
            String photoUrl = claims.get("photoUrl", String.class);

            return new GoogleIdTokenInfo(
                    sub,
                    email,
                    Boolean.TRUE.equals(emailVerified),
                    nom != null ? nom : "Utilisateur Google",
                    photoUrl
            );
        } catch (ErreurMetier em) {
            throw em;
        } catch (Exception e) {
            throw new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, "RG-07",
                    "Jeton d'inscription Google expiré ou invalide : veuillez vous réauthentifier");
        }
    }

    /** Marque le jeton temporaire comme consommé (usage unique). */
    public void consommer(String jeton) {
        if (jeton != null && !jeton.isBlank()) {
            jetonsConsommes.add(jeton);
        }
    }
}

