package ml.dogo.identite.application;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import java.util.Collections;
import java.util.List;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Service;

/**
 * Implémentation officielle utilisant le SDK Google Auth.
 * Met en cache les clés publiques Google avec respect des en-têtes HTTP Cache-Control
 * et valide cryptographiquement la signature RSA, l'audience, l'émetteur et l'expiration.
 * Ne consigne JAMAIS le contenu des jetons dans les journaux.
 */
@Service
public class GoogleTokenVerifierImpl implements GoogleTokenVerifier {

    private static final Logger LOG = LoggerFactory.getLogger(GoogleTokenVerifierImpl.class);

    private final String clientId;
    private final GoogleIdTokenVerifier verifier;
    private final boolean supportMock;

    public GoogleTokenVerifierImpl(@Value("${dogo.google.client-id:}") String clientId,
                                   Environment environment) {
        this.clientId = clientId != null ? clientId.strip() : "";
        this.supportMock = environment.matchesProfiles("demo", "local", "test");

        GoogleIdTokenVerifier.Builder builder = new GoogleIdTokenVerifier.Builder(
                new NetHttpTransport(), GsonFactory.getDefaultInstance());

        if (!this.clientId.isEmpty()) {
            builder.setAudience(Collections.singletonList(this.clientId));
        }
        builder.setIssuers(List.of("accounts.google.com", "https://accounts.google.com"));
        this.verifier = builder.build();
    }

    @Override
    public GoogleIdTokenInfo verifier(String idToken) {
        if (idToken == null || idToken.isBlank()) {
            throw new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, "RG-07",
                    "Jeton d'authentification Google absent");
        }

        // Support sécurisé des profils demo/local/test pour tests automatisés sans connexion sortante
        if (supportMock && idToken.startsWith("mock-google-token:")) {
            return verifierJetonMock(idToken);
        }

        try {
            GoogleIdToken googleIdToken = verifier.verify(idToken);
            if (googleIdToken == null) {
                LOG.warn("Échec de vérification du jeton Google : signature, audience ou expiration invalide");
                throw new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, "RG-07",
                        "Jeton d'authentification Google invalide ou expiré");
            }

            GoogleIdToken.Payload payload = googleIdToken.getPayload();
            String sub = payload.getSubject();
            String email = payload.getEmail();
            boolean emailVerified = Boolean.TRUE.equals(payload.getEmailVerified());
            String nom = (String) payload.get("name");
            String picture = (String) payload.get("picture");

            if (sub == null || sub.isBlank()) {
                throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-07",
                        "Identifiant Google (sub) absent du jeton");
            }

            return new GoogleIdTokenInfo(
                    sub.strip(),
                    email != null ? email.strip().toLowerCase() : null,
                    emailVerified,
                    nom != null ? nom.strip() : "Utilisateur Google",
                    picture != null ? picture.strip() : null
            );
        } catch (ErreurMetier em) {
            throw em;
        } catch (Exception e) {
            LOG.warn("Erreur lors de la validation cryptographique du jeton Google : {}", e.getMessage());
            throw new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, "RG-07",
                    "Jeton d'authentification Google invalide ou expiré");
        }
    }

    private GoogleIdTokenInfo verifierJetonMock(String mockToken) {
        // Format mock: mock-google-token:sub:email:emailVerified:name:picture
        String payload = mockToken.substring("mock-google-token:".length());
        String[] parts = payload.split(":", -1);
        String sub = parts.length > 0 && !parts[0].isBlank() ? parts[0] : "google-mock-sub-12345";
        String email = parts.length > 1 && !parts[1].isBlank() ? parts[1] : "utilisateur.google@gmail.com";
        boolean emailVerified = parts.length <= 2 || Boolean.parseBoolean(parts[2]);
        String nom = parts.length > 3 && !parts[3].isBlank() ? parts[3] : "Salif Modibo Keïta";
        String picture = parts.length > 4 && !parts[4].isBlank() ? parts[4] : null;

        if ("invalid".equalsIgnoreCase(sub) || "expired".equalsIgnoreCase(sub)) {
            throw new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, "RG-07",
                    "Jeton d'authentification Google invalide ou expiré");
        }
        return new GoogleIdTokenInfo(sub, email, emailVerified, nom, picture);
    }
}

